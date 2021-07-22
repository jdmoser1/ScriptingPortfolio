<#
.SYNOPSIS
    Present a list of users who are locked or password expired, to be remediated.
.DESCRIPTION
    Find all users in the active User OU that are locked out or password expired. Present the list in a GridView
    for the user to review. If the user selects user(s) and select "OK", the selected users will be remediated
    automatically. AD credentials are required, with the right to unlock or change attributes. 
.EXAMPLE
    PS C:\> UnlockUsers.ps1 -Credential $DomainCred
.INPUTS
    PSCredential    Credentials for reading and making changes to Active Directory
.OUTPUTS
    N/A
.NOTES
    This script must be interacted with. It is not intended for full automation. 
#>
[CmdletBinding()]
param (
    [parameter(DontShow)][string]$BaseOU = 'REDACTEDOUPATH'
    , [pscredential]$Credential = (Get-Credential)
)
try {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'UserSupport.psm1') -Force
    $ADUserSettings = @{
        SearchBase = $BaseOU 
        Filter = 'Enabled -eq $true' 
        Properties =  @('LockedOut', 'LastBadPasswordAttempt', 'PasswordExpired', 'PasswordLastSet')
        Credential = $Credential
        ErrorAction = 'Stop'
    }
    Get-ADUser @ADUserSettings | Find-LockedUser -Verbose | Out-GridView -PassThru | 
        Enable-LockedUser -Credential $Credential -Verbose
}
catch {
    Show-CustomError -ErrorRecord $PSItem
}

