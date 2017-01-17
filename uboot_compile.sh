#!/bin/bash

if [ "${1}" = "" ]; then
	echo "Usage: ./uboot_compile.sh <clean|one|pc|pcplus|plus|plus2e|lite|2>"
	exit -1
fi

TOP="$PWD/.."
export PATH="$TOP/toolchain/gcc-linaro/bin/":"$PATH"
cross_comp="arm-linux-gnueabi"

cd $TOP/u-boot
if [ ${1} = "clean" ]; then
	echo " Clear u-boot ..."
	rm -rf $TOP/uboot*.log > /dev/null 2>&1
	rm -rf $TOP/output/* > /dev/null 2>&1
	make distclean > /dev/null 2>&1
	sleep 1
	echo " Clear ok..."
	exit -1
fi

cd $TOP/u-boot/configs
CONFIG="orangepi_${1}_defconfig"
dts="sun8i-h3-orangepi-${1}.dtb"

if [ ! -f $CONFIG ]; then
	echo "source not found !"
	exit -1
fi

echo " Enter u-boot source director..."
cd ..

if [ "${1}" = "one" ] || [ "${1}" = "pc" ] || [ "${1}" = "pcplus" ] || [ "${1}" = "lite" ] || [ "${1}" = "2" ] || [ "${1}" = "plus" ] || [ "${1}" = "plus2e" ]; then
	make $CONFIG > /dev/null 2>&1
	echo " Build u-boot..."
	make -j4 ARCH=arm CROSS_COMPILE=${cross_comp}- > ../uboot_${1}.log 2>&1
	if [ ! -d $TOP/output/ ]; then
		mkdir -p $TOP/output
	fi
	rm -rf $TOP/output/*
	mkdir -p $TOP/output/uboot
	cp $TOP/u-boot/u-boot-sunxi-with-spl.bin $TOP/output/uboot -rf 
	echo "*****compile uboot ok*****"

	cp $TOP/external/Legacy_patch/uboot/orangepi.cmd $TOP/output/uboot/ -rf
	cd $TOP/output/uboot
	sed -i '/sun8i-h3/d' orangepi.cmd
	linenum=`grep -n "uImage" orangepi.cmd | awk '{print $1}' | awk -F: '{print $1}'`
	sed -i "${linenum}i fatload mmc 0 0x46000000 ${dts}" orangepi.cmd
	chmod +x orangepi.cmd u-boot-sunxi-with-spl.bin
	mkimage -C none -A arm -T script -d orangepi.cmd boot.scr
	
fi








