#!/bin/bash

build_image()
{	
	VER="v1.0"
	IMAGENAME="OrangePi_${PLATFORM}_${OS}_${DISTRO}_${IMAGETYPE}_${KERNEL}_${VER}"
	IMAGE="$BUILD/images/$IMAGENAME.img"

	if [ ! -d $BUILD/images ]; then
		mkdir -p $BUILD/images
	fi

	# Partition Setup
	boot0_position=8      # KiB
	uboot_position=16400  # KiB
	part_position=20480   # KiB
	boot_size=50          # MiB

	# Create beginning of disk
	dd if=/dev/zero bs=1M count=$((part_position/1024)) of="$IMAGE"

	# Create boot file system (VFAT)
	dd if=/dev/zero bs=1M count=${boot_size} of=${IMAGE}1
	mkfs.vfat -n BOOT ${IMAGE}1
	
	if [ $KERNELVER = "0" ]; then
		cp -rfa $BUILD/kernel/uImage_$PLATFORM $BUILD/kernel/uImage
		cp -rfa $EXTER/script/script.bin_$PLATFORM $BUILD/script.bin

		boot0="$BUILD/uboot/boot0_sdcard_sun8iw7p1.bin"
		uboot="$BUILD/uboot/u-boot-sun8iw7p1.bin"
		dd if="$boot0" conv=notrunc bs=1k seek=$boot0_position of="$IMAGE"
		dd if="$uboot" conv=notrunc bs=1k seek=$uboot_position of="$IMAGE"


		# Add boot support if there
		if [ -e "$BUILD/kernel/uImage" -a -e "$BUILD/script.bin" ]; then
			mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/uImage ::
			mcopy -sm -i ${IMAGE}1 ${BUILD}/script.bin :: || true
		fi
	else
		cp -rfa $BUILD/kernel/zImage_$PLATFORM $BUILD/kernel/zImage
		cp -rfa $EXTER/mainline/boot_files/uInitrd $BUILD/uInitrd
		cp -rfa $EXTER/mainline/boot_files/orangepiEnv.txt $BUILD/orangepiEnv.txt
		mkimage -C none -A arm -T script -d $EXTER/mainline/boot_files/boot.cmd $EXTER/mainline/boot_files/boot.scr
		cp -rfa $EXTER/mainline/boot_files/boot.* $BUILD/
	
		uboot="$BUILD/uboot/u-boot-sunxi-with-spl.bin-${PLATFORM}"
		dd if="$uboot" conv=notrunc bs=1k seek=$boot0_position of="$IMAGE"

		# Add boot support if there
		if [ -e "$BUILD/kernel/zImage" -a -d "$BUILD/dtb" ]; then
			mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/zImage ::
			mcopy -m -i ${IMAGE}1 ${BUILD}/uInitrd :: || true
			mcopy -m -i ${IMAGE}1 ${BUILD}/orangepiEnv.txt :: || true
			mcopy -m -i ${IMAGE}1 ${BUILD}/boot.* :: || true
			mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/System.map-$PLATFORM :: || true
			mcopy -sm -i ${IMAGE}1 ${BUILD}/dtb :: || true
		fi
	fi

	disk_size=$[(`du -s $DEST | awk 'END {print $1}'`+part_position)/1024+400+boot_size]

	if [ "$disk_size" -lt 60 ]; then
		echo "Disk size must be at least 60 MiB"
		exit 2
	fi

	echo "Creating image $IMAGE of size $disk_size MiB ..."

	dd if=${IMAGE}1 conv=notrunc oflag=append bs=1M seek=$((part_position/1024)) of="$IMAGE"
	rm -f ${IMAGE}1

	# Create additional ext4 file system for rootfs
	dd if=/dev/zero bs=1M count=$((disk_size-boot_size-part_position/1024)) of=${IMAGE}2
	mkfs.ext4 -O ^metadata_csum -F -b 4096 -E stride=2,stripe-width=1024 -L rootfs ${IMAGE}2

	if [ ! -d /media/tmp ]; then
		mkdir -p /media/tmp
	fi

	mount -t ext4 ${IMAGE}2 /media/tmp
	# Add rootfs into Image
	cp -rfa $DEST/* /media/tmp

	umount /media/tmp

	dd if=${IMAGE}2 conv=notrunc oflag=append bs=1M seek=$((part_position/1024+boot_size)) of="$IMAGE"
	rm -f ${IMAGE}2

	if [ -d $BUILD/orangepi ]; then
		rm -rf $BUILD/orangepi
	fi 

	if [ -d /media/tmp ]; then
		rm -rf /media/tmp
	fi

	# Add partition table
	cat <<EOF | fdisk "$IMAGE"
o
n
p
1
$((part_position*2))
+${boot_size}M
t
c
n
p
2
$((part_position*2 + boot_size*1024*2))

t
2
83
w
EOF

	cd $BUILD/images/ 
	rm -f ${IMAGENAME}.tar.gz
	md5sum ${IMAGE} > ${IMAGE}.md5sum
	tar czvf  ${IMAGENAME}.tar.gz $IMAGENAME.img*
	rm -f *.md5sum

	sync
}
