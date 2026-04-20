#!/bin/bash
#
# install redpill tcrp modules
#

getvars() {
  TARGET_PLATFORM="$(uname -a | awk '{print $NF}' | cut -d '_' -f2)"
  LINUX_VER="$(uname -r | cut -d '+' -f1)"
  REVISION="$(uname -a | cut -d ' ' -f4)"
}

# DSM/플랫폼/커널 조합 지문 계산 (BAK 유효성 판단용)
# 포맷: platform|kernel|productversion-buildnumber-smallfixnumber
# busybox ash 호환: md5sum/bash 불필요, local 미사용
get_dsm_fingerprint() {
  _fp_root="${1:-/tmpRoot}"
  _fp_vf="${_fp_root}/etc.defaults/VERSION"
  _fp_platform="$(uname -a | awk '{print $NF}' | cut -d '_' -f2)"
  _fp_kver="$(uname -r)"
  _fp_dsm="unknown"
  if [ -f "${_fp_vf}" ]; then
    _fp_pv="$(grep '^productversion=' "${_fp_vf}" | cut -d= -f2 | tr -d '"')"
    _fp_bn="$(grep '^buildnumber='    "${_fp_vf}" | cut -d= -f2 | tr -d '"')"
    _fp_sf="$(grep '^smallfixnumber=' "${_fp_vf}" | cut -d= -f2 | tr -d '"')"
    _fp_dsm="${_fp_pv}-${_fp_bn}-${_fp_sf}"
  fi
  echo "${_fp_platform}|${_fp_kver}|${_fp_dsm}"
}

getvars

if [ "${1}" = "modules" ]; then
  echo "all-modules - ${1}"
  [ -f "/addons/pml_on" ] && echo "/addons/pml_on file exists PML METHOD" || echo "/addons/pml_on file not exists IML METHOD"

  if [ ! -f "/addons/pml_on" ]; then
    gunzip -c /exts/all-modules/*${TARGET_PLATFORM}*${LINUX_VER}.tgz | tar xvf - -C /lib/modules/ >/dev/null 2>&1

    #[ -f /lib/modules/r8168_tx.ko ] && rm /lib/modules/r8168.ko

    [ ! -d /lib/firmware ] && mkdir /lib/firmware
    if [ -f /exts/all-modules/firmware.tgz ]; then
      gunzip -c /exts/all-modules/firmware.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1 \
        || echo "Firmware extraction failed" >&2
    fi
    if [ -f /exts/all-modules/firmware-custom.tgz ]; then
      gunzip -c /exts/all-modules/firmware-custom.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1 \
        || echo "Firmware-custom extraction failed" >&2
    fi
    if [ -f /exts/all-modules/firmwarei915.tgz ]; then
      gunzip -c /exts/all-modules/firmwarei915.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1 \
        || echo "Firmwarei915 extraction failed" >&2
    fi
    if [ -f /exts/all-modules/firmwareamdgpu.tgz ]; then
      gunzip -c /exts/all-modules/firmwareamdgpu.tgz | tar xvf - -C /lib/firmware/ >/dev/null 2>&1 \
        || echo "Firmwareamdgpu extraction failed" >&2
    fi
    #if [ ${REVISION} = "#64570" ]; then
    #  echo "Modify VERSION file for 7.2.0-64570-1"
    #  sed -i 's#smallfixnumber="0"#smallfixnumber="1"#' /etc.defaults/VERSION
    #  echo 'packing="nano"' >> /etc.defaults/VERSION
    #  echo 'packing_id="1"' >> /etc.defaults/VERSION
    #fi
    [ -f /lib/modules/modules.order ]   || : > /lib/modules/modules.order
    [ -f /lib/modules/modules.builtin ] || : > /lib/modules/modules.builtin
    /usr/sbin/depmod -a
  fi

elif [ "${1}" = "late" ]; then
  echo "all-modules - ${1}"

  #for file in /exts/all-modules/modules-${TARGET_PLATFORM}*${LINUX_VER}.tgz; do
  #  if [ -f "$file" ]; then
  #    gunzip -c "$file" | tar xvf - -C /tmpRoot/lib/modules/ >/dev/null 2>&1
  #    break
  #  fi
  #done
  
  [ -f "/addons/pml_on" ] && echo "/addons/pml_on file exists PML MOTHOD" || echo "/addons/pml_on file not exists IML MOTHOD"

  MODULES_DIR="/tmpRoot/usr/lib/modules"
  MODULES_BAK="${MODULES_DIR}.bak"
  META_FILE="${MODULES_DIR}.bak.meta"     # BAK 외부에 보관 (cp 시 복사되지 않도록)
  SRC_MODULES="/usr/lib/modules"

  # /bin/cp 사용 (initrd 네이티브, 의존성 없음)
  CP="/bin/cp"
  RM="/bin/rm"

  CURRENT_FP="$(get_dsm_fingerprint /tmpRoot)"
  SAVED_FP="$(cat "${META_FILE}" 2>/dev/null || true)"

  if [ -f "/addons/pml_on" ]; then
    echo "handle modules to /tmpRoot..."

    if [ -d "${MODULES_BAK}" ] && [ -n "$(ls ${MODULES_BAK}/ 2>/dev/null)" ] \
       && [ "${SAVED_FP}" = "${CURRENT_FP}" ]; then
        echo "restore from backup modules (fingerprint OK: ${CURRENT_FP})"
        ${RM} -rf "${MODULES_DIR}"
        ${CP} -rpf "${MODULES_BAK}" "${MODULES_DIR}" \
            || { echo "ERROR: restore failed!"; exit 1; }
    else
        if [ -d "${MODULES_BAK}" ] && [ "${SAVED_FP}" != "${CURRENT_FP}" ]; then
            echo "<4>[TCRP] BAK fingerprint mismatch (saved='${SAVED_FP}' current='${CURRENT_FP}') - recapture" > /dev/kmsg
        else
            echo "backup modules (first capture): ${CURRENT_FP}"
        fi
        ${RM} -rf "${MODULES_BAK}"
        ${CP} -rpf "${MODULES_DIR}" "${MODULES_BAK}" \
            || { echo "ERROR: backup failed!"; exit 1; }
        echo "${CURRENT_FP}" > "${META_FILE}"
    fi

    ${CP} -rpf "${SRC_MODULES}/"* "${MODULES_DIR}" \
        || { echo "ERROR: module copy failed!"; exit 1; }

    echo "modules copy done."
    [ -f /tmpRoot/lib/modules/modules.order ]   || : > /tmpRoot/lib/modules/modules.order
    [ -f /tmpRoot/lib/modules/modules.builtin ] || : > /tmpRoot/lib/modules/modules.builtin
    echo "Rebuilding module dependencies in /tmpRoot..."
    chroot /tmpRoot /sbin/depmod -a 2>/dev/null || echo "<3>[TCRP] WARNING: chroot depmod failed" > /dev/kmsg

  else
    # IML 모드: PML 이 남겼던 rootfs 오염을 BAK 으로 원상복원
    # 단 지문이 완전히 일치할 때만 수행 (불일치 시 rootfs 불변 유지)
    if [ -d "${MODULES_BAK}" ] && [ -n "$(ls ${MODULES_BAK}/ 2>/dev/null)" ] \
       && [ "${SAVED_FP}" = "${CURRENT_FP}" ]; then
        echo "IML mode: restoring pristine modules from BAK (fingerprint OK: ${CURRENT_FP})"
        # 이전 오염본 1개만 롤링 보존 (디스크 낭비 방지)
        ${RM} -rf "${MODULES_DIR}.polluted.prev" 2>/dev/null
        /bin/mv "${MODULES_DIR}" "${MODULES_DIR}.polluted.prev" 2>/dev/null
        ${CP} -rpf "${MODULES_BAK}" "${MODULES_DIR}" \
            || { echo "ERROR: IML restore failed!"; exit 1; }
        echo "IML restore done."
        [ -f /tmpRoot/lib/modules/modules.order ]   || : > /tmpRoot/lib/modules/modules.order
        [ -f /tmpRoot/lib/modules/modules.builtin ] || : > /tmpRoot/lib/modules/modules.builtin
        chroot /tmpRoot /sbin/depmod -a 2>/dev/null \
            || echo "<3>[TCRP] WARNING: IML chroot depmod failed" > /dev/kmsg
    elif [ -d "${MODULES_BAK}" ]; then
        echo "<4>[TCRP] IML mode: BAK fingerprint mismatch (saved='${SAVED_FP}' current='${CURRENT_FP}') - leave rootfs intact" > /dev/kmsg
    else
        echo "IML mode: no BAK present - nothing to restore"
    fi
  fi

  if [ "$TARGET_PLATFORM" = "broadwell" ]||[ "$TARGET_PLATFORM" = "broadwellnk" ]; then
    [ -f /lib/modules/dca.ko ] && modprobe dca && echo "dca loaded"
  fi

  #if lsmod | grep -q "^r8168_tx"; then
  #  rm /tmpRoot/lib/modules/r8168.ko && echo "tmpRoot r8168.ko removed" || echo "Failed to remove tmpRoot r8168.ko"
  #fi

  [ ! -d /tmpRoot/lib/firmware ] && mkdir /tmpRoot/lib/firmware
  if [ -f /exts/all-modules/firmware.tgz ]; then
    gunzip -c /exts/all-modules/firmware.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1 \
      || echo "Firmware extraction failed" >&2
  fi
  if [ -f /exts/all-modules/firmware-custom.tgz ]; then
    gunzip -c /exts/all-modules/firmware-custom.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1 \
      || echo "Firmware-custom extraction failed" >&2
  fi
  if [ -f /exts/all-modules/firmwarei915.tgz ]; then
    gunzip -c /exts/all-modules/firmwarei915.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1 \
      || echo "Firmwarei915 extraction failed" >&2
  fi
  if [ -f /exts/all-modules/firmwareamdgpu.tgz ]; then
    gunzip -c /exts/all-modules/firmwareamdgpu.tgz | tar xvf - -C /tmpRoot/lib/firmware/ >/dev/null 2>&1 \
      || echo "Firmwareamdgpu extraction failed" >&2
  fi    # patch smallfixversion for 7.2.0-64570-1

  #if [ ${REVISION} = "#64570" ]; then
  #  echo "Copy the modified version files for 7.2.0-64570-1 to /tmpRoot"
  #  cp -vf /etc.defaults/VERSION /tmpRoot/etc.defaults/VERSION
  #  cp -vf /etc.defaults/VERSION /tmpRoot/etc/VERSION
  #fi

fi

#if [ "$TARGET_PLATFORM" = "apollolake" ]||[ "$TARGET_PLATFORM" = "geminilake" ]; then
#  tar xvfz /exts/all-modules/${TARGET_PLATFORM}*${LINUX_VER}.tgz -C /exts/all-modules/ modules.*
#  cp -vf /exts/all-modules/modules.* /lib/modules
#fi
