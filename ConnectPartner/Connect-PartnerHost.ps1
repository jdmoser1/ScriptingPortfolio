<#
    .SYNOPSIS
        Provide connectivity to hosts in Sample Partner cloud environment using the provided security proxy 
        configuration. 
    .DESCRIPTION
        Provide connectivity to hosts in Sample Partner cloud environment using the provided security proxy 
        configuration. A host list is required in a CSV file, which is downloaded weekly from Sample
        Partner's Device 42 site. The user is presented a a list from the CSV, where individual hosts can be 
        selected. Multiple hosts can be selected at a time. After confirmed, an SSH window will open for each
        host. The user is still required to enter their password, as provided by Sample Partner
    .EXAMPLE
        PS C:\> Connect-PartnerHost.ps1 -PartnerUserName testuser -HostListPath C:\path\PartnerHosts.csv
        Use the username provided by Sample Partner, and present a list to select from the file "PartnerHosts.csv"
    
    .OUTPUTS
        None
#>
[CmdletBinding()]
param (
    # Username used to access hosts by SSH. Contact Sample Partner support if you were not provided a Username
    [Parameter(Mandatory,Position=0)][string]$PartnerUserName,
    # File path to host list file. File must be CSV. The recommendation is to use the [REDACTED]
    # [REDACTED], export as XLSX, and use Excel to convert to CSV. If not specified execution path will be 
    # checked for a CSV, then finally you will be asked to select a file
    [Parameter(Position=1)][string]$HostListPath,
    # Fully qualified domain name for a specific host. The script will ignore the HostListPath parameter and 
    # attempt to to directly connect to this host
    [Parameter(Position=2)][string]$HostName
)

#region Support Functions
function Show-EHMessageHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Name
        , [Parameter(Mandatory)][datetime]$StartTime
    )
    $Name.Split('\')[-1] + ' ' + [math]::Round(((Get-Date)-$StartTime).TotalSeconds,3) + '; '
}

function Show-EHCustomError {
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

function Read-EHFileDialog {
    # Code used from https://4sysops.com/archives/how-to-create-an-open-file-folder-dialog-box-with-powershell/ 
    [CmdletBinding()]
    param (
        [string]$InitialPath = $PSScriptRoot
    )
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = $InitialPath
    }
    $FileBrowser.ShowDialog() > $null
    $FileBrowser.FileNames
    Write-Verbose -Message (
        (Show-EHMessageHeader -Name $MyInvocation.InvocationName -StartTime $StartTime) +
        "Created dialog window with path $InitialPath"
    )
}

function Connect-EHSshHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$Name
        , [Parameter(Mandatory)][string]$PartnerUserName
    )
    process {
        try {
            $SshSettings = @{
                FilePath = "ssh.exe" 
                ArgumentList = "-t $PartnerUserName@root@$Name@" +
                    "access-control-server.sample.ninja"
                ErrorAction = 'stop'
            }
            Start-Process @SshSettings
            Write-Verbose -Message (
                (Show-EHMessageHeader -Name $MyInvocation.InvocationName -StartTime $StartTime) +
                "Started connection to $Name using $PartnerUserName"
            )
        }
        catch {
            Show-EHCustomError -ErrorRecord $PSItem
        }
    }
}
#endregion Support Functions

#region Procedure
try {
    $StartTime = Get-Date
    Write-Verbose -Message ($MyInvocation.InvocationName + " 0 seconds; Start")
    if ($HostName) {
        Connect-EHSshHost -Name $HostName -PartnerUserName $PartnerUserName
    } else {
        if (-not $HostListPath) {
            $HostListPath = (Get-ChildItem -Path $PSScriptRoot -Filter *.csv | Select-Object -Last 1).FullName
            Write-Verbose -Message "Found file in same path: $HostListPath"
            if (-not $HostListPath) {
                Write-Warning -Message 'HostListPath not called, please select a CSV file that contains Partner hostnames'
                Start-Sleep -Seconds 2
                $HostListPath = Read-EHFileDialog -ErrorAction Stop
            }
        }
        Write-Verbose -Message "Final path: $HostListPath"        
        $HostListPath | Import-Csv | Sort-Object -Property Name | Out-GridView -PassThru | 
            Connect-EHSshHost -PartnerUserName $PartnerUserName -ErrorAction Stop
        Write-Verbose -Message (
            (Show-EHMessageHeader -Name $MyInvocation.InvocationName -StartTime $StartTime) +
            "Task Complete"
        )
    }
}
catch {
    Show-EHCustomError -ErrorRecord $PSItem
}
#endregion Procedure

