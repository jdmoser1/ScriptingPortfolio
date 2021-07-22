<#
    This script performs the following check:
        SQL Database are all online, and SQL Agent Jobs
        recently ran without issues. 
    To comply with how Nagios handles return data, this
    script returns either 0 (OK), 1 (WARNING), or 2 
    (CRITICAL) as an error status.
    This script requires the SqlServer module.
#>

# Database server for Fourth Shift
$DBServer = 'REDACTEDNAME'
$Database = 'REDACTEDNAME'  
$DBUsername = 'REDACTEDCRED'
$DBPassword = 'REDACTEDCRED'
# Date in yyyyMMdd format, and time in hhmmss
$SQLJobCutoff = (Get-Date).AddMinutes(-120)
$SQLJobDate = Get-Date -Date $SQLJobCutoff -Format yyyyMMdd
$SQLJobTime = Get-Date -Date $SQLJobCutoff -Format hhmmss
# Job duration limit (hhmmss)
$SQLJobLimit = 500

## Validate required modules
If ('SqlServer' -notin (Get-Module -ListAvailable).Name) { Write-Warning -Message 'SqlServer module not found' }

## Commands
# Get database list and status
$DBStateQuery = 'SELECT name, state, state_desc FROM sys.databases'
Invoke-Sqlcmd -ServerInstance $DBServer -Database $Database -Query $DBStateQuery -Username $DBUsername -Password $DBPassword | ForEach-Object -Process {
    #Write-Output -InputObject ('Database ' + $_.name + ' has the current state: ' + $_.state_desc + "; `n" )
    If ($_.state -ne 0) {
        $DBStateException += 'Investigate database ' + $_.name + '; status reported: ' + $_.state_desc + "; `n"
    }
}


# Get SQL Agent job status
$SQLJobQuery = '
    SELECT 
        J.name
        , description
        , run_status
        , run_duration
        FROM msdb.dbo.sysjobs AS J
        JOIN msdb.dbo.sysjobhistory AS H
            ON J.job_id = H.job_id 
        WHERE J.enabled = 1
            AND run_date = ' + $SQLJobDate + ' 
            AND run_time > ' + $SQLJobTime + '
'
Invoke-Sqlcmd -ServerInstance $DBServer -Database $Database -Query $SQLJobQuery  -Username $DBUsername -Password $DBPassword | ForEach-Object -Process {
    #Write-Output -InputObject ('SQL Job ' + $_.name + ' has a status: ' + $_.run_status + '; ' + $_.run_duration)
    # Status 0 means "Failed"
    If ($_.run_status -eq 0) {
        $SQLJobException += 'Job ' + $_.name + ' (' + $_.description + ') failed.'
    }
    If ($_.run_duration -gt $SQLJobLimit) {
        # If the job runs for too long, generate alert
        $SQLJobException += 'Job ' + $_.name + ' (' + $_.description + ') is took a long time to complete: ' + $_.run_duration + "(hhmmss)  `n"
    }
}

# Set exit code
If ($DBStateException) {
    Write-Output -InputObject $DBStateException
    Exit 2
} Elseif ($SQLJobException -or $Error) {
    Write-Output -InputObject $SQLJobException
    Exit 1
} Else {
    Write-Output -InputObject 'All databases are online, and jobs are running successfully.'
    Exit 0
}