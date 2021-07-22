<#
    This procedure script handles these tasks for REDACTEDNAME:
        1. Create JPEG copies of Omron bitmap files 
        2. Add the JPEGs to an archive based on the week of the year
        3. Delete files which "Expired" 
        4. Delete empty folders in the AOI folder structure
    This must be ran on REDACTEDNAME
#>

# Create initial setup, run commands, and capture errors
Try {
    ## Initial setup
    $Error.Clear()
    $TimeStart = Get-Date
    # Create the PowerUtils drive at the Procedure path, and set as working directory
    If (-not ((Get-PSDrive) -match 'PowerUtils')) {
        New-PSDrive -Name 'PowerUtils' -PSProvider FileSystem -Root (Split-Path $MyInvocation.MyCommand.Path -Parent) -Scope Global
    }
    # Create new log
    $ProcedureName = (Get-Item $MyInvocation.MyCommand.Path).BaseName
    $LogFile = Join-Path -Path PowerUtils:\Logs -ChildPath ($ProcedureName + '-' + (Get-Date -Format yyyy-MM-dd-HHmmss) + '.log')
    Start-Transcript -Path $LogFile -IncludeInvocationHeader
    
    # Stored time of last (successful) procedure run
    $AOILastFile =  "PowerUtils:\Store\OmronAOILast.xml"
    $ArchiveAOILast = Import-CliXML -Path $AOILastFile
    Write-Output -InputObject "Last Run Time: $ArchiveAOILast" 
    # AOI Image Folder Paths
    $AOISource = "REDACTEDPATH" 
    $AOIArchive = "REDACTEDPATH" 
    # Clean files based on last successful run
    $AOICutoff = $ArchiveAOILast.AddDays(-14)

    ## Run commands
    # Cycle through each AOI Image folder
    Get-ChildItem -Path $AOISource | Where {($_.Name -like "REDACTEDSTRING*")} | ForEach-Object -Process {
        # Source and destination paths
        $LineSource =  $_.FullName
        $LineArchive = Join-Path -Path $AOIArchive -ChildPath $_.Name
        # Log line number
        Write-Output -InputObject ("Starting archive run on $LineSource at " + (Get-Date)) 
        # Delete AOI images based on cutoff value
        PowerUtils:\Scripts\RemoveAgedFiles-r4.ps1 -SourcePath $LineSource -OlderThan $AOICutoff -RemoveEmptyFolders
        # Copy .txt files over to archive location
        PowerUtils:\Scripts\CopyAgedFiles-r7.ps1 -SourcePath $LineSource -DestinationPath $LineArchive -Filter '*.txt' -NewerThan $ArchiveAOILast -OlderThan $TimeStart
        # Convert AOI .bmp files to .jpg (create new copy in the staging folder)
        PowerUtils:\Scripts\ConvertImages-r5.ps1 -SourcePath $LineSource -DestinationPath $LineArchive -NewerThan $ArchiveAOILast -OlderThan $TimeStart -BmpToJpg 
    }

    # Next steps should only occur if there are no errors up to this point.
    If (!$Error) {
        # Update the last run time
        #Write-Warning -Message 'Error controls bypassed'
        Write-Output -InputObject "Updating last run time to $TimeStart" 
        Export-Clixml -Path $AOILastFile -InputObject $TimeStart
    }

    ## Wrap up
    # Write nonfatal errors to log
    If ($Error) {
        Write-Output -InputObject '*Last detected errors*' 
        PowerUtils:\Scripts\FormatErrors-r1.ps1
        # Notify the System Administrator of the error
        $LogFileFullPath = (Get-Item -Path $LogFile).FullName
        $MessageContent = "Review the log for more details. ($LogFileFullPath)"
        PowerUtils:\Scripts\SendNotification-r3.ps1 -MessageLevel 'Test' -MessageSubject "Error: $ProcedureName" -MessageContent $MessageContent -ComputerName $env:COMPUTERNAME
    }
} Catch {
    Write-Output -InputObject '*Terminating errors*'
    PowerUtils:\Scripts\FormatErrors-r1.ps1
    # Notify the System Administrator of the error
    $LogFileFullPath = (Get-Item -Path $LogFile).FullName
    $MessageContent = "Review the log for more details. ($LogFileFullPath)"
    PowerUtils:\Scripts\SendNotification-r3.ps1 -MessageLevel 'Test' -MessageSubject "*Terminating* Error: $ProcedureName" -MessageContent $MessageContent -ComputerName $env:COMPUTERNAME
} Finally {
    # Get completion time for the script
    Write-Output -InputObject ("Log started at $TimeStart `n")
    $TotalTime = (Get-Date) - $TimeStart
    Write-Output -InputObject ('Script ran for ' + $TotalTime.Days + 'd, ' + $TotalTime.Hours + 'h, ' + $TotalTime.Minutes + 'm, ' + $TotalTime.Seconds + 's.')
    Write-Output -InputObject ("Last logged entry at " + (Get-Date))
    Stop-Transcript
}

