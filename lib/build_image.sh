#!/bin/bash

build_image()
{	
	IMAGENAME="OrangePi_${BOARD}_${OS}_${DISTRO}_${IMAGETYPE}_${KERNEL_NAME}_${VER}"
	IMAGE="${BUILD}/images/$IMAGENAME.img"

	if [ ! -d ${BUILD}/images ]; then
		mkdir -p ${BUILD}/images
	fi

	# Partition Setup
	boot0_position=8      # KiB
	uboot_position=16400  # KiB
	part_position=20480   # KiB
	boot_size=50          # MiB

	[[ ${PLATFORM} == "OrangePiA64" ]] && uboot_position=19096

	# Create beginning of disk
	dd if=/dev/zero bs=1M count=$((part_position/1024)) of="$IMAGE"

	# Create boot file system (VFAT)
	dd if=/dev/zero bs=1M count=${boot_size} of=${IMAGE}1
	mkfs.vfat -n BOOT ${IMAGE}1
	
	case "${PLATFORM}" in
		"OrangePiH2" | "OrangePiH3" | "OrangePiA64" | "OrangePiH5" | "OrangePiH6" | "OrangePiH6_Linux4.9")

			boot0="${UBOOT_BIN}/boot0_sdcard_${CHIP}.bin"
			uboot="${UBOOT_BIN}/u-boot-${CHIP}.bin"

			dd if="${boot0}" conv=notrunc bs=1k seek=${boot0_position} of="${IMAGE}"
			dd if="${uboot}" conv=notrunc bs=1k seek=${uboot_position} of="${IMAGE}"

			if [[ "${PLATFORM}" == "OrangePiH2" ]] || [[ "${PLATFORM}" == "OrangePiH3" ]]; then
				cp -rfa ${BUILD}/kernel/uImage_${BOARD} ${BUILD}/kernel/uImage
				cp -rfa ${EXTER}/chips/${CHIP}/script/script.bin_$BOARD $BUILD/script.bin
				mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/uImage ::
				mcopy -sm -i ${IMAGE}1 ${BUILD}/script.bin :: || true
				rm -rf $BUILD/script.bin
			elif [[ "${PLATFORM}" == "OrangePiH6_Linux4.9" ]]; then
				cp -rfa ${BUILD}/kernel/uImage_${BOARD} ${BUILD}/kernel/uImage
			        mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/uImage ::
			        mcopy -m -i ${IMAGE}1 ${BUILD}/uboot/H6.dtb :: || true
			        mcopy -m -i ${IMAGE}1 ${EXTER}/chips/$CHIP/initrd.img :: || true
			        mcopy -m -i ${IMAGE}1 ${EXTER}/chips/$CHIP/orangepi"${BOARD}"/uEnv.txt :: || true
			elif [[ "${PLATFORM}" == "OrangePiH5" ]]; then
				cp -rfa ${BUILD}/kernel/uImage_${BOARD} ${BUILD}/kernel/uImage
			        mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/uImage ::
			        mcopy -m -i ${IMAGE}1 ${BUILD}/uboot/H5.dtb :: || true
			        mcopy -m -i ${IMAGE}1 ${EXTER}/chips/$CHIP/initrd.img :: || true
			        mcopy -m -i ${IMAGE}1 ${EXTER}/chips/$CHIP/orangepi"${BOARD}"/uEnv.txt :: || true
			elif [[ "${PLATFORM}" == "OrangePiA64" ]]; then
				cp -rfa ${BUILD}/kernel/Image_${BOARD} ${BUILD}/kernel/Image
			        mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/Image ::
			        mcopy -m -i ${IMAGE}1 ${BUILD}/uboot/A64.dtb :: || true
			        mcopy -m -i ${IMAGE}1 ${EXTER}/chips/$CHIP/initrd.img :: || true
			        mcopy -m -i ${IMAGE}1 ${EXTER}/chips/$CHIP/orangepi"${BOARD}"/uEnv.txt :: || true
			fi
			;;

		"OrangePiH2_mainline" | "OrangePiH3_mainline" | "OrangePiH6_mainline")

			mkdir -p ${BUILD}/tmp
			cp -fa ${EXTER}/chips/${CHIP}/mainline/boot_file/uInitrd ${BUILD}/tmp/uInitrd
			cp -fa ${EXTER}/chips/${CHIP}/mainline/boot_file/orangepiEnv.txt ${BUILD}/tmp/orangepiEnv.txt
			mkimage -C none -A arm -T script -d ${EXTER}/chips/${CHIP}/mainline/boot_file/boot.cmd ${EXTER}/chips/${CHIP}/mainline/boot_file/boot.scr
			cp -fa ${EXTER}/chips/${CHIP}/mainline/boot_file/boot.* ${BUILD}/tmp/
	
			uboot="${BUILD}/uboot/u-boot-sunxi-with-spl.bin-${BOARD}"
			dd if="$uboot" conv=notrunc bs=1k seek=$boot0_position of="$IMAGE"

			if [[ ${PLATFORM} == "OrangePiH6_mainline" ]];then
				cp -fa ${BUILD}/kernel/Image_${BOARD} ${BUILD}/kernel/Image
				mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/Image ::
			elif [[ ${PLATFORM} == "OrangePiH2_mainline" ]] || [[ "${PLATFORM}" == "OrangePiH3_mainline" ]];then 
				cp -fa ${BUILD}/kernel/zImage_${BOARD} ${BUILD}/kernel/zImage
				mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/zImage ::
			fi

			mcopy -m -i ${IMAGE}1 ${BUILD}/tmp/uInitrd :: || true
			mcopy -m -i ${IMAGE}1 ${BUILD}/tmp/orangepiEnv.txt :: || true
			mcopy -m -i ${IMAGE}1 ${BUILD}/tmp/boot.* :: || true
			mcopy -m -i ${IMAGE}1 ${BUILD}/kernel/System.map-${BOARD} :: || true
			mcopy -sm -i ${IMAGE}1 ${BUILD}/dtb :: || true
			;;

		*)
			echo -e "\e[1;31m Pls select correct platform \e[0m"
			exit 0
			;;
	esac

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

	if [ -d ${BUILD}/orangepi ]; then
		rm -rf ${BUILD}/orangepi
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

	cd ${BUILD}/images/ 
	rm -f ${IMAGENAME}.tar.gz
	md5sum ${IMAGE} > ${IMAGE}.md5sum
	tar czvf  ${IMAGENAME}.tar.gz $IMAGENAME.img*
	rm -f *.md5sum

	sync
}
