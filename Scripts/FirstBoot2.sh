#!/bin/sh
#
###
#
# The purpose of this script is to make sure the most recent version of an app is installed at imaging time without having to keep updating the config in Casper Admin. Autopkg keeps the apps and custom trigger policy up to date.
# First boot script to install apps, the apps are installed by calling their custom trigger in the JSS
# The triggers for the app installs are set in the JSS under Parameter Values, for example the custom trigger policy for Java is Java7 so Java7 must be added as a parameter value in the JSS policy for either FirstBoot1 or FirstBoot2.
# BOTH FirstBoot1 and FirstBoot2 have to be added to the policy to complete
# Only 8 parameters can be set in the JSS therefore having 2 scripts allows up to 16 apps to be installed
# If a parameter is left empty it is skipped
# If FirstBoot2 has no parameters set it only checks for Apple updates and kills the jamfHelper process
# If Apple updates are available it will create a launch agent and script that will run at the login window at reboot
# A log file is created in /Library/Logs/FirstBootInstall
# FirstBoot1.sh is kicked off by a package installed on the boot drive after imaging that calls the JSS custom trigger. 
#
###

###
#
#            Name:  FirstBoot2.sh
#          Author:  Alan McCrossen <alan.mccrossen@wk.com>
#         Created:  2014-11-06
#   Last Modified:  2014-11-18
#         Version:  1.1
#
###

log_location=/Library/Logs/FirstBootInstall.log
pathToScript=$0
pathToPackage=$1
targetLocation=$2
targetVolume=$3
package9=$4
package10=$5
package11=$6
package12=$7
package13=$8
package14=$9
package15=${10}
package16=${11}


# Logging function
ScriptLogging(){

    DATE=`date +%Y-%m-%d\ %H:%M:%S`
    LOG="$log_location"
    
    echo "$DATE" " $1" >> $LOG
}

# Loop to run through each variable and if set install the package
for arg in $package9 $package10 $package11 $package12 $package13 $package14 $package15 $package16
do 
if [ -n $arg ]
then
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Installing $arg...please wait" -icon /Library/Scripts/Robot.icns &
ScriptLogging "Installing $arg"
jamf policy -trigger $arg >> $log_location 2>&1
fi
done

# All 3rd party apps are installed, time to check for Apple updates
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Checking for Apple updates..." -icon /Library/Scripts/Robot.icns &
ScriptLogging "Checking for Apple updates"

AvailableUpdatesNoRestartNeeded=`softwareupdate -l | grep recommended | grep -v restart`
AvailableUpdatesRestartRequired=`softwareupdate -l | grep restart`

sleep 3
  
if [[ "$AvailableUpdatesRestartRequired" != "" ]] || [[ "$AvailableUpdatesNoRestartNeeded" != "" ]]; then
	ScriptLogging "Updates available, will be installed at reboot"
  /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Apple updates are available and will be installed at reboot" -icon /Library/Scripts/Robot.icns &

##########################################################################################################
# Create LaunchAgent /Library/LaunchAgents/com.wk.FirstBootAppleSoftwareUpdates.plist, 
# that will run /Library/Scripts/FirstBootAppleSoftwareUpdate.sh at the Login Window at reboot
########################################################################################################## 
 
  /bin/cat > "/Library/LaunchAgents/com.wk.FirstBootAppleSoftwareUpdates.plist" << 'LAUNCHAGENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.wk.FirstBootAppleSoftwareUpdates</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Library/Scripts/FirstBootAppleSoftwareUpdates.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>LimitLoadToSessionType</key>
	<string>LoginWindow</string>
</dict>
</plist>
LAUNCHAGENT
##########################################################################################################
########################################################################################################## 


	# Set the correct ownership and permissions
	chown root:wheel /Library/LaunchAgents/com.wk.FirstBootAppleSoftwareUpdates.plist
	chmod 644 /Library/LaunchAgents/com.wk.FirstBootAppleSoftwareUpdates.plist

##########################################################################################################
# Create FirstBootAppleSoftwareUpdate.sh which will install Apple updates
# Once the updates are installed the machine will reboot and check for updates again
# It will keep doing this until all updates are installed
# It will then run Recon before removing the script and launchagent
##########################################################################################################
	/bin/cat > "/Library/Scripts/FirstBootAppleSoftwareUpdates.sh" << 'SCRIPT'
#!/bin/sh

# Script to check for and install Apple software updates at the login window during imaging.
# Created along with a launchagent, com.wk.FirstBootAppleSoftwareUpdates.plist, by FirstBoot2.sh
# Used as part of Casper Imaging workflow to make sure all news Macs have the latest Apple software versions

log_location=/Library/Logs/FirstBootInstall.log

#####################################################
# FUNCTIONS
#####################################################
# Logging
ScriptLogging(){

    DATE=`date +%Y-%m-%d\ %H:%M:%S`
    LOG="$log_location"
    
    echo "$DATE" " $1" >> $LOG
}

#####################################################

# Network check, used to check computer is online before trying to check for updates
CheckForNetwork(){

# Determine if the network is up by looking for any non-loopback network interfaces.

    local test
    
    if [[ -z "${NETWORKUP:=}" ]]; then
        test=$(ifconfig -a inet 2>/dev/null | sed -n -e '/127.0.0.1/d' -e '/0.0.0.0/d' -e '/inet/p' | wc -l)
        if [[ "${test}" -gt 0 ]]; then
            NETWORKUP="-YES-"
        else
            NETWORKUP="-NO-"
        fi
    fi
}

#####################################################
# END OF FUNCTIONS
#####################################################

ScriptLogging "*BOOT TIME*"

/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Waiting for network to come online...please ensure ethernet cable is connected" -icon /Library/Scripts/Robot.icns &
ScriptLogging "Checking for active network connection."

CheckForNetwork
i=1
while [[ "${NETWORKUP}" != "-YES-" ]] && [[ $i -ne 720 ]]
do
    sleep 5
    NETWORKUP=
    CheckForNetwork
    echo $i
    i=$(( $i + 1 ))
done

# The network connection check will occur every 5 seconds and if no network connection is found within 60 minutes the script will exit.

if [[ "${NETWORKUP}" != "-YES-" ]]; then
   ScriptLogging "Network connection appears to be offline...Exiting."
   /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "No network connection...exiting" -icon /Library/Scripts/Robot.icns &
   sleep 5
   killall jamfHelper
   rm /Library/LaunchAgents/com.wk.FirstBootAppleSoftwareUpdates.plist
   rm /Library/Scripts/FirstBootAppleSoftwareUpdates.sh
fi

if [[ "${NETWORKUP}" == "-YES-" ]]; then
ScriptLogging "Network connection appears to be live."
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Checking for Apple updates...please wait" -icon /Library/Scripts/Robot.icns &

ScriptLogging "Checking for updates"
AvailableUpdatesNoRestartNeeded=`softwareupdate -l | grep recommended | grep -v restart`
AvailableUpdatesRestartRequired=`softwareupdate -l | grep restart`
 
	if [[ "$AvailableUpdatesRestartRequired" != "" ]] || [[ "$AvailableUpdatesNoRestartNeeded" != "" ]]; then
		ScriptLogging "Updates available...installing" 
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Installing Apple updates...this might take a while" -icon /Library/Scripts/Robot.icns &
		softwareupdate -i -a 2>&1 >> $log_location
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Restarting" -icon /Library/Scripts/Robot.icns &
		ScriptLogging "Updates complete...restarting"
		shutdown -r now
	else
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "All up to date...updating inventory" -icon /Library/Scripts/Robot.icns &
		ScriptLogging "No Apple updates available"
		jamf recon 2>&1 >> $log_location
		/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Just finishing up...almost there...be patient" -icon /Library/Scripts/RobotWaving.icns &
		sleep 4
		ScriptLogging "Killing jamfHelper"
		killall jamfHelper
		ScriptLogging "Removing launchagent and script"
		killall jamfHelper
		rm /Library/LaunchAgents/com.wk.FirstBootAppleSoftwareUpdates.plist
		rm /Library/Scripts/FirstBootAppleSoftwareUpdates.sh
	fi
fi
SCRIPT
##########################################################################################################
########################################################################################################## 


	# Set the correct ownership and permissions
	chown root:wheel /Library/Scripts/FirstBootAppleSoftwareUpdates.sh
	chmod 755 /Library/Scripts/FirstBootAppleSoftwareUpdates.sh
	sleep 5
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Restarting" -icon /Library/Scripts/Robot.icns &
  
else
	# No Apple updates to worry about lets just run recon and restart
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "No Apple updates available" -icon /Library/Scripts/Robot.icns &
	ScriptLogging "No Apple updates available"
	sleep 3
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Updating inventory...please wait" -icon /Library/Scripts/Robot.icns &
	jamf recon >> $log_location
	/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Just finishing up...almost there...be patient" -icon /Library/Scripts/RobotWaving.icns &
fi

ScriptLogging "Restarting"