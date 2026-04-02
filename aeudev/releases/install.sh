#!/usr/bin/env ash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

if [ "${1}" = "early" ]; then
  echo "Installing addon eudev - ${1}"
  tar -zxf /exts/aeudev/eudev-7.1.tgz -C /
  #[ ! -L "/usr/sbin/modprobe" ] && ln -sf /usr/bin/kmod /usr/sbin/modprobe
  #[ ! -L "/usr/sbin/modinfo" ] && ln -sf /usr/bin/kmod /usr/sbin/modinfo
  #[ ! -L "/usr/sbin/depmod" ] && ln -sf /usr/bin/kmod /usr/sbin/depmod

elif [ "${1}" = "modules" ]; then
  echo "Installing addon eudev - ${1}"

  # mv -f /usr/lib/udev/rules.d/60-persistent-storage.rules /usr/lib/udev/rules.d/60-persistent-storage.rules.bak
  # mv -f /usr/lib/udev/rules.d/60-persistent-storage-tape.rules /usr/lib/udev/rules.d/60-persistent-storage-tape.rules.bak
  # mv -f /usr/lib/udev/rules.d/80-net-name-slot.rules /usr/lib/udev/rules.d/80-net-name-slot.rules.bak
  [ -e /proc/sys/kernel/hotplug ] && printf '\000\000\000\000' >/proc/sys/kernel/hotplug
  /usr/sbin/depmod -a
  /usr/sbin/udevd -d || {
    echo "FAIL"
    exit 1
  }
  echo "Triggering add events to udev"
  udevadm trigger --type=subsystems --action=add
  udevadm trigger --type=devices --action=add
  udevadm trigger --type=devices --action=change
  udevadm settle --timeout=30 || echo "udevadm settle failed"
  # Give more time
  sleep 10
  # Remove from memory to not conflict with RAID mount scripts
  /usr/bin/killall udevd
  # modprobe pcspeaker, pcspkr
  [ -f /lib/modules/pcspeaker.ko ] && /usr/sbin/modprobe pcspeaker || true
  [ -f /lib/modules/pcspkr.ko ] && /usr/sbin/modprobe pcspkr || true
  # modprobe modules for the sensors
  for I in coretemp k10temp hwmon-vid it87 nct6683 nct6775 adt7470 adt7475 adm1021 adm1031 adm9240 lm75 lm78 lm90; do
    [ -f /lib/modules/${I}.ko ] && /usr/sbin/modprobe "${I}" || true
  done
  
  # Remove kvm module
  /usr/sbin/lsmod 2>/dev/null | grep -q ^kvm_intel && /usr/sbin/modprobe -r kvm_intel || true # kvm-intel.ko
  /usr/sbin/lsmod 2>/dev/null | grep -q ^kvm_amd && /usr/sbin/modprobe -r kvm_amd || true     # kvm-amd.ko

elif [ "${1}" = "late" ]; then
  echo "Installing addon eudev - ${1}"
  # [ ! -L "/tmpRoot/usr/sbin/modprobe" ] && ln -sf /usr/bin/kmod /tmpRoot/usr/sbin/modprobe
  [ ! -L "/tmpRoot/usr/sbin/modinfo" ] && ln -sf /usr/bin/kmod /tmpRoot/usr/sbin/modinfo
  [ ! -L "/tmpRoot/usr/sbin/depmod" ] && ln -sf /usr/bin/kmod /tmpRoot/usr/sbin/depmod

  [ ! -f "/tmpRoot/usr/bin/eject" ] && cp -vpf /usr/bin/eject /tmpRoot/usr/bin/eject

  echo "copy firmware"
  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  /tmpRoot/bin/cp -rnf /usr/lib/firmware/* /tmpRoot/usr/lib/firmware/

  echo "Copy rules"
  /tmpRoot/bin/cp -vrf /usr/lib/udev/* /tmpRoot/usr/lib/udev/

  mkdir -p "/tmpRoot/usr/lib/systemd/system"
  DEST="/tmpRoot/usr/lib/systemd/system/udevrules.service"
  {
    echo "[Unit]"
    echo "Description=mshell addon udev daemon"
    echo
    echo "[Service]"
    echo "Type=oneshot"
    echo "RemainAfterExit=yes"
    echo "ExecStart=/usr/bin/udevadm hwdb --update"
    echo "ExecStart=/usr/bin/udevadm control --reload-rules"
    echo
    echo "[Install]"
    echo "WantedBy=multi-user.target"
  } >"${DEST}"
  chmod 644 "${DEST}"
  mkdir -p /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -sf /usr/lib/systemd/system/udevrules.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/udevrules.service

  # if custom modules or amdgpu modules exists
  if [[ -f /exts/all-modules/firmware-custom.tgz || -f /exts/all-modules/firmwareamdgpu.tgz ]]; then
    # 모든 패키지(Container Manager, Plex 등)가 로드되기 전에 모듈을 올려 /dev/dri 노드를 생성
    # 펌웨어와 모듈이 복사된 후 실행
    DEST="/tmpRoot/usr/lib/systemd/system/mshell-amdgpu.service"
    {
      echo "[Unit]"
      echo "Description=MSHELL AMDGPU Module Loader"
      echo "After=local-fs.target"
      echo "Before=pkgctl.target"
      echo
      echo "[Service]"
      echo "Type=oneshot"
      echo "ExecStart=/bin/sh -c '/sbin/depmod -a && /sbin/modprobe amdgpu'"
      echo "RemainAfterExit=yes"      
      echo
      echo "[Install]"
      echo "WantedBy=multi-user.target"
    } >"${DEST}"
    chmod 644 "${DEST}"
    ln -sf /usr/lib/systemd/system/mshell-amdgpu.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/mshell-amdgpu.service
  fi
  
fi
