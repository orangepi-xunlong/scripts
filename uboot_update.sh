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

UBOOT=$ROOT/output/uboot/u-boot-sunxi-with-spl.bin

# Clean SD partition
dd bs=1K seek=8 count=1015 if=/dev/zero of="$OUTPUT"
# Update uboot
pv "$UBOOT" | dd bs=1K seek=8 of="$OUTPUT" && sync

sync
clear
whiptail --title "OrangePi Build System" --msgbox "Succeed to update Uboot" 10 40 0
