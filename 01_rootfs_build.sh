#!/bin/bash
set -e
########################################################################
##
##
## Build rootfs
########################################################################
if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi

if [ -z $1 ]; then
	DISTRO="xenial"
else
	DISTRO=$1
fi

BUILD="$ROOT/external"
OUTPUT="$ROOT/output"
DEST="$OUTPUT/rootfs"
LINUX="$ROOT/kernel"
SCRIPTS="$ROOT/scripts"
TOOLCHAIN=$ROOT/toolchain/bin/arm-linux-gnueabi-

DEST=$(readlink -f "$DEST")
LINUX=$(readlink -f "$LINUX")

# Install Kernel modules
make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLCHAIN modules_install INSTALL_MOD_PATH="$DEST"

# Install Kernel headers
make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLCHAIN headers_install INSTALL_HDR_PATH="$DEST/usr/local"

cp $BUILD/firmware $DEST/lib/ -rf

rm -rf $OUTPUT/${DISTRO}_rootfs
cp -rfa $DEST $OUTPUT/${DISTRO}_rootfs

clear
whiptail --title "OrangePi Build System" \
        --msgbox "Build Rootfs Ok. The path of output: $DEST" 10 50 0
