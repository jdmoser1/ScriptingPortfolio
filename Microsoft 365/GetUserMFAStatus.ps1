<#
.SYNOPSIS
    Report MFA and remote blocked users
.DESCRIPTION
    Get Active AD users in user OU, then get membership in MFA allowed and Remote blocked groups
.EXAMPLE
    GetUserMFAStatus.ps1 -FilePath REDACTEDPATH\UserMFAStatus.csv
    Save csv file at the specified path.
.INPUTS
    FilePath to files save location
.OUTPUTS
    CSV files
#>
[CmdletBinding()]
param (
    [string]$FilePath = 'REDACTEDPATH\UserMFAStatus.csv'
    , [parameter(DontShow)][string]$SearchBase = 'REDACTEDOUPATH'
    , [parameter(DontShow)][string]$MFAGroup = 'REDACTEDNAME'
    , [parameter(DontShow)][string]$BlockedGroup = 'REDACTEDNAME'
)
$ADUsers = (Get-ADUser -SearchBase $SearchBase -Filter 'Enabled -eq $true').SamAccountName 
$MFAUsers = (Get-ADGroupMember -Identity $MFAGroup -ErrorAction SilentlyContinue).SamAccountName
$BlockedUsers = (Get-ADGroupMember -Identity $BlockedGroup -ErrorAction SilentlyContinue).SamAccountName
$ADUsers | ForEach-Object -Process {
    [PSCustomObject]@{
        UserName        =   $_
        MFAAllowed      =   ($_ -in $MFAUsers)
        RemoteBlocked   =   ($_ -in $BlockedUsers)
    }
} | Export-Csv -Path $FilePath -NoTypeInformation -Force
