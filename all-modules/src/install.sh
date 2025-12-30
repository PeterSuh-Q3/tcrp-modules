#!/bin/bash
#
# install redpill tcrp modules
#

getvars() {
  TARGET_PLATFORM="$(uname -a | awk '{print $NF}' | cut -d '_' -f2)"
  LINUX_VER="$(uname -r | cut -d '+' -f1)"
  REVISION="$(uname -a | cut -d ' ' -f4)"
}

getvars

if [ "${1}" = "modules" ]; then
  echo "all-modules - ${1}"
    
  gunzip -c /exts/all-modules/${TARGET_PLATFORM}*${LINUX_VER}.tgz | tar xvf - -C /lib/modules/ >/dev/null 2>&1

  #[ -f /lib/modules/r8168_tx.ko ] && rm /lib/modules/r8168.ko

  [ ! -d /lib/firmware ] && mkdir /lib/firmware
  gunzip -c /exts/all-modules/firmware.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1

  [ -f /exts/all-modules/firmwarei915.tgz ] && gunzip -c /exts/all-modules/firmwarei915.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1
  # patch smallfixversion for 7.2.0-64570-1
  #if [ ${REVISION} = "#64570" ]; then
  #  echo "Modify VERSION file for 7.2.0-64570-1"
  #  sed -i 's#smallfixnumber="0"#smallfixnumber="1"#' /etc.defaults/VERSION
  #  echo 'packing="nano"' >> /etc.defaults/VERSION
  #  echo 'packing_id="1"' >> /etc.defaults/VERSION
  #fi
  /usr/sbin/depmod -a
elif [ "${1}" = "late" ]; then
  echo "all-modules - ${1}"
  #if lsmod | grep -q "^r8168_tx"; then
  #  rm /tmpRoot/lib/modules/r8168.ko && echo "tmpRoot r8168.ko removed" || echo "Failed to remove tmpRoot r8168.ko"
  #fi
  [ ! -d /tmpRoot/lib/firmware ] && mkdir /tmpRoot/lib/firmware
  gunzip -c /exts/all-modules/firmware.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1
  [ -f /exts/all-modules/firmwarei915.tgz ] && gunzip -c /exts/all-modules/firmwarei915.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1
  #if [ ${REVISION} = "#64570" ]; then
  #  echo "Copy the modified version files for 7.2.0-64570-1 to /tmpRoot"
  #  cp -vf /etc.defaults/VERSION /tmpRoot/etc.defaults/VERSION
  #  cp -vf /etc.defaults/VERSION /tmpRoot/etc/VERSION
  #fi
  /usr/sbin/depmod -a
  if [ "$TARGET_PLATFORM" = "broadwell" ]||[ "$TARGET_PLATFORM" = "broadwellnk" ]; then
    [ -f /tmp/lib/modules/dca.ko ] && modprobe dca
  fi
fi

#if [ "$TARGET_PLATFORM" = "apollolake" ]||[ "$TARGET_PLATFORM" = "geminilake" ]; then
#  tar xvfz /exts/all-modules/${TARGET_PLATFORM}*${LINUX_VER}.tgz -C /exts/all-modules/ modules.*
#  cp -vf /exts/all-modules/modules.* /lib/modules
#fi
