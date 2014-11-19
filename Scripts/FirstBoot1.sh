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
#            Name:  FirstBoot1.sh
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
package1=$4
package2=$5
package3=$6
package4=$7
package5=$8
package6=$9
package7=${10}
package8=${11}


# Logging function
ScriptLogging(){

    DATE=`date +%Y-%m-%d\ %H:%M:%S`
    LOG="$log_location"
    
    echo "$DATE" " $1" >> $LOG
}

ScriptLogging "Lets Begin"

killall jamfHelper
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Preparing installs...please wait" -icon /Library/Scripts/Robot.icns &
jamf recon >> $log_location 2>&1

# Loop to run through each variable and if set install the package
for arg in $package1 $package2 $package3 $package4 $package5 $package6 $package7 $package8
do 
if [ -n $arg ]
then
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -description "Installing $arg...please wait" -icon /Library/Scripts/Robot.icns &
ScriptLogging "Installing $arg"
jamf policy -trigger $arg >> $log_location 2>&1
fi
done