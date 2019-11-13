#!/bin/bash

uboot_check()
{

        for ((i = 0; i < 5; i++)); do
                UBOOT_PATH=$(whiptail --title "OrangePi Build System" \
                        --inputbox "Pls input device node of TF card.(eg: /dev/sdc)" \
                        10 60 3>&1 1>&2 2>&3)

                if [ $i = "4" ]; then
                        whiptail --title "OrangePi Build System" --msgbox "Error, Invalid Path" 10 40 0
                        exit 0
                fi

                if [ ! -b "$UBOOT_PATH" ]; then
                        whiptail --title "OrangePi Build System" --msgbox \
                                "The input path invalid! Pls input correct path!" \
                                --ok-button Continue 10 40 0
                else
                        i=200
                fi
        done
}

boot_check()
{

        for ((i = 0; i < 5; i++)); do
                BOOT_PATH=$(whiptail --title "OrangePi Build System" \
                        --inputbox "Pls input mount path of BOOT.(/media/orangepi/BOOT)" \
                        10 60 3>&1 1>&2 2>&3)

                if [ $i = "4" ]; then
                        whiptail --title "OrangePi Build System" --msgbox "Error, Invalid Path" 10 40 0
                        exit 0
                fi

                if [ ! -d "$BOOT_PATH" ]; then
                        whiptail --title "OrangePi Build System" --msgbox \
                                "The input path invalid! Pls input correct path!" \
                                --ok-button Continue 10 40 0
                else
                        i=200
                fi
        done
}

rootfs_check()
{

        for ((i = 0; i < 5; i++)); do
                ROOTFS_PATH=$(whiptail --title "OrangePi Build System" \
                        --inputbox "Pls input mount path of rootfs.(/media/orangepi/rootfs)" \
                        10 60 3>&1 1>&2 2>&3)

                if [ $i = "4" ]; then
                        whiptail --title "OrangePi Build System" --msgbox "Error, Invalid Path" 10 40 0
                        exit 0
                fi

                if [ ! -d "$ROOTFS_PATH" ]; then
                        whiptail --title "OrangePi Build System" --msgbox \
                                "The input path invalid! Pls input correct path!" \
                                --ok-button Continue 10 40 0
                else
                        i=200
                fi
        done
}

prepare_host()
{

	if ! hash apt-get 2>/dev/null; then
	        whiptail --title "Orangepi Build System" --msgbox "This scripts requires a Debian based distrbution."
		        exit 1
	fi

	apt-get -y --no-install-recommends --fix-missing install \
		        bsdtar mtools u-boot-tools pv bc \
		        gcc automake make binfmt-support flex \
		        lib32z1 lib32z1-dev qemu-user-static bison \
		        dosfstools libncurses5-dev lib32stdc++-5-dev debootstrap \
		        swig libpython2.7-dev libssl-dev python-minimal

	# Prepare toolchains
	chmod 755 -R $ROOT/toolchain/*
}

kernel_update()
{
	
	if [ $KERNELVER = 0 ]; then
		KERNEL_IMAGE=$BUILD/kernel/uImage_${PLATFORM}

		# Update kernel
		rm -rf $BOOT_PATH/uImage
		cp -rf $KERNEL_IMAGE $BOOT_PATH/uImage
	else
		KERNEL_IMAGE=$BUILD/kernel/zImage_${PLATFORM}

		# Update kernel
		rm -rf $BOOT_PATH/zImage
		rm -rf $BOOT_PATH/dtb
		cp -rf $KERNEL_IMAGE $BOOT_PATH/zImage
		cp -rf $BUILD/dtb $BOOT_PATH/
	fi

	sync
	clear

	whiptail --title "OrangePi Build System" \
		                 --msgbox "Succeed to update kernel" \
				                   10 60
}

modules_update()
{

	# Remove old modules
	rm -rf $ROOTFS_PATH/lib/modules

	cp -rfa $BUILD/lib/modules $ROOTFS_PATH/lib/

	sync
	clear

	whiptail --title "OrangePi Build System" \
		             --msgbox "Succeed to update Module" \
			                      10 40 0
}

uboot_update()
{
	
	if [ $KERNELVER = 0 ]; then
		boot0=$BUILD/uboot/boot0_sdcard_sun8iw7p1.bin
		uboot=$BUILD/uboot/u-boot-sun8iw7p1.bin

		# Clean TF partition
		dd bs=1K seek=8 count=1015 if=/dev/zero of="$UBOOT_PATH"
		# Update uboot
		dd if=$boot0 of=$UBOOT_PATH conv=notrunc bs=1k seek=8
		dd if=$uboot of=$UBOOT_PATH conv=notrunc bs=1k seek=16400
	else
		dd if=/dev/zero of=$UBOOT_PATH bs=1k seek=8 count=1015
		uboot=$BUILD/uboot/u-boot-sunxi-with-spl.bin-${PLATFORM}
		dd if=$uboot of=$UBOOT_PATH conv=notrunc bs=1k seek=16400
	fi

	sync
	clear

	whiptail --title "OrangePi Build System" --msgbox "Succeed to update Uboot" 10 40 0
}
