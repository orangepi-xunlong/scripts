#!/bin/bash
set -e
#################################
##
## Compile U-boot
## This script will compile u-boot
#################################
# ROOT must be top direct.
if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi
# PLATFORM.
if [ -z $PLATFORM ]; then
	PLATFORM="OrangePiH3_Pc"
fi

# Uboot direct
UBOOT=$ROOT/uboot
BUILD=$ROOT/output/uboot
EXTERNAL=$ROOT/external
CORES=$((`cat /proc/cpuinfo | grep processor | wc -l` - 1))

if [ ! -d $BUILD ]; then
	mkdir -p $BUILD
else
	rm -rf $BUILD/*
fi

# Perpar souce code
if [ ! -d $UBOOT ]; then
	whiptail --title "OrangePi Build System" \
		--msgbox "u-boot doesn't exist, pls perpare u-boot source code." \
		10 50 0
	exit 0
fi

cd $UBOOT
clear
echo "Compile U-boot......"
if [ ! -f $UBOOT/u-boot-sun8iw7p1.bin ]; then
	make  sun8iw7p1_config
fi
make -j${CORES}
echo "Complete compile...."

echo "Compile boot0......"
if [ ! -f $UBOOT/sunxi_spl/boot0/boot0_sdcard.bin ]; then
	make  sun8iw7p1_config
fi
make spl -j${CORES}
cd -
echo "Complete compile...."
#####################################################################
###
### Merge uboot with different binary
#####################################################################

cp $UBOOT/boot0_sdcard_sun8iw7p1.bin $BUILD
cp $UBOOT/u-boot-sun8iw7p1.bin $BUILD
cp $EXTERNAL/Legacy_patch/uboot/* $BUILD

cd $BUILD/
./update_boot0 boot0_sdcard_sun8iw7p1.bin sys_config.bin SDMMC_CARD
./update_uboot u-boot-sun8iw7p1.bin sys_config.bin

rm -rf sys_config.bin  update_boot0  update_uboot

cd -
whiptail --title "OrangePi Build System" \
	--msgbox "Build uboot finish. The output path: $BUILD" 10 60 0
