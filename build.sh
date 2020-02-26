#!/bin/bash

set -e

ROOT=`pwd`
UBOOT=$ROOT/uboot
UBOOT=$ROOT/uboot
BUILD=$ROOT/output
LINUX=$ROOT/kernel
EXTER=$ROOT/external
SCRIPTS=$ROOT/scripts
DEST=$BUILD/rootfs

OS=""
DISTRO=""
ROOTFS=""
BOOT_PATH=""
UBOOT_PATH=""
ROOTFS_PATH=""

SOURCES="CN"
METHOD="download"
UNTAR="bsdtar -xpf"
CORES=$(nproc --ignore=1)

if [[ $EUID == 0 ]]; then
        :
else
	echo " "
        echo -e "\e[1;31m This script requires root privileges, trying to use sudo \e[0m"
	echo " "
        sudo "${ROOT}/build.sh"
	exit $?
fi

source "${SCRIPTS}"/lib/general.sh
source "${SCRIPTS}"/lib/compilation.sh
source "${SCRIPTS}"/lib/distributions.sh
source "${SCRIPTS}"/lib/build_image.sh

if [ ! -d $BUILD ]; then
    mkdir -p $BUILD
fi

MENUSTR="Welcome to OrangePi Build System. Pls choose Platform."
##########################################
OPTION=$(whiptail --title "OrangePi Build System" \
	--menu "$MENUSTR" 20 80 10 --cancel-button Exit --ok-button Select \
	"0"  "OrangePi PC Plus" \
	"1"  "OrangePi PC" \
	"2"  "OrangePi Plus2E" \
	"3"  "OrangePi Lite" \
	"4"  "OrangePi One" \
        "5"  "OrangePi 2" \
        "6"  "OrangePi ZeroPlus2 H3" \
        "7"  "OrangePi Plus" \
        "8"  "OrangePi Zero" \
        "9"  "OrangePi R1" \
	3>&1 1>&2 2>&3)

if [ $OPTION = "0" ]; then
	export PLATFORM="pc-plus"
elif [ $OPTION = "1" ]; then
	export PLATFORM="pc"
elif [ $OPTION = "2" ]; then
	export PLATFORM="plus2e"
elif [ $OPTION = "3" ]; then
	export PLATFORM="lite"
elif [ $OPTION = "4" ]; then
	export PLATFORM="one"
elif [ $OPTION = "5" ]; then
	export PLATFORM="2"
elif [ $OPTION = "6" ]; then
	export PLATFORM="zero_plus2_h3"
elif [ $OPTION = "7" ]; then
	export PLATFORM="plus"
elif [ $OPTION = "8" ]; then
	export PLATFORM="zero"
elif [ $OPTION = "9" ]; then
	export PLATFORM="r1"
else
	echo -e "\e[1;31m Pls select correct platform \e[0m"
	exit 0
fi

## prepare development tools
if [ ! -f $BUILD/.tmp_toolchain ]; then
	prepare_host
	touch $BUILD/.tmp_toolchain
fi

#MENUSTR="Pls select kernel version"
#KERNELVER=$(whiptail --title "OrangePi Build System" \
#        --menu "$MENUSTR" 20 60 3 --cancel-button Finish --ok-button Select \
#        "0"   "Linux3.4.113" \
#        "1"   "Linux5.3.5" \
#        3>&1 1>&2 2>&3)

#Todo
if [ -d $LINUX/certs ]; then
	KERNELVER=1
else
	KERNELVER=0
fi

if [ $KERNELVER = "0" ]; then
	TOOLS=$ROOT/toolchain/gcc-linaro-1.13.1-2012.02-x86_64_arm-linux-gnueabi/bin/arm-linux-gnueabi-
	KERNEL="linux3.4.113"
	#LINUX=$ROOT/linux_3.4.113
	#UBOOT=$ROOT/uboot_201109
else
	TOOLS=$ROOT/toolchain/gcc-linaro-7.2.1-2017.11-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-
	KERNEL="linux5.3.5"
fi

MENUSTR="Pls select build option"
OPTION=$(whiptail --title "OrangePi Build System" \
	--menu "$MENUSTR" 20 60 10 --cancel-button Finish --ok-button Select \
	"0"   "Build Release Image" \
	"1"   "Build Rootfs" \
	"2"   "Build Uboot" \
	"3"   "Build Linux" \
	"4"   "Build Kernel only" \
	"5"   "Build Module only" \
	"6"   "Update kernel Image" \
	"7"   "Update Module" \
	"8"   "Update Uboot" \
	3>&1 1>&2 2>&3)

if [ $OPTION = "0" -o $OPTION = "1" ]; then
	TMP=$OPTION
	TMP_DISTRO=""

SelectDistro()
{
	MENUSTR="Distro Options"
	OPTION=$(whiptail --title "OrangePi Build System" \
		--menu "$MENUSTR" 20 60 10 --cancel-button Finish --ok-button Select \
		"0"   "[$SOURCES]Change repository server" \
		"1"   "Ubuntu Xenial" \
		"2"   "Debian Stretch" \
		3>&1 1>&2 2>&3)
        if [ $OPTION = "0" ]; then
                SelectSources
        elif [ $OPTION = "1" ]; then
                TMP_DISTRO="xenial"
		OS="ubuntu"
        elif [ $OPTION = "2" ]; then
                TMP_DISTRO="stretch"
		OS="debian"
        fi
}

SelectSources()
{
	SOURCES=$(whiptail --title "Repository Server" --nocancel --radiolist \
	        "What is the repository server of your choice?" 20 60 5 \
	        "CN" "The server from China." ON \
	        "CDN" "Deafult CDN repository server(RCMD)." OFF \
	        "OFCL" "Official repository server." OFF 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
		echo "The chosen server is:" $SOURCES
		SelectDistro
	fi
}
	SelectDistro
        DISTRO=$TMP_DISTRO

        TYPE=$(whiptail --title "OrangePi Build System" \
                --menu "$MENUSTR" 20 60 3 --cancel-button Finish --ok-button Select \
                "0"   "Server" \
                "1"   "Desktop" \
                3>&1 1>&2 2>&3)
	
	if [ ${TYPE} = "1" ]; then
        	IMAGETYPE="desktop"
	else
        	IMAGETYPE="server"
	fi
	
	if [ $KERNELVER = 0 ]; then
        	if [ ! -f $BUILD/kernel/uImage_$PLATFORM ]; then
                	BUILD_KERNEL=1
			compile_kernel
        	fi
	else
        	if [ ! -f $BUILD/kernel/zImage_$PLATFORM ]; then
                	BUILD_KERNEL=1
			compile_kernel
        	fi
	fi

	if [ $KERNELVER = 0 ]; then
        	if [ ! -f $BUILD/uboot/boot0_sdcard_sun8iw7p1.bin ]; then
			compile_uboot
        	fi
	else
        	if [ ! -f $BUILD/uboot/u-boot-sunxi-with-spl.bin-${PLATFORM} ]; then
			compile_uboot
        	fi
	fi


        if [ $TMP = "0" ]; then
		build_rootfs
		build_image 

		whiptail --title "OrangePi Build System" --msgbox "Succeed to build Image" \
                               10 40 0 --ok-button Continue
	else
		build_rootfs

		whiptail --title "OrangePi Build System" --msgbox "Succeed to build rootfs" \
                               10 40 0 --ok-button Continue
        fi
elif [ $OPTION = "2" ]; then
	compile_uboot
elif [ $OPTION = "3" ]; then
	BUILD_KERNEL=1
	BUILD_MODULE=1
	compile_kernel
elif [ $OPTION = "4" ]; then
	BUILD_KERNEL=1
	BUILD_MODULE=0
	compile_kernel
elif [ $OPTION = "5" ]; then
	BUILD_KERNEL=0
	BUILD_MODULE=1
	compile_kernel
elif [ $OPTION = "6" ]; then
	boot_check
	kernel_update
elif [ $OPTION = '7' ]; then
	rootfs_check
	modules_update
elif [ $OPTION = '8' ]; then
	uboot_check
	uboot_update
else
	whiptail --title "OrangePi Build System" \
		--msgbox "Pls select correct option" 10 50 0
fi
