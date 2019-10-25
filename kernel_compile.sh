#!/bin/bash
set -e
##############################################
##
## Compile kernel
##
##############################################
if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi
# Platform
if [ -z $PLATFORM ]; then
	PLATFORM="pc-plus"
fi
# Cleanup
if [ -z $CLEANUP ]; then
	CLEANUP="0"
fi

# kernel option
if [ -z $BUILD_KERNEL ]; then
	BUILD_KERNEL="0"
fi
# module option
if [ -z $BUILD_MODULE ]; then
	BUILD_MODULE="0"
fi
# Knernel Direct
LINUX=$ROOT/kernel
# Compile Toolchain
TOOLS=$ROOT/toolchain/bin/arm-linux-gnueabi-
# OUTPUT DIRECT
BUILD=$ROOT/output
EXTER=$ROOT/external
CORES=8

if [ ! -d $BUILD ]; then
	mkdir -p $BUILD
fi 

if [ ! -d $BUILD/kernel ]; then
	mkdir -p $BUILD/kernel
fi 

# Perpare souce code
if [ ! -d $LINUX ]; then
	whiptail --title "OrangePi Build System" --msgbox \
		"Kernel doesn't exist, pls perpare linux source code." 10 40 0 --cancel-button Exit
	exit 0
fi

clear
echo -e "\e[1;31m Start Compile.....\e[0m"

if [ $CLEANUP = "1" ]; then
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS clean
	echo -e "\e[1;31m Clean up kernel \e[0m"
fi

if [ ! -f $LINUX/.config ]; then
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS sun8iw7p1smp_defconfig
	echo -e "\e[1;31m Using ${PLATFROM}_linux_defconfig \e[0m"
fi

if [ $BUILD_KERNEL = "1" ]; then
	# make kernel
	echo -e "\e[1;31m Start Compile Kernel \e[0m"
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES}
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES} uImage
fi

if [ $BUILD_MODULE = "1" ]; then
	if [ ! -d $BUILD/lib ]; then
		mkdir -p $BUILD/lib
	else
		rm -rf $BUILD/lib/* 
	fi

	# install module
	echo -e "\e[1;31m Start Install Module \e[0m"
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES} modules_install INSTALL_MOD_PATH=$BUILD

	# install mali driver
	#echo -e "\e[1;31m Start Install Mali driver \e[0m"
	#cd $EXTER/sunxi-mali
	#export CROSS_COMPILE=$TOOLS
	#export KDIR=$LINUX
	#export INSTALL_MOD_PATH=$BUILD
	#rm -rf *
	#git checkout .
	#./build.sh -r r6p2 -b
	#./build.sh -r r6p2 -i
fi

#if [ $BUILD_KERNEL = "1" ]; then
#	if [ ! -d $BUILD/dtb ]; then
#		mkdir -p $BUILD/dtb
#	else
#		rm -rf $BUILD/dtb/*
#	fi

	# copy dtbs
#	echo -e "\e[1;31m Start Copy dtbs \e[0m"
#  	cp $LINUX/arch/arm/boot/dts/sun8i-h3-orangepi*.dtb $BUILD/dtb/ 	
#  	cp $LINUX/arch/arm/boot/dts/sun8i-h2-plus-orangepi-zero.dtb $BUILD/dtb/ 	
	
	cp $LINUX/arch/arm/boot/uImage $BUILD/kernel/uImage_$PLATFORM
#	cp $LINUX/System.map $BUILD/System.map-$PLATFORM
#fi

clear
whiptail --title "OrangePi Build System" --msgbox \
	"Build Kernel OK. The path of output file: ${BUILD}" 10 80 0
