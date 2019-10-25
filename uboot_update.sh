#!/bin/bash
set -e
#########################################################
##
##
## Update uboot and boot0
#########################################################
# ROOT must be top direct
if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi
# Output path, must /dev/sdx
OUTPUT="$1"

BOOT0=$ROOT/output/uboot/boot0_sdcard_sun8iw7p1.bin
UBOOT=$ROOT/output/uboot/u-boot-sun8iw7p1.bin

# Clean SD partition
dd bs=1K seek=8 count=1015 if=/dev/zero of="$OUTPUT"
# Update uboot
sudo dd if=$BOOT0 of=$OUTPUT bs=1k seek=8
sudo dd if=$UBOOT of=$OUTPUT bs=1k seek=16400

sync
clear
whiptail --title "OrangePi Build System" --msgbox "Succeed to update Uboot" 10 40 0
