<#
    This script copies files based on minimum or maximum age,
    from the source to the destination
    By default, the folder structure is recreated, but can be "flattened"
#>
param(
    [Parameter(Mandatory=$True,Position=1)][String]$SourcePath
    , [Parameter(Mandatory=$True,Position=2)][String]$DestinationPath
    , [Parameter(Position=3)][DateTime]$OlderThan = (Get-Date)
    , [Parameter(Position=4)][DateTime]$NewerThan = (Get-Date -Date '01/01/1985')
    , [string]$Filter = '*'
    , [switch]$Flat
    , [switch]$RemoveOriginal
    , [switch]$SimpleOutput
)
# Stop the script if SourcePath doesn't exist
If (-not (Test-Path -Path $SourcePath)) {
    Write-Warning -Message "$SourcePath is not readable"
    Return
}
# Source path must by full path
$SourcePath = (Get-Item $SourcePath).FullName
# Global exclusions. Filter in code first, where feasible.
$FileExclusions = @(
    '*.tmp'
    , '*.sys'
    , 'tmp.xml?'
    , '*Temp*'
)
# Reset counter
$I = 0

# Troubleshooting info
Write-Output -InputObject (Get-Item $MyInvocation.MyCommand.Path).BaseName
If ($SimpleOutput) {
    Write-Output -InputObject ((Get-Date).ToString() + "; Source: $SourcePath")
} Else {
    Write-Output -InputObject ('Time Start: ' + (Get-Date).DateTime)
    Write-Output -InputObject ("Copying files from: `n $SourcePath `n to $DestinationPath")
    Write-Output -InputObject ("Which matches the filter $Filter.")
    Write-Output -InputObject ("Flatten switch: $Flat Remove Original: $RemoveOriginal")
    Write-Output -InputObject ('Older than ' + $OlderThan.DateTime)
    Write-Output -InputObject ('Newer than ' + $NewerThan.DateTime)
}

# Get all files with that match the filter under the source folder, which are not folders, symlinks, or system files. 
Get-ChildItem -Path $SourcePath -Filter $Filter -Attributes Normal,Archive -Exclude $FileExclusions -Recurse -File | `
    # Filter files which are newer than specificed days (default 100 years) but at least as new as days (default is now)
    Where {(($_.LastWriteTime -ge $NewerThan) -or ($_.CreationTime -ge $NewerThan)) -and (($_.LastWriteTime -le $OlderThan) -or ($_.CreationTime -le $OlderThan))} | `
    # Process files that meet all the criteria
    Foreach-Object -Process { 
    # Check that file is readable
        Try {
            $CurrentName = $_.FullName
            $CurrentReadable = $True
            $_.OpenRead().Close()
        } Catch {
            $CurrentReadable = $False 
            Write-Output -InputObject ("Unable to read $CurrentName")           
        }
        If ($CurrentReadable) {
            # Should the folder structure be "flattened"
            If ($Flat) {
                # Enable for diagnostics
                If (-not (Test-Path -Path $DestinationPath)) {
                    New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null 
                }
                #Write-Output -InputObject ("Copying " + $_.Name + " to $DestinationPath")
                Copy-Item -Path $_.FullName -Destination $DestinationPath -Force -ErrorAction Continue
            } Else {
                # Create full path for new file    
                $FileDestPath = $_.Directory.ToString().Replace($SourcePath,$DestinationPath)
                $FileDestName = Join-Path -Path $FileDestPath -ChildPath $_.Name
                # Create any subfolders needed to preserve folder structure
                If (-not (Test-Path -Path $FileDestPath)) {
                    New-Item -Path $FileDestPath -ItemType Directory -Force | Out-Null 
                }
                # Check first that the file doesn't already exist. Then, create the new file!
                If ((-not (Test-Path $FileDestName)) -or ($_.LastWriteTime -gt (Get-Item $FileDestName).LastWriteTime)) {
                    # Enable for diagnostics
                    #Write-Output -InputObject ("Copying " + $_.Name + " to $FileDestPath")
                    # copy file to destination
                    Copy-Item -Path $_.FullName -Destination $FileDestPath -Force -ErrorAction Continue
                } 
            }
            # If enabled, delete original file
            If ($RemoveOriginal) {
                # Enable for diagnostics
                #Write-Output -InputObject ("Removing " + $_.FullName)
                Remove-Item -Path $_.FullName -Force -ErrorAction Continue
            }
            # Count number of items processed
            $I++
        }
    }
# Troubleshooting info
If ($SimpleOutput) {
    Write-Output -InputObject ("Done! $I files; " + (Get-Date).ToString())
} Else {
    Write-Output -InputObject ("Finished script run! Processed $I files. End time: " + (Get-Date).DateTime)
}
