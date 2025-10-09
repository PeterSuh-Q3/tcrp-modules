#!/usr/bin/env ash
#
# Copyright (C) 2022 Ing <https://github.com/wjz304>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# [NEW] 유효한 MAC 판별 함수
is_valid_mac() {
  local mac="$1"
  printf "%s" "$mac" | grep -qiE '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$'
}

# [NEW] MAC + addr_assign_type(=0)까지 기다리는 함수
#        - addr_assign_type 파일이 없을 경우, "MAC만 유효하면 성공"으로 폴백
wait_for_mac_and_type() {
  local dev="$1"
  local timeout="${2:-120}"
  local interval="${3:-1}"
  local start_ts end_ts mac type tried_up=0

  if [ ! -e "/sys/class/net/$dev/address" ]; then
    echo "WARN: $dev not found in /sys/class/net"
    return 1
  fi

  start_ts=$(date +%s)
  end_ts=$((start_ts + timeout))

  while [ "$(date +%s)" -lt "$end_ts" ]; do
    mac=$(cat "/sys/class/net/$dev/address" 2>/dev/null || echo "00:00:00:00:00:00")
    type=$(cat "/sys/class/net/$dev/addr_assign_type" 2>/dev/null || echo "")

    # addr_assign_type이 있는 커널: '0'(영구 MAC)까지 대기
    if [ -n "$type" ]; then
      if is_valid_mac "$mac" && [ "$mac" != "00:00:00:00:00:00" ] && [ "$type" -eq 0 ] 2>/dev/null; then
        echo "MAC for $dev is now $mac (addr_assign_type=$type)"
        return 0
      fi
    else
      # 없는 커널: MAC이 유효/비영(비-제로)이면 성공으로 간주
      if is_valid_mac "$mac" && [ "$mac" != "00:00:00:00:00:00" ]; then
        echo "MAC for $dev is now $mac (addr_assign_type not present; accepted)"
        return 0
      fi
    fi

    # 드라이버 초기화를 자극: 첫 5초 이후 1회 link up 시도
    if [ $tried_up -eq 0 ] && [ $(( $(date +%s) - start_ts )) -ge 5 ]; then
      if command -v ip >/dev/null 2>&1; then
        ip link set dev "$dev" up 2>/dev/null && tried_up=1
      fi
    fi

    sleep "$interval"
  done

  # 최종 상태를 출력
  if [ -z "$type" ]; then
    echo "WARN: Timed out waiting for valid MAC on $dev (MAC=$mac, addr_assign_type not present)"
  else
    echo "WARN: Timed out waiting for valid MAC and addr_assign_type=0 on $dev (MAC=$mac, type=$type)"
  fi
  return 1
}


if [ "${1}" = "early" ]; then
  echo "Installing addon eudev - ${1}"
  tar -zxf /exts/eudev/eudev-7.1.tgz -C /
  [ ! -L "/usr/sbin/modprobe" ] && ln -vsf /usr/bin/kmod /usr/sbin/modprobe
  [ ! -L "/usr/sbin/modinfo" ] && ln -vsf /usr/bin/kmod /usr/sbin/modinfo
  #[ ! -L "/usr/sbin/depmod" ] && ln -vsf /usr/bin/kmod /usr/sbin/depmod
elif [ "${1}" = "modules" ]; then
  echo "Installing addon eudev - ${1}"

  # mv -f /usr/lib/udev/rules.d/60-persistent-storage.rules /usr/lib/udev/rules.d/60-persistent-storage.rules.bak
  # mv -f /usr/lib/udev/rules.d/60-persistent-storage-tape.rules /usr/lib/udev/rules.d/60-persistent-storage-tape.rules.bak
  # mv -f /usr/lib/udev/rules.d/80-net-name-slot.rules /usr/lib/udev/rules.d/80-net-name-slot.rules.bak
  [ -e /proc/sys/kernel/hotplug ] && printf '\000\000\000\000' >/proc/sys/kernel/hotplug
  /usr/sbin/depmod -a

  # udevd 시작
  /usr/sbin/udevd -d || {
    echo "FAIL"
    exit 1
  }

  echo "Triggering add events to udev"

  # 기존 트리거 흐름 유지
  udevadm trigger --type=subsystems --action=add
  udevadm trigger --type=devices --action=add
  udevadm trigger --type=devices --action=change

  # 0) [NEW] udevd 실행 중이어야 함 (이미 실행되어 있다면 건너뜀)
  udevadm trigger -s pci --action=add
  udevadm settle --timeout=60 || true

  # 1) [NEW] 널리 쓰이는 NIC 드라이버 강제 로딩
  for m in e1000e igb r8169 virtio_net vmxnet3 ixgbe mlx5_core; do modprobe -q "$m" || true; done

  # 2) [NEW] PCI modalias 기반 오토 로딩 백업
  for d in /sys/bus/pci/devices/*; do
    [ -e "$d/modalias" ] || continue
    modprobe -b "$(cat "$d/modalias")" 2>/dev/null || true
  done

  # 3) [NEW]  네트워크 서브시스템을 명시적으로 한 번 더 자극 + sett
  udevadm trigger -s net --action=add
  udevadm trigger -s net --action=change
  # [CHANGED] settle 시간을 충분히 늘림 (기본 60초)
  udevadm settle --timeout=60 || echo "udevadm settle failed"

  # 4) 링크 업으로 드라이버 초기화 자극
  for dev in $(ls -1 /sys/class/net | grep -v '^lo$'); do
    [ -e "/sys/class/net/$dev/device" ] || continue
    ip link set dev "$dev" up 2>/dev/null || true
  done

  # [REMOVED/MOVED] 기존의 sleep 10 및 조기 killall udevd는 아래로 이동
  # sleep 10
  # Remove from memory to not conflict with RAID mount scripts
  # /usr/bin/killall udevd

  # [NEW] 설정 가능한 파라미터
  MAC_WAIT_TIMEOUT="${MAC_WAIT_TIMEOUT:-120}"   # NIC 당 최대 대기 시간(초)
  MAC_WAIT_INTERVAL="${MAC_WAIT_INTERVAL:-1}"   # 폴링 간격(초)
  FORCE_KILL_UDEVD="${FORCE_KILL_UDEVD:-0}"     # 1이면 NIC 준비 실패에도 udevd를 종료

  # [NEW] 모든 NIC에 대해 대기
  echo "Waiting for NICs to present permanent MAC addresses..."
  ALL_NICS_READY=true
  READY_COUNT=0
  TOTAL_COUNT=0

  # 5) [NEW] addr_assign_type==0까지 대기 
  for dev in $(ls -1 /sys/class/net | grep -v '^lo$'); do
    # 물리/가상 NIC에 매핑된 인터페이스만 처리 (bond/vlan/tun 등은 보통 device가 없음)
    [ -e "/sys/class/net/$dev/device" ] || continue

    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    echo " - $dev: waiting (timeout=${MAC_WAIT_TIMEOUT}s, interval=${MAC_WAIT_INTERVAL}s)..."
    if wait_for_mac_and_type "$dev" "$MAC_WAIT_TIMEOUT" "$MAC_WAIT_INTERVAL"; then
      READY_COUNT=$((READY_COUNT + 1))
    else
      ALL_NICS_READY=false
    fi
  done
  if [ "$TOTAL_COUNT" -eq 0 ]; then
    echo "INFO: No eligible NICs found under /sys/class/net (excluding 'lo')."
  fi
  echo "NIC readiness summary: $READY_COUNT / $TOTAL_COUNT ready"
  if [ "$ALL_NICS_READY" = true ]; then
    echo "All NICs are ready with permanent MACs."
  else
    echo "WARN: Some NICs are not ready with permanent MACs."
  fi

  # [MOVED] (원래 위치에서 이동) 필요시 잠깐 더 여유
  sleep 2

  # [CHANGED] udevd 종료 시점: NIC 준비가 끝난 뒤에 종료
  if [ "$ALL_NICS_READY" = true ] || [ "$FORCE_KILL_UDEVD" -eq 1 ]; then
    echo "Stopping udevd..."
    # Remove from memory to not conflict with RAID mount scripts
    /usr/bin/killall udevd || true
  else
    echo "INFO: Keeping udevd running because some NICs were not ready."
  fi

  # modprobe pcspeaker, pcspkr
  /usr/sbin/modprobe pcspeaker || true
  /usr/sbin/modprobe pcspkr || true

  # modprobe modules for the sensors
  for I in coretemp k10temp hwmon-vid it87 nct6683 nct6775 adt7470 adt7475 adm1021 adm1031 adm9240 lm75 lm78 lm90; do
    /usr/sbin/modprobe "${I}" || true
  done
  
  # Remove kvm module
  /usr/sbin/lsmod 2>/dev/null | grep -q ^kvm_intel && /usr/sbin/modprobe -r kvm_intel || true # kvm-intel.ko
  /usr/sbin/lsmod 2>/dev/null | grep -q ^kvm_amd && /usr/sbin/modprobe -r kvm_amd || true     # kvm-amd.ko

elif [ "${1}" = "late" ]; then
  echo "Installing addon eudev - ${1}"
  # [ ! -L "/tmpRoot/usr/sbin/modprobe" ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/modprobe
  [ ! -L "/tmpRoot/usr/sbin/modinfo" ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/modinfo
  [ ! -L "/tmpRoot/usr/sbin/depmod" ] && ln -vsf /usr/bin/kmod /tmpRoot/usr/sbin/depmod

  [ ! -f "/tmpRoot/usr/bin/eject" ] && cp -vpf /usr/bin/eject /tmpRoot/usr/bin/eject

  echo "copy modules"
  export LD_LIBRARY_PATH=/tmpRoot/bin:/tmpRoot/lib
  isChange=false
  /tmpRoot/bin/cp -rnf /usr/lib/firmware/* /tmpRoot/usr/lib/firmware/
  if grep -q 'RR@RR' /proc/version 2>/dev/null; then
    if [ -d /tmpRoot/usr/lib/modules.bak ]; then
      /tmpRoot/bin/rm -rf /tmpRoot/usr/lib/modules
      /tmpRoot/bin/cp -rpf /tmpRoot/usr/lib/modules.bak /tmpRoot/usr/lib/modules
    else
      echo "RR@RR, backup modules."
      /tmpRoot/bin/cp -rpf /tmpRoot/usr/lib/modules /tmpRoot/usr/lib/modules.bak
    fi
    /tmpRoot/bin/cp -rpf /usr/lib/modules/* /tmpRoot/usr/lib/modules
    isChange=true
  else
    if [ -d /tmpRoot/usr/lib/modules.bak ]; then
      echo "RR@RR, restore modules from backup."
      /tmpRoot/bin/rm -rf /tmpRoot/usr/lib/modules
      /tmpRoot/bin/mv -rf /tmpRoot/usr/lib/modules.bak /tmpRoot/usr/lib/modules
    fi
    for L in $(grep -v '^\s*$\|^\s*#' /addons/modulelist 2>/dev/null | awk '{if (NF == 2) print $1"###"$2}'); do
      O=$(echo "${L}" | awk -F'###' '{print $1}')
      M=$(echo "${L}" | awk -F'###' '{print $2}')
      [ -z "${M}" ] || [ ! -f "/usr/lib/modules/${M}" ] && continue
      if [ "$(echo "${O:0:1}" | sed 's/.*/\U&/')" = "F" ]; then
        /tmpRoot/bin/cp -vrf /usr/lib/modules/${M} /tmpRoot/usr/lib/modules/
      else
        /tmpRoot/bin/cp -vrn /usr/lib/modules/${M} /tmpRoot/usr/lib/modules/
      fi
      isChange=true
    done
  fi
  echo "isChange: ${isChange}"
  [ "${isChange}" = "true" ] && /usr/sbin/depmod -a -b /tmpRoot

  # Restore kvm module
  /usr/sbin/modprobe kvm_intel || true # kvm-intel.ko
  /usr/sbin/modprobe kvm_amd || true   # kvm-amd.ko

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

  mkdir -vp /tmpRoot/usr/lib/systemd/system/multi-user.target.wants
  ln -vsf /usr/lib/systemd/system/udevrules.service /tmpRoot/usr/lib/systemd/system/multi-user.target.wants/udevrules.service
fi
