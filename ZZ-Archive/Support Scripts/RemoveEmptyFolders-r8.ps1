<#
    This script recurses through a folder directory structure and deletes empty folders that it finds. 
#>
param(
    [Parameter(Mandatory=$True,Position=1)][String]$FolderPath,
    [Parameter(Position=2)][DateTime]$OlderThan = (Get-Date),
    [Parameter(Position=3)][Switch]$AlternateMethod = $False
)
# Reset counter
$I = 0
# Troubleshooting info
Write-Output -InputObject (Get-Item $MyInvocation.MyCommand.Path).BaseName
Write-Output -InputObject ("Time Start: " + (Get-Date).DateTime)
Write-Output -InputObject ("Removing empty folders from: `n $FolderPath")
Write-Output -InputObject ("Older than " + $OlderThan.DateTime + "; Alt Method: $AlternateMethod")

# Function to evaluate contents of folder; returns true or false
function FolderHasContents {
    param(
        [String]$CurrentFolderPath,
        [Switch]$AlternateMethod
    )
    # AlternateMethod looks at folders closer to the root first to determine
    # if that folder should be deleted. This will reduce "directory name must 
    # be less than 248 characters" errors (but it won't eliminate all of them). 
    # This method may take longer, or cause other errors. 
    If ($AlternateMethod) { 
        If (Get-ChildItem -Path $CurrentFolderPath -Attributes Normal,Archive -Recurse | Select-Object -First 1) {
            Return $True
        }
    } Else {
        # Standard method
        If (Get-ChildItem -Path $CurrentFolderPath -Attributes Directory,Normal,Archive | Select-Object -First 1 ) {
            Return $True
        }
    } 
}

# Get folders under the Path
Get-ChildItem -Path $FolderPath -Directory -Recurse | `
    # Don't list folders that are not empty or newer than date 
    Where-Object {(($_.CreationTime -lt $OlderThan) -and ($_.LastWriteTime -lt $OlderThan) -and -not (FolderHasContents -CurrentFolderPath $_.FullName -AlternateMethod:$AlternateMethod))} | `
    ForEach-Object -Process {
        # Enable for diagnostics
        #Write-Output -InputObject ("Removing " + $_.FullName)
        # Delete folder
        Remove-Item -Path $_.FullName -Recurse -Force 
        # Count number of items processed
        $I++
    }
# Troubleshooting info
Write-Output -InputObject ("Finished script run! Processed $I folders. End time: " + (Get-Date).DateTime)