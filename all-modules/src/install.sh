#!/bin/bash
#
# install redpill tcrp modules
#

function getvars() {
  TARGET_PLATFORM="$(uname -u | cut -d '_' -f2)"
  LINUX_VER="$(uname -r | cut -d '+' -f1)"
  REVISION="$(uname -a | cut -d ' ' -f4)"
}

getvars

if [ "${1}" = "modules" ]; then
  echo "all-modules - modules"
  
  echo "extract sbin.tgz to /usr/sbin/ and /usr/lib/ "
  tar xfz /exts/all-modules/sbin.tgz -C /
  chmod 700 /usr/sbin/jq
  chmod 700 /usr/sbin/kmod
  chmod 700 /usr/sbin/lspci
  chmod 700 /usr/sbin/sed
  chmod 700 /usr/sbin/tar
  
  #if [ "$TARGET_PLATFORM" = "denverton" ]; then
  #  /bin/cp -vf /usr/sbin/tar  /bin/
  #else
    rm -f /usr/sbin/tar
  #fi
  
  echo "link depmod,modprobe,libudev.so.1 to kmod"
  ln -s /usr/sbin/kmod /usr/sbin/depmod
  
  # It's for SA6400
  rm -f /usr/sbin/modprobe
    
  ln -s /usr/sbin/kmod /usr/sbin/modprobe
  ln -s /lib/libudev.so.1.6.2 /lib/libudev.so.1
  
  tar xvfz /exts/all-modules/${TARGET_PLATFORM}*${LINUX_VER}.tgz -C /lib/modules/

  echo "all-modules - modules"
  [ ! -d /lib/firmware ] && mkdir /lib/firmware
  tar xvfz /exts/all-modules/firmware.tgz -C /lib/firmware/
  # patch smallfixversion for 7.2.0-64570-1
  #if [ ${REVISION} = "#64570" ]; then
  #  echo "Modify VERSION file for 7.2.0-64570-1"
  #  sed -i 's#smallfixnumber="0"#smallfixnumber="1"#' /etc.defaults/VERSION
  #  echo 'packing="nano"' >> /etc.defaults/VERSION
  #  echo 'packing_id="1"' >> /etc.defaults/VERSION
  #fi
elif [ "${1}" = "late" ]; then
  echo "all-modules - late"
  [ ! -d /tmpRoot/lib/firmware ] && mkdir /tmpRoot/lib/firmware
  tar xvfz /exts/all-modules/firmware.tgz -C /tmpRoot/lib/firmware/
  #if [ ${REVISION} = "#64570" ]; then
  #  echo "Copy the modified version files for 7.2.0-64570-1 to /tmpRoot"
  #  cp -vf /etc.defaults/VERSION /tmpRoot/etc.defaults/VERSION
  #  cp -vf /etc.defaults/VERSION /tmpRoot/etc/VERSION
  #fi
fi
/usr/sbin/depmod -a
#if [ "$TARGET_PLATFORM" = "apollolake" ]||[ "$TARGET_PLATFORM" = "geminilake" ]; then
#  tar xvfz /exts/all-modules/${TARGET_PLATFORM}*${LINUX_VER}.tgz -C /exts/all-modules/ modules.*
#  cp -vf /exts/all-modules/modules.* /lib/modules
#fi
