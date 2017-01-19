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

# Update kernel and DTB
cp -rf $KERNEL $KERNEL_PATH/uImage
cp -rf $ROOT/output/uboot/boot.scr $KERNEL_PATH/

sync

whiptail --title "OrangePi Build System" \
		 --msgbox "Succeed to update kernel" \
		  10 60
