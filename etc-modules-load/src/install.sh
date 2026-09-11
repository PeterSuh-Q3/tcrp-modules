#!/usr/bin/env ash

# Load optional system and hardware-monitoring modules during the modules
# phase, after all-modules has extracted the target pack and run depmod.
# This addon intentionally does not stop udevd and does not add an arbitrary
# boot delay.

KVER_CLEAN=$(uname -r | sed -n 's/^\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
ZPADKVER=$(printf "%01d%03d%03d\n" $(echo "$KVER_CLEAN" | tr '.' ' '))

# virtio_modprobe / mmc_modprobe / usblan_modprobe moved here from ddsml's
# check-all-modules.sh so they run regardless of whether ddsml or eudev is
# the installed hardware-detection addon.

virtio_modprobe() {
  echo "Checking for VirtIO"
  if (grep -r -q -E "(QEMU|VirtualBox)" /sys/devices/virtual/dmi/id/); then
    echo "VirtIO hypervisor detected"
    /usr/sbin/insmod /lib/modules/virtio.ko
    /usr/sbin/insmod /lib/modules/virtio_ring.ko
    /usr/sbin/insmod /lib/modules/virtio_mmio.ko
    /usr/sbin/insmod /lib/modules/virtio_pci.ko
    #if [ "${LINUX_VER}" != "5.10.55" ]; then
    /usr/sbin/insmod /lib/modules/virtio_blk.ko
    /usr/sbin/insmod /lib/modules/virtio_net.ko
    /usr/sbin/insmod /lib/modules/virtio_scsi.ko
    #fi
  else
    echo "*No* VirtIO hypervisor detected"
  fi
}

mmc_modprobe() {
  echo "excute modprobe for mmc(include sd)..."
  /usr/sbin/modprobe mmc_block
  /usr/sbin/modprobe mmc_core
  if [ "$ZPADKVER" -gt 4004059 ]; then
      /usr/sbin/modprobe rtsx_pci
      /usr/sbin/modprobe rtsx_pci_sdmmc
  fi
  /usr/sbin/modprobe sdhci
  # sdhci_pci (cqhci-capable backport) needs these providers; load them
  # explicitly in case modules.dep is stale and does not auto-pull them.
  /usr/sbin/modprobe cqhci 2>/dev/null
  /usr/sbin/modprobe sdhci-pci-data 2>/dev/null
  /usr/sbin/modprobe sdhci_pci
  sleep 1
  if [ `/sbin/lsmod |grep -i mmc|wc -l` -gt 0 ] ; then
      echo "Module mmc loaded succesfully!!!"
  else
      echo "Module mmc failed to load successfully!!!"
  fi
}

usblan_modprobe() {

  modules="aqc111 asix ax88179_178a r8152 r8153_ecm rtl8150"
  module_dir="/lib/modules"

  for mod in $modules; do
    modpath="$module_dir/${mod}.ko"
    if [ -f "$modpath" ]; then
      echo "Loading module: $mod"
      modprobe "$mod"
    else
      echo "Module file not found for: $mod"
    fi
  done
}

module_file() {
  _ml_name="$1"
  for _ml_candidate in "${_ml_name}" "$(echo "${_ml_name}" | tr '_' '-')" \
                       "$(echo "${_ml_name}" | tr '-' '_')"; do
    [ -f "/lib/modules/${_ml_candidate}.ko" ] && {
      echo "/lib/modules/${_ml_candidate}.ko"
      return 0
    }
  done
  return 1
}

# modules.dep generated from a partial all-modules archive can omit a required
# provider.  Verify modinfo dependencies directly and load them first; a
# consumer is skipped rather than allowed to emit an Unknown symbol error.
load_module_with_dependencies() {
  _ml_name="$1"
  _ml_seen="${2:-}"

  case " ${_ml_seen} " in
    *" ${_ml_name} "*) return 0 ;;
  esac
  _ml_seen="${_ml_seen} ${_ml_name}"

  _ml_file="$(module_file "${_ml_name}")" || {
    echo "etc-modules-load: skip ${_ml_name} (module file is absent)"
    return 1
  }
  _ml_deps="$(/usr/sbin/modinfo -F depends "${_ml_file}" 2>/dev/null)" || {
    echo "etc-modules-load: skip ${_ml_name} (cannot read module dependencies)"
    return 1
  }

  for _ml_dep in $(echo "${_ml_deps}" | tr ',' ' '); do
    [ -n "${_ml_dep}" ] || continue
    load_module_with_dependencies "${_ml_dep}" "${_ml_seen}" || {
      echo "etc-modules-load: skip ${_ml_name} (provider ${_ml_dep} is unavailable)"
      return 1
    }
  done

  _ml_modprobe_output="$(/usr/sbin/modprobe "${_ml_name}" 2>&1)"
  _ml_modprobe_status=$?
  if [ "${_ml_modprobe_status}" -ne 0 ]; then
    case "${_ml_modprobe_output}" in
      *"No such device"*)
        echo "etc-modules-load: ${_ml_name} is not applicable to this hardware"
        return 0
        ;;
      *)
        [ -n "${_ml_modprobe_output}" ] && echo "${_ml_modprobe_output}" >&2
        echo "etc-modules-load: failed to load ${_ml_name}"
        return 1
        ;;
    esac
  fi
}

if [ "${1}" = "modules" ]; then
  echo "etc-modules-load - ${1}"

  /usr/sbin/depmod -a

  TARGET_PLATFORM="$(uname -a | awk '{print $NF}' | cut -d '_' -f2)"
  usblan_modprobe
  virtio_modprobe
  case $TARGET_PLATFORM in
  avoton | bromolow | braswell | cedarview | grantley)
      ;;
  apollolake | broadwell | broadwellnk | v1000 | r1000 | denverton | geminilake | *)
      mmc_modprobe
      ;;
  esac

  # PC speaker support
  load_module_with_dependencies pcspeaker || true
  load_module_with_dependencies pcspkr || true

  # CPU temperature drivers are mutually exclusive.  Select the driver from
  # the actual CPU vendor, then avoid an external module if Synology already
  # exports the matching temperature callback from vmlinux.
  if grep -qm1 '^vendor_id[[:space:]]*:.*GenuineIntel' /proc/cpuinfo; then
    if grep -qw 'syno_cpu_temperature' /proc/kallsyms 2>/dev/null; then
      echo "etc-modules-load: skip coretemp (provided by Synology kernel)"
    else
      load_module_with_dependencies coretemp || true
    fi
  elif grep -qm1 '^vendor_id[[:space:]]*:.*AuthenticAMD' /proc/cpuinfo; then
    if grep -qw 'syno_k10cpu_temperature' /proc/kallsyms 2>/dev/null; then
      echo "etc-modules-load: skip k10temp (provided by Synology kernel)"
    else
      load_module_with_dependencies k10temp || true
    fi
  else
    echo "etc-modules-load: skip CPU temperature driver (unknown CPU vendor)"
  fi

  # Other optional hardware-monitoring drivers are safe to probe.
  for I in hwmon-vid it87 nct6683 nct6775 \
           adt7470 adt7475 adm1021 adm1031 adm9240 lm75 lm78 lm90; do
    load_module_with_dependencies "${I}" || true
  done

  # Remove only the KVM implementation unsupported by the current CPU.
  # A module in use will not be unloaded; failure is intentionally ignored.
  if grep -qm1 'vmx' /proc/cpuinfo; then
    /usr/sbin/lsmod 2>/dev/null | grep -q '^kvm_amd' &&
      /usr/sbin/modprobe -r kvm_amd || true
  elif grep -qm1 'svm' /proc/cpuinfo; then
    /usr/sbin/lsmod 2>/dev/null | grep -q '^kvm_intel' &&
      /usr/sbin/modprobe -r kvm_intel || true
  else
    /usr/sbin/lsmod 2>/dev/null | grep -q '^kvm_intel' &&
      /usr/sbin/modprobe -r kvm_intel || true
    /usr/sbin/lsmod 2>/dev/null | grep -q '^kvm_amd' &&
      /usr/sbin/modprobe -r kvm_amd || true
  fi
fi
