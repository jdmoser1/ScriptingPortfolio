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
        .\New-FASession.ps1 -BrowserArguments https://example.com -TestDomain example.com -ProcessSearchString AnyDesk
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
    # Definitions of browsers you want open, including command line options
    [Parameter(Position=2)][System.Collections.ArrayList]$FABrowsers = @(
        [PSCustomObject]@{FilePath='firefox.exe';ArgumentList='-P "Profile 1" -no-remote'}
        [PSCustomObject]@{FilePath='edge.exe';ArgumentList='--profile-directory="Profile 2"'}
    )
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
$Script:ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
#endregion Supporting Information

#region Supporting Functions
function Get-FAProcessCount {
    [CmdletBinding()]
    param (
        [Parameter()][string]$ProcessSearchString
    )
    # begin {}
    # end {}
    process {
        try {
            Get-Process | Where-Object -Property Name -Like -Value "$ProcessSearchString*" | Measure-Object | 
                Select-Object -ExpandProperty Count
            Write-Verbose -Message (
                "Get-FAProcessCount " + $Timer.Elapsed.Seconds + " Counted $ProcessSearchString"
            )
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
        [Parameter()][string]$ProcessSearchString
        , [Parameter()][switch]$DontCheckProcessAgainstUser

    )
    # begin {}
    # end {}
    process {
        try {
            $ProcessCount = Get-FAProcessCount -ProcessSearchString $ProcessSearchString
            if (
                ($DontCheckProcessAgainstUser -and ($ProcessCount -gt 0)) -or 
                ($ProcessCount -eq (Get-CimInstance -ClassName Win32_LoggedOnUser|Measure-Object).Count)
            ) {
                $true
                Write-Verbose -Message (
                    "Test-FAProcessCount " + $Timer.Elapsed.Seconds + " Tested $ProcessSearchString as true"
                )
            } else {
                $false
                Write-Verbose -Message (
                    "Test-FAProcessCount " + $Timer.Elapsed.Seconds + " Tested $ProcessSearchString as false"
                )
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
        [Parameter()][string]$TestDomain
    )
    # begin {}
    # end {}
    process {
        try {
            if ((Test-NetConnection -ComputerName $TestDomain -Port 443).TcpTestSucceeded) {
                $true
            } else {
                $false
            }
            Write-Verbose -Message (
                "Test-FAConnection " + $Timer.Elapsed.Seconds + " Tested for $TestDomain and $ProcessSearchString"
            )
        } catch {
            Write-Error -ErrorRecord $PSItem
            Write-Verbose -Message ('Error type: ' + $PSItem.Exception.GetType().FullName)
            Write-Verbose -Message ('Trace: ' + $PSItem.ScriptStackTrace.Replace("`n","`n`t"))
        }
    }
}

function Start-FABrowsers {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline,Position=0)][string[]]$InputObject
    )
    begin {
        # $ErrorActionPreference = 'Stop'
        $i = 0
    }
    end {
        $true
        Write-Verbose -Message ("Start-FABrowsers " + $Timer.Elapsed.Seconds + " Objects evaluated: $i")
    }    
    process {
        try {
            Start-Process -FilePath $InputObject.FilePath -ArgumentList $InputObject.ArgumentList
            Write-Verbose -Message ("Start-FABrowsers " + $Timer.Elapsed.Seconds + " attempted to open")
            $i++
        }
        catch {
            Write-Error -ErrorRecord $PSItem
            Write-Verbose -Message ('Error type: ' + $PSItem.Exception.GetType().FullName)
            Write-Verbose -Message ('Trace: ' + $PSItem.ScriptStackTrace.Replace("`n","`n`t"))
        }
    }
}

function Get-FABrowserProcesses {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline,Position=0)][string[]]$ProcessName
    )
    begin {
        $i = 0
    }
    end {
        Write-Verbose -Message ("Get-FABrowserProcesses " + $Timer.Elapsed.Seconds + " Objects evaluated: $i")
    }
    process {
        try {
            Get-Process $ProcessName
            Write-Verbose -Message (
                "Get-FABrowserProcesses " + $Timer.Elapsed.Seconds + " Listed processes for $ProcessName"
            )
            $i++
        } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
            Write-Verbose -Message (
                "Get-FABrowserProcesses " + $Timer.Elapsed.Seconds + " $ProcessName not found"
            )
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
        $IsConnected = Test-FAConnection -TestDomain $TestDomain
        $ProcessCountParameters = @{
            ProcessSearchString         =   $ProcessSearchString 
            DontCheckProcessAgainstUser =   $DontCheckProcessAgainstUser
        }
        $IsProcessCount = Test-FAProcessCount @ProcessCountParameters
        if ($IsConnected -and $IsProcessCount -and -not $CurrentProcessState) {
            $CurrentProcessState = $FABrowsers | Start-FABrowsers
            Write-Verbose -Message ("(while) " + $Timer.Elapsed.Seconds + " ($i) Starting $BrowserPath")
        } elseif ((-not $IsConnected) -or (-not $IsProcessCount)) {
            $BrowserList | Get-FABrowserProcesses | Stop-Process -Force
            $CurrentProcessState = $false
            Write-Verbose -Message ("(while) " + $Timer.Elapsed.Seconds + " ($i) terminating all browsers")
        } else {
            Write-Verbose -Message ("(while) " + $Timer.Elapsed.Seconds + " ($i) Tests are valid, no change")
        }
        Start-Sleep -Seconds 2
        $i++
    }
} catch {
    Write-Error -ErrorRecord $PSItem
    Write-Verbose -Message ('Error type: ' + $PSItem.Exception.GetType().FullName)
    Write-Verbose -Message ('Trace: ' + $PSItem.ScriptStackTrace.Replace("`n","`n`t"))
} finally {
    $BrowserList | Get-FABrowserProcesses | Stop-Process -Force 
    #Write-Host -ForegroundColor Cyan -Object "INFO: `tAll browser sessions terminated."
    #Read-Host -Prompt 'Press [enter] to exit.'
    Write-Verbose -Message ('Task Complete. Time: ' + $Timer.Elapsed.TotalSeconds)
    $Timer.Stop()
}
#endregion Procedure

