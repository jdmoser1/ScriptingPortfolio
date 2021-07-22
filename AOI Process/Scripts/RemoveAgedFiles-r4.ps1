<#
    This script deletes files that are older than a specified date
#>
param(
    [Parameter(Mandatory=$True,Position=1)][String]$SourcePath,
    [Parameter(Position=2)][DateTime]$OlderThan = ((Get-Date).AddYears(-100)),
    [string]$Filter = "*",
    [switch]$Archive,
    [switch]$RemoveEmptyFolders
)

# Reset counter
$I = 0
# Troubleshooting info
Write-Output -InputObject (Get-Item $MyInvocation.MyCommand.Path).BaseName
Write-Output -InputObject ("Time Start: " + (Get-Date).DateTime)
Write-Output -InputObject ("Removing files from: `n $SourcePath")
Write-Output -InputObject ("Older than " + $OlderThan.DateTime)
Write-Output -InputObject ("With filter $Filter, archive bit check set to $Archive")

# Get all files with that match the filter under the source folder
Get-ChildItem -Path $SourcePath -Filter $Filter -Attributes Directory,Normal,Archive -Recurse | `
    # Filter files which are older than specified date. To be safe, check both Modified Time and Created Time
    Where {($_.LastWriteTime -lt $OlderThan) -and ($_.CreationTime -lt $OlderThan)} | `
    # Are we looking for the archive bit? If so, remove if file is not marked for archiving. Otherwise remove
    ForEach-Object -Process { 
        # Handle folders if $RemoveEmptyFolders is set. Otherwise handle files only. If $Archive is set, evaluate only files that are missing the archive bit.
        If (($_.Attributes -notmatch "Directory") -and ((-not $Archive) -or ($_.Attributes -match "Normal"))) {
            # Enable for Diagnostics
            #"Removing file " + $_.FullName
            Remove-Item -Path $_.FullName -Force
            # Count number of items processed
            $I++
        } Elseif (($_.Attributes -match "Directory") -and $RemoveEmptyFolders -and -not (Get-ChildItem -Path $_.FullName -Attributes Directory,Normal,Archive)) {
            # Enable for Diagnostics
            #"Removing folder " + $_.FullName
            Remove-Item -Path $_.FullName -Recurse -Force
            # Count number of items processed
            $I++
        }
}
# Troubleshooting info
Write-Output -InputObject ("Finished script run! Processed $I files. End time: " + (Get-Date).DateTime)