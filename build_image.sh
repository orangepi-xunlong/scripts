#!/bin/bash
################################################################
##
##
## Build Release Image
################################################################
set -e

if [ -z $ROOT ]; then
	ROOT=`cd .. && pwd`
fi

if [ -z $1 ]; then
	DISTRO="xineal"
else
	DISTRO=$1
fi

if [ -z $2 ]; then
	PLATFORM="pc-plus"
else
	PLATFORM=$2
fi

if [ $3 = "1" ]; then
	IMAGETYPE="desktop"
#	disk_size="3000"
else
	IMAGETYPE="server"
#	disk_size="2100"
fi

BUILD="$ROOT/external"
OUTPUT="$ROOT/output"
KERNEL="linux3.4.113"
OS="ubuntu"
VER="v1.0"
IMAGENAME="OrangePi_${PLATFORM}_${OS}_${DISTRO}_${IMAGETYPE}_${KERNEL}_${VER}.img"
IMAGE="$OUTPUT/images/$IMAGENAME"
ROOTFS="$OUTPUT/rootfs"

if [ ! -d $OUTPUT/images ]; then
        mkdir -p $OUTPUT/images
fi

# Partition Setup
boot0_position=8      # KiB
uboot_position=16400  # KiB
part_position=20480   # KiB
boot_size=50          # MiB
disk_size=$[(`du -s $ROOTFS | awk 'END {print $1}'`+part_position)/1024+300+boot_size]

if [ -z "$disk_size" ]; then
	disk_size=100 #MiB
fi

if [ "$disk_size" -lt 60 ]; then
	echo "Disk size must be at least 60 MiB"
	exit 2
fi

echo "Creating image $IMAGE of size $disk_size MiB ..."

boot0="$ROOT/output/uboot/boot0_sdcard_sun8iw7p1.bin"
uboot="$ROOT/output/uboot/u-boot-sun8iw7p1.bin"

set -x

# Create beginning of disk
dd if=/dev/zero bs=1M count=$((part_position/1024)) of="$IMAGE"
dd if="$boot0" conv=notrunc bs=1k seek=$boot0_position of="$IMAGE"
dd if="$uboot" conv=notrunc bs=1k seek=$uboot_position of="$IMAGE"


# Create boot file system (VFAT)
dd if=/dev/zero bs=1M count=${boot_size} of=${IMAGE}1
mkfs.vfat -n BOOT ${IMAGE}1

cp -rfa $OUTPUT/kernel/uImage_$PLATFORM $OUTPUT/kernel/uImage
cp -rfa $BUILD/script/script.bin_$PLATFORM $OUTPUT/script.bin
#cp -rfa $BUILD/boot_files/uInitrd $OUTPUT/uInitrd
#cp -rfa $BUILD/boot_files/orangepiEnv.txt $OUTPUT/orangepiEnv.txt

#mkimage -C none -A arm -T script -d $BUILD/boot_files/boot.cmd $BUILD/boot_files/boot.scr
#cp -rfa $BUILD/boot_files/boot.* $OUTPUT/

# Add boot support if there
if [ -e "$OUTPUT/kernel/uImage" -a -e "$OUTPUT/script.bin" ]; then
	mcopy -m -i ${IMAGE}1 ${OUTPUT}/kernel/uImage ::
	mcopy -sm -i ${IMAGE}1 ${OUTPUT}/script.bin :: || true
fi
dd if=${IMAGE}1 conv=notrunc oflag=append bs=1M seek=$((part_position/1024)) of="$IMAGE"
rm -f ${IMAGE}1

# Create additional ext4 file system for rootfs
dd if=/dev/zero bs=1M count=$((disk_size-boot_size-part_position/1024)) of=${IMAGE}2
mkfs.ext4 -F -b 4096 -E stride=2,stripe-width=1024 -L rootfs ${IMAGE}2

if [ ! -d /media/tmp ]; then
	mkdir -p /media/tmp
fi

mount -t ext4 ${IMAGE}2 /media/tmp
# Add rootfs into Image
cp -rfa $OUTPUT/rootfs/* /media/tmp

umount /media/tmp

dd if=${IMAGE}2 conv=notrunc oflag=append bs=1M seek=$((part_position/1024+boot_size)) of="$IMAGE"
rm -f ${IMAGE}2

if [ -d $OUTPUT/orangepi ]; then
	rm -rf $OUTPUT/orangepi
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

cd $OUTPUT/images/ 
rm -f ${IMAGENAME}.tar.gz
md5sum ${IMAGENAME} > ${IMAGENAME}.md5sum
tar czvf  ${IMAGENAME}.tar.gz $IMAGENAME*
rm -f *.md5sum

sync
clear
