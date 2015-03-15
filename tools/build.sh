#!/bin/bash.
# Copyright (C) 2015 Joey Rizzoli
# Copyright (C) 2015 Grouper-Nvidia
#
# Sources: https://github.com/grouper-nvidia/build
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

## 
# var
#
DATE=$(date +%F-%H-%M-%S)

TOPNV=$(realpath .)
BUILDZIP=nv-3.1-$DATE.zip
OUTNV=$TOPNV/out
TARGETZIP=$OUTNV/target-zip

NVTOOLCHAIN=$TOPNV/prebuilt/toolchain/arm-eabi-4.8/bin/arm-eabi-
DEFCONFIG=tegra3_android_defconfig
KERNEL_PATH=$TOPNV/kernel/nv-3.1
ZIMAGEOUT=$KERNEL_PATH/arch/arm/boot/zImage

LOG_ZIMAGE=/tmp/nv-3.1_zImage_log
ZIP_LOG=/tmp/nv-3.1_zip_log
PUUSH_LOG=/tmp/nv-3.1_puush_log

##
# zImage
#

function buildzimage(){
  cd $KERNEL_PATH
  export ARCH=arm
  export SUBARCH=arm
  export CROSS_COMPILE=$NVTOOLCHAIN
  make $DEFCONFIG
  make -j16  2>&1 | tee $LOG_ZIMAGE
  RETURN=$0
  if [ "$RETURN" == 0]; then
    if [ -f $OUTNV/zImage]; then
      rm -f $OUTNV/zImage
    else
       if [! -d $TOPNV/out]; then
         mkdir $OUTNV
       fi
    fi
    cp $ZIMAGEOUT $OUTNV/zImage
    return 0
  else
    return 1
  fi
}

##
# flashablezip
#

function buildzip(){
  cp -r $TOPNV/anykernel $TARGETZIP
  if [ -f $OUTNV/zImage]; then
    cp $OUTNV/zImage $TARGETZIP/kernel/zImage
    zip -r $OUTNV/$BUILDZIP $TARGETZIP
    return $0
  else
    return 1
  fi
}

##
# upload
#

function puush(){
  local PUUSH_API_KEY="F463D642E0E1418161091A502178F254" #my own api key
  # puush upload script - written by @M1cha
  if [ -z "$PUUSH_API_KEY"]; then
    return 1
  elif [ -z "$1"]; then
    return 2
  elif ! [ -f "$1" -a -r "$1" ]; then
    return 3
  fi
  curl "https://puush.me/api/up" -# -F "k=$PUUSH_API_KEY" -F "z=poop" -F "f=@$1" | sed -E 's/^.+,(.+),.+,.+$/\1\n/'
  return 0
}

function upload(){
  if [-f $BUILDZIP]; then
    echo "Uploading..."
    puush $BUILDZIP | grep "http://puu.sh/" | tee $BUILD_URL
    RETURN=$0
    if [ $RETURN == 0]; then
      PUBLIC_URL=$(cat $BUILD_URL)
      echo -e "$PUBLIC_URL" >> $TOPNV/release/Readme.md
      cd $TOPNV/release
      git add Readme.md &> /dev/null
      git commit -m "Updload build $BUILDNAME" &> /dev/null
      echo "Pushing $BUILDNAME to GitHub..."
      git push https://github.com/grouper-nvidia/release master
      return $0
    else
      case "$RETURN" in
        1) printerr "Set the variable PUUSH_API_KEY in $0 or with 'export PUUSH_API_KEY=\"apiKeyHere\""; return 1;;
        2) printerr "Specify a file to be uploaded"; return 1;;
        3) printerr "File '$1' is not valid (it is not a file or it is not readable)"; return 1;;
      esac
    fi
  else
    return 1
  fi
}

##
# tools
#

function printerr(){
  echo "$(tput setaf 1)$1$(tput sgr 0)"
}

function printdone(){
  echo "$(tput setaf 2)$1$(tput sgr 0)"
}

function printok(){
  echo "$(tput setaf 3)$1$(tput sgr 0)"
}

##
# core
#

function core(){
  clear
  if [[ $1 == "zImage" ]]; then
    buildzimage | tee $LOG_ZIMAGE
    if [ ! $0 == 0 ]; then
      printerr "Error: something went wrong, check $LOG_ZIMAGE"
      exit 1
    else
      printdone "Done! zImage: $OUTNV/zImage"
    fi
  elif [[ $1 == "all" ]]; then
    buildzimage | tee $LOG_ZIMAGE
    if [ ! $0 == 0 ]; then
      printerr "Error: something went wrong, check $LOG_ZIMAGE"
    else
      printok "Done! zImage: $OUTNV/zImage"
      sleep 1
      buildzip | tee $ZIP_LOG
      if [! $0 == 0]; then
        printerr "Error: something went wrong, check $ZIP_LOG"
        exit 1
      else
        printok "Done! Zip: $TARGETZIP"
        sleep 1
        echo ""
        read -p "Do you want to upload this build to github? (You need write access to release repo) [y/N]" CHOICE
        if [ $CHOICE == "y"]; then
          upload | tee PUUSH_LOG
          if [ ! $0 == 0]; then
            printerr "Error: something went wrong, check $PUUSH_LOG"
            exit 1
          else
            printdone "Done!: Build link: $PUBLIC_URL"
          fi
        fi
      fi
    fi
  fi
}

core $1