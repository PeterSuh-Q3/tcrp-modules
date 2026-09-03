#!/usr/bin/env ash

# Load optional system and hardware-monitoring modules during the modules
# phase, after all-modules has extracted the target pack and run depmod.
# This addon intentionally does not stop udevd and does not add an arbitrary
# boot delay.
if [ "${1}" = "modules" ]; then
  echo "etc-modules-load - ${1}"

  # PC speaker support
  [ -f /lib/modules/pcspeaker.ko ] && /usr/sbin/modprobe pcspeaker || true
  [ -f /lib/modules/pcspkr.ko ] && /usr/sbin/modprobe pcspkr || true

  # Hardware-monitoring sensor modules.  coretemp and k10temp are harmless
  # when the CPU family does not match; the driver simply exposes no device.
  for I in coretemp k10temp hwmon-vid it87 nct6683 nct6775 \
           adt7470 adt7475 adm1021 adm1031 adm9240 lm75 lm78 lm90; do
    [ -f "/lib/modules/${I}.ko" ] && /usr/sbin/modprobe "${I}" || true
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
