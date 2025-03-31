# Don't forget Requires -RunAsAdministrator -Modules ActiveDirectory -Version 5.0 or other
#region Classes
#endregion Classes

#region Support Functions
#endregion Support Functions

#region Public Functions
function Read-FileDialog {
    <#
    .DESCRIPTION
        Code used from https://4sysops.com/archives/how-to-create-an-open-file-folder-dialog-box-with-powershell/
    #>
    [CmdletBinding()]
    param (
        [string]$InitialPath = $PSScriptRoot
    )
    Add-Type -AssemblyName System.Windows.Forms
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
        InitialDirectory = [Environment]::GetFolderPath('Desktop') 
    }
    $FileBrowser.InitialDirectory = $InitialPath
    $FileBrowser.ShowDialog() > $null
    $FileBrowser.FileNames
    Write-Verbose -Message (
        (Show-MessageHeader -Name $MyInvocation.InvocationName -StartTime $StartTime) +
        "Created dialog window with path $InitialPath"
    )
}

function Out-Selection {
    <#
    .DESCRIPTION
        This function just demonstrates the use of the Out-GridView cmdlet. No need to use this, just use 
        Out-GridView directly
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]$InputObject
    )
    $InputObject | Out-GridView -PassThru
}
#endregion Public Functions
