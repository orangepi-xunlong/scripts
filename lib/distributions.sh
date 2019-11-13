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

	qemu-debootstrap --arch=armhf --keyring=$TEMP/$KR $dist rootfs ${SOURCES}
	rm -f $KR

	# keeping things clean as this is copied later again
	rm -f rootfs/usr/bin/qemu-arm-static

	bsdtar -C $TEMP/rootfs -a -cf $tgz .
	rm -fr $TEMP/rootfs

	cd -
}

do_chroot() {
	# Add qemu emulation.
	cp /usr/bin/qemu-arm-static "$DEST/usr/bin"

	cmd="$@"
	chroot "$DEST" mount -t proc proc /proc || true
	chroot "$DEST" mount -t sysfs sys /sys || true
	chroot "$DEST" $cmd
	chroot "$DEST" umount /sys
	chroot "$DEST" umount /proc

	# Clean up
	rm -f "$DEST/usr/bin/qemu-arm-static"
}

do_conffile() {
        mkdir -p $DEST/opt/boot
	if [ $KERNELVER = 0 ]; then
        	cp $EXTER/install_to_emmc_$OS $DEST/usr/local/sbin/install_to_emmc -f
        	cp $EXTER/uboot/*.bin $DEST/opt/boot/ -f
        	cp $EXTER/resize_rootfs.sh $DEST/usr/local/sbin/ -f
	else
		cp $BUILD/uboot/u-boot-sunxi-with-spl.bin-${PLATFORM} $DEST/opt/boot/u-boot-sunxi-with-spl.bin -f
        	cp $EXTER/mainline/install_to_emmc_$OS $DEST/usr/local/sbin/install_to_emmc -f
        	cp $EXTER/mainline/resize_rootfs.sh $DEST/usr/local/sbin/ -f
        	cp $EXTER/mainline/boot_emmc/* $DEST/opt/boot/ -f
	fi

        cp $EXTER/sshd_config $DEST/etc/ssh/ -f
        cp $EXTER/profile_for_root $DEST/root/.profile -f
        cp $EXTER/bluetooth/bt.sh $DEST/usr/local/sbin/ -f
        cp $EXTER/bluetooth/brcm_patchram_plus/brcm_patchram_plus $DEST/usr/local/sbin/ -f
        chmod +x $DEST/usr/local/sbin/*
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
		xenial)
			case $SOURCES in
				"CDN"|"OFCL")
			       	        SOURCES="http://ports.ubuntu.com"
					ROOTFS="http://cdimage.ubuntu.com/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-16.04-core-armhf.tar.gz"
				        ;;
				"CN")
				        #SOURCES="http://mirrors.aliyun.com/ubuntu-ports"
		                        #SOURCES="http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports"
				        SOURCES="http://mirrors.ustc.edu.cn/ubuntu-ports"
					ROOTFS="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-16.04-core-armhf.tar.gz"
				        ;;
				*)
					SOURCES="http://ports.ubuntu.com"
					ROOTFS="http://cdimage.ubuntu.com/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-16.04-core-armhf.tar.gz"
					;;
			esac
			;;
		bionic)
		        case $SOURCES in
		                "CDN"|"OFCL")
		                        SOURCES="http://ports.ubuntu.com"
					ROOTFS="http://cdimage.ubuntu.com/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-18.04-base-armhf.tar.gz"
		                        ;;
		                "CN")
		                        #SOURCES="http://mirrors.aliyun.com/ubuntu-ports"
		                        SOURCES="http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports"
				        #SOURCES="http://mirrors.ustc.edu.cn/ubuntu-ports"
					ROOTFS="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-18.04-base-armhf.tar.gz"
		                        ;;
		                *)
		                        SOURCES="http://ports.ubuntu.com"
					ROOTFS="http://cdimage.ubuntu.com/ubuntu-base/releases/${DISTRO}/release/ubuntu-base-18.04-base-armhf.tar.gz"
		                        ;;
		        esac
		        ;;
		stretch)
			ROOTFS="${DISTRO}-base-arm.tar.gz"
			METHOD="debootstrap"
			case $SOURCES in
		                "CDN")
		                        SOURCES="http://httpredir.debian.org/debian"
		                        ;;
		                "OFCL")
		                        SOURCES="http://ftp2.debian.org/debian"
		                        ;;
		                "CN")
		                        SOURCES="http://ftp2.cn.debian.org/debian"
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

	rm "$DEST/etc/resolv.conf"
	cp /etc/resolv.conf "$DEST/etc/resolv.conf"
	if [ "$DISTRO" = "xenial" -o "$DISTRO" = "bionic" ]; then
		DEB=ubuntu
		DEBUSER=orangepi
		EXTRADEBS="software-properties-common libjpeg8-dev usbmount zram-config ubuntu-minimal"
		ADDPPACMD=
		DISPTOOLCMD=
	elif [ "$DISTRO" = "sid" -o "$DISTRO" = "stretch" -o "$DISTRO" = "stable" ]; then
		DEB=debian
		DEBUSER=orangepi
		EXTRADEBS="sudo net-tools g++ libjpeg-dev"
		ADDPPACMD=
		DISPTOOLCMD=
	else
		echo "Unknown DISTRO=$DISTRO"
		exit 2
	fi
	add_${DEB}_apt_sources $DISTRO
	rm -rf "$DEST/etc/apt/sources.list.d/proposed.list"
	cat > "$DEST/second-phase" <<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8

apt-get -y update
apt-get -y install dosfstools curl xz-utils iw rfkill
apt-get -y install wpasupplicant openssh-server alsa-utils
apt-get -y install rsync u-boot-tools vim
apt-get -y install parted network-manager git autoconf gcc libtool
apt-get -y install libsysfs-dev pkg-config libdrm-dev xutils-dev hostapd
apt-get -y install dnsmasq apt-transport-https man subversion
apt-get -y install imagemagick libv4l-dev cmake bluez
apt-get -y install $EXTRADEBS

apt-get install -f

apt-get -y remove --purge ureadahead
$ADDPPACMD
apt-get -y update
$DISPTOOLCMD
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
	tar czf ${DISTRO}_server_rootfs.tar.gz rootfs
	cd -
}

prepare_rootfs_desktop()
{
	cp /etc/resolv.conf "$DEST/etc/resolv.conf"
	if [ $DISTRO = "xenial" ]; then
	cat > "$DEST/type-phase" <<EOF
#!/bin/bash
apt-get -y install lubuntu-desktop

apt-get install -f
apt-get -y autoremove
apt-get clean
EOF

	else
	cat > "$DEST/type-phase" <<EOF
#!/bin/bash
apt-get -y install xorg xfce4 xfce4-goodies vlc network-manager-gnome

apt-get -y autoremove
apt-get clean
EOF
	fi

	chmod +x "$DEST/type-phase"
	do_chroot /type-phase
	rm -f "$DEST/type-phase"
        rm -f "$DEST/etc/resolv.conf"

	cd $BUILD
	tar czf ${DISTRO}_desktop_rootfs.tar.gz rootfs
	cd -
}

server_setup()
{
	if [ $PLATFORM = "zero_plus2_h3" ];then
		:
	else
	cat > "$DEST/etc/network/interfaces.d/eth0" <<EOF
auto eth0
iface eth0 inet dhcp
EOF
	fi
	cat > "$DEST/etc/hostname" <<EOF
OrangePi
EOF
	cat > "$DEST/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 orangepi

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
	sed -i 's|After=rc.local.service|#\0|;' "$DEST/lib/systemd/system/serial-getty@.service"
	rm -f "$DEST"/etc/ssh/ssh_host_*

	# Bring back folders
	mkdir -p "$DEST/lib"
	mkdir -p "$DEST/usr"

	# Create fstab
	cat  > "$DEST/etc/fstab" <<EOF
# <file system>	<dir>	<type>	<options>			<dump>	<pass>
/dev/mmcblk0p1	/boot	vfat	defaults			0		2
/dev/mmcblk0p2	/	ext4	defaults,noatime		0		1
EOF

	if [ ! -d $DEST/lib/modules ]; then
		mkdir "$DEST/lib/modules"
	else
		rm -rf $DEST/lib/modules
		mkdir "$DEST/lib/modules"
	fi

	# Install Kernel modules
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS modules_install INSTALL_MOD_PATH="$DEST"

	# Install Kernel headers
	make -C $LINUX ARCH=arm CROSS_COMPILE=$TOOLS headers_install INSTALL_HDR_PATH="$DEST/usr/local"
	cp $EXTER/firmware $DEST/lib/ -rf

	#rm -rf $BUILD/${DISTRO}_${IMAGETYPE}_rootfs
	#cp -rfa $DEST $BUILD/${DISTRO}_${IMAGETYPE}_rootfs
}

build_rootfs()
{
	prepare_env

	if [ $TYPE = "1" ]; then
		if [ -f $BUILD/${DISTRO}_desktop_rootfs.tar.gz ]; then
			rm -rf $DEST
			tar zxf $BUILD/${DISTRO}_desktop_rootfs.tar.gz -C $BUILD
		else
			if [ -f $BUILD/${DISTRO}_server_rootfs.tar.gz ]; then
				rm -rf $DEST
				tar zxf $BUILD/${DISTRO}_server_rootfs.tar.gz -C $BUILD
				prepare_rootfs_desktop
			else
				prepare_rootfs_server
				prepare_rootfs_desktop

			fi
		fi
		server_setup
#		desktop_setup
	else
		if [ -f $BUILD/${DISTRO}_server_rootfs.tar.gz ]; then
			rm -rf $DEST
			tar zxf $BUILD/${DISTRO}_server_rootfs.tar.gz -C $BUILD
		else
			prepare_rootfs_server
		fi
		server_setup
	fi
}
