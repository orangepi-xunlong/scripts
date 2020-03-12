#!/bin/bash

# Functions:
# compile_uboot
# compile_kernel

compile_uboot()
{
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

	case "${PLATFORM}" in
		"OrangePiH2" | "OrangePiH3" | "OrangePiH5" | "OrangePiH6" | "OrangePiH6_Linux4.9")
			make "${CHIP}"_config 

			case "${BOARD}" in 
				"3" | "zeroplus2h5")
					cp include/configs/${CHIP}.h.emmc include/configs/${CHIP}.h
					if [ ${BOARD} = "3" ]; then
						cp ${EXTER}/chips/${CHIP}/emmc.patch ${UBOOT}/
						patch -p1 < emmc.patch 1>/dev/null 2>&1
					fi
					make -j${CORES} CROSS_COMPILE="${UBOOT_COMPILE}"
					make spl CROSS_COMPILE="${UBOOT_COMPILE}" 1>/dev/null 2>&1
					git checkout .
					pack

		       			cp ${BUILD}/uboot/boot0_sdcard_${CHIP}.bin ${EXTER}/chips/${CHIP}/boot_emmc/boot0.bin
		        		cp ${BUILD}/uboot/u-boot-${CHIP}.bin ${EXTER}/chips/${CHIP}/boot_emmc/uboot.bin
					;;
				*)
					;;
			esac

			cd $UBOOT
			cp include/configs/${CHIP}.h.tf include/configs/${CHIP}.h
			make -j${CORES} CROSS_COMPILE="${UBOOT_COMPILE}"
			make spl CROSS_COMPILE="${UBOOT_COMPILE}" 
			pack
			;;
			
		"OrangePiA64")
			if [ ! -f $UBOOT/u-boot-sun50iw1p1.bin ]; then
			        make -C $UBOOT ARCH=arm CROSS_COMPILE=${UBOOT_COMPILE} ${CHIP}_config
			fi
			make -C $UBOOT ARCH=arm CROSS_COMPILE=${UBOOT_COMPILE}
			pack
			;;

		"OrangePiH2_mainline" | "OrangePiH3_mainline" | "OrangePiH6_mainline")
			[[ ${PLATFORM} == "OrangePiH6_mainline" ]] && cp ${EXTER}/chips/${CHIP}/mainline/bl31.bin ${UBOOT}/
			make orangepi_"${BOARD}"_defconfig
			make -j${CORES} ARCH=arm CROSS_COMPILE="${UBOOT_COMPILE}"
			cp "$UBOOT"/u-boot-sunxi-with-spl.bin "$UBOOT_BIN"/u-boot-sunxi-with-spl.bin-"${BOARD}" -f
			;;

		*)
	        	echo -e "\e[1;31m Pls select correct platform \e[0m"
	        	exit 0
			;;
	esac

	cd ${ROOT}
	echo -e "\e[1;31m Complete U-boot compile.... \e[0m"
}

compile_kernel()
{
	if [ ! -d $BUILD ]; then
		mkdir -p $BUILD
	fi

	if [ ! -d $BUILD/kernel ]; then
		mkdir -p $BUILD/kernel
	fi

	echo -e "\e[1;31m Start compiling the kernel ...\e[0m"

	case "${PLATFORM}" in 
		"OrangePiH2" | "OrangePiH3")
			make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS "orangepi_${BOARD}"_defconfig
			echo -e "\e[1;31m Using "orangepi_${BOARD}"_defconfig\e[0m"
			make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES} uImage
			cp $LINUX/arch/"${ARCH}"/boot/uImage $BUILD/kernel/uImage_$BOARD
			;;

		"OrangePiH5" | "OrangePiH6" | "OrangePiH6_Linux4.9")
			make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS "orangepi_${BOARD}"_defconfig
			echo -e "\e[1;31m Using "orangepi_${BOARD}"_defconfig\e[0m"
			make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES} Image
			make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES} dtbs
			mkimage -A arm -n "${PLATFORM}" -O linux -T kernel -C none -a 0x40080000 -e 0x40080000 \
		                -d $LINUX/arch/"${ARCH}"/boot/Image "${BUILD}"/kernel/uImage_"${BOARD}"
			;;
			
		"OrangePiA64")
			make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS "orangepi_${BOARD}"_defconfig
			echo -e "\e[1;31m Using "orangepi_${BOARD}"_defconfig\e[0m"
			make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES} Image
			cp $LINUX/arch/"${ARCH}"/boot/Image $BUILD/kernel/Image_$BOARD
			;;

		"OrangePiH2_mainline" | "OrangePiH3_mainline" | "OrangePiH6_mainline") 
			make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS "${CHIP}"smp_defconfig
			echo -e "\e[1;31m Using "${CHIP}"smp_defconfig\e[0m"

			make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES}

			rm -rf $BUILD/dtb/*
			if [ ${ARCH} = "arm" ];then
				mkdir -p $BUILD/dtb
			else
				mkdir -p $BUILD/dtb/allwinner
			fi

			# copy dtbs
			echo -e "\e[1;31m Start Copy dtbs \e[0m"

			if [[ ${PLATFORM} == "OrangePiH3_mainline" ]] || [[ ${PLATFORM} == "OrangePiH2_mainline" ]];then
       				cp $LINUX/arch/"${ARCH}"/boot/dts/sun8i-h3-orangepi*.dtb $BUILD/dtb/
       				cp $LINUX/arch/"${ARCH}"/boot/dts/sun8i-h2-plus-orangepi-*.dtb $BUILD/dtb/
				cp $LINUX/arch/"${ARCH}"/boot/zImage $BUILD/kernel/zImage_$BOARD
			elif [ ${PLATFORM} = "OrangePiH6_mainline" ];then
       				cp $LINUX/arch/"${ARCH}"/boot/dts/allwinner/sun50i-h6-orangepi*.dtb $BUILD/dtb/allwinner/
				cp $LINUX/arch/"${ARCH}"/boot/Image $BUILD/kernel/Image_$BOARD
			fi

			cp $LINUX/System.map $BUILD/kernel/System.map-$BOARD
			;;
		*)
	        	echo -e "\e[1;31m Pls select correct platform \e[0m"
			exit 0
	esac

	echo -e "\e[1;31m Complete kernel compilation ...\e[0m"
	compile_module
}

compile_module(){
	
	if [ ! -d $BUILD/lib ]; then
	        mkdir -p $BUILD/lib
	else
	        rm -rf $BUILD/lib/*
	fi

	# install module
	echo -e "\e[1;31m Start installing kernel modules ... \e[0m"
	make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES} modules
	make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES} modules_install INSTALL_MOD_PATH=$BUILD
	echo -e "\e[1;31m Complete kernel module installation ... \e[0m"

	#whiptail --title "OrangePi Build System" --msgbox \
	#	"Build Kernel OK. The path of output file: ${BUILD}" 10 80 0
}
