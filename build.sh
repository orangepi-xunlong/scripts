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

if [ ! -d $ROOT/output ]; then
    mkdir -p $ROOT/output
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
	OPTION=0
	SOURCES="CN"

SelectDistro()
{
	MENUSTR="Distro Options"
	OPTION=$(whiptail --title "OrangePi Build System" \
		--menu "$MENUSTR" 20 60 10 --cancel-button Finish --ok-button Select \
		"0"   "[$SOURCES]Change repository server" \
		"1"   "Ubuntu Xenial" \
		3>&1 1>&2 2>&3)
        if [ $OPTION = "0" ]; then
                SelectSources
        elif [ $OPTION = "1" ]; then
                TMP_DISTRO="xenial"
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
	
        if [ ! -f $ROOT/output/kernel/uImage_$PLATFORM ]; then
                export BUILD_KERNEL=1
                cd $SCRIPTS
                ./kernel_compile.sh
                cd -
        fi
        if [ ! -d $ROOT/output/lib ]; then
                if [ -f $ROOT/output/lib ]; then
                        rm $ROOT/output/lib
                fi
                mkdir $ROOT/output/lib
                export BUILD_MODULE=1
                cd $SCRIPTS
                ./kernel_compile.sh
                cd -
        fi
        if [ ! -f $ROOT/output/uboot/boot0_sdcard_sun8iw7p1.bin ]; then
            cd $SCRIPTS
                ./uboot_compile.sh
                cd -
        fi

        cd $SCRIPTS
        DISTRO=$TMP_DISTRO
        if [ -d $ROOT/output/${DISTRO}_${IMAGETYPE}_rootfs ]; then
                if (whiptail --title "OrangePi Build System" --yesno \
                        "${DISTRO} rootfs has exist! Do you want use it?" 10 60) then
                        OP_ROOTFS=0
                else
                        OP_ROOTFS=1
                fi
                if [ $OP_ROOTFS = "0" ]; then
                        if [ -d $ROOT/output/rootfs ]; then
                                sudo rm -rf $ROOT/output/rootfs
                        fi
                        sudo cp -rfa $ROOT/output/${DISTRO}_${IMAGETYPE}_rootfs $ROOT/output/rootfs
                        #whiptail --title "OrangePi Build System" --msgbox "Rootfs has build" \
                        #        10 40 0 --ok-button Continue
                else
                        sudo ./00_rootfs_build.sh $DISTRO $PLATFORM $TYPE $SOURCES
                        sudo ./01_rootfs_build.sh $DISTRO $TYPE 
                fi
        else
                sudo ./00_rootfs_build.sh $DISTRO $PLATFORM $TYPE $SOURCES
                sudo ./01_rootfs_build.sh $DISTRO $TYPE
        fi
        if [ $TMP = "0" ]; then
		#sudo ./02_rootfs_build.sh
                sudo ./build_image.sh $DISTRO $PLATFORM $TYPE
                whiptail --title "OrangePi Build System" --msgbox "Succeed to build Image" \
                                10 40 0 --ok-button Continue
        fi
        exit 0
elif [ $OPTION = "2" ]; then
	cd $SCRIPTS
	./uboot_compile.sh $PLATFORM
	clear
	exit 0
elif [ $OPTION = "3" ]; then
	export BUILD_KERNEL=1
	export BUILD_MODULE=1
	cd $SCRIPTS
	./kernel_compile.sh 
	exit 0
elif [ $OPTION = "4" ]; then
	export BUILD_KERNEL=1
	export BUILD_MODULE=0
	cd $SCRIPTS
	./kernel_compile.sh
	exit 0
elif [ $OPTION = "5" ]; then
	export BUILD_KERNEL=0
	export BUILD_MODULE=1
	cd $SCRIPTS
	./kernel_compile.sh
	exit 0
elif [ $OPTION = "6" ]; then
	echo ""
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
	./kernel_update.sh $BOOT_PATH $PLATFORM
	exit 0
elif [ $OPTION = '8' ]; then
	echo ""
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
	sudo ./uboot_update.sh $UBOOT_PATH $PLATFORM
	exit 0
else
	whiptail --title "OrangePi Build System" \
		--msgbox "Pls select correct option" 10 50 0
	exit 0
fi
