#!/bin/bash
#
###############################################################################
#
# Purpose:      This script is meant to automate the removal of the Railo CFML
#               processing engine along with related plugins and modules.
#
# Copyright:    Copyright (C) 2012-2013
#               by Jordan Michaels (jordan@viviotech.net)
#
# License:      LGPL 3.0
#               http://www.opensource.org/licenses/lgpl-3.0.html
#
#               This program is distributed in the hope that it will be useful, 
#               but WITHOUT ANY WARRANTY; without even the implied warranty of 
#               MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
#               GNU General Public License for more details.
#
# Usage:        Simply run "remove_railo4cpanel.sh" to remove railo4cpanel
#
###############################################################################

version=1.0;
progname=$(basename $0);
basedir=$( cd "$( dirname "$0" )" && pwd );

# variable to be replaced by installation program to store the install directory
# myInstallDir="@@installdir@@";
myInstallDir="/opt/railo";

# switch the subshell to the basedir so all relative dirs resolve
cd $basedir;

# ensure we're running as root
if [ ! $(id -u) = "0" ]; then
        echo "Error: This installation script needs to be run as root.";
        echo "Exiting...";
        exit;
fi

###############################################################################
# BEGIN FUNCTION LIST
###############################################################################

function print_welcome {
        echo "";
        echo "###############################################################";
        echo "#        Welcome to the Railo4cPanel Removal Program          #";
        echo "###############################################################";
	echo "";

while true; do
	echo "!!WARNING!!";
	echo "Performing this removal will permenantly delete Railo Server,";
	echo "the railo4cpanel plugins, modules, and all associated files";
	echo "and directories. This action is PERMANENT and CANNOT be UNDONE!";
	echo "";
	read -p "Are you sure you want to proceed? (y/N): " yn;
	case $yn in
		[Yy]* ) break;;
		[Nn]* ) echo "* ABORTED at user request. Exiting..."; exit 1;;
		#* ) echo "Answer must be 'y' or 'n'";;
		* ) echo "* ABORTED at user request. Exiting..."; exit 1;;
	esac
done

}

function remove_railo_cpanel_plugin {
	# remove the web-based files for the plugin
	echo -n "* [INFO] Removing Railo Plugin for cPanel front-end...";
	rm -rf /usr/local/cpanel/base/frontend/default/railo_plugin/;
	local commandSuccessful=$?;
		
	# 0 means command executed just fine
        if [ $commandSuccessful -eq 0 ]; then
                echo "[SUCCESS]";
        else
                echo "[FAIL]";
                echo "";
                echo "* [INFO] Command Failed: rm -rf /usr/local/cpanel/base/frontend/default/railo_plugin/";
                echo "* Script exit code: ${commandSuccessful}";
                echo "";
        fi
	
	# unregister the plugin from within cPanel
	echo -n "* [INFO] Unregistering the Railo cPanel Plugin...";
	/usr/local/cpanel/bin/unregister_cpanelplugin /usr/local/cpanel/bin/railo_plugin.cpanelplugin > /dev/null
	local commandSuccessful=$?;

        # 0 means command executed just fine
        if [ $commandSuccessful -eq 0 ]; then
                echo "[SUCCESS]";
        else
                echo "[FAIL]";
                echo "";
                echo "* [INFO] Command Failed: /usr/local/cpanel/bin/unregister_cpanelplugin /usr/local/cpanel/bin/railo_plugin.cpanelplugin";
                echo "* Script exit code: ${commandSuccessful}";
                echo "";
        fi

}

function remove_railo_apache_config {
	# remove the railo apache include if it exists
	myRailoApacheConfig="/usr/local/apache/conf/userdata/railo.conf";
	echo -n "* Removing Railo Apache Config...";
	if [[ -f $myRailoApacheConfig ]]; then
		rm -f $myRailoApacheConfig;
		local commandSuccessful=$?;
	fi
	if [ $commandSuccessful -eq 0 ]; then
                echo "[SUCCESS]";
        else
                echo "[FAIL]";
                echo "";
                echo "* [INFO] Command Failed: rm -f ${myRailoApacheConfig}";
                echo "* Script exit code: ${commandSuccessful}";
                echo "";
        fi
	
	echo -n "* Applying Apache Changes to Users...";
	/scripts/ensure_vhost_includes --all-users;
	local commandSuccessful=$?;
	
	if [ $commandSuccessful -eq 0 ]; then
                echo "[SUCCESS]";
        else
                echo "[FAIL]";
                echo "";
                echo "* [INFO] Command Failed: /scripts/ensure_vhost_includes --all-users";
                echo "* Script exit code: ${commandSuccessful}";
                echo "";
        fi
}

function remove_railo_hooks {
	# function to remove the includes from POSTWWWACCT and PREKILLACCT
	myHookFile="/scripts/prekillacct";
	# see if the railo config is still present
	if [[ ! -f $myHookFile ]]; then
	        echo "* PREKILLACCT does not exist...skipping.";
	else
		echo -n "* Removing PREKILLACCT config...";
		sed -i '/#\ @BEGINRAILO/,/#\ @ENDRAILO/d' $myHookFile
		echo "[SUCCESS]";
	fi
	
	myHookFile="/scripts/postwwwacct";
        # see if the railo config is still present
        if [[ ! -f $myHookFile ]]; then
                echo "* POSTWWWACCT does not exist...skipping.";
        else
                echo -n "* Removing POSTWWWACCT config...";
                sed -i '/#\ @BEGINRAILO/,/#\ @ENDRAILO/d' $myHookFile
		echo "[SUCCESS]";
        fi
	
        myHookFile="/scripts/postkillacct";
        # see if the railo config is still present
        if [[ ! -f $myHookFile ]]; then
                echo "* POSTKILLACCT does not exist...skipping.";
        else
                echo -n "* Removing POSTKILLACCT config...";
                sed -i '/#\ @BEGINRAILO/,/#\ @ENDRAILO/d' $myHookFile
                echo "[SUCCESS]";
        fi

	#echo -n "* Removing Railo Hook Files...";
	#rm -rf /scripts/postwwwacct_railo;
	#rm -rf /scripts/prekillacct_railo;
	#echo "[SUCCESS]";
}

function remove_railo_server {
	# run the railo uninstaller in silent mode
	echo -n "* Removing Railo Server...";
	${myInstallDir}/uninstall --mode unattended;
	local commandSuccessful=$?;

        # 0 means command executed just fine
        if [ $commandSuccessful -eq 0 ]; then
                echo "[SUCCESS]";
        else
                echo "[FAIL]";
                echo "";
                echo "* [INFO] Command Failed: ${myInstallDir}/uninstall --mode unattended";
                echo "* Script exit code: ${commandSuccessful}";
                echo "";
        fi
}

function cleanup_railo {
	# this command should be saved till last as it removes everything
	# related to Railo from the /opt/ directory
	echo -n "* Performing final clean-up...";
	rm -rf /opt/railo*;
	local commandSuccessful=$?;

        # 0 means command executed just fine
        if [ $commandSuccessful -eq 0 ]; then
                echo "[SUCCESS]";
        else
                echo "[FAIL]";
                echo "";
                echo "* [INFO] Command Failed: rm -rf /opt/railo*;";
                echo "* Script exit code: ${commandSuccessful}";
                echo "";
        fi
}

###############################################################################
# END FUNCTION LIST
###############################################################################

print_welcome;
remove_railo_cpanel_plugin;
remove_railo_apache_config;
remove_railo_hooks;
remove_railo_server;
cleanup_railo;

echo "* DONE";
