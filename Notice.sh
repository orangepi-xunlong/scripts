#!/bin/bash

################
# 
# This scripts is used to remind user when writing data into SDcard.
# When you use Udisk to download new Image or modules, you need to care for 
# the device node of Udisk. you can use "ls /dev/" to confirm it.
# Note! Pls check the device node for Udisk, If we ignore this operation, we may
# write data into dangerout area, it's terrible for system!!!! So, pls check your 
# device node of Udisk when you write data into Udisk!
#
# Create by: Buddy
# Date:      2017-01-05
#
###############

whiptail --title "OrangePi Build System" \
         --msgbox "Warning!! Please check the device node of UDisk! It's very necessary to check before writing data into SDcard! If not, you will write data into dangerous area, and it's very terrible for your system! So, please check device node of UDisk" 10 80 0 --ok-button Continue

whiptail --title "OrangePi Build System" \
         --msgbox "`df -l`" 20 80 0 --ok-button Continue
