<#
This script handles email notifications
There are multiple levels, and notifications are handled differently based on level
Some notification levels are not implemented, and are added to maintain consistency to the monitoring system levels
    1. Test - Justin only 
    2. Warning - Sample mailbox
    3. Severe  - SMS alerts, Sample distro and Sample mailbox
Notification levels Information, Urgent, and Critical are not officially implemented.
#>
param(
    [Parameter(Position=1)][String]$MessageLevel = "Test",
    [Parameter(Position=2)][String]$MessageSubject = "Network Notification",
    [Parameter(Mandatory=$True,Position=3)]$MessageContent,
    [Parameter(Position=4)][String]$ComputerName = $env:COMPUTERNAME
)

# Initial configuration
# Set the recipient based on alert priority
Switch ($MessageLevel) {
    "Test" { 
        $Recipient = "sample1@sample.ninja" 
    } 
    "Warning" {
        $Recipient = "sample2@sample.ninja" 
    }
    "Urgent" { 
        $Recipient = "sample3@sample.ninja" 
    }
    "Critical" {
        # SMS works best as plain text
        $Recipient = "sample4@sample.ninja"
        $MessagePlainText = $True 
    }
    "WDPCritical" {
        # SMS works best as plain text
        $Recipient = "sample5@sample.ninja"
        $MessagePlainText = $True
    }
    default {
        $Recipient = "sample1@sample.ninja" 
    }
}
# Sender address
$Sender = "sample0@sample.ninja"
# Message creation time
$MessageTime = Get-Date

# Build out the message and send it
If ($MessagePlainText) {
    $MessageBody = $MessageContent
    Send-MailMessage -From $Sender -To $Recipient -Subject $MessageSubject -Body $MessageBody -SmtpServer smtp.sample.ninja
} Else { 
    $MessageBody = "
        <!doctype html>
        <html>
            <head>
            </head>
            <body>
                <table border='0' cellpadding='1' cellspacing='1' style='width: 500px;'>
	                <tbody>
		                <tr>
			                <td><span style='font-family:tahoma,geneva,sans-serif;'>Computer Name:</span></td>
			                <td><span style='font-family:tahoma,geneva,sans-serif;'>$ComputerName</span></td>
		                </tr>
		                <tr>
			                <td><span style='font-family:tahoma,geneva,sans-serif;'>Message Level:</span></td>
			                <td><span style='font-family:tahoma,geneva,sans-serif;'>$MessageLevel</span></td>
		                </tr>
		                <tr>
			                <td><span style='font-family:tahoma,geneva,sans-serif;'>Time:</span></td>
			                <td><span style='font-family:tahoma,geneva,sans-serif;'>$MessageTime</span></td>
		                </tr>
		                <tr>
			                <td><span style='font-family:tahoma,geneva,sans-serif;'>Message:</span></td>
			                <td><span style='font-family:tahoma,geneva,sans-serif;'>$MessageContent</span></td>
		                </tr>
	                </tbody>
                </table>
            </body>
        </html>
    "
    Send-MailMessage -From $Sender -To $Recipient -Subject $MessageSubject -Body $MessageBody -BodyAsHtml -SmtpServer smtp.otsego
}