# Path to save output objects
$JSONRoot = 'C:\Sample'
$SharedMailPath = Join-Path -Path $JSONRoot -ChildPath 'SharedMailboxUsers.json'
$DistroMemberPath = Join-Path -Path $JSONRoot -ChildPath 'DistroMembers.json'
$DistroSendAsPath = Join-Path -Path $JSONRoot -ChildPath 'DistroSendAsUsers.json'
$SendAsUsersPath = Join-Path -Path $JSONRoot -ChildPath 'SendAsUsers.json'
$AliasPath = Join-Path -Path $JSONRoot -ChildPath 'Aliases.json'
# Fitler string to exclude in valid user(s)
$InvalidUserFilter = 'S-1-5-21-'
$DistroInvalidFilter = 'SELF'
# domain designator to be stripped
$RemoveString = 'Sample.ninja\'
# List of default Users to exclude from Shared Malbox access
$DefaultFullAccessUsers = [System.Collections.ArrayList]@(
    'NT AUTHORITY\SELF'
    'Sample.ninja\Domain Admins'
    'Sample.ninja\Enterprise Admins'
    'Sample.ninja\Organization Management'
    'Sample.ninja\Administrator'
    'Sample.ninja\Exchange Servers'
    'Sample.ninja\Exchange Domain Servers'
    'Sample.ninja\Public Folder Management'
    'NT AUTHORITY\SYSTEM'
    'NT AUTHORITY\NETWORK SERVICE'
    'Sample.ninja\Delegated Setup'
    'Sample.ninja\Exchange Trusted Subsystem'
    'Sample.ninja\Exchange Services'
    'SampleUser0'
    'BUILTIN\Administrators'
    'SampleUser1'
    'Everyone'
    'NT AUTHORITY\ANONYMOUS LOGON'
    'Sample.ninja\Discovery Management'
)
# Filter aliases to only include arborfcu.org and eccu1.org aliases
$AliasFilter = '.org'


# Distribution List Members
# will be using Add-DistributionGroupMember; example params -Identity distrogroup -Member mailbox
# due to Exchange/PowerShell brokenness, load group list to temp variable, then pipe the variable
$TempDistroGroups = Get-DistributionGroup | Select-Object -ExpandProperty Alias
$TempDistroGroups | ForEach-Object -Process {
        Get-DistributionGroupMember -Identity $PSItem | ForEach-Object -Begin {
                $CurrentDistro = $PSItem
            } -End {
                Remove-Variable -Name CurrentDistro
            } -Process {
                Write-Output -InputObject (
                    [PSCustomObject]@{
                        Mailbox = $PSItem.Alias
                        GroupName = $CurrentDistro
                    }
                )
            }
} | ConvertTo-Json | Out-File -FilePath $DistroMemberPath -Force
Remove-Variable -Name TempDistroGroups

# Process mailboxes for FullAccess Permissions
# due to Exchange/PowerShell brokenness, load mailbox list to temp variable, then pipe the variable
$TempMailboxes = Get-Mailbox | Select-Object -ExpandProperty Alias
$TempMailboxes | ForEach-Object -Process {
    Get-MailboxPermission -Identity $PSItem | Where-Object -FilterScript {
        ($PSItem.User -NotIn $DefaultFullAccessUsers) -and ($PSItem.User -notmatch $InvalidUserFilter)
        } | ForEach-Object -Begin {
            $CurrentSharedMailbox = $PSItem
        } -End {
            Remove-Variable -Name CurrentSharedMailbox
        } -Process {
            Write-Output -InputObject (
                [PSCustomObject]@{
                    Mailbox = $CurrentSharedMailbox
                    FullAccessUser = $PSItem.User.Replace($RemoveString,'')
                }
            )
        }
} | ConvertTo-Json | Out-File -FilePath $SharedMailPath -Force
Remove-Variable -Name TempMailboxes

# Get email address aliases for each recipient and organize in a list
Get-Recipient |  Where-Object -Property RecipientTypeDetails -EQ -Value 'UserMailbox' |
    Select-Object -Property PrimarySmtpAddress,Alias,EmailAddresses | ForEach-Object -Process {
        $PSItem.EmailAddresses | Select-String -Pattern $AliasFilter -SimpleMatch | ForEach-Object -Begin {
            $CurrentPrimary = $PSItem.PrimarySmtpAddress
            $CurrentMailbox = $PSItem.Alias
        } -End {
            Remove-Variable -Name CurrentPrimary
            Remove-Variable -Name CurrentMailbox
        } -Process {
            $TempAlias = $PSItem.ToString().ToLower().Replace('smtp:','')
            if ($TempAlias -ne $CurrentPrimary) {
                Write-Output -InputObject (
                    [PSCustomObject]@{
                        Mailbox = $CurrentMailbox
                        Alias = $TempAlias
                    }
                )
            }
            Remove-Variable -Name TempAlias
        }
} | ConvertTo-Json | Out-File -FilePath $AliasPath -Force

# Get list of "Send As" users for distribution groups
$Distros = Get-DistributionGroup 
$Distros | ForEach-Object -Process {
    Write-Host  $PSItem.Name        
    Get-ADPermission -Identity $PSItem.Name | Where-Object {
        ($PSItem.ExtendedRights -like '*Send-As*') -and 
        ($PSItem.IsInherited -eq $false) -and 
        ($PSItem.User -notlike '*SELF')
    } | ForEach-Object -Begin {
        $CurrentMailbox = $PSItem.SamAccountName
        Write-Host  $PSItem.SamAccountName
    } -End {
        Remove-Variable -Name CurrentMailbox
    } -Process {
        Write-Host $PSItem.User.Replace($RemoveString,'')
        Write-Output -InputObject (
            [PSCustomObject]@{
                Mailbox =   $CurrentMailbox
                User    =   $PSItem.User.Replace($RemoveString,'')
            }
        )
    }
} | ConvertTo-Json | Out-File -FilePath $DistroSendAsPath -Force
    
# Get list of "Send As" users for gemeral mailboxes
$Mailboxes = Get-Mailbox 
$Mailboxes | ForEach-Object -Process {
    Write-Host  $PSItem.Name        
    Get-ADPermission -Identity $PSItem.Name | Where-Object {
        ($PSItem.ExtendedRights -like '*Send-As*') -and 
        ($PSItem.IsInherited -eq $false) -and 
        ($PSItem.User -notlike '*SELF')
    } | ForEach-Object -Begin {
        $CurrentMailbox = $PSItem.SamAccountName
        Write-Host  $PSItem.SamAccountName
    } -End {
        Remove-Variable -Name CurrentMailbox
    } -Process {
        Write-Host $PSItem.User.Replace($RemoveString,'')
        Write-Output -InputObject (
            [PSCustomObject]@{
                Mailbox =   $CurrentMailbox
                User    =   $PSItem.User.Replace($RemoveString,'')
            }
        )
    }
} | ConvertTo-Json | Out-File -FilePath $SendAsUsersPath -Force
    
    