#!/bin/sh
#
# Event handler script for restarting Tomcat on FS01
#
# We have 5 retry checks before bailing out. Try to restart on the 2nd check. 

# What state is the HTTP service in?
case "$1" in
	OK)
		;;
	WARNING)
		;;
	UNKNOWN)
		;;
	CRITICAL)
		case "$2" in
			SOFT)
				case "$3" in
					1)
						echo -n "Restarting Tomcat (2nd soft critical state)..."
						# Call NSClient++ (by NRPE) to handle the restart 
						/usr/local/nagios/libexec/check_nrpe -H SampleIP -c handler_restart_tomcat
						;;
					3)
						echo -n "Restarting Tomcat (2nd soft critical state)..."
						# Call NSClient++ (by NRPE) to handle the restart 
						/usr/local/nagios/libexec/check_nrpe -H SampleIP -c handler_restart_tomcat
						;;
				esac
				;;
			HARD)
				;;
		esac
		;;
esac
exit 0