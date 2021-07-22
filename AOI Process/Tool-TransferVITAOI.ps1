<#
    This procedure script moves AOI files from Old-style folder 
    structures to the new-style structure in a folder
#>
param(
    [Parameter(Position=1)][String]$AOIRoot,
    [Parameter(Position=2)][String]$AOIArchive,
    [Parameter(Position=3)][String]$SplitArchive,
    [String]$OmronSubPath,
    [int]$SplitNumber = 1727
)
# Create initial setup, run commands, and capture errors
Try {
    ## Initial setup
    $Error.Clear()
    # Create the PowerUtils drive at the Procedure path, and set as working directory
    Set-Location -Path REDACTEDPATH
    If ((Get-PSDrive) -match "PowerUtils") {
        Remove-PSDrive -Name "PowerUtils" 
    }
    # Allow input for current PowerUtils location (local drive is recommended), unless a parameter is set
    $ProdPath = "REDACTEDPATH"
    If (-not $AOIRoot -or -not $AOIArchive) {
        $InPath = Read-Host -Prompt "Enter the PowerUtils location [$ProdPath]" 
        # Default value
        If ($InPath) {
        $ProdPath = $InPath
        }
    }
    New-PSDrive -Name "PowerUtils" -PSProvider "FileSystem" -Root $ProdPath -Scope "Global"
    Set-Location -Path PowerUtils:
    # Create new log
    $TimeStart = Get-Date
    $LogName = (Get-Item $MyInvocation.MyCommand.Path).BaseName
    $LogFile = Join-Path -Path PowerUtils: -ChildPath ("Logs\" + $LogName + "-" + (Get-Date -Format yyyy-MM-dd-HHmmss) + ".log")
    #Start-Transcript -Path $LogFile -IncludeInvocationHeader
    # Powershell 3.0
    Start-Transcript -Path $LogFile
    Write-Output -InputObject ("Log output for " + $LogName + " generated at " + $TimeStart + "`n")
    # Default paths. If parameter is not set, ask
    $DefaultRoot = "REDACTEDPATH"
    $DefaultArchive = "REDACTEDPATH"
    If (-not $AOIRoot) {
        Write-Warning -Message 'This tool cannot split archives in interactive mode'
        Write-Output -InputObject ("Root path for VIT AOI images [$DefaultRoot]")
        $InPath = Read-Host
        If ($InPath) { $AOIRoot = $InPath } Else { $AOIRoot = $DefaultRoot }
    }
    If (-not $AOIArchive) {
        Write-Output -InputObject ("Path for archive location [$DefaultArchive]")
        $InArchive = Read-Host
        If ($InArchive) { $AOIArchive = $InArchive } Else { $AOIArchive = $DefaultArchive }
    }
    # Omron Root
    $OmronRoot = Join-Path -Path $AOIRoot -ChildPath 'Omron'
    # VIT Root
    $VITAOIRoot = Join-Path -Path $AOIRoot -ChildPath 'VITAOI'
    # Review path
    $VITReviewPath = Join-Path -Path $VITAOIRoot -ChildPath 'Orphaned'
    # VIT folder name check
    $ExpectedMEString = 'REDACTEDSTRING*'
    # Counter
    $J = 0 
    # Upper limit, stop script at this increment
    #$JMax = 4400

    ## Run commands
    # If needed, create archive folder
    #If (-not (Test-Path -Path $VITAOIArchive)) {
    #    New-Item -Path $VITAOIArchive -ItemType Directory -Force | Out-Null
    #}

    # For Omron, move the files to a subfolder based on $OmronSubPath
    Get-ChildItem -Path $OmronRoot -Directory | ForEach-Object -Process {
        # Current paths
        $CurrentFolderName = $_.BaseName
        $CurrentArchive = ($AOIArchive, $CurrentFolderName, $OmronSubPath) -join '\' 
        Write-Output -InputObject ((Get-Date -Format HH:mm:ss) + "  Moving Omron files to $CurrentArchive")
        Get-ChildItem -Path $_.FullName | Move-Item -Destination $CurrentArchive -Force
    }
    # Move error message out of $Error
    If ($Error) {
        $ScriptError += $Error
        $Error.Clear()
    }

    # For VITAOI, Loop through each "REDACTEDNAME" folder
    Get-ChildItem -Path $VITAOIRoot -Directory | Where-Object -Property FullName -Value $ExpectedMEString -Match | ForEach-Object -Process {
        # Terminate at JMax
        #If ($J -ge $JMax) {
        #    Return
        #}
        # Current ME name
        $CurrentMEName = $_.BaseName
        # Process each subfolder
        Get-ChildItem -Path $_.FullName | ForEach-Object -Process {
            If (-not ($_.Basename.StartsWith('93'))) {
                Write-Output -InputObject ((Get-Date).ToString() + " Run $J " + $_.FullName + ' is non-standard. Skipping.')
                #Move-Item -Path $_.FullName -Destination $VITReviewPath -Force
            } Elseif (Get-ChildItem -Path $_.FullName -Filter "*.jpeg" -Recurse | Select-Object -First 1) {
                # Current subfolder information
                $CurrentPathName = $_.BaseName
                # Get the week number based on substring location
                $CurrentWeekID = $_.BaseName.Substring(10,4)
                # Are we splitting archives? If so, we use a different archive location for any 
                # paths that are below SplitNumber
                If ($SplitArchive -and ($CurrentWeekID -le $SplitNumber)) {
                    $CurrentArchive = ($SplitArchive, $CurrentMEName, $CurrentWeekID, $CurrentPathName) -join '\' 
                    #Join-Path -Path (Join-Path -Path $SplitArchive -ChildPath $CurrentWeekID) -ChildPath $CurrentPathName
                } Else {
                    $CurrentArchive = ($AOIArchive, $CurrentMEName, $CurrentWeekID, $CurrentPathName) -join '\' 
                    #Join-Path -Path (Join-Path -Path $VITAOIArchive -ChildPath $CurrentWeekID) -ChildPath $CurrentPathName
                }
                # Enable for diagnostics
                Write-Output -InputObject ((Get-Date -Format HH:mm:ss) + " Run $J - Moving JPEGs from: `n " + $_.FullName + " `n to $CurrentArchive")
                # Copy over files and flatten the current directories            
                PowerUtils:\Scripts\CopyAgedFiles-r7.ps1 -SourcePath $_.FullName -DestinationPath $CurrentArchive -Filter '*1_1.jpeg' -Flat | Out-Null
                PowerUtils:\Scripts\CopyAgedFiles-r7.ps1 -SourcePath $_.FullName -DestinationPath $CurrentArchive -Filter '*3_1.jpeg' -Flat | Out-Null
                PowerUtils:\Scripts\CopyAgedFiles-r7.ps1 -SourcePath $_.FullName -DestinationPath $CurrentArchive -Filter '*1_1_Color.jpeg' -Flat | Out-Null
                #PowerUtils:\Scripts\CopyAgedFiles-r7.ps1 -SourcePath $CurrentPath -DestinationPath $CurrentArchive -Filter '*.xml' -Flat
                Get-ChildItem -Path $_.FullName -Recurse -Filter "*.xml" -File | Select-Object -First 1 | Copy-Item -Destination $CurrentArchive -Force
                # On error, skip deleting the folder and clear the error.
                If ($Error) {
                    $ScriptError += $Error
                    $Error.Clear()
                } Else {
                    Remove-Item -Path $_.FullName -Recurse -Force
                }                
            } Else {
                Write-Output -InputObject ((Get-Date -Format HH:mm:ss) + " Run $J " + $_.FullName + ' has no JPEGs. Deleting.')
                # Delete folder
                If (-not $Error) {
                    Remove-Item -Path $_.FullName -Recurse -Force
                }
            }
            # Count number of executions 
            $J++
        }
    }
    # Output number of executions
    Write-Output -InputObject ("Processed $J files for " + $CurrentPath + " End time: " + (Get-Date).DateTime)

    ## Wrap up
    # Write nonfatal errors to log
    If (($Error) -or ($ScriptError)) {
        Write-Output -InputObject "*Last detected errors*" 
        Write-Output -InputObject ($Error | Select-Object -First 20)
        Write-Output -InputObject ($ScriptError | Select-Object -First 20)
    }
} Catch {
    Write-Output -InputObject "*Permanent errors*"
    Write-Output -InputObject $_ 
} Finally {
    # Get completion time for the script
    Write-Output -InputObject ("Log started at " + $TimeStart + "`n")
    Write-Output -InputObject ("Last logged entry at " + (Get-Date))
    Stop-Transcript
}


