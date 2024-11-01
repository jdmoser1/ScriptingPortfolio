<#
    This procedure script handles these tasks:
        Check for near-term password expirations for Active Directory 
        and Fourth Shift Users. Also email the user if email is available.
    This script requires the SQL and AD modules on the local server
#>
Param(
    [Switch]$Logonly = $False
)

# Create initial setup, run commands, and capture errors
Try {
    ## Initial setup
    $Error.Clear()
    $TimeStart = Get-Date
    # Create the PowerUtils drive at the Procedure path, and set as working directory
    If (-not ((Get-PSDrive) -match 'PowerUtils')) {
        New-PSDrive -Name 'PowerUtils' -PSProvider FileSystem -Root (Split-Path $MyInvocation.MyCommand.Path -Parent) -Scope Global
    }
    # Create new log
    $ProcedureName = (Get-Item $MyInvocation.MyCommand.Path).BaseName
    $LogFile = Join-Path -Path PowerUtils:\Logs -ChildPath ($ProcedureName + '-' + (Get-Date -Format yyyy-MM-dd-HHmmss) + '.log')
    Start-Transcript -Path $LogFile -IncludeInvocationHeader
    # Distinguished names in AD to search for users
    $ADOU = "OU=Sample,DC=Sample,DC=ninja"
    # Database server for Fourth Shift
    $DBServer = 'SampleServer'
    $Database = 'Sample0'  
    # Message settings
    $SMTPServer = "Sample1"
    $MessageSender = "sample@sample.ninja"

    ## Validate required modules
    If ('SqlServer' -notin (Get-Module -ListAvailable).Name) { Write-Warning -Message 'SqlServer module not found' }
    If ('ActiveDirectory' -notin (Get-Module -ListAvailable).Name) { Write-Warning -Message 'Active Directory module not found' }

    # Number of days that passwords are set to expire in AD
    $ADExpiration = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge.TotalDays
    # days that passwords expire in Fourth Shift
    $FSExpiration = (Invoke-Sqlcmd -ServerInstance $DBServer -Database $Database -Query "Select MaximumExpirationDays FROM FS_PasswordConfig" -ConnectionTimeout 240).MaximumExpirationDays

    ## Run commands
    # Get list of AD Users and check for expiration. Nofity as needed
    Get-ADUser -Filter {(PasswordNeverExpires -eq $false) -and (Enabled -eq $true)} -SearchBase $ADOU -Properties Name,PasswordLastSet,EmailAddress | `
        ForEach-Object -Process {
            # Detect users who have expiration but no listed email
            If (-not $_.EmailAddress) { 
                $UserException += $_.Name + " has an AD account but no listed email address. <br\>`n"
            }
            # Get number of days left before expiration
            If ($_.PasswordLastSet -eq $null) {
                $ADUserDays = 90
            } Else {
                $ADUserName = $_.Name
                $ADUserDays = $ADExpiration - [System.Math]::Round((((Get-Date) - $_.PasswordLastSet).TotalDays),0) 
                Switch ($ADUserDays){
                    10  { $ADUserMessage = "There are 10 days remaining until your computer password expires." }
                    5   { $ADUserMessage = "There are 5 days remaining until your computer password expires." }
                    3   { $ADUserMessage = "There are 3 days remaining until your computer password expires." }
                    2   { $ADUserMessage = "There are 2 days remaining until your computer password expires." }
                    1   { $ADUserMessage = "There is 1 day remaining until your computer password expires." }
                    0   { 
                            $ADUserMessage = "Your computer account will expire today if you do not change your password soon." 
                            $UserException += "$ADUserName has an expired AD password ($ADUserDays days) <br\>`n"
                        }
                    -2  {   $ADUserMessage = $False
                            $UserException += "$ADUserName has an expired AD password ($ADUserDays days) <br\>`n"  
                        }
                    Default { $ADUserMessage = $False }
                }
            }
            # Document expired accounts
            If ($ADUserMessage) {
                $ADMessageBody = "<p>Hello,</p>
                    <p>
                    $ADUserMessage
                    </p>
                    <p>
                    To change your password now, press CTRL-ALT-Delete and select 
                    `"Change Password.`" New passwords should be 8 characters in length and 
                    different from what you used previously. For assistance, please contact the IT
                    Department.
                    </p>"
                # Enable for testing
                Write-Output -InputObject ( $_.Name + ' - ' + $ADUserMessage )
                If (-not $Logonly) {
                    $ADMessageSubject = "Notice: Your computer password will expire soon."
                    Send-MailMessage -SmtpServer $SMTPServer  -To $_.EmailAddress -From $MessageSender -Subject $ADMessageSubject -Body $ADMessageBody -BodyAsHtml
                }
            }
            $ADUserMessage = $False
        }
    # Get list of FShift Users and check for expiration. Nofity as needed 
    $FSUserQuery = "SELECT UserName,LastMaintainedDate,UserEmail FROM FS_UserAccess WHERE AccountStatus='A' AND Expire='Y'"
    Invoke-Sqlcmd -ServerInstance $DBServer -Database $Database -Query $FSUserQuery -ConnectionTimeout 240 | `
        ForEach-Object -Process {
            $FSUserName = $_.UserName.Trim()
            $FSUserDays = $FSExpiration - [System.Math]::Round((((Get-Date) - (Get-Date -Date $_.LastMaintainedDate)).TotalDays),0)
            Switch ($FSUserDays){
                10  { $FSUserMessage = "There are 10 days remaining until your Fourth Shift password expires." }
                5   { $FSUserMessage = "There are 5 days remaining until your Fourth Shift password expires." }
                3   { $FSUserMessage = "There are 3 days remaining until your Fourth Shift password expires." }
                2   { $FSUserMessage = "There are 2 days remaining until your Fourth Shift password expires." }
                1   { $FSUserMessage = "Your Fourth Shift account will expire today if you do not change your password soon." }
                0   { 
                        $FSUserMessage = $False
                        $UserException += $FSUserName + " has an expired FS password ($FSUserDays days) <br\>`n" 
                    }
                -2  { 
                        $FSUserMessage = $False
                        $UserException += $FSUserName + " has an expired FS password ($FSUserDays days) <br\>`n" 
                    }
                Default { $FSUserMessage = $False }
            }
            # Clean excess whitespace
            $FSUserEmail = $_.UserEmail.Trim()
            # Not all FS users have emails. For the ones that don't create a UserException for the SysAdmin to review
            If ($FSUserMessage -and -not $FSUserEmail) { 
                $UserException += $_.UserName.Trim() + " does not have an email listed. Message: $FSUserMessage. <br\>`n"
            } Elseif ($FSUserMessage) {
                $FSMessageBody = "<p>Hello,</p>
                    <p>
                    $FSUserMessage
                    </p>
                    <p>
                    To change your password in Forth Shift, enter the PASS function. For `"Starting 
                    User ID,`" enter your initials. Type your password twice under `"Password.`"
                    New passwords should be 8 characters in length and different from what you used 
                    previously. For assistance, please contact the IT Department.
                    </p>"
                # Enable for testing
                Write-Output -InputObject ( $_.UserName.Trim() + ' - ' + $FSUserMessage )
                If (-not $Logonly) {
                    $FSMessageSubject = "Notice: Your Fourth Shift password will expire soon."
                    Send-MailMessage -SmtpServer $SMTPServer  -To $FSUserEmail -From $MessageSender -Subject $FSMessageSubject -Body $FSMessageBody -BodyAsHtml
                }
            }
            $FSUserMessage = $False
        }

    # Send user exception report to IT
    If ($UserException) {
        Write-Output -InputObject $UserException
        PowerUtils:\Scripts\SendNotification-r3.ps1 -MessageLevel "Test" -MessageSubject "User Exceptions: $LogName" -MessageContent $UserException -ComputerName $env:COMPUTERNAME
    }

    ## Wrap up
    # Write nonfatal errors to log
    $ProcedureErrors = PowerUtils:\Scripts\FormatErrors-r1.ps1
    If ($ProcedureErrors) {
        Write-Output -InputObject '*Last detected errors*' 
        Write-Output -InputObject $ProcedureErrors
        # Notify the System Administrator of the error
        $LogFileFullPath = (Get-Item -Path $LogFile).FullName
        $MessageContent = "Review the log for more details. ($LogFileFullPath)"
        PowerUtils:\Scripts\SendNotification-r3.ps1 -MessageLevel 'Warning' -MessageSubject "Error: $ProcedureName" -MessageContent $MessageContent -ComputerName $env:COMPUTERNAME
    }
} Catch {
    Write-Output -InputObject '*Terminating errors*'
    PowerUtils:\Scripts\FormatErrors-r1.ps1
    # Notify the System Administrator of the error
    $LogFileFullPath = (Get-Item -Path $LogFile).FullName
    $MessageContent = "Review the log for more details. ($LogFileFullPath)"
    PowerUtils:\Scripts\SendNotification-r3.ps1 -MessageLevel 'Warning' -MessageSubject "*Terminating* Error: $ProcedureName" -MessageContent $MessageContent -ComputerName $env:COMPUTERNAME
} Finally {
    # Get completion time for the script
    Write-Output -InputObject ("Log started at $TimeStart `n")
    $TotalTime = (Get-Date) - $TimeStart
    Write-Output -InputObject ('Script ran for ' + $TotalTime.Days + 'd, ' + $TotalTime.Hours + 'h, ' + $TotalTime.Minutes + 'm, ' + $TotalTime.Seconds + 's.')
    Write-Output -InputObject ("Last logged entry at " + (Get-Date))
    Stop-Transcript
}


