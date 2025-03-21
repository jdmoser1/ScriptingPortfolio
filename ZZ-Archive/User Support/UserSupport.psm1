#Requires -Modules ActiveDirectory 
#region message
$ModuleMessageSettings = @{
    Message =   'UserSupport loaded. For more detail, enter "Get-Module UserSupport | Format-List"'
    Verbose =   $true
}
Write-Verbose @ModuleMessageSettings
#endregion message

#region support functions
function Show-CustomError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    Write-Host -ForegroundColor Red -Object ("ERROR:`t" + $ErrorRecord.Exception.Message)
    Write-Host -ForegroundColor Red -Object ("`t" + $ErrorRecord.ScriptStackTrace.Replace("`n","`n`t"))
    if ($ErrorRecord.TargetObject) {
        Write-Host -ForegroundColor Red -Object ("`tObject:`t" + $ErrorRecord.TargetObject)
    }
    Write-Host -ForegroundColor Red -Object ("`tLine:`t" + $ErrorRecord.InvocationInfo.Line.Trim())
    Write-Host -ForegroundColor Red -Object ("`tType:`t" + $ErrorRecord.Exception.GetType().FullName)
}

function DateDifference {
    param(
        $DateTime 
    )
    if ($null -eq $DateTime) {
        0
    } else {
        [int16]((Get-Date) - ($DateTime)).Days
    }
}
#endregion support functions

#region public functions
function Find-LockedUser {
    <#
    .SYNOPSIS
        Find users that are password expired or locked out.
    .DESCRIPTION
        Validates user acounts for issues that would prevent login (does not check for 'Disabled' state). User 
        list should come from AD and include the properties lockedout, lastbadpasswordattempt, and
        passwordlastset in addition to the defaults. Lock out and expired statuses are identified by a $true 
        result
    .EXAMPLE
        PS C:\> Get-Adusers -Properties lockedout,lastbadpasswordattempt,passwordlastset | Find-LockedUser
    .INPUTS
        PSCustomOpject  ADUser object(s)
    .OUTPUTS
        PSCustom object
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory,ValueFromPipeline)][PSCustomObject]$User
        # , [parameter(DontShow)][int16]$MaxDays = 42
    )
    begin { 
        Write-Verbose -Message ($MyInvocation.InvocationName + "; Start")
        $i = 0 
    }
    end {
        Write-Verbose -Message ($MyInvocation.InvocationName + "; Task Complete. $i Total")
    }
    process {
        try {
            if ($User.LockedOut -or $User.PasswordExpired) {
                [PSCustomObject]@{
                    Name                    =   $User.Name
                    SamAccountName          =   $User.SamAccountName
                    LockedOut               =   $User.LockedOut
                    PasswordExpired         =   $User.PasswordExpired
                    LastBadPasswordAttempt  =   $User.LastBadPasswordAttempt
                    PasswordDays            =   (DateDifference -DateTime $User.PasswordLastSet)
                    PasswordLastSet         =   $User.PasswordLastSet
                }
                Write-Verbose -Message ($MyInvocation.InvocationName + "; Found issue with " + $User.Name)
                $i++
            }
        }
        catch {
            Show-CustomError -ErrorRecord $PSItem
        }
    }
}

function Enable-LockedUser {
    <#
    .SYNOPSIS
        Unlock or reset expiration on AD accounts
    .DESCRIPTION
        Check if LockedOut or PasswordExpired are true. Unlock account, Reset expiration, or both.
    .EXAMPLE
        PS C:\> $LockedUsers | Enable-LockedUser -Credential $Credential
        Explanation of what the example does
    .INPUTS
        PSCustomOpject  ADUser object(s)
        PSCredential    Credential used to make chanes in AD
    .OUTPUTS
        N/A
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory,ValueFromPipeline)][PSCustomObject]$User
        , [pscredential]$Credential = (Get-Credential)
    )
    begin { 
        Write-Verbose -Message ($MyInvocation.InvocationName + "; Start")
        $i = 0 
    }
    end {
        Write-Verbose -Message ($MyInvocation.InvocationName + "; Task Complete. $i Total")
    }
    process {
        try {
            if ($User.LockedOut) {
                Unlock-ADAccount -Identity $User.SamAccountName -Credential $Credential -ErrorAction Stop
                Write-Verbose -Message (
                    $MyInvocation.InvocationName + "; "  + $User.SamAccountName + ' unlocked' 
                )
            }
            if ($User.PasswordExpired) {
                $ClearExpirationParameters = @{
                    Identity    =   $User.SamAccountName
                    Replace     =   @{PwdLastSet=0} 
                    ErrorAction =   "Stop" 
                    Credential  =   $Credential
                }
                Set-ADUser @ClearExpirationParameters
                $ResetExpirationParameters = @{
                    Identity    =   $User.SamAccountName
                    Replace     =   @{PwdLastSet=-1} 
                    ErrorAction =   "Stop" 
                    Credential  =   $Credential
                }
                Set-ADUser @ResetExpirationParameters
                Write-Verbose -Message (
                    $MyInvocation.InvocationName + "; "  + $User.SamAccountName + ' expiration reset' 
                )
            }
            $i++
        }
        catch {
            Show-CustomError -ErrorRecord $PSItem
        }

    }
}
#endregion public functions
