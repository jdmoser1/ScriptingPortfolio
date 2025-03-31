# Don't forget Requires -RunAsAdministrator -Modules ActiveDirectory -Version 5.0 or other
<#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        Long description
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
#>
[CmdletBinding()]
param (
    # Parameter help description
    [Parameter(ValueFromPipeline,Position=0)][string]$Path = $PSScriptRoot
)


#region Supporting Information
$Timer = [system.diagnostics.stopwatch]::StartNew()
Write-Verbose -Message "`t 0.00 `t Start"
$TextFilter = [System.Collections.ArrayList]@(
    ".ps1"
    , ".psm1"
    , ".psd1"
    , ".ps1xml"
    , ".json"
    , ".xml"
    , ".txt"
)
#endregion Supporting Information

#region Supporting Functions
function Get-LineCount {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory,ValueFromPipeline,Position=0)][System.IO.FileInfo]$FileInfo
    )
    begin {
        $ErrorActionPreference = 'Stop'
        $i = 0
    }
    end {
        Write-Verbose -Message "Get-LineCount Objects evaluated: $i"
    }
    process {
        try {
            # uncomment to generate error
            #Invoke-Error -Message "This is a fake Cmdlet and will cause an error"
            [PSCustomObject]@{
                Name = $FileInfo.Name
                LineCount = (Get-Content -Path $FileInfo.FullName | Measure-Object).Count
            }
            Write-Verbose -Message ('Enumerated lines for ' + $FileInfo.Name)
            $i++
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
    Get-ChildItem -Path $Path | Where-Object -Property Extension -In -Value $TextFilter | Get-LineCount 
} catch {
    Write-Error -ErrorRecord $PSItem
    Write-Verbose -Message ('Error type: ' + $PSItem.Exception.GetType().FullName)
    Write-Verbose -Message ('Trace: ' + $PSItem.ScriptStackTrace.Replace("`n","`n`t"))
} finally {
    Write-Verbose -Message ('Task Complete. Time: ' + $Timer.Elapsed.TotalSeconds)
    $Timer.Stop()
}
#endregion Procedure

