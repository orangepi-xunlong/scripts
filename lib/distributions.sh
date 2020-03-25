#!/bin/bash

deboostrap_rootfs() {
	dist="$1"
	tgz="$(readlink -f "$2")"
	TEMP=$(mktemp -d)

	[ "$TEMP" ] || exit 1
	cd $TEMP && pwd

	# this is updated very seldom, so is ok to hardcode
	debian_archive_keyring_deb="${SOURCES}/pool/main/d/debian-archive-keyring/debian-archive-keyring_2019.1_all.deb"
	wget -O keyring.deb "$debian_archive_keyring_deb"
	ar -x keyring.deb && rm -f control.tar.gz debian-binary && rm -f keyring.deb
	DATA=$(ls data.tar.*) && compress=${DATA#data.tar.}

	KR=debian-archive-keyring.gpg
	bsdtar --include ./usr/share/keyrings/$KR --strip-components 4 -xvf "$DATA"
	rm -f "$DATA"

	apt-get -y install debootstrap qemu-user-static

	qemu-debootstrap --arch=${ROOTFS_ARCH} --keyring=$TEMP/$KR $dist rootfs ${SOURCES}
	rm -f $KR

	# keeping things clean as this is copied later again
	rm -f rootfs"${QEMU}"

	bsdtar -C $TEMP/rootfs -a -cf $tgz .
	rm -fr $TEMP/rootfs
}

do_chroot() {
	# Add qemu emulation.
	cp ${QEMU} "$DEST/usr/bin"

	cmd="$@"
	chroot "$DEST" mount -t proc proc /proc || true
	chroot "$DEST" mount -t sysfs sys /sys || true
	chroot "$DEST" $cmd
	chroot "$DEST" umount /sys
	chroot "$DEST" umount /proc

	# Clean up
	rm -f "${DEST}${QEMU}"
}

do_conffile() {
        mkdir -p $DEST/opt/boot

	BOARD_FILE="$EXTER/chips/${CHIP}"
	
	case "${PLATFORM}" in
		
		"OrangePiH2" | "OrangePiH3" | "OrangePiH5" | "OrangePiA64" | "OrangePiH6_Linux4.9")
	       	 	[[ -d ${BOARD_FILE}/boot_emmc ]] && cp ${BOARD_FILE}/boot_emmc/* $DEST/opt/boot/ -f
	        	cp ${BOARD_FILE}/resize_rootfs.sh $DEST/usr/local/sbin/ -f
	       	 	cp ${BOARD_FILE}/install_to_emmc $DEST/usr/local/sbin/install_to_emmc -f
	       	 	cp ${BOARD_FILE}/orangepi"${BOARD}"/sbin/* $DEST/usr/local/sbin/ -f
	       	 	cp ${BOARD_FILE}/orangepi"${BOARD}"/modules.conf $DEST/etc/modules-load.d/ -f
			;;
			
		"OrangePiH2_mainline" | "OrangePiH3_mainline" | "OrangePiH6_mainline")
	       	 	[[ -d ${BOARD_FILE}/mainline/boot_emmc ]] && cp ${BOARD_FILE}/mainline/boot_emmc/* $DEST/opt/boot/ -f
			cp $BUILD/uboot/u-boot-sunxi-with-spl.bin-${BOARD} $DEST/opt/boot/u-boot-sunxi-with-spl.bin -f
	       	 	cp ${BOARD_FILE}/mainline/install_to_emmc_$OS $DEST/usr/local/sbin/install_to_emmc -f
	        	cp ${EXTER}/common/mainline/resize_rootfs.sh $DEST/usr/local/sbin/ -f
	       	 	cp ${BOARD_FILE}/mainline/orangepi"${BOARD}"/sbin/* $DEST/usr/local/sbin/ -f
	       	 	cp ${BOARD_FILE}/mainline/orangepi"${BOARD}"/modules.conf $DEST/etc/modules-load.d/ -f
			;;

		*)	
		        echo -e "\e[1;31m Pls select correct platform \e[0m"
		        exit 0
			;;
	esac

        cp $EXTER/common/rootfs/sshd_config $DEST/etc/ssh/ -f
        cp $EXTER/common/rootfs/networking.service $DEST/lib/systemd/system/networking.service -f
        cp $EXTER/common/rootfs/profile_for_root $DEST/root/.profile -f
        cp $EXTER/common/rootfs/cpu.sh $DEST/usr/local/sbin/ -f

        chmod +x $DEST/usr/local/sbin/*
}

add_bt_service() {
	cat > "$DEST/lib/systemd/system/bt.service" <<EOF
[Unit]
Description=OrangePi BT Service

[Service]
ExecStart=/usr/local/sbin/bt.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
	do_chroot systemctl enable bt.service
}

add_audio_service() {
	cat > "$DEST/lib/systemd/system/audio.service" <<EOF
[Unit]
Description=OrangePi Audio Service

[Service]
ExecStart=/usr/local/sbin/audio.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        do_chroot systemctl enable audio.service
}

add_ssh_keygen_service() {
	cat > "$DEST/etc/systemd/system/ssh-keygen.service" <<EOF
[Unit]
Description=Generate SSH keys if not there
Before=ssh.service
ConditionPathExists=|!/etc/ssh/ssh_host_key
ConditionPathExists=|!/etc/ssh/ssh_host_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key.pub

[Service]
ExecStart=/usr/bin/ssh-keygen -A
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=ssh.service
EOF
	do_chroot systemctl enable ssh-keygen
}

add_opi_python_gpio_libs() {
        cp $EXTER/common/OPi.GPIO $DEST/usr/local/sbin/ -rfa

        cat > "$DEST/install_opi_gpio" <<EOF
#!/bin/bash

cd /usr/local/sbin/OPi.GPIO
python3 setup.py install
EOF
        chmod +x "$DEST/install_opi_gpio"
        do_chroot /install_opi_gpio
	rm $DEST/install_opi_gpio

	cp ${BOARD_FILE}/orangepi"${BOARD}"/test_gpio.py $DEST/usr/local/sbin/ -f
}

add_opi_config_libs() {
        cp $EXTER/common/opi_config_libs $DEST/usr/local/sbin/ -rfa
        cp $EXTER/common/opi_config_libs/opi-config $DEST/usr/local/sbin/ -rfa

	rm -rf $DEST/etc/update-motd.d/* 
        cp $EXTER/common/rootfs/update-motd.d/* $DEST/etc/update-motd.d/ -rf
}

add_opi_wallpaper() {
	WPDIR="$DEST/usr/share/xfce4/backdrops/"

	if [ $TYPE = "1" -o -d $DEST/usr/share/xfce4/backdrops ]; then
		cp $EXTER/common/rootfs/orangepi*.jpg ${WPDIR} -f
		cd ${WPDIR}
		rm -f xubuntu-wallpaper.png
		ln -sv orangepi1.jpg xubuntu-wallpaper.png 
		cd -
	fi
}

add_debian_apt_sources() {
	local release="$1"
	local aptsrcfile="$DEST/etc/apt/sources.list"
	cat > "$aptsrcfile" <<EOF
deb ${SOURCES} ${release} main contrib non-free
#deb-src ${SOURCES} ${release} main contrib non-free
EOF
	# No separate security or updates repo for unstable/sid
	[ "$release" = "sid" ] || cat >> "$aptsrcfile" <<EOF
deb ${SOURCES} ${release}-updates main contrib non-free
#deb-src ${SOURCES} ${release}-updates main contrib non-free

deb http://security.debian.org/ ${release}/updates main contrib non-free
#deb-src http://security.debian.org/ ${release}/updates main contrib non-free
EOF
}

add_ubuntu_apt_sources() {
	local release="$1"
	cat > "$DEST/etc/apt/sources.list" <<EOF
deb ${SOURCES} ${release} main restricted universe multiverse
deb-src ${SOURCES} ${release} main restricted universe multiverse

deb ${SOURCES} ${release}-updates main restricted universe multiverse
deb-src ${SOURCES} ${release}-updates main restricted universe multiverse

deb ${SOURCES} ${release}-security main restricted universe multiverse
deb-src $SOURCES ${release}-security main restricted universe multiverse

deb ${SOURCES} ${release}-backports main restricted universe multiverse
deb-src ${SOURCES} ${release}-backports main restricted universe multiverse
EOF
}

prepare_env()
{
	if [ ${ARCH} = "arm" ];then
		QEMU="/usr/bin/qemu-arm-static"
		ROOTFS_ARCH="armhf"
	elif [ ${ARCH} = "arm64" ];then
		QEMU="/usr/bin/qemu-aarch64-static"
		ROOTFS_ARCH="arm64"
	fi

	if [ ! -d "$DEST" ]; then
		echo "Destination $DEST not found or not a directory."
		echo "Create $DEST"
		mkdir -p $DEST
	fi

	if [ "$(ls -A -Ilost+found $DEST)" ]; then
		echo "Destination $DEST is not empty."
		echo "Clean up space."
		rm -rf $DEST
	fi

	cleanup() {
		if [ -e "$DEST/proc/cmdline" ]; then
			umount "$DEST/proc"
		fi
		if [ -d "$DEST/sys/kernel" ]; then
			umount "$DEST/sys"
		fi
		if [ -d "$TEMP" ]; then
			rm -rf "$TEMP"
		fi
	}
	trap cleanup EXIT

	case $DISTRO in
		"xenial" | "bionic")
			case $SOURCES in
				"OFCL")
			       	        SOURCES="http://ports.ubuntu.com"
					ROOTFS="http://cdimage.ubuntu.com/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-${DISTRO_NUM}-base-${ROOTFS_ARCH}.tar.gz"
				        ;;
				"ALIYUN")
				        SOURCES="http://mirrors.aliyun.com/ubuntu-ports"
					ROOTFS="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-${DISTRO_NUM}-base-${ROOTFS_ARCH}.tar.gz"
				        ;;
				"USTC")
					SOURCES="http://mirrors.ustc.edu.cn/ubuntu-ports"
					ROOTFS="https://mirrors.ustc.edu.cn/ubuntu-cdimage/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-${DISTRO_NUM}-base-${ROOTFS_ARCH}.tar.gz"
				        ;;
				"TSINGHUA")
		                        SOURCES="http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports"
					ROOTFS="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-${DISTRO_NUM}-base-${ROOTFS_ARCH}.tar.gz"
				        ;;
				*)
					SOURCES="http://ports.ubuntu.com"
					ROOTFS="http://cdimage.ubuntu.com/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-${DISTRO_NUM}-base-${ROOTFS_ARCH}.tar.gz"
					;;
			esac
			;;
		"stretch" | "buster")
			ROOTFS="${DISTRO}-base-${ARCH}.tar.gz"
			METHOD="debootstrap"

			case $SOURCES in
		                "OFCL")
		                        SOURCES="http://ftp.debian.org/debian"
		                        ;;

				"ALIYUN")
					SOURCES="http://mirrors.aliyun.com/debian"
					;;

				"USTC")
		                        SOURCES="http://mirrors.ustc.edu.cn/debian"
					;;

			       	"TSINGHUA")
		                        SOURCES="https://mirrors.tuna.tsinghua.edu.cn/debian"
		                        ;;
				*)
					SOURCES="http://httpredir.debian.org/debian"
		                        ;;
		        esac
			;;
		*)
			echo "Unknown distribution: $DISTRO"
			exit 1
			;;
	esac

	TARBALL="$EXTER/$(basename $ROOTFS)"
	if [ ! -e "$TARBALL" ]; then
		if [ "$METHOD" = "download" ]; then
			echo "Downloading $DISTRO rootfs tarball ..."
			wget -O "$TARBALL" "$ROOTFS"
		elif [ "$METHOD" = "debootstrap" ]; then
			deboostrap_rootfs "$DISTRO" "$TARBALL"
		else
			echo "Unknown rootfs creation method"
			exit 1
		fi
	fi

	# Extract with BSD tar
	echo -n "Extracting ... "
	mkdir -p $DEST
	$UNTAR "$TARBALL" -C "$DEST"
	echo "OK"
}

prepare_rootfs_server()
{

	DEBUSER="orangepi"

	rm "$DEST/etc/resolv.conf"
	cp /etc/resolv.conf "$DEST/etc/resolv.conf"
	rm -rf "$DEST/etc/apt/sources.list.d/proposed.list"
	add_${OS}_apt_sources $DISTRO

	case "${DISTRO}" in

		"xenial" | "bionic")
			EXTRADEBS="software-properties-common libjpeg8-dev usbmount ubuntu-minimal ifupdown"
			;;
			
		"stretch" | "buster")
			EXTRADEBS="sudo net-tools g++ libjpeg-dev" 
			;;

		*)	
			echo "Unknown DISTRO=$DISTRO"
			exit 2
			;;
	esac

	cat > "$DEST/second-phase" <<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8

apt-get -y update
apt-get -y --no-install-recommends install dosfstools curl xz-utils iw rfkill wireless-tools wpasupplicant openssh-server alsa-utils rsync u-boot-tools vim parted network-manager git autoconf gcc libtool libsysfs-dev pkg-config libdrm-dev xutils-dev hostapd dnsmasq apt-transport-https man subversion imagemagick libv4l-dev cmake bluez python3-pip python3-setuptools dialog expect bc cpufrequtils figlet toilet lsb-core $EXTRADEBS

apt-get install -f
apt-get -y remove --purge ureadahead
apt-get -y update
adduser --gecos $DEBUSER --disabled-login $DEBUSER --uid 1000
adduser --gecos root --disabled-login root --uid 0
echo root:orangepi | chpasswd
chown -R 1000:1000 /home/$DEBUSER
echo "$DEBUSER:$DEBUSER" | chpasswd
usermod -a -G sudo $DEBUSER
usermod -a -G adm $DEBUSER
usermod -a -G video $DEBUSER
usermod -a -G plugdev $DEBUSER
apt-get -y autoremove
apt-get clean
EOF
	chmod +x "$DEST/second-phase"
	do_chroot /second-phase
	rm -f "$DEST/second-phase"
        rm -f "$DEST/etc/resolv.conf"

	cd $BUILD
	tar czf ${DISTRO}_${ARCH}_server_rootfs.tar.gz rootfs
}

prepare_rootfs_desktop()
{
	cp /etc/resolv.conf "$DEST/etc/resolv.conf"
	add_${OS}_apt_sources $DISTRO

	if [ $DISTRO = "xenial" ]; then
		if [ ${ARCH} = "arm64" ];then
	cat > "$DEST/type-phase" <<EOF
#!/bin/bash
apt-get update
apt-get -y install xubuntu-desktop

apt-get -y autoremove
EOF
		else
	cat > "$DEST/type-phase" <<EOF
#!/bin/bash
apt-get update
apt-get -y install lubuntu-desktop

apt-get -y autoremove
EOF
		fi
	else
	cat > "$DEST/type-phase" <<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install xorg xfce4 xfce4-goodies vlc network-manager-gnome

apt-get -y autoremove
EOF
	fi

	chmod +x "$DEST/type-phase"
	do_chroot /type-phase
	rm -f "$DEST/type-phase"
        rm -f "$DEST/etc/resolv.conf"

	cd $BUILD
	tar czf ${DISTRO}_${ARCH}_desktop_rootfs.tar.gz rootfs
}

server_setup()
{
#	cat > "$DEST/etc/network/interfaces.d/eth0" <<EOF
#auto eth0
#iface eth0 inet dhcp
#EOF

	cat > "$DEST/etc/hostname" <<EOF
orangepi$BOARD
EOF
	cat > "$DEST/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 orangepi$BOARD

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
	cat > "$DEST/etc/resolv.conf" <<EOF
nameserver 8.8.8.8
EOF

	do_conffile
	add_ssh_keygen_service
	add_opi_python_gpio_libs
	add_opi_config_libs
	add_audio_service

	case ${BOARD} in 
		"3" | "lite2" | "zeroplus2h5" | "zeroplus2h3" | "prime" | "win")
			add_bt_service
			;;
		*)
			;;
	esac

	sed -i 's|After=rc.local.service|#\0|;' "$DEST/lib/systemd/system/serial-getty@.service"
	rm -f "$DEST"/etc/ssh/ssh_host_*

	# Bring back folders
	mkdir -p "$DEST/lib"
	mkdir -p "$DEST/usr"

	# Create fstab
	cat  > "$DEST/etc/fstab" <<EOF
# <file system>	<dir>	<type>	<options>			<dump>	<pass>
LABEL=BOOT	/boot	vfat	defaults			0		2
LABEL=rootfs	/	ext4	defaults,noatime		0		1
EOF

	if [ ! -d $DEST/lib/modules ]; then
		mkdir "$DEST/lib/modules"
	else
		rm -rf $DEST/lib/modules
		mkdir "$DEST/lib/modules"
	fi

	# Install Kernel modules
	make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS modules_install INSTALL_MOD_PATH="$DEST"
	# Install Kernel headers
	make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS headers_install INSTALL_HDR_PATH="$DEST/usr/local"

	cp $EXTER/common/firmware $DEST/lib/ -rfa
}

build_rootfs()
{
	prepare_env

	if [ $TYPE = "1" ]; then
		if [ -f $BUILD/${DISTRO}_${ARCH}_desktop_rootfs.tar.gz ]; then
			rm -rf $DEST
			tar zxf $BUILD/${DISTRO}_${ARCH}_desktop_rootfs.tar.gz -C $BUILD
		else
			if [ -f $BUILD/${DISTRO}_${ARCH}_server_rootfs.tar.gz ]; then
				rm -rf $DEST
				tar zxf $BUILD/${DISTRO}_${ARCH}_server_rootfs.tar.gz -C $BUILD
				prepare_rootfs_desktop
			else
				prepare_rootfs_server
				prepare_rootfs_desktop

			fi
		fi
		server_setup
	else
		if [ -f $BUILD/${DISTRO}_${ARCH}_server_rootfs.tar.gz ]; then
			rm -rf $DEST
			tar zxf $BUILD/${DISTRO}_${ARCH}_server_rootfs.tar.gz -C $BUILD
		else
			prepare_rootfs_server
		fi
		server_setup
	fi
}
