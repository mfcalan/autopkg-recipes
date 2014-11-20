#!/bin/sh

###
#
# Script to be used with Casper to auto update apps using custom triggers
# If the app is running it will quit and wait until the next run
# JAMFs Management Action.app is used to inform the user what has been updated via Notification Center
# Inventory is taken to remove the Mac from the smart group
# $4 is the application name, this will be used to check if the process is running
# $5 is the JSS custom trigger that will be used to install the app
# $4 and $5 are set in the parameter value fields in the policy settings in the JSS
#
###

###
#
#            Name:  AutoUpdate.sh
#          Author:  Alan McCrossen <alan.mccrossen@wk.com>
#         Created:  2014-11-19
#         Version:  1.0
#
###


app="$4"
trigger="$5"
process=`pgrep -f "$app"`
	
if [[ $process != "" ]]; then
   	echo "$app is running. Skipping auto update."
else
    echo "$app is not running. Calling policy trigger $trigger."
    /usr/sbin/jamf policy -trigger $trigger
    /Library/Application\ Support/JAMF/bin/Management\ Action.app/Contents/MacOS/Management\ Action -message "$app has been updated"
    jamf recon
fi