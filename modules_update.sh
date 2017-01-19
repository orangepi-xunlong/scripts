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

FILE_NUM=$(ls $BUILD/lib/modules -lR | grep "^-" | wc -l)
#####
# Remove old modules
rm -rf $OUTPUT/lib/modules
rm -rf $OUTPUT/lib/firmware

cp -rfa $BUILD/lib/modules $OUTPUT/lib/ 
cp -rfa $BUILD/lib/firmware $OUTPUT/lib/ 

sync 
clear
whiptail --title "OrangePi Build System" \
	     --msgbox "Succeed to update Module" \
		 10 40 0 
