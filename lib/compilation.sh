#!/bin/bash

# Functions:
# compile_uboot
# compile_kernel

compile_uboot()
{
	UBOOT_BIN=$BUILD/uboot	
	
	if [ ! -d $UBOOT_BIN ]; then
		mkdir -p $UBOOT_BIN
	fi

	# Perpar souce code
	if [ ! -d $UBOOT ]; then
		whiptail --title "OrangePi Build System" \
			--msgbox "u-boot doesn't exist, pls perpare u-boot source code." \
			10 50 0
		exit 0
	fi

	cd $UBOOT
	echo -e "\e[1;31m Build U-boot \e[0m"

	if [ $KERNELVER = "0" ]; then
		if [ ! -f $UBOOT/u-boot-sun8iw7p1.bin ]; then
			make  sun8iw7p1_config
		fi
		make -j${CORES}
		echo "\n" 

		echo -e "\e[1;31m Compile boot0...... \e[0m"
		if [ ! -f $UBOOT/sunxi_spl/boot0/boot0_sdcard.bin ]; then
			make  sun8iw7p1_config
		fi
		make spl -j${CORES}
		cd -
		echo -e "\e[1;31m Complete boot0 compile.... \e[0m"
		#####################################################################
		###
		### Merge uboot with different binary
		#####################################################################

		cp $UBOOT/boot0_sdcard_sun8iw7p1.bin $UBOOT_BIN
		cp $UBOOT/u-boot-sun8iw7p1.bin $UBOOT_BIN
		cp $EXTER/uboot/tools/* $UBOOT_BIN

		cd $UBOOT_BIN
		./update_boot0 boot0_sdcard_sun8iw7p1.bin sys_config.bin SDMMC_CARD
		./update_uboot u-boot-sun8iw7p1.bin sys_config.bin

		rm -rf sys_config.bin  update_boot0  update_uboot
		cd -
	else
		make orangepi_${PLATFORM}_defconfig
		make -j4 ARCH=arm CROSS_COMPILE=$TOOLS

		cp $UBOOT/u-boot-sunxi-with-spl.bin $UBOOT_BIN/u-boot-sunxi-with-spl.bin-${PLATFORM} -f 
	fi

	echo -e "\e[1;31m Complete U-boot compile.... \e[0m"

	#whiptail --title "OrangePi Build System" \
	#	--msgbox "Build uboot finish. The output path: $BUILD" 10 60 0
}

compile_kernel()
{
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

	if [ $BUILD_KERNEL = "1" ]; then

		echo -e "\e[1;31m Start compiling the kernel ...\e[0m"

		if [ ! -f $LINUX/.config ]; then
        		make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS sun8iw7p1smp_defconfig
        		echo -e "\e[1;31m Using sun8iw7p1smp_defconfig\e[0m"
		fi

		if [ $KERNELVER = "0" ]; then
			make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES} uImage
			make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES} modules
			cp $LINUX/arch/arm/boot/uImage $BUILD/kernel/uImage_$PLATFORM
		else
			# make kernel
			make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES}

			if [ ! -d $BUILD/dtb ]; then
				mkdir -p $BUILD/dtb
			else
				rm -rf $BUILD/dtb/*
			fi
			# copy dtbs
			echo -e "\e[1;31m Start Copy dtbs \e[0m"
	       		cp $LINUX/arch/arm/boot/dts/sun8i-h3-orangepi*.dtb $BUILD/dtb/
	       		cp $LINUX/arch/arm/boot/dts/sun8i-h2-plus-orangepi-zero.dtb $BUILD/dtb/
			cp $LINUX/arch/arm/boot/zImage $BUILD/kernel/zImage_$PLATFORM
			cp $LINUX/System.map $BUILD/kernel/System.map-$PLATFORM
		fi

		echo -e "\e[1;31m Complete kernel compilation ...\e[0m"
	fi

	if [ $BUILD_MODULE = "1" ]; then
		if [ ! -d $BUILD/lib ]; then
		        mkdir -p $BUILD/lib
		else
		        rm -rf $BUILD/lib/*
		fi

		# install module
		echo -e "\e[1;31m Start installing kernel modules ... \e[0m"
		make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES} modules
		make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS -j${CORES} modules_install INSTALL_MOD_PATH=$BUILD
		echo -e "\e[1;31m Complete kernel module installation ... \e[0m"

	fi

	#whiptail --title "OrangePi Build System" --msgbox \
	#	"Build Kernel OK. The path of output file: ${BUILD}" 10 80 0
}
