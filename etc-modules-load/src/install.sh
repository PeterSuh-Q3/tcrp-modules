#!/usr/bin/env ash

# Load optional system and hardware-monitoring modules during the modules
# phase, after all-modules has extracted the target pack and run depmod.
# This addon intentionally does not stop udevd and does not add an arbitrary
# boot delay.

install_superiotool() {
  _ml_tool_src="/exts/etc-modules-load/syno-superiotool-x86_64.gz"
  _ml_tool_dest="$1"
  _ml_tool_dir="${_ml_tool_dest%/*}"
  _ml_tool_tmp="${_ml_tool_dest}.tmp.$$"

  if [ ! -f "${_ml_tool_src}" ]; then
    echo "etc-modules-load: syno-superiotool package is missing (${_ml_tool_src})" >&2
    return 1
  fi
  mkdir -p "${_ml_tool_dir}" || return 1
  if ! gzip -dc "${_ml_tool_src}" > "${_ml_tool_tmp}"; then
    rm -f "${_ml_tool_tmp}"
    echo "etc-modules-load: failed to decompress syno-superiotool" >&2
    return 1
  fi
  chmod 0755 "${_ml_tool_tmp}" && mv -f "${_ml_tool_tmp}" "${_ml_tool_dest}" || {
    rm -f "${_ml_tool_tmp}"
    echo "etc-modules-load: failed to install syno-superiotool at ${_ml_tool_dest}" >&2
    return 1
  }
  echo "etc-modules-load: installed executable ${_ml_tool_dest}"
}

module_file() {
  local _ml_name _ml_candidate
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
  local _ml_name _ml_seen _ml_file _ml_deps _ml_dep
  local _ml_modprobe_output _ml_modprobe_status
  _ml_name="$1"
  _ml_seen="${2:-}"

  case " ${_ml_seen} " in
    *" ${_ml_name} "*)
      echo "etc-modules-load: dependency cycle detected at ${_ml_name}" >&2
      return 1
      ;;
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
  return 0
}

if [ "${1}" = "modules" ]; then
  echo "etc-modules-load - ${1}"

  # Keep a runnable copy in this event's PATH for Super I/O diagnostics.
  install_superiotool /usr/local/bin/syno-superiotool || true

  # PC speaker support
  load_module_with_dependencies pcspeaker || true
  load_module_with_dependencies pcspkr || true

  # CPU temperature drivers are mutually exclusive.  Select the driver from
  # the actual CPU vendor, then avoid an external module if Synology already
  # exports the matching temperature callback from vmlinux.
  # CPU 제조사 확인
  CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
  
  if [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
    if grep -qw 'syno_k10cpu_temperature' /proc/kallsyms 2>/dev/null; then
      echo "etc-modules-load: skip k10temp (provided by Synology kernel)"
    else
      load_module_with_dependencies k10temp || true
    fi
  elif [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    if grep -qw 'syno_cpu_temperature' /proc/kallsyms 2>/dev/null; then
      echo "etc-modules-load: skip coretemp (provided by Synology kernel)"
    else
      load_module_with_dependencies coretemp || true
    fi
  else
    echo "etc-modules-load: skip CPU temperature driver (unknown CPU vendor)"
  fi

  # Other optional hardware-monitoring drivers are safe to probe.
  for I in hwmon-vid nct6683 nct6775 it87 f71882fg \
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
elif [ "${1}" = "late" ]; then
  echo "etc-modules-load - ${1}"

  # Stage the same standalone diagnostic tool into the DSM root filesystem.
  install_superiotool /tmpRoot/usr/local/bin/syno-superiotool || true
fi
