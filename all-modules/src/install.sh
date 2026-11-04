#!/bin/bash
#
# install redpill tcrp modules
#

getvars() {
  TARGET_PLATFORM="$(uname -a | awk '{print $NF}' | cut -d '_' -f2)"
  LINUX_VER="$(uname -r | cut -d '+' -f1)"
  REVISION="$(uname -a | cut -d ' ' -f4)"
  # DSM major.minor (예: 7.3) — 모듈팩 tgz 파일명 정확 지정용 (glob * 배제)
  # productversion 은 "7.3.2" 처럼 micro 를 포함하므로 부적합 → major / minor 변수만 사용
  # VERSION 파일은 var="value" 형식이라 source(.) 로 안전하게 읽음
  DSM_VER=""
  _verfile=""
  for _vf in /etc.defaults/VERSION /etc/VERSION; do
    [ -f "${_vf}" ] && { _verfile="${_vf}"; break; }
  done
  if [ -z "${_verfile}" ]; then
    echo "<3>[TCRP] all-modules: VERSION file not found (/etc.defaults/VERSION, /etc/VERSION) - DSM_VER unset" > /dev/kmsg
  else
    major=""; minor=""
    . "${_verfile}"
    if [ -n "${major}" ] && [ -n "${minor}" ]; then
      DSM_VER="${major}.${minor}"
    else
      echo "<3>[TCRP] all-modules: cannot build DSM_VER from ${_verfile} (major='${major}' minor='${minor}')" > /dev/kmsg
    fi
  fi
}

# Detect display-class PCI devices without depending on lspci's
# human-readable output format. The optional root is used by local tests.
has_display_pci_vendor() {
  _wanted_vendor="${1}"
  _pci_root="${2:-/sys/bus/pci/devices}"
  for _pci_dev in "${_pci_root}"/*; do
    [ -r "${_pci_dev}/vendor" ] && [ -r "${_pci_dev}/class" ] || continue
    _pci_vendor="$(cat "${_pci_dev}/vendor" 2>/dev/null)"
    [ "${_pci_vendor}" = "${_wanted_vendor}" ] || continue
    _pci_class="$(cat "${_pci_dev}/class" 2>/dev/null)"
    case "${_pci_class}" in
      0x03????) return 0 ;;
    esac
  done
  return 1
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

iml_restore_log() {
  _restore_msg="[TCRP][IML-RESTORE] $*"
  echo "${_restore_msg}"
  echo "<4>${_restore_msg}" > /dev/kmsg 2>/dev/null || true
}

read_version_field() {
  awk -F= -v key="$2" '$1 == key { gsub(/["\r]/, "", $2); print $2; exit }' "$1" 2>/dev/null
}

read_synoinfo_field() {
  awk -F= -v key="$2" '$1 == key { sub(/^[^=]*=/, ""); gsub(/["\r]/, ""); print; exit }' "$1" 2>/dev/null
}

# Restore only the original DSM module tree from the verified initrd hda1 archive.
restore_modules_from_hda1() {
  _archive=/addons/hda1.tgz
  _root=/tmpRoot
  _version_file="${_root}/etc.defaults/VERSION"
  _synoinfo="${_root}/etc.defaults/synoinfo.conf"
  _product="$(read_version_field "${_version_file}" productversion)"
  _build="$(read_version_field "${_version_file}" buildnumber)"
  _smallfix="$(read_version_field "${_version_file}" smallfixnumber)"
  _model="$(read_synoinfo_field "${_synoinfo}" upnpmodelname)"
  _unique="$(read_synoinfo_field "${_synoinfo}" unique)"
  _archive_tar="${_root}/tmp/.tcrp-hda1-restore.tar"
  _stage="${_root}/tmp/.tcrp-hda1-restore"
  _state="${_root}/tmp/.tcrp-hda1-restore.state"
  _target_link="$(chroot "${_root}" /usr/bin/readlink -f /lib/modules 2>/dev/null)"
  _target="${_root}${_target_link}"
  _rollback="${_target}.tcrp-rollback"
  _new="${_target}.tcrp-new"
  _list="${_root}/tmp/.tcrp-hda1-restore.list"
  _meta="/addons/hda1.meta"
  _hash="$(sha256sum "${_archive}" 2>/dev/null | awk '{print $1}')"

  iml_restore_log "START source=hda1 target=/tmpRoot/lib/modules dsm=${_product}-${_build}-${_smallfix}"
  if [ -z "${_product}" ] || [ -z "${_build}" ] || [ -z "${_smallfix}" ] || [ -z "${_model}" ] || [ -z "${_unique}" ]; then
    iml_restore_log "ERROR code=VERSION_UNKNOWN archive DSM/model identity unavailable; restore skipped; BAK fallback disabled"
    return 1
  fi

  # The archive's own VERSION and synoinfo values are authoritative. Never use model.dtb.
  mkdir -p "${_root}/tmp" || return 1
  cp -f "${_archive}" "${_archive_tar}" || return 1
  chroot "${_root}" /usr/bin/tar -xJOf /tmp/.tcrp-hda1-restore.tar etc.defaults/VERSION > "${_root}/tmp/.tcrp-hda1-VERSION" 2>/dev/null || {
    iml_restore_log "ERROR code=VERSION_UNKNOWN cannot read archive etc.defaults/VERSION; restore skipped; BAK fallback disabled"
    return 1
  }
  chroot "${_root}" /usr/bin/tar -xJOf /tmp/.tcrp-hda1-restore.tar etc.defaults/synoinfo.conf > "${_root}/tmp/.tcrp-hda1-synoinfo.conf" 2>/dev/null || {
    iml_restore_log "ERROR code=VERSION_UNKNOWN cannot read archive synoinfo.conf; restore skipped; BAK fallback disabled"
    return 1
  }
  _archive_product="$(read_version_field "${_root}/tmp/.tcrp-hda1-VERSION" productversion)"
  _archive_build="$(read_version_field "${_root}/tmp/.tcrp-hda1-VERSION" buildnumber)"
  _archive_smallfix="$(read_version_field "${_root}/tmp/.tcrp-hda1-VERSION" smallfixnumber)"
  _archive_model="$(read_synoinfo_field "${_root}/tmp/.tcrp-hda1-synoinfo.conf" upnpmodelname)"
  _archive_unique="$(read_synoinfo_field "${_root}/tmp/.tcrp-hda1-synoinfo.conf" unique)"
  if [ -z "${_archive_product}" ] || [ -z "${_archive_build}" ] || [ -z "${_archive_smallfix}" ] || [ -z "${_archive_model}" ] || [ -z "${_archive_unique}" ]; then
    iml_restore_log "ERROR code=VERSION_UNKNOWN archive DSM/model identity incomplete; restore skipped; BAK fallback disabled"
    rm -f "${_archive_tar}"
    return 1
  fi
  if [ "${_product}-${_build}-${_model}-${_unique}" != "${_archive_product}-${_archive_build}-${_archive_model}-${_archive_unique}" ] || [ "${_archive_smallfix}" != "0" ]; then
    iml_restore_log "ERROR code=VERSION_MISMATCH installed=${_product}-${_build}-${_smallfix}-${_model}-${_unique} base=${_archive_product}-${_archive_build}-${_archive_smallfix}-${_archive_model}-${_archive_unique}; restore skipped; BAK fallback disabled"
    rm -f "${_archive_tar}"
    return 1
  fi
  case "${_smallfix}" in ''|*[!0-9]*)
    iml_restore_log "ERROR code=VERSION_UNKNOWN invalid installed smallfixnumber '${_smallfix}'; restore skipped; BAK fallback disabled"
    rm -f "${_archive_tar}"
    return 1
  esac
  # Resolve /lib/modules inside DSM and reject paths outside its supported locations.
  case "${_target_link}" in /usr/lib/modules|/lib/modules) ;; *)
    iml_restore_log "ERROR stage=target invalid DSM /lib/modules target '${_target_link}'"
    rm -f "${_archive_tar}"
    return 1
  esac
  _bundle="/addons/hda1-smallfix"
  _manifest="${_bundle}/manifest"
  if [ ! -f "${_manifest}" ] || ! grep -qx "base=${_archive_product}-${_archive_build}" "${_manifest}" || \
     ! grep -qx "platform=${TARGET_PLATFORM}" "${_manifest}" || \
     ! grep -qx "model=${_archive_model}" "${_manifest}" || \
     ! grep -qx "unique=${_archive_unique}" "${_manifest}" || \
     ! grep -qx "base_sha256=${_hash}" "${_manifest}"; then
    iml_restore_log "ERROR code=SMALLFIX_BUNDLE_MISSING smallfix manifest identity missing or mismatched; restore skipped; BAK fallback disabled"
    rm -f "${_archive_tar}"
    return 1
  fi
  [ -n "${_hash}" ] || { iml_restore_log "ERROR stage=hash sha256sum failed"; rm -f "${_archive_tar}"; return 1; }
  rm -rf "${_stage}" "${_new}"
  mkdir -p "${_stage}" "${_new}" || { iml_restore_log "ERROR stage=prepare mkdir failed"; return 1; }
  _applied_updates="none"
  if [ "${_smallfix}" -gt 0 ]; then
    _layer="${_bundle}/U${_smallfix}.tar"
    _expected_layer_hash="$(awk -v n="${_smallfix}" '$1 == ("update=" n) {sub(/^sha256=/, "", $2); print $2; exit}' "${_manifest}")"
    _actual_layer_hash="$(sha256sum "${_layer}" 2>/dev/null | awk '{print $1}')"
    if [ -z "${_expected_layer_hash}" ] || [ "${_actual_layer_hash}" != "${_expected_layer_hash}" ]; then
      iml_restore_log "ERROR code=SMALLFIX_SNAPSHOT_MISSING exact U${_smallfix} snapshot missing or SHA-256 mismatch; restore skipped; BAK fallback disabled"
      rm -f "${_archive_tar}"
      return 1
    fi
    _layer_listing="${_root}/tmp/.tcrp-hda1-U${_smallfix}.list"
    tar -tf "${_layer}" > "${_layer_listing}" 2>/dev/null || { iml_restore_log "ERROR stage=snapshot U${_smallfix} cannot be listed"; return 1; }
    if ! awk '{p=$0; sub(/^\.\//,"",p); if (p !~ /^usr\/lib\/modules(\/|$)/ || p ~ /(^|\/)\.\.(\/|$)/) exit 1}' "${_layer_listing}"; then
      iml_restore_log "ERROR stage=snapshot U${_smallfix} contains an unsafe or out-of-scope path"
      rm -f "${_archive_tar}" "${_layer_listing}"
      return 1
    fi
    cp -f "${_layer}" "${_root}/tmp/.tcrp-hda1-U${_smallfix}.tar" || return 1
    chroot "${_root}" /usr/bin/tar -xf "/tmp/.tcrp-hda1-U${_smallfix}.tar" -C /tmp/.tcrp-hda1-restore 2>/dev/null || {
      iml_restore_log "ERROR stage=snapshot exact U${_smallfix} extraction failed"
      rm -f "${_archive_tar}" "${_layer_listing}"
      return 1
    }
    [ -d "${_stage}/usr/lib/modules" ] || { iml_restore_log "ERROR stage=snapshot U${_smallfix} module tree missing"; return 1; }
    cp -a "${_stage}/usr/lib/modules/." "${_new}/" || return 1
    _applied_updates="U${_smallfix}"
  else
    chroot "${_root}" /usr/bin/tar -tJf /tmp/.tcrp-hda1-restore.tar > "${_list}" 2>/dev/null || {
      iml_restore_log "ERROR stage=archive archive listing failed"
      rm -f "${_archive_tar}"
      return 1
    }
    if awk '{p=$0; sub(/^\.\//,"",p); if (p ~ /^\// || p ~ /(^|\/)\.\.(\/|$)/) exit 1}' "${_list}"; then :; else
      iml_restore_log "ERROR stage=archive unsafe archive path"
      rm -f "${_archive_tar}" "${_list}"
      return 1
    fi
    awk '{p=$0; sub(/^\.\//,"",p); if (p ~ /^usr\/lib\/modules(\/|$)/ || p ~ /^lib\/modules(\/|$)/) print $0}' "${_list}" > "${_root}/tmp/.tcrp-hda1-modules.list"
    [ -s "${_root}/tmp/.tcrp-hda1-modules.list" ] || { iml_restore_log "ERROR stage=archive no module tree in base hda1"; return 1; }
    cp "${_root}/tmp/.tcrp-hda1-modules.list" "${_root}/tmp/.tcrp-hda1-extract.list" || return 1
    chroot "${_root}" /usr/bin/tar -xJf /tmp/.tcrp-hda1-restore.tar -C /tmp/.tcrp-hda1-restore -T /tmp/.tcrp-hda1-extract.list 2>/dev/null || {
      iml_restore_log "ERROR stage=extract base hda1 module extraction failed"
      rm -f "${_archive_tar}"
      return 1
    }
    if [ -d "${_stage}/usr/lib/modules" ]; then
      cp -a "${_stage}/usr/lib/modules/." "${_new}/" || return 1
    elif [ -d "${_stage}/lib/modules" ]; then
      cp -a "${_stage}/lib/modules/." "${_new}/" || return 1
    else
      iml_restore_log "ERROR stage=extract base module tree missing"
      return 1
    fi
  fi
  [ -n "$(ls -A "${_new}" 2>/dev/null)" ] || { iml_restore_log "ERROR stage=snapshot selected module tree empty"; return 1; }

  # Recover interrupted previous swaps before starting another replacement.
  if [ -f "${_state}" ]; then
    if [ -d "${_rollback}" ]; then
      rm -rf "${_target}"
      mv "${_rollback}" "${_target}" || {
        iml_restore_log "ERROR stage=recovery previous swap rollback failed"
        return 1
      }
      iml_restore_log "INFO stage=recovery restored modules after interrupted prior swap"
    fi
    rm -f "${_state}"
  fi
  printf '%s\n' prepared > "${_state}" || return 1
  if [ -d "${_target}" ]; then mv "${_target}" "${_rollback}" || { rm -f "${_state}"; return 1; }; fi
  printf '%s\n' old-moved > "${_state}" || return 1
  if ! mv "${_new}" "${_target}"; then
    [ -d "${_rollback}" ] && mv "${_rollback}" "${_target}"
    iml_restore_log "ERROR stage=replace install failed; rollback attempted"
    return 1
  fi
  printf '%s\n' installed > "${_state}" || return 1
  [ -f "${_root}/lib/modules/modules.order" ] || : > "${_root}/lib/modules/modules.order"
  [ -f "${_root}/lib/modules/modules.builtin" ] || : > "${_root}/lib/modules/modules.builtin"
  if ! chroot "${_root}" /sbin/depmod -a 2>/dev/null; then
    rm -rf "${_target}"
    [ -d "${_rollback}" ] && mv "${_rollback}" "${_target}"
    iml_restore_log "ERROR stage=depmod failed; rollback attempted"
    return 1
  fi
  rm -rf "${_rollback}" "${_stage}"
  rm -f "${_state}" "${_archive_tar}" "${_list}" "${_root}/tmp/.tcrp-hda1-modules.list" "${_root}/tmp/.tcrp-hda1-extract.list" "${_root}/tmp/.tcrp-hda1-VERSION" "${_root}/tmp/.tcrp-hda1-synoinfo.conf" "${_root}/tmp/.tcrp-hda1-U"*.tar "${_root}/tmp/.tcrp-hda1-U"*.list
  rm -f "${PML_MARKER}"
  iml_restore_log "SUCCESS source=hda1 target=/tmpRoot/lib/modules dsm=${_archive_product}-${_archive_build}-${_smallfix} model=${_archive_model} unique=${_archive_unique} applied_updates=${_applied_updates:-none} base_sha256=${_hash} depmod=complete"
  return 0
}

getvars

if [ "${1}" = "modules" ]; then
  echo "all-modules - ${1}"
  [ -f "/addons/pml_on" ] && echo "/addons/pml_on file exists PML METHOD" || echo "/addons/pml_on file not exists IML METHOD"

  if [ ! -f "/addons/pml_on" ]; then
    # 모듈팩 tgz 선택: 1) DSM_VER 정확 지정 <platform>-<DSM_VER>-<LINUX_VER>.tgz 우선
    #                  2) 실패 시 glob 폴백 - 단 '유효한 gzip'만 채택(손상본 invalid magic 회피)
    MODPACK=""
    _exact="/exts/all-modules/${TARGET_PLATFORM}-${DSM_VER}-${LINUX_VER}.tgz"
    if [ -n "${DSM_VER}" ] && [ -f "${_exact}" ] && gunzip -t "${_exact}" 2>/dev/null; then
      MODPACK="${_exact}"
    else
      for _cand in /exts/all-modules/*${TARGET_PLATFORM}*${LINUX_VER}.tgz; do
        [ -f "${_cand}" ] || continue
        if gunzip -t "${_cand}" 2>/dev/null; then
          MODPACK="${_cand}"; break
        fi
        echo "<4>[TCRP] all-modules: corrupt pack skipped (${_cand})" > /dev/kmsg
      done
    fi
    if [ -z "${MODPACK}" ]; then
      echo "<3>[TCRP] all-modules: no valid module pack (platform=${TARGET_PLATFORM} dsm=${DSM_VER} kver=${LINUX_VER}) - /lib/modules will be empty" > /dev/kmsg
    else
      echo "all-modules: extracting ${MODPACK}"
      if ! gunzip -c "${MODPACK}" | tar xf - -C /lib/modules/ 2>/dev/null; then
        echo "<3>[TCRP] all-modules: extraction FAILED (${MODPACK})" > /dev/kmsg
      fi
    fi

    # DRM 전용 팩(i915/amdgpu 등, <platform>-<DSM_VER>-<LINUX_VER>-drm.tgz)이
    # 별도로 배포된 조합이면 기본 모듈팩과 나란히 추가로 풀어준다.
    # 없는 조합(예: epyc7003ntb)에서는 조용히 skip - 에러 아님.
    DRMPACK=""
    _exact_drm="/exts/all-modules/${TARGET_PLATFORM}-${DSM_VER}-${LINUX_VER}-drm.tgz"
    if [ -n "${DSM_VER}" ] && [ -f "${_exact_drm}" ] && gunzip -t "${_exact_drm}" 2>/dev/null; then
      DRMPACK="${_exact_drm}"
    else
      for _cand in /exts/all-modules/*${TARGET_PLATFORM}*${LINUX_VER}-drm.tgz; do
        [ -f "${_cand}" ] || continue
        if gunzip -t "${_cand}" 2>/dev/null; then
          DRMPACK="${_cand}"; break
        fi
        echo "<4>[TCRP] all-modules: corrupt drm pack skipped (${_cand})" > /dev/kmsg
      done
    fi
    if [ -n "${DRMPACK}" ]; then
      echo "all-modules: extracting drm pack ${DRMPACK}"
      if ! gunzip -c "${DRMPACK}" | tar xf - -C /lib/modules/ 2>/dev/null; then
        echo "<3>[TCRP] all-modules: drm pack extraction FAILED (${DRMPACK})" > /dev/kmsg
      fi
    fi

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
    # Pre-load these with dependency resolution so DSM's later direct insmod
    # (SYNOLoadModules, no deps) finds them already loaded and skips them,
    # avoiding boot-time "Unknown symbol" on their providers.
    /usr/sbin/modprobe cpufreq_ondemand 2>/dev/null
    /usr/sbin/modprobe cpufreq_conservative 2>/dev/null
    /usr/sbin/modprobe i40e 2>/dev/null

    # i915 선제 적재:
    #  - 4.4.302: MSHELL@PeterSuh-Q3 서명 확인 후 Intel GPU 검출 시 적재
    #  - 5.10.55: 서명 확인 없이 Intel GPU 검출 시 적재
    if [ -f /lib/modules/i915.ko ]; then
      I915_OK=0
      case "${LINUX_VER}" in
        4.4.302)
          if grep -qa "MSHELL@PeterSuh-Q3" /lib/modules/i915.ko; then
            I915_OK=1
          else
            echo "all-modules: i915.ko MSHELL signature not found - skip"
          fi
          ;;
        5.10.55)
          I915_OK=1
          ;;
      esac
      if [ "${I915_OK}" = "1" ]; then
        if has_display_pci_vendor "0x8086"; then
          echo "all-modules: Intel GPU detected (${LINUX_VER}) - loading i915"
          /usr/sbin/modprobe i915 && echo "i915 loaded OK" || echo "i915 modprobe failed"
        else
          echo "all-modules: no Intel display-class PCI device found (vendor 8086)"
        fi
      fi
    fi

    # ddsml uses a static modules.alias.4.json and does not recognise amdgpu PCI IDs.
    # eudev auto-loads via dynamic /lib/modules/modules.alias generated by depmod above.
    # When running under ddsml, manually detect AMD VGA (PCI class 0300, vendor 1002)
    # and trigger modprobe so amdgpu loads even without eudev.
    if [ -f /lib/modules/amdgpu.ko ]; then
      if has_display_pci_vendor "0x1002"; then
        echo "all-modules: AMD GPU detected - loading amdgpu (ddsml compatibility)"
        /usr/sbin/modprobe amdgpu && echo "amdgpu loaded OK" || echo "amdgpu modprobe failed"
      else
        echo "all-modules: no AMD display-class PCI device found (vendor 1002)"
      fi
    fi
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
  META_FILE="${MODULES_DIR}.bak.meta"          # BAK 지문 (BAK 외부 보관)
  PML_MARKER="${MODULES_DIR}.pml_active"       # PML 오염 흔적 마커 (지문 기록)
  SRC_MODULES="/usr/lib/modules"

  # /bin/cp 사용 (initrd 네이티브, 의존성 없음)
  CP="/bin/cp"
  RM="/bin/rm"

  CURRENT_FP="$(get_dsm_fingerprint /tmpRoot)"
  SAVED_FP="$(cat "${META_FILE}" 2>/dev/null || true)"
  MARKER_FP="$(cat "${PML_MARKER}" 2>/dev/null || true)"

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

    # PML 오염 흔적 마커 — IML 부팅 시 이 파일이 있으면 복원 트리거
    echo "${CURRENT_FP}" > "${PML_MARKER}"
    echo "PML pollution marker written: ${CURRENT_FP}"

    echo "modules copy done."
    [ -f /tmpRoot/lib/modules/modules.order ]   || : > /tmpRoot/lib/modules/modules.order
    [ -f /tmpRoot/lib/modules/modules.builtin ] || : > /tmpRoot/lib/modules/modules.builtin
    echo "Rebuilding module dependencies in /tmpRoot..."
    chroot /tmpRoot /sbin/depmod -a 2>/dev/null || echo "<3>[TCRP] WARNING: chroot depmod failed" > /dev/kmsg

  else
    if [ -f "/addons/hda1.tgz" ]; then
      # hda1 존재 시 버전 확인 실패는 BAK로 우회하지 않는다.
      restore_modules_from_hda1 || true
    else
      iml_restore_log "INFO source=BAK reason=hda1 archive absent"
      # IML 모드: PML 오염이 "확실한" 경우만 복원
      # 조건 3중:
    #   1) PML 마커 존재 (= 직전 부팅 중 한 번이라도 PML 오버레이 있었음)
    #   2) 마커 지문 == 현재 지문 (= 같은 플랫폼/DSM에서 발생한 오염)
    #   3) BAK 지문 == 현재 지문 (= BAK가 현재 DSM에 유효)
    # 셋 다 만족할 때만 복원, 아니면 rootfs 불변
    if [ -f "${PML_MARKER}" ] \
       && [ "${MARKER_FP}" = "${CURRENT_FP}" ] \
       && [ -d "${MODULES_BAK}" ] && [ -n "$(ls ${MODULES_BAK}/ 2>/dev/null)" ] \
       && [ "${SAVED_FP}" = "${CURRENT_FP}" ]; then
        echo "IML mode: PML pollution confirmed (marker=${MARKER_FP}) - restoring"
        # 이전 오염본 1개 롤링 보존
        ${RM} -rf "${MODULES_DIR}.polluted.prev" 2>/dev/null
        /bin/mv "${MODULES_DIR}" "${MODULES_DIR}.polluted.prev" 2>/dev/null
        ${CP} -rpf "${MODULES_BAK}" "${MODULES_DIR}" \
            || { echo "ERROR: IML restore failed!"; exit 1; }
        # 마커 제거 — 일회성 복원 (다음 IML 부팅에서 재실행 방지)
        ${RM} -f "${PML_MARKER}"
        echo "IML restore done, PML marker cleared."
        [ -f /tmpRoot/lib/modules/modules.order ]   || : > /tmpRoot/lib/modules/modules.order
        [ -f /tmpRoot/lib/modules/modules.builtin ] || : > /tmpRoot/lib/modules/modules.builtin
        if chroot /tmpRoot /sbin/depmod -a 2>/dev/null; then
            iml_restore_log "SUCCESS source=BAK target=/tmpRoot/lib/modules dsm=${CURRENT_FP} depmod=complete"
        else
            iml_restore_log "ERROR source=BAK stage=depmod failed after restore"
        fi
    elif [ -f "${PML_MARKER}" ] && [ "${MARKER_FP}" != "${CURRENT_FP}" ]; then
        echo "<4>[TCRP] IML mode: PML marker fingerprint mismatch (marker='${MARKER_FP}' current='${CURRENT_FP}') - leave rootfs intact" > /dev/kmsg
    elif [ -f "${PML_MARKER}" ] && [ "${SAVED_FP}" != "${CURRENT_FP}" ]; then
        echo "<4>[TCRP] IML mode: BAK fingerprint mismatch (saved='${SAVED_FP}' current='${CURRENT_FP}') - leave rootfs intact" > /dev/kmsg
    else
        echo "IML mode: no PML pollution evidence - nothing to restore"
      fi
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
