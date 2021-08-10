<#
.SYNOPSIS
    Report MFA and remote blocked users
.DESCRIPTION
    Get Active AD users in user OU, then get membership in MFA allowed and Remote blocked groups
.EXAMPLE
    GetUserMFAStatus.ps1 -FilePath C:\Sample\UserMFAStatus.csv
    Save csv file at the specified path.
.INPUTS
    FilePath to files save location
.OUTPUTS
    CSV files
#>
[CmdletBinding()]
param (
    [string]$FilePath = 'C:\Sample\UserMFAStatus.csv'
    , [parameter(DontShow)][string]$SearchBase = 'OU=Sample,DC=Sample,DC=ninja'
    , [parameter(DontShow)][string]$MFAGroup = 'Sample0'
    , [parameter(DontShow)][string]$BlockedGroup = 'Sample1'
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
