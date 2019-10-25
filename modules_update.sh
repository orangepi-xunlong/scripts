#!/bin/bash
################################################
##
## Update Modules
################################################
set -e
if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi
OUTPUT="$1"
BUILD=$ROOT/output

#####
# Remove old modules
rm -rf $OUTPUT/lib/modules

cp -rfa $BUILD/lib/modules $OUTPUT/lib/ 

sync 
clear
whiptail --title "OrangePi Build System" \
	     --msgbox "Succeed to update Module" \
		 10 40 0 
