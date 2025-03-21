#Requires -RunAsAdministrator 
<#
    .SYNOPSIS
        Install Splunk Universal Forwarder service
    .DESCRIPTION
        Install the Forwarder on an endpoint, and complete post-install tasks to ensure the Forward service 
        works properly. Request and install the client certificate. Copy settings files and update. 
    .EXAMPLE
        PS > .\Install-SplunkForwarder.ps1 
        Install Splunk using default parameters
    .NOTES
        The installation file *must* be an MSI. The file is expected to start with "splunkforwarder" and 
        include a version number in the name. The name of the support folder should match this string.
#>
[CmdletBinding()]
param (
    # Path to the folder where the msi is located. Default is the script's root path
    [Parameter(Position=0)][string]$SoftwarePath = $PSScriptRoot
    , # Path to files used to complete post-install. Default is the script's root path
    [Parameter(Position=2)][string]$SupportFilePath = $PSScriptRoot
    , # The desired version of Splunk to install. If not specfied, the "latest" installer found will be used. 
    [Parameter(Position=3)][string]$TargetVersion
    , # If switch is set, this script will output $true for success or $false for any non-terminating error. 
    [switch]$ReturnStatus
    , [Parameter(DontShow)][string]$FQDN = ([System.Net.Dns]::GetHostByName(($env:computerName)).HostName)
    , [Parameter(DontShow)][string]$SiteName = (
        (Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\netlogon\Parameters).DynamicSiteName
    )
    , [Parameter(DontShow)][string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath 'SplunkForwarder.json')
)

#region Support Functions
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

function Start-ExeWithExitCode {
    [CmdletBinding()]
    param (
        [string]$DisplayName
        , [string]$FilePath
        , [string]$ArgumentList
    )
    try {
        if (!$DisplayName) {
            $DisplayName = Split-Path -Path $FilePath -Leaf
        }
        $ExeSettings = @{
            FilePath        =   $FilePath
            ArgumentList    =   $ArgumentList
            PassThru        =   $true
            NoNewWindow     =   $true
            Wait            =   $true
            ErrorAction     =   'Stop'
        }
        $ExeResult = Start-Process @ExeSettings
        Write-Verbose -Message ($DisplayName + ' finished with the ExitCode: ' + $ExeResult.ExitCode)        
    }
    catch {
        Show-CustomError -ErrorRecord $PSItem
    }

}

function Set-FileWithReplace {
    [CmdletBinding()]
    param (
        [string]$SourcePath
        , [string]$TargetPath
        , [string]$PatternString
        , [string]$ReplaceString
    )
    try {
        (Get-Content -Path $SourcePath -ErrorAction Stop) -replace $PatternString,$ReplaceString |
            Out-File -FilePath $TargetPath -Force -ErrorAction Stop
    }
    catch {
        Show-CustomError -ErrorRecord $PSItem
    }
}

function Find-ExeVersion {
    [CmdletBinding()]
    param (
        [string]$SearchString
    )
    try {
        [System.Collections.ArrayList]@(
            'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
        ) | Get-ChildItem -ErrorAction SilentlyContinue | Get-ItemProperty -ErrorAction Stop |
            Where-Object -FilterScript {
                ($PSitem.PSChildName -like $SearchString) -or ($PSitem.DisplayName -like $SearchString) 
            } | Select-Object -ExpandProperty DisplayVersion -First 1
        Write-Verbose -Message "Completed search for $SearchString"
    }
    catch {
        Show-CustomError -ErrorRecord $PSItem
    }
}

function Get-SiteSplunkServer {
    [CmdletBinding()]
    param (
        [string]$SiteName
        , [System.Collections.ArrayList]$SplunkSites
        , [string]$DefaultSplunkServer
    )
    $SplunkServer = $SplunkSites | Where-Object -Property Name -EQ -Value $SiteName | 
        Select-Object -First 1 -ExpandProperty SplunkServer
    if (-not $SplunkServer) {
        $SplunkServer = $DefaultSplunkServer
    }
    $SplunkServer
}
#endregion Support Functions

#region Support Files
try {
    $Config = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    Write-Verbose -Message "Config file loaded ($ConfigPath)"
}
catch {
    Write-Host -ForegroundColor Red -Object (
        'Unable to load file; (' + $_.Exception.GetType().FullName + '); ' +
        'Files: ' + $ConfigPath 
    )
    Return
}
#endregion Support Files

#region Procedure
try {
    Write-Verbose -Message ($MyInvocation.InvocationName + " 0 seconds; Start")

    #region Get MSI Path
    $GetExeSettings = @{
        Path = $SoftwarePath 
        Filter = ($Config.MSIPrefix + '-' + $TargetVersion + '*.msi')
        ErrorAction = 'Stop'
    }
    $ExePath = ((Get-ChildItem @GetExeSettings).FullName | Select-Object -Last 1)
    #endregion Get MSI Path

    #region Install Splunk
    if (
        $TargetVersion -and 
        ((Find-ExeVersion -SearchString '*UniversalForwarder*') -like ($TargetVersion+'*'))
        ) {
        Write-Verbose -Message "Splunk installed with current version $TargetVersion"
    } else {
        $InstallSettings = @{
            DisplayName     =   'Splunk Forwarder Installer'
            FilePath        =   'msiexec.exe'
            ArgumentList    =   '/i "' + $ExePath + '" ' + $Config.InstallOptions
        }
        Start-ExeWithExitCode @InstallSettings
    }
    #endregion Install Splunk

    #region Set Splunk Files
    $InFileParameters = @{
        SourcePath      =   (Join-Path -Path $SupportFilePath -ChildPath 'inputs.conf') 
        TargetPath      =   $Config.LocalFilePaths.inputs
        PatternString   =   'FQDNAME'
        ReplaceString   =   $FQDN
        ErrorAction     =   'Stop'
    }
    Set-FileWithReplace @InFileParameters
    $SiteParameters = @{
        SiteName            =   $SiteName
        SplunkSites         =   $Config.SplunkSites
        DefaultSplunkServer =   $Config.DefaultSplunkServer
    }
    $OutFileParameters = @{
        SourcePath      =   (Join-Path -Path $SupportFilePath -ChildPath 'outputs.conf') 
        TargetPath      =   $Config.LocalFilePaths.outputs
        PatternString   =   'SPLUNKSVR'
        ReplaceString   =   Get-SiteSplunkServer @SiteParameters
        ErrorAction     =   'Stop'
    }
    Set-FileWithReplace @OutFileParameters
    Start-Service -Name 'SplunkForwarder' -ErrorAction Stop
    Write-Verbose -Message "SplunkForwarder started on the $FQDN"
    #endregion Set Splunk Files
}
catch {
    Show-CustomError -ErrorRecord $PSItem
}
finally {
    #region Script Results
    $ReturnResult = [PSCustomObject]@{
        FQDN            =   $FQDN
        SplunkInstalled =   $null
        FilesSet        =   $null
        ServiceStart    =   $null
    }
    Write-Host -ForegroundColor Green 'Splunk Status Validation'
    $TCPParameters = @{
        ComputerName    =   $OutFileParameters.ReplaceString 
        Port            =   $Config.DefaultPort
    }
    if ((Test-NetConnection @TCPParameters).TcpTestSucceeded) {
        Write-Host -ForegroundColor Green -Object '[X] Splunk server is accessible'
    } else {
        Write-Host -ForegroundColor Yellow -Object '[_] Splunk server not found. Please validate DNS or firewall'
    }
    $ExeVersion = Find-ExeVersion -SearchString '*UniversalForwarder*'
    if (($ExeVersion -like ($TargetVersion+'*')) -or ($ExeVersion -and -not $TargetVersion)) {
        Write-Host -ForegroundColor Green -Object '[X] Splunk is installed or updated'
        $ReturnResult.SplunkInstalled = $true
    } else {
        Write-Host -ForegroundColor Red -Object '[!] Splunk is installed or updated'
    }
    if (
        (Get-Content -Path $InFileParameters.TargetPath -ErrorAction SilentlyContinue | 
            Select-String -SimpleMatch $FQDN)
        ) {
        Write-Host -ForegroundColor Green -Object '[X] Splunk files set'
        $ReturnResult.FilesSet = $true
    } else {
        Write-Host -ForegroundColor Red -Object '[!] Splunk files set'
    }
    if (
        $ReturnResult.SplunkInstalled -and 
        ((Get-Service -Name SplunkForwarder -ErrorAction SilentlyContinue).Status -eq 'Running')
        ) {
        Write-Host -ForegroundColor Green -Object '[X] Splunk is running'
        $ReturnResult.ServiceStart = $true
    } elseif ($ReturnResult.SplunkInstalled) {
        Write-Host -ForegroundColor Red -Object '[!] Splunk is running'
    }
    if ($ReturnStatus) {
        $ReturnResult
    }
    #endregion Script Results
}
#endregion Procedure