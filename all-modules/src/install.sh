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
    
  gunzip -c /exts/all-modules/*${TARGET_PLATFORM}*${LINUX_VER}.tgz | tar xvf - -C /lib/modules/ >/dev/null 2>&1

  #[ -f /lib/modules/r8168_tx.ko ] && rm /lib/modules/r8168.ko

  [ ! -d /lib/firmware ] && mkdir /lib/firmware
  [ -f /exts/all-modules/firmware.tgz ] && gunzip -c /exts/all-modules/firmware.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1
  [ -f /exts/all-modules/firmware-custom.tgz ] && gunzip -c /exts/all-modules/firmware-custom.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1
  [ -f /exts/all-modules/firmwarei915.tgz ] && gunzip -c /exts/all-modules/firmwarei915.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1
  [ -f /exts/all-modules/firmwareamdgpu.tgz ] && gunzip -c /exts/all-modules/firmwareamdgpu.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1  
  # patch smallfixversion for 7.2.0-64570-1
  #if [ ${REVISION} = "#64570" ]; then
  #  echo "Modify VERSION file for 7.2.0-64570-1"
  #  sed -i 's#smallfixnumber="0"#smallfixnumber="1"#' /etc.defaults/VERSION
  #  echo 'packing="nano"' >> /etc.defaults/VERSION
  #  echo 'packing_id="1"' >> /etc.defaults/VERSION
  #fi
  [ -f /lib/modules/modules.order ]   || : > /lib/modules/modules.order
  [ -f /lib/modules/modules.builtin ] || : > /lib/modules/modules.builtin
  /usr/sbin/depmod -a
elif [ "${1}" = "late" ]; then
  echo "all-modules - ${1}"

  #for file in /exts/all-modules/modules-${TARGET_PLATFORM}*${LINUX_VER}.tgz; do
  #  if [ -f "$file" ]; then
  #    gunzip -c "$file" | tar xvf - -C /tmpRoot/lib/modules/ >/dev/null 2>&1
  #    break
  #  fi
  #done

  #if lsmod | grep -q "^r8168_tx"; then
  #  rm /tmpRoot/lib/modules/r8168.ko && echo "tmpRoot r8168.ko removed" || echo "Failed to remove tmpRoot r8168.ko"
  #fi
  [ ! -d /tmpRoot/lib/firmware ] && mkdir /tmpRoot/lib/firmware
  [ -f /exts/all-modules/firmware.tgz ] && gunzip -c /exts/all-modules/firmware.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1
  [ -f /exts/all-modules/firmware-custom.tgz ] && gunzip -c /exts/all-modules/firmware-custom.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1
  [ -f /exts/all-modules/firmwarei915.tgz ] && gunzip -c /exts/all-modules/firmwarei915.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1
  [ -f /exts/all-modules/firmwareamdgpu.tgz ] && gunzip -c /exts/all-modules/firmwareamdgpu.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1
  #if [ ${REVISION} = "#64570" ]; then
  #  echo "Copy the modified version files for 7.2.0-64570-1 to /tmpRoot"
  #  cp -vf /etc.defaults/VERSION /tmpRoot/etc.defaults/VERSION
  #  cp -vf /etc.defaults/VERSION /tmpRoot/etc/VERSION
  #fi
  [ -f /tmpRoot/lib/modules/modules.order ]   || : > /tmpRoot/lib/modules/modules.order
  [ -f /tmpRoot/lib/modules/modules.builtin ] || : > /tmpRoot/lib/modules/modules.builtin
  if [ "$TARGET_PLATFORM" = "broadwell" ]||[ "$TARGET_PLATFORM" = "broadwellnk" ]; then
    #ls -l /lib/modules/dca.ko
    [ -f /lib/modules/dca.ko ] && modprobe dca && echo "dca loaded"
  fi
  echo "Rebuilding module dependencies in /tmpRoot..."
  chroot /tmpRoot /sbin/depmod -a 2>/dev/null || echo "<3>[TCRP] WARNING: chroot depmod failed" > /dev/kmsg
fi

#if [ "$TARGET_PLATFORM" = "apollolake" ]||[ "$TARGET_PLATFORM" = "geminilake" ]; then
#  tar xvfz /exts/all-modules/${TARGET_PLATFORM}*${LINUX_VER}.tgz -C /exts/all-modules/ modules.*
#  cp -vf /exts/all-modules/modules.* /lib/modules
#fi
