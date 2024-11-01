# Path to save output objects
$JSONRoot = 'C:\Sample'
$SharedMailPath = Join-Path -Path $JSONRoot -ChildPath 'SharedMailboxUsers.json'
$DistroMemberPath = Join-Path -Path $JSONRoot -ChildPath 'DistroMembers.json'
$AliasPath = Join-Path -Path $JSONRoot -ChildPath 'Aliases.json'
$SendAsUsersPath = Join-Path -Path $JSONRoot -ChildPath 'SendAsUsers.json'

# "List" of access rights to add
$AccessRight = 'FullAccess'
# string  to add to identity to complete the UPN
$AtSuffix = '@Sample.ninja'
# "List" of access rights to add
$SendAsRight = 'SendAs'

# add the user to ditribution groups if missing
# ConvertFrom-Json is enclosed to force enumeration. See https://github.com/PowerShell/PowerShell/issues/3424
(Get-Content -Path $DistroMemberPath -Raw | ConvertFrom-Json) | 
    Where-Object -FilterScript {
        $PSItem.Mailbox -notin (Get-DistributionGroupMember -Identity $PSItem.GroupName | Select-Object -ExpandProperty alias)
    } | ForEach-Object -Process {
        Add-DistributionGroupMember -Identity $PSItem.GroupName -Member $PSItem.Mailbox
    }

# add the user to the mailbox, given the user isn't already there, with AccessRight permissions
# ConvertFrom-Json is enclosed to force enumeration. See https://github.com/PowerShell/PowerShell/issues/3424
(Get-Content -Path $SharedMailPath -Raw | ConvertFrom-Json) | 
    Where-Object -FilterScript {-not (Get-MailboxPermission -Identity $PSItem.Mailbox -User $PSItem.FullAccessUser)} | 
    ForEach-Object -Process {
        Add-MailboxPermission -Identity $PSItem.Mailbox -User $PSItem.FullAccessUser -AccessRights $AccessRight
    }

# add alias to the user, given the alias isn't already there
# ConvertFrom-Json is enclosed to force enumeration. See https://github.com/PowerShell/PowerShell/issues/3424
(Get-Content -Path $AliasPath -Raw | ConvertFrom-Json) | 
    ForEach-Object -Process {
        $CurrentMailbox = Get-Recipient -Identity $PSItem.Mailbox -ErrorAction SilentlyContinue
        if ($PSItem.Alias -notin $CurrentMailbox.EmailAddresses.ToLower().Replace('smtp:','')) {
            $CurrentAliases = $CurrentMailbox.EmailAddresses
            $CurrentAliases.Add('smtp:'+$PSItem.Alias) | Out-Null
            Set-Mailbox -Identity $PSItem.Mailbox -EmailAddresses $CurrentAliases
            Remove-Variable -Name CurrentAliases
        }
        Remove-Variable -Name CurrentMailbox
    }

# Get object list and process for user additions
(Get-Content -Path $SendAsUsersPath -Raw | ConvertFrom-Json) | Where-Object -FilterScript {
    ($PSItem.User + $AtSuffix) -notin (Get-RecipientPermission -AccessRights $SendAsRight -Identity $PSItem.Mailbox).Trustee
} | ForEach-Object -Process {
    $SplatAddPermission = @{
        AccessRights    =   $SendAsRight
        Identity        =   $PSItem.Mailbox
        Trustee         =   ($PSItem.User + $AtSuffix)
        Confirm         =   $false
    }
    Add-RecipientPermission @SplatAddPermission
    Remove-Variable -Name SplatAddPermission
}
