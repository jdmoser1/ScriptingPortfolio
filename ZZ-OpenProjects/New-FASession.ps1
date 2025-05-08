<#
    .SYNOPSIS
        Starts a broswer with a target site, monitors remote connectivity and may terminate browsers
    .DESCRIPTION
        This script will open a specific site in a browser (Facebook Ads in Chrome), and will check for a 
        remote session and Internet connectivity every 2 seconds. If it can't ping the TestDomain, or if 
        the number of remote app processes drops. All listed browsers are terminated. Pressing CTRL-C should 
        also terminate browsers (see known issues below)

        For the remote app, the script retains the original number of processes, and terminates the browsers if
        the number of processed drops. This is a valid test for AnyDesk and TeamViewer, but needs to be tested 
        if another remote app is used. 
    .EXAMPLE
        .\New-FASession.ps1
        Start browser session with all defaults, including test targets.
    .EXAMPLE
        .\New-FASession.ps1 -TargetUri https://example.com -TestDomain example.com -ProcessSearchString TeamViewer
        Start browser session with example.com, and testing connectivity to example.com and TeamViewer
    .NOTES
        Known issues
          * In one test, pressing CTRL-C terminated the browser window that the target site is loaded in, but 
            not all browser windows. In other tests, CTRL-C worked as expected.  
          * TestDomain must be a valid domain or IP address. In one test, an unresolvable domain name caused
            the test to stall. In other tests, an invalid domain caused the script to terminate immediately, as
            expected.  
#>
[CmdletBinding()]
param (
    # Full path to desired browser
    [Parameter(position=0)][string]$BrowserPath = (
        Join-Path -Path $env:ProgramFiles -ChildPath "Google\Chrome\Application\chrome.exe"
    )
    , # Full URL to open in the browser
    [Parameter(Position=1)][string]$TargetUri = 'https://www.facebook.com/business'
    , # FQDN (DNS name) of server to test against. The test uses HTTPS to test
    [Parameter(Position=2)][string]$TestDomain = 'router.teamviewer.com'
    , # Process name of the remote app to monitor. Must be the name as shown in Task Manager without the 
    # extention (.exe)
    [Parameter(Position=3)][string]$ProcessSearchString = 'TeamViewer_Desktop'
    , # List of browser processes to terminate, also as listed in Task Manager without an extention
    [Parameter(Position=4)][string[]]$BrowserList = @('chrome','msedge','firefox','operah','safari')
    , # Number of hours for script to run before completing
    [Parameter(Position=5)][int]$RunTimeHrs = 23
    , # If true, just check that the search process count is more than 0; default behavior is to check number of
    # search process matches number of users
    [Parameter(Position=6)][switch]$DontCheckProcessAgainstUser
)


#region Supporting Information
$Timer = [system.diagnostics.stopwatch]::StartNew()
Write-Verbose -Message "`t 0.00 `t Start"
#endregion Supporting Information

#region Supporting Functions
function Get-FAProcessCount {
    [CmdletBinding()]
    param (
        [string]$ProcessSearchString
    )
    # begin {}
    # end {}
    process {
        try {
            Get-Process | Where-Object -Property Name -Like -Value "$ProcessSearchString*" | Measure-Object | 
                Select-Object -ExpandProperty Count
            Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " Counted $ProcessSearchString")
        } catch {
            Write-Error -ErrorRecord $PSItem
            Write-Verbose -Message ('Error type: ' + $PSItem.Exception.GetType().FullName)
            Write-Verbose -Message ('Trace: ' + $PSItem.ScriptStackTrace.Replace("`n","`n`t"))
        }
    }
}

function Test-FAProcessCount {
    [CmdletBinding()]
    param (
        [string]$ProcessSearchString
        , [Parameter][switch]$DontCheckProcessAgainstUser

    )
    # begin {}
    # end {}
    process {
        try {
            $ProcessCount = Get-FAProcessCount -ProcessSearchString $ProcessSearchString
            if (
                ($DontCheckProcessAgainstUser -and ($ProcessCount -gt 0)) -or 
                ($ProcessCount -ne (Get-CimInstance -ClassName Win32_LoggedOnUser|Measure-Object).Count)
            ) {
                $true
                Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " Tested $ProcessSearchString as true")
            } else {
                $false
                Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " Tested $ProcessSearchString as false")
            }            
        } catch {
            Write-Error -ErrorRecord $PSItem
            Write-Verbose -Message ('Error type: ' + $PSItem.Exception.GetType().FullName)
            Write-Verbose -Message ('Trace: ' + $PSItem.ScriptStackTrace.Replace("`n","`n`t"))
        }
    }
}


function Test-FAConnection {
    [CmdletBinding()]
    param (
        [string]$TestDomain
        #,[string]$ProcessSearchString
        #, [int]$InitialProcCount
    )
    begin {
        $ErrorActionPreference = 'Stop'
    }
    # end {}
    process {
        try {
            if ((Test-NetConnection -ComputerName $TestDomain -Port 443).TcpTestSucceeded) {
                $true
            } else {
                $false
            }
            Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " Tested for $TestDomain and $ProcessSearchString")
        } catch {
            Write-Error -ErrorRecord $PSItem
            Write-Verbose -Message ('Error type: ' + $PSItem.Exception.GetType().FullName)
            Write-Verbose -Message ('Trace: ' + $PSItem.ScriptStackTrace.Replace("`n","`n`t"))
        }
    }
}

function Get-FABrowserProcesses {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline,Position=0)][string[]]$ProcessName
    )
    begin {
        $ErrorActionPreference = 'Stop'
        $i = 0
    }
    end {
        Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " Get-LineCount Objects evaluated: $i")
    }
    process {
        try {
            Get-Process $ProcessName
            Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " Listed processes for $ProcessName")
            $i++
        } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
            Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " $ProcessName not found")
        } catch {
            Write-Error -ErrorRecord $PSItem
            Write-Verbose -Message ('Error type: ' + $PSItem.Exception.GetType().FullName)
            Write-Verbose -Message ('Trace: ' + $PSItem.ScriptStackTrace.Replace("`n","`n`t"))
        }
    }
}
#endregion Supporting Functions

#region Procedure
try {
    $i = 0
    while ((Get-Date) -lt (Get-Date).AddHours($RunTimeHrs)) {
        if ($TargetProcess.Id -and -not $TargetProcess.HasExited) {
            $IsTargetActive = $true
        } else {
            $IsTargetActive = $false
        }
        $IsConnected = Test-FAConnection -TestDomain $TestDomain
        $ProcessCountParameters = @{
            ProcessSearchString         =   $ProcessSearchString 
            DontCheckProcessAgainstUser =   $DontCheckProcessAgainstUser
        }
        $IsProcessCount = Test-FAProcessCount @ProcessCountParameters
        if ($IsConnected -and $IsProcessCount -and -not $IsTargetActive) {
            $TargetProcess = Start-Process -FilePath $BrowserPath -ArgumentList $TargetUri -Passthru
            Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " ($i) Starting $BrowserPath")
        } elseif ($IsTargetActive -and ((-not $IsConnected) -or (-not $IsProcessCount))) {
            $TargetProcess | Stop-Process -Force
            $BrowserList | Get-FABrowserProcesses | Stop-Process -Force
            Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " ($i) terminating all browsers")
        } else {
            Write-Verbose -Message ("`t" + $Timer.Elapsed.Seconds + " ($i) Tests are valid, no change")
        }
        # Get-FAProcessCount -ProcessSearchString $ProcessSearchString
        Start-Sleep -Seconds 2
        $i++
    }
    #$InitialProcCount = Get-FAProcessCount  $ProcessSearchString
    # $i = 0
    # $ConnectionParameters = @{
    #     TestDomain          =   $TestDomain
    #     ProcessSearchString =   $ProcessSearchString
    #     InitialProcCount    =   $InitialProcCount
    # }
    # while (Test-FAConnection @ConnectionParameters) {
    #     $i++
    #     Write-Host -ForegroundColor Cyan -Object (
    #         "INFO: `t" +(Get-Date -Format HH:mm:ss) + " ($i) Connection Check Passed"
    #     )
    # 

    # }
} catch {
    Write-Error -ErrorRecord $PSItem
    Write-Verbose -Message ('Error type: ' + $PSItem.Exception.GetType().FullName)
    Write-Verbose -Message ('Trace: ' + $PSItem.ScriptStackTrace.Replace("`n","`n`t"))
} finally {
    $TargetProcess | Stop-Process -Force
    $BrowserList | Get-FABrowserProcesses | Stop-Process -Force 
    Write-Host -ForegroundColor Cyan -Object "INFO: `tAll browser sessions terminated."
    Read-Host -Prompt 'Press [enter] to exit.'
    Write-Verbose -Message ('Task Complete. Time: ' + $Timer.Elapsed.TotalSeconds)
    $Timer.Stop()
}
#endregion Procedure

