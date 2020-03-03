#!/bin/bash

function do_prepare()
{
	TOOLS_DIR="${EXTER}/chips/${CHIP}/pack/tools"
	FILE="${EXTER}/chips/${CHIP}/pack/bin"
	SYS_CONFIG="${EXTER}/chips/${CHIP}/sys_config/sys_config_orangepi_${BOARD}.fex"

	PATH=${TOOLS_DIR}:$PATH

	configs_file_list=(
	${FILE}/*.fex
	${FILE}/boot_package.cfg
	)

	boot_file_list=(
	${UBOOT}/boot0_sdcard_${CHIP}.bin:${PACK_OUT}/boot0_sdcard.fex
	${UBOOT}/u-boot-${CHIP}.bin:${PACK_OUT}/u-boot.fex
	${FILE}/scp.bin:${PACK_OUT}/scp.fex
	${FILE}/bl31.bin:${PACK_OUT}/monitor.fex
	${SYS_CONFIG}:${PACK_OUT}/sys_config.fex
	)

	for file in ${configs_file_list[@]} ; do
		cp -f $file ${PACK_OUT}/ 2> /dev/null
	done

	for file in ${boot_file_list[@]} ; do
		cp -rf `echo $file | awk -F: '{print $1}'` \
			`echo $file | awk -F: '{print $2}'` 2>/dev/null
	done
}

function do_ini_to_dts()
{
	local DTC_SRC_PATH=${LINUX}/arch/$ARCH/boot/dts/sunxi/
	local DTC_INI_FILE_BASE=${SYS_CONFIG}
	local DTC_INI_FILE=${BUILD}/sys_config_fix.fex

	cp $DTC_INI_FILE_BASE $DTC_INI_FILE
	sed -i "s/\(\[dram\)_para\(\]\)/\1\2/g" $DTC_INI_FILE
	sed -i "s/\(\[nand[0-9]\)_para\(\]\)/\1\2/g" $DTC_INI_FILE
	DTC_SRC_FILE=${EXTER}/chips/${CHIP}/pack/bin/dtc_src_file

	dtc_alph -O dtb -o ${BUILD}/sunxi.dtb	\
		-b 0			\
		-i $DTC_SRC_PATH	\
		-F $DTC_INI_FILE	\
		$DTC_SRC_FILE 1>/dev/null 2>&1
	if [ $? -ne 0 ]; then
		pack_error "Conver script to dts failed"
		exit 1
	fi

	#echo -e "\e[1;31m ######################## \e[0m"
	#echo -e "\e[1;31m Conver script to dts ok \e[0m"
	#echo -e "\e[1;31m ######################## \e[0m"
}

function do_common()
{
	set +e

	cd ${PACK_OUT}

	unix2dos sys_config.fex 2>/dev/null
	script sys_config.fex > /dev/null
	cp sys_config.bin config.fex 2>/dev/null
	
	cp ${BUILD}/sunxi.dtb sunxi.fex
	update_uboot_fdt u-boot.fex sunxi.fex u-boot.fex >/dev/null
	update_scp scp.fex sunxi.fex >/dev/null

	# Those files for Nand or Card
	update_boot0 boot0_sdcard.fex	sys_config.bin SDMMC_CARD > /dev/null
	update_uboot u-boot.fex sys_config.bin > /dev/null

	unix2dos boot_package.cfg 2>/dev/null
	dragonsecboot -pack boot_package.cfg 1>/dev/null 2>&1

	#Here, will check if need to used multi config.fex or not
	update_uboot_v2 u-boot.fex sys_config.bin ${CHIP_BOARD} 1>/dev/null 2>&1

	# Copy dtb
	if [ ${PLATFORM} = "OrangePiH6" ]; then
		cp ${PACK_OUT}/sunxi.fex ${BUILD}/uboot/H6.dtb
	elif [ ${PLATFORM} = "OrangePiH5" ]; then
		cp ${PACK_OUT}/sunxi.fex ${BUILD}/uboot/H5.dtb
	fi

        cp ${PACK_OUT}/boot0_sdcard.fex ${UBOOT_BIN}/boot0_sdcard_${CHIP}.bin
        cp ${PACK_OUT}/boot_package.fex ${UBOOT_BIN}/u-boot-${CHIP}.bin

	# Clear Space
	rm ${BUILD}/sunxi.dtb
	rm -rf ${PACK_OUT}
	rm ${BUILD}/sys_config_fix.fex

	set -e
}

do_pack_a64()
{
	TOOLS_DIR="${EXTER}/chips/${CHIP}/pack/tools"
	FILE="${EXTER}/chips/${CHIP}/pack/bin"

	PATH=${TOOLS_DIR}:$PATH

	cp -avf ${FILE}/* ${PACK_OUT}/
	cp -avf $UBOOT/u-boot-sun50iw1p1.bin ${PACK_OUT}/u-boot.bin

	cd ${PACK_OUT}

	# Build binary device tree
	dtc -Odtb -o A64.dtb A64.dts

	# Build sys_config.bin
	unix2dos sys_config.fex
	script sys_config.fex

	# Merge u-boot.bin infile outfile mode [secmonitor | secos | scp]
	merge_uboot  u-boot.bin  bl31.bin  u-boot-merged.bin secmonitor
	merge_uboot  u-boot-merged.bin  scp.bin  u-boot-merged2.bin scp

	# Merge uboot and dtb
	update_uboot_fdt u-boot-merged2.bin A64.dtb u-boot-with-dtb.bin

	# Merge uboot and sys_config.fex
	update_uboot u-boot-with-dtb.bin sys_config.bin

        cp ${PACK_OUT}/boot0.bin ${UBOOT_BIN}/boot0_sdcard_${CHIP}.bin
        cp ${PACK_OUT}/u-boot-with-dtb.bin ${UBOOT_BIN}/u-boot-${CHIP}.bin
        cp ${PACK_OUT}/A64.dtb ${UBOOT_BIN}/

	cd -
}

pack()
{
	# Cleanup
	if [ -d $PACK_OUT ]; then
		rm -rf ${PACK_OUT}
	fi
	mkdir -p ${PACK_OUT}

	if [ ${PLATFORM} = "OrangePiA64" ];then
		do_pack_a64
	else
		do_prepare
		do_ini_to_dts
		do_common
	fi
}
