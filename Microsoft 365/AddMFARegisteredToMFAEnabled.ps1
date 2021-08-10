[CmdletBinding()]
param (
    [pscredential]$DomainCredential = (Get-Credential)
    , [parameter(DontShow)][string]$AllowGroup = 'REDACTEDNAME'
    , [parameter(DontShow)][string]$DenyGroup = 'REDACTEDNAME'
)
if (-not (Get-MsolDomain -ErrorAction SilentlyContinue)) {
    Connect-MsolService
}
#Connect-MsolService -Credential $O365Credential
Get-MsolUser -All -ErrorAction Stop | 
  Where-Object { $PSitem.StrongAuthenticationMethods -ne $null -and $PSitem.BlockCredential -eq $False } | 
  ForEach-Object -Process { Get-ADUser -Filter ('UserPrincipalName -eq "' + $PSItem.UserPrincipalName + '"') } | 
  ForEach-Object -Process { 
      $SplatGroupAdd = @{
          Identity    =   $AllowGroup 
          Members     =   $PSitem.SamAccountName 
          Credential  =   $DomainCredential
      }
      Add-ADGroupMember @SplatGroupAdd
      $SplatGroupRemove = @{
          Identity    =   $DenyGroup
          Members     =   $PSitem.SamAccountName 
          Credential  =   $DomainCredential
          Confirm     =   $false
      }
      Remove-ADGroupMember @SplatGroupRemove
      Write-Output -InputObject ('Updated ' + $PSItem.UserPrincipalName)
  }