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
        'SampleServer0'
        'SampleServer1'
        'SampleServer2'
        'SampleServer3'
        'SampleServer4'
        'SampleServer5'
        'SampleServer6'
        'SampleServer7'
    )
    , [parameter(DontShow)][string]$SoftwarePath = '\\SampleServer\Sample'
    , [parameter(DontShow)][string]$LocalPath = 'D:\Sample'
    , [parameter(DontShow)][string]$LocalPatchstore = 'C:\Sample\Patchstore'
    , [parameter(DontShow)][string]$LocalRepository = 'C:\Sample\Repository'
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
        Get-Content -Path 'D:\Sample\DSInstallerlog.log' -Tail 4
        New-Item -Path $Using:LocalPatchstore -Force
        New-Item -Path $Using:LocalRepository -Force
        Set-ItemProperty -Path 'HKLM:\Sample' -Name PatchStore_Directory -Value $Using:LocalPatchstore 
        Set-ItemProperty -Path 'HKLM:\Sample' -Name SoftwareRepo_Directory -Value $Using:LocalRepository
        Restart-Service -Name 'Sample'
    }
    Remove-Variable CurrentSession
}