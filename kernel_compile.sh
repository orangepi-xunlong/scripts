#!/bin/bash

if [ "${1}" = "" ]; then
	echo "Usage: ./kernel_compile.sh <clean|one|pc|pcplus|plus|plus2e|lite|2> <clean>"
	exit 0
fi

TOP="$PWD/.."
if [ ! -d $TOP/output ]; then
	mkdir -p $TOP/output
fi

###
BUILD_KERNEL=$2
BUILD_MODULE=$3

#export PATH="$TOP/toolchain/toolchain_tar/bin":"$PATH"
cross_comp="$TOP/toolchain/bin/arm-linux-gnueabi"
cd $TOP/output
rm -rf $TOP/external/Legacy_patch/rootfs-lobo.img.gz > /dev/null 2>&1
cd $TOP/external/Legacy_patch/rootfs-test1
mkdir run > /dev/null 2>&1
mkdir -p conf/conf.d > /dev/null 2>&1

find . | cpio --quiet -o -H newc > ../rootfs-lobo.img
cd ..
gzip rootfs-lobo.img

cd $TOP/kernel
LINKERNEL_DIR=`pwd`
rm -rf $TOP/output/lib > /dev/null 2>&1
mkdir -p $TOP/output/lib > /dev/null 2>&1
cp $TOP/external/Legacy_patch/rootfs-lobo.img.gz $TOP/output/rootfs.cpio.gz
rm -rf $TOP/kernel/output
if [ ! -d $TOP/kernel/output ]; then
	mkdir -p $TOP/kernel/output
fi
chmod +x $TOP/kernel/output
rm -rf $TOP/kernel/output/*
cp $TOP/output/rootfs.cpio.gz $TOP/kernel/output/
#============================================================================================

make_kernel() {
if [ "${1}" = "plus" ] || [ "${1}" = "plus2e" ]; then
	cp $TOP/external/Legacy_patch/Kconfig.piplus drivers/net/ethernet/sunxi/eth/Kconfig
	cp $TOP/external/Legacy_patch/sunxi_geth.c.piplus drivers/net/ethernet/sunxi/eth/sunxi_geth.c
	cp $TOP/external/Legacy_patch/sun8iw7p1smp_linux_defconfig arch/arm/configs/sun8iw7p1smp_linux_defconfig
elif [ "${1}" = "one" ] || [ "${1}" = "pc" ] || [ "${1}" = "pcplus" ] || [ "${1}" = "lite" ] || [ "${1}" = "2" ]; then
	cp $TOP/external/Legacy_patch/Kconfig.pi2 drivers/net/ethernet/sunxi/eth/Kconfig
	cp $TOP/external/Legacy_patch/sunxi_geth.c.pi2 drivers/net/ethernet/sunxi/eth/sunxi_geth.c
	cp $TOP/external/Legacy_patch/sun8iw7p1smp_linux_defconfig arch/arm/configs/sun8iw7p1smp_linux_defconfig
fi

#===========================================================================================
clear

if [ "${2}" = "clean" ]; then
	make ARCH=arm CROSS_COMPILE=${cross_comp}- mrproper > /dev/null 2>&1
fi
sleep 1
echo -e "\e[1;31m Building kernel for OrangePi-${1} ...\e[0m"
if [ ! -f $TOP/kernel/.config ]; then
    echo -e "\e[1;31m Configuring ... \e[0m"
	make ARCH=arm CROSS_COMPILE=${cross_comp}- mrproper > /dev/null 2>&1
    make ARCH=arm CROSS_COMPILE=${cross_comp}- sun8iw7p1smp_linux_defconfig 
fi
if [ $? -ne 0 ]; then
	echo " Error: Kernel not built."
	exit 1
fi
sleep 1

#===================================================================================
# build kernel (use -jN, where N is number of cores you can spare for building)

if [ $BUILD_KERNEL = "1" ]; then
    echo -e "\e[1;31m Building Kernel and Modules \e[0m"
    make -j6 ARCH=arm CROSS_COMPILE=${cross_comp}- uImage
    if [ $? -ne 0 ] || [ ! -f arch/arm/boot/uImage ]; then
            echo " Error: kernel not built."
            exit 1
    fi
    #==================================================
    # copy uImage to output
    cp arch/arm/boot/uImage $TOP/output/uImage_${1}
fi

if [ $BUILD_MODULE = "1" ]; then
    make -j6 ARCH=arm CROSS_COMPILE=${cross_comp}- modules 

    sleep 1

    #====================================================
    # export modules to output

    echo -e "\e[1;31m Exporting Modules \e[0m"
    rm -rf $TOP/output/lib/* 
    make ARCH=arm CROSS_COMPILE=${cross_comp}- INSTALL_MOD_PATH=$TOP/output modules_install 
    if [ $? -ne 0 ] || [ ! -f arch/arm/boot/uImage ]; then
	    echo " Error."
    fi
    echo -e "\e[1;31m Exporting Firmware ... \e[0m"
    make ARCH=arm CROSS_COMPILE=${cross_comp}- INSTALL_MOD_PATH=$TOP/output firmware_install 
    if [ $? -ne 0 ] || [ ! -f arch/arm/boot/uImage ]; then
	    echo " Error."
    fi
    sleep 1

    # build mali driver
    if [ -f $TOP/kernel/localversion-rt ]; then
        rm $TOP/kernel/localversion-rt
    fi
    cd $TOP/scripts
    if [ "${1}" = "one" ] || [ "${1}" = "pc" ] || [ "${1}" = "pcplus" ] || [ "${1}" = "lite" ] || [ "${1}" = "2" ] || [ "${1}" = "plus" ] || [ "${1}" = "plus2e" ]; then
	    ./build_mali_driver.sh
    fi

fi
}
#==========================================================================================

if [ "${1}" = "clean" ]; then
	echo "cleaning ..."
	make ARCH=arm CROSS_COMPILE=${cross_comp}- mrproper > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo " Error."
	fi
	rm -rf $TOP/output/lib/* > /dev/null 2>&1
	rm -rf $TOP/output/uImage* > /dev/null 2>&1
	rm -rf $TOP/kbuild* > /dev/null 2>&1
	rm -rf $TOP/malibuild* > /dev/null 2>&1
	rm if  $TOP/kernel/modules/malibuild* > /dev/null 2>&1
	rm -rf output/* > /dev/null 2>&1
	rm -rf $TOP/external/Legacy_patch/rootfs-lobo.img.gz > /dev/null 2>&1
else
	make_kernel "${1}" "${2}"
fi

echo "******OK*****"

clear
cd $TOP/output/
LPATH="`pwd`"
cd -

whiptail --title "OrangePi Build System" --msgbox \
 "`figlet OrangePi` Succeed to build Linux!            Path:$LPATH" \
            15 50 0

clear






