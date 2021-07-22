<#
    This procedure script handles these tasks for Local AOI Machines:
        Convert OIS images to JPEG and move to AOI01. With the current 
        configuration, this script should be restarted every two hours. (So 
        that terminating errors don't cause the local drive to fill up.)
#>
# Create initial setup, run commands, and capture errors
Try {
    ## Initial setup
    $Error.Clear()
    # Create new log
    $TimeStart = Get-Date
    $LogName = (Get-Item $MyInvocation.MyCommand.Path).BaseName
    $LogFile = Join-Path -Path "REDACTEDPATH" -ChildPath ("Logs\" + $LogName + "-" + (Get-Date -Format yyyy-MM-dd-HHmmss) + ".log")
    Start-Transcript -Path $LogFile 
    Write-Output -InputObject ("Log output for " + $LogName + " generated at " + $TimeStart + "`n")
    # Folder locations
    # The exact location for the local path isn't controlled by IT. It should always be a subfolder of this location
    $VITAOILocalRoot = "REDACTEDPATH"
    # Common path to OIS extractor executable 
    $OISExtractorPath = "REDACTEDEXE"
    # Folder Locations differ based on computer
    Switch ($Env:COMPUTERNAME) {
        "REDACTEDNAME0" {
            $MEID = 'REDACTEDNAME'
            $VITAOIArchive = "REDACTEDPATH"
        }
        "REDACTEDNAME1" {
            $MEID = 'REDACTEDNAME'
            $VITAOIArchive = "REDACTEDPATH"
        }
        "REDACTEDNAME2" {
            $MEID = 'REDACTEDNAME'
            $VITAOIArchive = "REDACTEDPATH"
        }
        "REDACTEDNAME3" {
            $MEID = 'REDACTEDNAME'
            $VITAOIArchive = "REDACTEDPATH"
        }
        "REDACTEDNAME4" {
            $MEID = 'Test'
            $VITAOILocalRoot = 'REDACTEDPATH'
        }
        default {
            $MEID = 'Unknown'
            $VITAOIArchive = 'REDACTEDPATH'

        }
    }
    # Path for 'problem' images
    $VITAOIOrphaned = 'REDACTEDPATH'
    # Time to end 
    $VITAOIEnd = $TimeStart.AddMinutes(116)
    # Counter
    $J = 0

    ## Run commands
    # Clean out the logs folder
    Get-ChildItem -Path C:\Support\Logs | Where {($_.LastWriteTime -le (Get-Date).AddDays(-5))} | Foreach {
        Remove-Item -Path $_.FullName
    }

    # Connect to remote paths
    & cmdkey /add:REDACTEDNAME /user:REDACTEDCRED /pass:REDACTEDCRED

    # Loop for until end of time period
    While ((Get-Date) -lt $VITAOIEnd) {
        # Avoid processing folders that the machine is still working on, don't process anything newer than VITAOIDelay
        $VITAOIDelay = (Get-Date).AddSeconds(-120)
        # Process each folder in the root path
        Get-ChildItem -Path $VITAOILocalRoot | ForEach-Object -Process {
            # Process image subfolders that changed since last run
            Get-ChildItem -Path $_.FullName | `
                Where {($_.LastWriteTime -le $VITAOIDelay) -and ($_.CreationTime -le $VITAOIDelay)} | `
                Foreach {
                    # Expected final location
                    $CurrentPath = $_.FullName
                    # Enable during testing
                    #Write-Output -InputObject "Extracting JPEGs from $CurrentPath"
                    # Use OISExtractor tool local to AOI1701 to extract images from .ois and convert them to .jpg
                    $OISExtractorGray1 = '-f "' + $CurrentPath + '" -d "' + $CurrentPath + '" -i JPEG -D -l L1'
                    $OISExtractorGray3 = '-f "' + $CurrentPath + '" -d "' + $CurrentPath + '" -i JPEG -D -l L3'
                    $OISExtractorColor = '-f "' + $CurrentPath + '" -d "' + $CurrentPath + '" -i JPEG -D -F'
                    Start-Process -FilePath $OISExtractorPath -ArgumentList $OISExtractorGray1 -Wait -NoNewWindow -ErrorAction Continue
                    Start-Process -FilePath $OISExtractorPath -ArgumentList $OISExtractorGray3 -Wait -NoNewWindow -ErrorAction Continue
                    $OISExtractorResult = Start-Process -FilePath $OISExtractorPath -ArgumentList $OISExtractorColor -PassThru -Wait -NoNewWindow -ErrorAction Continue
                    # Move JPegs to Archive
                    If  (Test-Path $VITAOIArchive) {
                        # Enable during testing
                        #Write-Output -InputObject "Moving $CurrentPath to $VITAOIArchive"
                        # Move the remaining files to the final location
                        #Move-Item -Path $CurrentStagingPath -Destination $VITAOIArchive -Force
                        Copy-Item -Path $CurrentPath -Destination $VITAOIArchive -Filter "*.jpeg" -Recurse -Force -ErrorAction Continue
                        Copy-Item -Path $CurrentPath -Destination $VITAOIArchive -Filter "*.jpg" -Recurse -Force -ErrorAction Continue
                        # Remove if no executable error
                        If ($OISExtractorResult.ExitCode -eq 0) {
                            Write-Output -InputObject ('Complete: ' + $_.Name)
                            Remove-Item -Path $CurrentPath -Recurse
                            # Update SQL database with passing result (Powershell 2.0 Compatible)
                            $SQLConnection = New-Object System.Data.SqlClient.SqlConnection
                            $SQLConnection.ConnectionString = "Data Source=REDACTEDNAME;Initial Catalog=REDACTEDNAME;uid=REDACTEDCRED;pwd=REDACTEDCRED"
                            $SQLConnection.Open()
                            $SQLCommand = $SQLConnection.CreateCommand()
                            $SQLCommand.CommandText = ("INSERT INTO REDACTEDNAME (Panel,TransferStatus,MEID) VALUES ('"+$_.Name+"',1,'$MEID')")
                            $SQLCommand.ExecuteReader()
                            $SQLConnection.Close()
                        } Else {
                            Copy-Item -Path $CurrentPath -Destination $VITAOIOrphaned -Recurse -Force -ErrorAction Continue
                            Remove-Item -Path $CurrentPath -Recurse -Force -ErrorAction Continue
                        }
                    }
                    # Count number of executions
                    $J++
                }
        }
        # Output number of executions
        Write-Output -InputObject ("Processed " + $J + " files for " + $VITAOIPath + " End time: " + (Get-Date).DateTime)
        $J = 0
        Start-Sleep -Seconds 60
    }

    ## Wrap up
    # Write nonfatal errors to log
    If ($Error) {
        Write-Output -InputObject "*Last detected errors*" 
        Write-Output -InputObject ($Error | Select-Object -First 20)
        # Notify the System Administrator of the error
        $MessageContent = ("Review the log " + $LogFile + " for more details.")
        $MessageSubject = ("Error: " + $LogName)
        REDACTEDPATH\Scripts\SendNotification-r3.ps1 -MessageLevel "Warning" -MessageSubject $MessageSubject -MessageContent $MessageContent -ComputerName $env:COMPUTERNAME
    }
} Catch {
    Write-Output -InputObject "*Permanent errors*"
    Write-Output -InputObject $_ 
    # Notify the System Administrator of the error
    $MessageContent = ("Review the log " + $LogFile + " for more details.")
    $MessageSubject = ("Error: " + $LogName)
    REDACTEDPATH\Scripts\SendNotification-r3.ps1 -MessageLevel "Warning" -MessageSubject $MessageSubject -MessageContent $MessageContent -ComputerName $env:COMPUTERNAME
} Finally {
    # unlink credentials
    #& cmdkey /delete:safusot-14aoi01
    # Get completion time for the script
    Write-Output -InputObject ("Log started at " + $TimeStart + "`n")
    Write-Output -InputObject ("Last logged entry at " + (Get-Date))
    Stop-Transcript
}

