<#
.SYNOPSIS
    Remotely install Disribution Service on on multiple servers, and set the Patch and Software registry keys.
.NOTES
    General notes
#>
[CmdletBinding()]
param (
    [pscredential]$Credential = (Get-Credential)
    , [parameter(DontShow)][System.Collections.ArrayList]$Servers = @(
        'REDACTEDNAME0'
        'REDACTEDNAME1'
        'REDACTEDNAME2'
        'REDACTEDNAME3'
        'REDACTEDNAME4'
        'REDACTEDNAME5'
        'REDACTEDNAME6'
        'REDACTEDNAME7'
    )
    , [parameter(DontShow)][string]$SoftwarePath = 'REDACTEDPATH'
    , [parameter(DontShow)][string]$LocalPath = 'REDACTEDPATH'
    , [parameter(DontShow)][string]$LocalPatchstore = 'REDACTEDPATH'
    , [parameter(DontShow)][string]$LocalRepository = 'REDACTEDPATH'
)


$Servers | ForEach-Object -Process {
    Write-Output -InputObject ('Starting DCDistribution Install on ' + $PSItem + ' at ' + (Get-Date).DateTime)
    $CurrentSession = New-PSSession -ComputerName $PSItem -Credential $Credential
    Copy-Item -Path $SoftwarePath -Destination $LocalPath -ToSession $CurrentSession -Recurse -Force
    Invoke-Command -Session $CurrentSession -ScriptBlock {
        $SplatProcess = @{
            FilePath            =   'msiexec.exe' 
            ArgumentList        =   '/i DCDistributionServer.msi TRANSFORMS="DCDistributionServer.mst" ' + 
                            'ENABLESILENT=yes REBOOT=ReallySuppress INSTALLTYPE=Manual /quiet ' + 
                            '/lv DSInstallerlog.log'
            WorkingDirectory    =   $Using:LocalPath 
            Wait                =   $true
            NoNewWindow         =   $true
        }
        Start-Process @SplatProcess
        Get-Content -Path 'REDACTEDPATH\DSInstallerlog.log' -Tail 4
        New-Item -Path $Using:LocalPatchstore -Force
        New-Item -Path $Using:LocalRepository -Force
        Set-ItemProperty -Path 'REDACTEDPATH' -Name PatchStore_Directory -Value 'REDACTEDPATH' #-PropertyType String
        Set-ItemProperty -Path 'REDACTEDPATH' -Name SoftwareRepo_Directory -Value 'REDACTEDPATH' #-PropertyType String
        Restart-Service -Name 'REDACTEDNAME'
    }
    Remove-Variable CurrentSession
}