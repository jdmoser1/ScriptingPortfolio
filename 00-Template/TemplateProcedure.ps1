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
    [Parameter(ValueFromPipeline,Position=0)][string]$Path 
    # Parameter help description
    , [Parameter(DontShow)][string]$ModulePath = (Join-Path -Path $PSScriptRoot -ChildPath 'Template.psm1')
)

#region Supporting Information
try {
    Write-Verbose -Message ($MyInvocation.InvocationName +"  0s  (seconds) Start")
    Import-Module -Name $ModulePath -ErrorAction Stop -Verbose:$false -Force
    if ($VerbosePreference -eq 'Continue') {
        Enable-TEMPLATEVerbose
    }
    Write-TEMPLATEVerbose -Message ("Modules Loaded: `n" + $ModulePath) 
} catch [System.IO.FileNotFoundException] {
    Write-Host -ForegroundColor Cyan -Object "PROMPT:  Module file not found. Please enter the full path of the"
    Write-Host -ForegroundColor Cyan -NoNewline -Object "PROMPT:  TEMPLATE module to continue"
    Import-Module -Name (Read-Host -Prompt '?') -ErrorAction Stop -Verbose:$false -Force
} catch {
    Write-Warning -Message "Unable to load file. Check path: $ModulePath"
    Write-Warning -Message "Details:"
    Write-Error -ErrorRecord $PSItem
    Return
}
try {
    Start-TEMPLATETimer
    Enable-TEMPLATEChecklist 
    if (-not $Path) {
        $Path = (Read-TEMPLATEValue -Name Path -Default $PSScriptRoot)
    }
} catch {
    Write-TEMPLATEError -ErrorRecord $PSItem
}
#endregion Supporting Information

#region Supporting Functions
#endregion Supporting Functions

#region Procedure
try {
    Write-TEMPLATEChecklist
    Get-ChildItem -Path $Path | New-TEMPLATEObject  | Get-TEMPLATELineCount 
    Get-TEMPLATEFileCount -Path $Path
    # The following is for demonstration and must be deleted before production use
    Set-TEMPLATEIncrementChecklistItem -ItemName Null
} catch {
    Write-TEMPLATEError -ErrorRecord $PSItem
} finally {
    Write-TEMPLATEChecklist
    Write-TEMPLATEVerbose -Message 'Task Complete' 
    Clear-TEMPLATETimer
}
#endregion Procedure
