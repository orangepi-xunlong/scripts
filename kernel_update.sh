#!/bin/bash
set -e
##################################################
##
## Update kernel and DTS
##################################################
if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi
PLATFORM=$2
KERNEL=$ROOT/output/uImage_${PLATFORM}
KERNEL_PATH="$1"

# Update kernel
rm -rf $KERNEL_PATH/uImage
cp -rf $KERNEL $KERNEL_PATH/uImage

sync

whiptail --title "OrangePi Build System" \
		 --msgbox "Succeed to update kernel" \
		  10 60
