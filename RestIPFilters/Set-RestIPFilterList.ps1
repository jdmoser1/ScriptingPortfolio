<#
.SYNOPSIS
    Sets the IP address list for a customer
.DESCRIPTION
    Sets the existing IP address list, in Custom Software, for a customer in a given environment, by optionally adding, 
    removing, or both IP address lists.
.OUTPUTS
    Messages to the host
.EXAMPLE
    PS> .\Set-RestIPFilterList.ps1 -EnvironmentName Test -IdCode xzy -Credential (Get-Credential) 
    Set the IP address list for customer xzy. 
.EXAMPLE
    PS> .\Set-RestIPFilterList.ps1
    You'll be asked to provide all required information, and set the IP address list for a customer
.NOTES
    Set-RestIPFilterList.ps1 is a frontend for the RestIPFilter module. This allows you to make basic changes 
    for one Custom Software customer without having to interact with the module or knowing out to use each of the imported
    cmdlets.

    Examples assume the working directory is set to the path that the script is located

    Version: 2024.02.06
    This is the first release. Changes and bug fixes will be listed here.
    Known Issues
        * Procedural add/removal of multiple entries causes a failure. For now you must make one add and/or one
            remove at a time
        * Authtoken is not automatically refreshed. If you retain an Authtoken, it will expire after 10 minutes
#>
[CmdletBinding()]
param (
    # Specifies the environment to use. Available options are listed in teh RestIPFilter.json file if not
    # entered, you will be prompted for it.
    [Parameter(Position=0)][string]$EnvironmentName 
    , # Specifies the customer IdCode. If not entered you will be prompted for it
    [Parameter(Position=1)][string]$IdCode 
    , # Credential (username and password) for Custom Software. You may create this using Get-Credential. Might be 
    # Clarivate credentials. If not entered you will be prompted for them.
    [Parameter(Position=2)][pscredential]$Credential = (Get-Credential -Message 'Enter username and password')
    , # Parameter help description
    [Parameter(Position=3)][string[]]$AddIpList
    , # Parameter help description
    [Parameter(Position=4)][string[]]$RemoveIpList
    , [Parameter(DontShow)][string]$ModulePath = (Join-Path -Path $PSScriptRoot -ChildPath 'RestIPFilter.psm1')
)

#region Supporting Information
try {
    $Timer = [system.diagnostics.stopwatch]::StartNew()
    Write-Verbose -Message ($MyInvocation.InvocationName +"`t0.00`tStart")
    Import-Module -Name $ModulePath -ErrorAction Stop -Verbose:$false -Force
    if ($VerbosePreference -eq 'Continue') {
        Enable-VIFVerbose
    }
    Write-VIFVerbose -Message ("Modules Loaded: `n" + $ModulePath) -Timer $Timer
} catch [System.IO.FileNotFoundException] {
    Write-Host -ForegroundColor Cyan -Object "PROMPT:`tModule file not found. Please enter the full path of the"
    Write-Host -ForegroundColor Cyan -NoNewline -Object "PROMPT:`tRestIPFilter module to continue"
    Import-Module -Name (Read-Host -Prompt '?') -ErrorAction Stop -Verbose:$false -Force
} catch {
    Write-Warning -Message "Unable to load file. Check path: $ModulePath"
    Write-Warning -Message "Details:"
    Write-Error -ErrorRecord $PSItem
    $Timer.Stop()
    Return
}
#endregion Supporting Information

#region Supporting Functions
#endregion Supporting Functions

#region Procedure
try {
    if (-not $EnvironmentName) {
        $EnvironmentName = (Read-VIFEnvironment).Name
    }
    if (-not $IdCode) {
        $IdCode = (
            New-VIFObject -EnvironmentName $EnvironmentName -UseReferenceIdCode | 
                New-VIFAuthToken -Credential $Credential | Get-VIFCustomerList -ShowWindow
        ).Customer.IdCode
    }
    New-VIFObject -EnvironmentName $EnvironmentName -IdCode $IdCode | 
        New-VIFAuthToken -Credential $Credential | Find-VIFCustomerInfo | Get-VIFIpAddressList -ShowIPList |
        Remove-VIFIpAddressList -IpAddressList $RemoveIpList -PassThru -Force | 
        Add-VIFIpAddressList -IpAddressList $AddIpList
} catch {
    Write-VIFError -ErrorRecord $PSItem
} finally {
    Write-VIFVerbose -Message 'Task Complete' -Timer $Timer
    $Timer.Stop()
}
#endregion Procedure
