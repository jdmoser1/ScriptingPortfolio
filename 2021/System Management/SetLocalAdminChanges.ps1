#Requires -RunAsAdministrator 
<#
.SYNOPSIS
    Enforce local user account compliance
.DESCRIPTION
    This procedure completes the following tasks:
        Disable all local accounts except the approved account in the JSON file
        Rename the Administrator account
        Reset the password for the Administrator account
        Reset the password for the local account defined in the JSON
.INPUTS
    Path to configuration JSON file
.OUTPUTS
    N/A
.NOTES
    Template version 2021-07-29
#>
[CmdletBinding()]
param (
    [string]$JsonPath = (Join-Path -Path $PSScriptRoot -ChildPath 'LocalAdminChanges.json')
)

#region Support Functions
function Show-MessageHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Name
        , [Parameter(Mandatory)][datetime]$StartTime
    )
    $Name + "`t" + [math]::Round(((Get-Date)-$StartTime).TotalSeconds,3) +";`t"
}

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
#endregion Support Functions

#region Procedure
try {
    Write-Verbose -Message ($MyInvocation.MyCommand.Name + "`t0 seconds;`tStart")
    $StartTime = Get-Date
    $Config = Get-Content -Path $JsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    Get-LocalUser | Where-Object -Property Name -Ne $Config.LocalAdmin.Name | 
        Disable-LocalUser -ErrorAction Stop
    Write-Verbose -Message (
        (Show-MessageHeader -Name $MyInvocation.MyCommand.Name -StartTime $StartTime) +
        'Disabled accounts except for ' + $Config.LocalAdmin.Name
    )    
    try {
        Rename-LocalUser -Name Administrator -NewName $Config.Administrator.NewName -ErrorAction Stop
        Write-Verbose -Message (
            (Show-MessageHeader -Name $MyInvocation.MyCommand.Name -StartTime $StartTime) +
            'Renamed Administrator account to ' + $Config.Administrator.NewName
        )        
    }
    catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
        Write-Verbose -Message (
            (Show-MessageHeader -Name $MyInvocation.MyCommand.Name -StartTime $StartTime) +
            'Could not find Administrator account'
        )
    }
    $SASettings = @{
        Name        =   $Config.Administrator.NewName 
        Password    =   (ConvertTo-SecureString -String $Config.Administrator.SecureString -Key $Config.Key)
    }
    Set-LocalUser @SASettings 
    Write-Verbose -Message (
        (Show-MessageHeader -Name $MyInvocation.MyCommand.Name -StartTime $StartTime) +
        'Set ' + $Config.Administrator.NewName + ' password'
    )
    $SLASettings = @{
        Name                    =   $Config.LocalAdmin.Name
        Password        =   (ConvertTo-SecureString -String $Config.LocalAdmin.SecureString -Key $Config.Key)
        PasswordNeverExpires    =   $true
        AccountNeverExpires     =   $true
        ErrorAction             =   'Stop'
    }
    try {
        Set-LocalUser @SLASettings
    }
    catch [Microsoft.PowerShell.Commands.UserNotFoundException] {
        New-LocalUser @SLASettings
    }
    Write-Verbose -Message (
        (Show-MessageHeader -Name $MyInvocation.MyCommand.Name -StartTime $StartTime) +
        'Set ' + $Config.LocalAdmin.Name + ' password'
    )
    Write-Verbose -Message (
        (Show-MessageHeader -Name $MyInvocation.MyCommand.Name -StartTime $StartTime) +
        'Procedure complete'
    )
}
catch {
    Show-CustomError -ErrorRecord $PSItem
}
#endregion Procedure

