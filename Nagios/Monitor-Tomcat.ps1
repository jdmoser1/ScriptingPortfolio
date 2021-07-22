<#
    This script performs the following check:
        The Tomcat serviceis using less than 80 threads. At
        that point, it's assumed that Tomcat has crashed, 
        and is grabbing up threads until it has restarted.        
    To comply with how Nagios handles return data, A true
    result returns a 0 code with a message. A false result
    returns a 2 (Critical)
#>

$TomcatThreadCount = (Get-Process -Name Tomcat7).Threads.Count
$TomcatThreshold = 75
Write-Output -InputObject "Tomcat: thread count at $TomcatThreadCount - threshold is $TomcatThreshold"

If ($TomcatThreadCount -ge $TomcatThreshold) {
    Exit 2
} Else {
    Exit 0
}
