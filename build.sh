#!/bin/bash
set -e
##########################################
##
## Build H3 Linux
## 
## Maintainer: Buddy <buddy.zhang@aliyun.com>
##########################################
export ROOT=`pwd`
SCRIPTS=$ROOT/scripts
export BOOT_PATH
export ROOTFS_PATH
export UBOOT_PATH

root_check()
{
	if [ "$(id -u)" -ne "0" ]; then
		echo "This option requires root."
		echo "Pls use command: sudo ./build.sh"
		exit 0
	fi	
}

UBOOT_check()
{
    cd $ROOT/scripts
    ./Notice.sh
    cd -
	for ((i = 0; i < 5; i++)); do
		UBOOT_PATH=$(whiptail --title "OrangePi Build System" \
			--inputbox "Pls input device node of SDcard.(/dev/sdc)" \
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

BOOT_check()
{
	## Get mount path of u-disk
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

ROOTFS_check()
{
	for ((i = 0; i < 5; i++)); do
		ROOTFS_PATH=$(whiptail --title "OrangePi Build System" \
			--inputbox "Pls input mount path of rootfs.(/media/orangepi/linux)" \
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

if [ ! -d $ROOT/output ]; then
    mkdir -p $ROOT/output
fi

MENUSTR="Welcome to OrangePi Build System. Pls choose Platform."
##########################################
OPTION=$(whiptail --title "OrangePi Build System" \
	--menu "$MENUSTR" 15 60 7 --cancel-button Exit --ok-button Select \
	"0"  "OrangePi PC" \
	"1"  "OrangePi PC Plus" \
	"2"  "OrangePi Plus2E" \
	"3"  "OrangePi Lite" \
	"4"  "OrangePi Plus2" \
	"5"  "OrangePi One" \
	"6"  "OrangePi 2" \
	3>&1 1>&2 2>&3)

if [ $OPTION = "0" ]; then
	export PLATFORM="pc"
elif [ $OPTION = "1" ]; then
	export PLATFORM="pcplus"
elif [ $OPTION = "2" ]; then
	export PLATFORM="plus2e"
elif [ $OPTION = "3" ]; then
	export PLATFORM="lite"
elif [ $OPTION = "4" ]; then
	export PLATFORM="plus"
elif [ $OPTION = "5" ]; then
	export PLATFORM="one"
elif [ $OPTION = "6" ]; then
	export PLATFORM="2"
else
	echo -e "\e[1;31m Pls select correct platform \e[0m"
	exit 0
fi

##########################################
## Root Password check
for ((i = 0; i < 5; i++)); do
	PASSWD=$(whiptail --title "OrangePi Build System" \
		--passwordbox "Enter your root password. Note! Don't use root to run this scripts" \
		10 60 3>&1 1>&2 2>&3)
	
	if [ $i = "4" ]; then
		whiptail --title "Note Box" --msgbox "Error, Invalid password" 10 40 0	
		exit 0
	fi

	sudo -k
	if sudo -lS &> /dev/null << EOF
$PASSWD
EOF
	then
		i=10
	else
		whiptail --title "OrangePi Build System" --msgbox "Invalid password, Pls input corrent password" \
			10 40 0	--cancel-button Exit --ok-button Retry
	fi
done

echo $PASSWD | sudo ls &> /dev/null 2>&1

if [ ! -d $ROOT/output ]; then
    mkdir -p $ROOT/output
fi

## prepare development tools
if [ ! -f $ROOT/output/.tmp_toolchain ]; then
	cd $SCRIPTS
	sudo ./Prepare_toolchain.sh
	sudo touch $ROOT/output/.tmp_toolchain
	cd -
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
	"6"   "Install Image into SDcard" \
	"7"   "Update kernel Image" \
	"8"   "Update Module" \
	"9"   "Update Uboot" \
	3>&1 1>&2 2>&3)

if [ $OPTION = "0" -o $OPTION = "1" ]; then
	sudo echo ""
	clear
	TMP=$OPTION
	TMP_DISTRO=""
	MENUSTR="Distro Options"
	OPTION=$(whiptail --title "OrangePi Build System" \
		--menu "$MENUSTR" 20 60 10 --cancel-button Finish --ok-button Select \
		"0"   "Ubuntu Pecise" \
		"1"   "Ubuntu Trusty" \
		"2"	  "Ubuntu Utopic" \
		"3"   "Ubuntu Vivid" \
		"4"   "Ubuntu Wily" \
		"5"   "Ubuntu Xenial" \
		"6"   "Debian Wheezy" \
		"7"   "Debian Jessie" \
		"8"   "Raspbian Wheezy" \
		"9"   "Raspbian Jessie" \
		3>&1 1>&2 2>&3)

	if [ ! -f $ROOT/output/uImage_${PLATFORM} ]; then
		cd $SCRIPTS
		sudo ./kernel_compile.sh ${PLATFORM} "1" "1"
		sudo ./uboot_compile.sh ${PLATFORM}
		cd -
	fi

	cd $SCRIPTS
    sudo ./create_image "$OPTION"
	exit 0
elif [ $OPTION = "2" ]; then
	cd $SCRIPTS
	sudo ./uboot_compile.sh $PLATFORM
	clear
	exit 0
elif [ $OPTION = "3" ]; then
	export BUILD_KERNEL=1
	export BUILD_MODULE=1
	cd $SCRIPTS
	sudo ./kernel_compile.sh $PLATFORM $BUILD_KERNEL $BUILD_MODULE
	exit 0
elif [ $OPTION = "4" ]; then
	export BUILD_KERNEL=1
	export BUILD_MODULE=0
	cd $SCRIPTS
	sudo ./kernel_compile.sh $PLATFORM $BUILD_KERNEL $BUILD_MODULE
	exit 0
elif [ $OPTION = "5" ]; then
	export BUILD_KERNEL=0
	export BUILD_MODULE=1
	cd $SCRIPTS
	sudo ./kernel_compile.sh $PLATFORM $BUILD_KERNEL $BUILD_MODULE
	exit 0
elif [ $OPTION = "6" ]; then
	sudo echo ""
	clear
	UBOOT_check
	clear
	whiptail --title "OrangePi Build System" \
			 --msgbox "Burning Image to SDcard. Pls select Continue button" \
				10 40 0	--ok-button Continue
	pv "$ROOT/output/${PLATFORM}.img" | sudo dd bs=1M of=$UBOOT_PATH && sync
	clear
	whiptail --title "OrangePi Build System" --msgbox "Succeed to Download Image into SDcard" \
				10 40 0	--ok-button Continue
	exit 0
elif [ $OPTION = '7' ]; then
	clear 
	BOOT_check
	clear
	cd $SCRIPTS
	sudo ./kernel_update.sh $BOOT_PATH $PLATFORM
	exit 0
elif [ $OPTION = '8' ]; then
	sudo echo ""
	clear 
	ROOTFS_check
	clear
	cd $SCRIPTS
	sudo ./modules_update.sh $ROOTFS_PATH
	exit 0
elif [ $OPTION = '9' ]; then
	clear
	UBOOT_check
	clear
	cd $SCRIPTS
	sudo ./uboot_update.sh $UBOOT_PATH
	exit 0
else
	whiptail --title "OrangePi Build System" \
		--msgbox "Pls select correct option" 10 50 0
	exit 0
fi
