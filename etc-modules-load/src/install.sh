#!/usr/bin/env ash

# Load optional system and hardware-monitoring modules during the modules
# phase, after all-modules has extracted the target pack and run depmod.
# This addon intentionally does not stop udevd and does not add an arbitrary
# boot delay.

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

  /usr/sbin/modprobe "${_ml_name}" || {
    echo "etc-modules-load: failed to load ${_ml_name}"
    return 1
  }
}

if [ "${1}" = "modules" ]; then
  echo "etc-modules-load - ${1}"

  # PC speaker support
  load_module_with_dependencies pcspeaker || true
  load_module_with_dependencies pcspkr || true

  # Hardware-monitoring sensor modules.  coretemp and k10temp are harmless
  # when the CPU family does not match; the driver simply exposes no device.
  for I in coretemp k10temp hwmon-vid it87 nct6683 nct6775 \
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
