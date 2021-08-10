<#
    Template Version 2018-03-15
    This procedure script handles these tasks for SampleServer:
        1. Based on server ID, copy Veeam Archive Files to external disk
        2. Clean up archived files on originating server
    It's assumed that Veeam completed successfully. ToDo: integrate Veeam 
    PowerShell features so we don't operate on assumption.
#>

# Create initial setup, run commands, and capture errors
Try {
    ## Initial setup
    # Cleanup any previous 
    Try { Stop-Transcript } Catch {}
    $Error.Clear()
    $ScriptConfig = [PSCustomObject]@{
        TimeStart = Get-Date
        ProcedureName = (Get-Item $MyInvocation.MyCommand.Path).BaseName
        # For valid severity levels, see SendNotification-r?.ps1
        AlertSeverity = 'Test'
        Logpat = $Null
        AlertSubject = $Null
        LogFullPath = $Null
        AlertMessage = $Null
    }
    # Create the PowerUtils drive at the Procedure path, and set as working directory
    If (-not ((Get-PSDrive) -match 'PowerUtils')) {
        New-PSDrive -Name 'PowerUtils' -PSProvider FileSystem -Root (Split-Path $MyInvocation.MyCommand.Path -Parent) -Scope Global
    }
    # Create new log
    $ScriptConfig.LogPath = Join-Path -Path PowerUtils: -ChildPath ('Logs\' + $ScriptConfig.ProcedureName + '-' + (Get-Date -Format yyyy-MM-dd-HHmmss) + '.log')
    Start-Transcript -Path $ScriptConfig.LogPath -IncludeInvocationHeader
    # Prepare message content in case of error alert trigger
    Start-Sleep -Milliseconds 200
    $ScriptConfig.AlertSubject = ($ScriptConfig.AlertSeverity + ': ' + $ScriptConfig.ProcedureName)
    $ScriptConfig.LogFullPath = (Get-Item -Path $ScriptConfig.LogPath).FullName
    $ScriptConfig.AlertMessage = ('Review the log for more details: ' + $ScriptConfig.LogFullPath)

    # Veeam repository information
    $VeeamRepo = [PSCustomObject]@{
        Source = Get-Item -Path 'C:\Backup'
        Destination = Get-Item -Path 'D:\Backup'
        Filter = '*.vbk'
        Backups = [PSCustomObject]@{
                NAS1 = [PSCustomObject]@{
                    FileFilter = 'Sample0*.vbk'
                    LastRun = $Null
                }
                AOI01 = [PSCustomObject]@{
                    FileFilter = 'Sample1*.vbk'
                    LastRun = $Null
                }
            }

    } 

    # Paths to be processed
    $AOIGroups = [System.Collections.ArrayList]@(
        [PSCustomObject]@{
            Name = 'Sample0'
            PathMaster = Get-Item -Path '\\SampleServer\Sample0'
            PathFilter = 'Sample?'
            SearchDepth = 1
            VeeamTarget = 'Sample0'
        }
        , [PSCustomObject]@{
            Name = 'Sample1'
            PathMaster = Get-Item -Path '\\SampleServer\Sample1'
            PathFilter = 'Sample*'
            SearchDepth = 1
            VeeamTarget = 'Sample1'
        }
        , [PSCustomObject]@{
            Name = 'Sample2'
            PathMaster = Get-Item -Path '\\SampleServer\Sample2'
            PathFilter = 'Sample'
            SearchDepth = 1
            VeeamTarget = 'Sample0'
        }
    )

    ## Run commands
    # Copy Veeam backup files to external hard drive
    Write-Output -InputObject 'Copying Veeam backup files to external hard drive.'
    PowerUtils:\Scripts\CopyAgedFiles-r7.ps1 -SourcePath $VeeamRepo.Source -DestinationPath $VeeamRepo.Destination -Filter $VeeamRepo.Filter

    # Get last run times for Veeam backups. If any is not found, generate error.
    $VeeamRepo.Backups | Get-Member -MemberType NoteProperty | ForEach-Object -Process {
        $VeeamRepo.Backups.($_.Name).Lastrun = (
            Get-ChildItem -Path $VeeamRepo.Source -Filter $VeeamRepo.Backups.($_.Name).FileFilter -Recurse -File | `
                Sort-Object -Property CreationTime | Select-Object -First 1
        ).CreationTime
        If ($VeeamRepo.Backups.($_.Name).Lastrun -eq $Null) {
            Write-Error -Message 'Veeam backup file not found' -TargetObject $_.Name
        }
    }

    # Clean up AOI group folders by (oldest) backup date, given no error up to now
    If (-not $Error) {
        $AOIGroups | ForEach-Object -Process {
            Write-Output -InputObject ('Cleaning folders for ' + $_.Name)
            # Get Veeam oldest run time for the backup file for the current AOI data
            $CurrentLastRun = $VeeamRepo.Backups.($_.VeeamTarget).LastRun
            # Enable For Diagnostics
            Write-Output -InputObject ("Last Veeam Backup for this AOI group ran: $CurrentLastRun")
            #Expand paths to be processed
            Get-ChildItem -Path $_.PathMaster -Filter $_.PathFilter -Recurse -Depth $_.SearchDepth -Directory | `
                ForEach-Object -Process {
                    Write-Output -InputObject ('Cleaning ' + $_.FullName)
                    PowerUtils:\Scripts\RemoveAgedFiles-r4.ps1 -SourcePath $_.FullName -OlderThan $CurrentLastRun
                    PowerUtils:\Scripts\RemoveEmptyFolders-r8.ps1 -FolderPath $_.FullName
                }
            Remove-Variable -Name CurrentLastRun
        }
    }

    ## Wrap up
    # Write nonfatal errors to log
    $ScriptConfig.AddNote('Errors',(PowerUtils:\Scripts\FormatErrors-r2.ps1))
    # Notify the System Administrator of the error
    If ($ScriptConfig.Errors) {
        Write-Output -InputObject $ScriptConfig.Errors
        PowerUtils:\Scripts\SendNotification-r3.ps1 -MessageLevel $ScriptConfig.AlertSeverity -MessageSubject $ScriptConfig.AlertSubject -MessageContent $ScriptConfig.AlertMessage -ComputerName $env:COMPUTERNAME
    }
} Catch {
    Write-Output -InputObject '**** Script Terminated ****'
    PowerUtils:\Scripts\FormatErrors-r2.ps1
    # Notify the System Administrator of the error
    PowerUtils:\Scripts\SendNotification-r3.ps1 -MessageLevel $ScriptConfig.AlertSeverity -MessageSubject $ScriptConfig.AlertSubject -MessageContent $ScriptConfig.AlertMessage -ComputerName $env:COMPUTERNAME
} Finally {
    # Get completion time for the script
    Write-Output -InputObject ('Log started at ' + $ScriptConfig.TimeStart)
    $ScriptConfig.AddNote('TimeEnd',(Get-Date))
    Write-Output -InputObject ("Last logged entry at " + $ScriptConfig.TimeEnd)
    $ScriptConfig.AddNote('TotalTime',($ScriptConfig.TimeEnd - $ScriptConfig.TimeStart))
    Write-Output -InputObject ('Script ran for ' + $ScriptConfig.TotalTime.Days + 'd, ' + $ScriptConfig.TotalTime.Hours + 'h, ' + $ScriptConfig.TotalTime.Minutes + 'm, ' + $ScriptConfig.TotalTime.Seconds + 's.')
    Stop-Transcript
}

