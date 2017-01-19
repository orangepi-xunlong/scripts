#!/bin/bash

echo "  Building mali drivers..."

if [ -z $TOP ]; then
	TOP=`cd .. && pwd`
fi
#export PATH="$TOP/toolchain/toolchain_tar/bin/":"$PATH"
cross_comp="$TOP/toolchain/bin/arm-linux-gnueabi"

SCRIPT_DIR=`pwd`

cd $TOP/kernel

# ####################################
# Copy config file to config directory

make ARCH=arm CROSS_COMPILE=${cross_comp}- sun8iw7p1smp_linux_defconfig 
if [ $? -ne 0 ]; then
    echo "  Error: defconfig."
    exit 1
fi

export LICHEE_PLATFORM=linux
export KERNEL_VERSION=`make ARCH=arm CROSS_COMPILE=${cross_comp}- -s kernelversion -C ./`

LICHEE_KDIR=`pwd`
KDIR=`pwd`
export LICHEE_MOD_DIR=${LICHEE_KDIR}/output/lib/modules/${KERNEL_VERSION}
mkdir -p $LICHEE_MOD_DIR/kernel/drivers/gpu/mali 
mkdir -p $LICHEE_MOD_DIR/kernel/drivers/gpu/ump 

export LICHEE_KDIR
export MOD_DIR=${LICHEE_KDIR}/output/lib/modules/${KERNEL_VERSION}
export KDIR

cd modules/mali
make ARCH=arm CROSS_COMPILE=${cross_comp}- clean 
if [ $? -ne 0 ]; then
    echo "  Error: clean."
    exit 1
fi
make ARCH=arm CROSS_COMPILE=${cross_comp}- build 
if [ $? -ne 0 ]; then
    echo "  Error: build."
    exit 1
fi
make ARCH=arm CROSS_COMPILE=${cross_comp}- install 
if [ $? -ne 0 ]; then
    echo "  Error: install."
    exit 1
fi

cp -rf $MOD_DIR/kernel/drivers/gpu/* $TOP/output/lib/modules/3.4.112/kernel/drivers/gpu/

cd ..
cd ..
echo "  mali build OK."
exit 0
