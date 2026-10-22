#!/bin/sh
# DSM-side installer for build-time-pinned SPK metadata. Payloads are kept on
# a mounted DSM volume, never in initrd-dsm, /tmp, or the system partition.
[ "$#" -ge 4 ] || exit 2
KIND="$1"; META="$2"; HOOK="$3"; ACTION="$4"
TEST_ROOT="${MSHELL_SPK_TEST_ROOT:-}"
prefix_path() { [ -n "${TEST_ROOT}" ] && printf '%s%s' "${TEST_ROOT}" "$1" || printf '%s' "$1"; }
case "${KIND}" in
  manager) PKG=mshellmanager; PREFIX=mshellmanager-x86_64; LOG="$(prefix_path /var/log/mshell-manager-install.log)" ;;
  smartinfo) PKG=Synosmartinfo; PREFIX=Synosmartinfo-x86_64; LOG="$(prefix_path /var/log/synosmartinfo-install.log)" ;;
  amdgpu) PKG=syno-amdgpu-runtime; PREFIX=syno-amdgpu-runtime; LOG="$(prefix_path /var/log/amdgpu-packages-install.log)" ;;
  *) exit 2 ;;
esac
log() { echo "$(date '+%F %T') ${KIND}: $*" >> "${LOG}"; }
mkdir -p "$(dirname "${LOG}")"
[ "${ACTION}" = stop ] && exit 0
[ "${ACTION}" = start ] || exit 0
SYNOPKG="${MSHELL_SYNPKG_BIN:-$(prefix_path /usr/syno/bin/synopkg)}"
[ -n "${TEST_ROOT}" ] && META="$(prefix_path "${META}")" && HOOK="$(prefix_path "${HOOK}")"
[ -s "${META}" ] || { log "pinned release metadata is missing; pending until next boot"; exit 0; }
meta() {
  python3 - "$META" "$1" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f: value=json.load(f).get(sys.argv[2], "")
    print(value if isinstance(value, (str, int)) else "")
except Exception: pass
PY
}
version_is_newer() {
  awk -v installed="$1" -v candidate="$2" 'BEGIN { n=split(installed,a,"."); m=split(candidate,b,"."); z=(n>m?n:m); for(i=1;i<=z;i++){x=(i in a?a[i]+0:0);y=(i in b?b[i]+0:0);if(y>x)exit 0;if(y<x)exit 1} exit 1 }'
}
cleanup() {
  rm -f "${META}" "${HOOK}" "${SPK:-}" "${PART:-}"
  [ -n "${NAME:-}" ] || return 0
  for volume in "${TEST_ROOT}"/volume[0-9]* /volume[0-9]*; do
    [ -d "${volume}" ] || continue
    volume_number=${volume##*/}; volume_number=${volume_number#volume}
    case "${volume_number}" in ''|*[!0-9]*) continue ;; esac
    rm -f "${volume}/@tmp/mshell-spk-delivery/${NAME}" \
      "${volume}/@tmp/mshell-spk-delivery/${NAME}.part"
  done
}
NAME="$(meta name)"; URL="$(meta url)"; SHA="$(meta sha256)"; SIZE="$(meta size)"; TARGET="$(meta version)"
if ! echo "${NAME}" | grep -Eq "^${PREFIX}-[A-Za-z0-9.+_-]+\.spk$" || \
   [ "${URL##*/}" != "${NAME}" ] || ! echo "${URL}" | grep -Eq '^https://[^[:space:]]+$' || \
   ! echo "${SHA}" | grep -Eq '^[a-f0-9]{64}$' || ! echo "${SIZE}" | grep -Eq '^[1-9][0-9]*$' || \
   ! echo "${TARGET}" | grep -Eq '^[0-9]+(\.[0-9]+){1,3}$'; then
  log "pinned metadata failed validation; pending until corrected"; exit 0
fi
if [ "${KIND}" = amdgpu ]; then
  PLATFORM="$(meta platform)"; KERNEL="$(meta kernel)"; DSM_VERSION="$(meta dsm_version)"
  JELLYFIN_X64_PLATFORMS='apollolake avoton braswell broadwell broadwellnk broadwellnkv2 broadwellntbap bromolow denverton epyc7002 geminilake geminilakenk grantley icelaked kvmx64 purley r1000 r1000nk v1000 v1000nk'
  case " ${JELLYFIN_X64_PLATFORMS} " in *" ${PLATFORM} "*) ;; *) log "AMD runtime platform ${PLATFORM} is unsupported; not installing"; cleanup; exit 0 ;; esac
  case "${DSM_VERSION}" in 7.4*) ;; *) log "AMD runtime DSM ${DSM_VERSION} is unsupported; not installing"; cleanup; exit 0 ;; esac
  case "${KERNEL}" in 5.10.55) ;; *) log "AMD runtime kernel ${KERNEL} is unsupported; not installing"; cleanup; exit 0 ;; esac
fi
ready_attempt=1
while [ "${ready_attempt}" -le 4 ]; do
  if [ -x "${SYNOPKG}" ] && [ -d "$(prefix_path /var/packages)" ]; then
    break
  fi
  log "DSM package manager/volume services are not ready (attempt ${ready_attempt}/4)"
  [ "${ready_attempt}" -lt 4 ] && sleep "${MSHELL_SPK_RETRY_DELAY:-20}"
  ready_attempt=$((ready_attempt + 1))
done
[ -x "${SYNOPKG}" ] && [ -d "$(prefix_path /var/packages)" ] || {
  log "synopkg or DSM package services are still unavailable; pending until next boot"; exit 0;
}
INSTALLED="$("${SYNOPKG}" version "${PKG}" 2>/dev/null | tr -d '\r\n')"
if [ -n "${INSTALLED}" ] && ! version_is_newer "${INSTALLED}" "${TARGET}"; then
  log "${PKG} ${INSTALLED} is current"
  if [ "${KIND}" = amdgpu ]; then "${SYNOPKG}" start "${PKG}" >> "${LOG}" 2>&1 || log "start failed; DSM package service can retry"; fi
  if [ "${KIND}" = manager ] && "${SYNOPKG}" version MshellManager >/dev/null 2>&1; then
    "${SYNOPKG}" stop MshellManager >> "${LOG}" 2>&1 || true
    "${SYNOPKG}" uninstall MshellManager >> "${LOG}" 2>&1 || { log "legacy package cleanup pending"; exit 0; }
  fi
  if [ "${KIND}" = manager ]; then
    if ! "${SYNOPKG}" start "${PKG}" >> "${LOG}" 2>&1; then
      log "start failed; installer hook retained for next boot retry"
      exit 0
    fi
    log "${PKG} start command succeeded"
  fi
  cleanup; exit 0
fi
download_volume() {
  expected_kb=$((SIZE / 1024 + 1)); required_kb=$((expected_kb * 2 + 131072))
  preferred=""
  if [ -z "${TEST_ROOT}" ]; then
    appstore_path="$(readlink -f /var/packages/@appstore 2>/dev/null)"
    case "${appstore_path}" in /volume[0-9]*/@appstore) preferred="${appstore_path%/@appstore}" ;; esac
  fi
  if [ -n "${preferred}" ]; then set -- "${preferred}"; else set -- "${TEST_ROOT}"/volume[0-9]* /volume[0-9]*; fi
  for volume do
    [ -d "${volume}" ] || continue
    volume_number=${volume##*/}; volume_number=${volume_number#volume}
    case "${volume_number}" in ''|*[!0-9]*) continue ;; esac
    if [ -n "${TEST_ROOT}" ]; then
      mounted=1
    elif awk -v target="${volume}" '$2 == target { found=1 } END { exit !found }' /proc/mounts; then
      mounted=1
    else
      mounted=0
    fi
    [ "${mounted}" = 1 ] || continue
    available=$(df -Pk "${volume}" 2>/dev/null | awk 'NR==2 {print $4}')
    case "${available}" in ''|*[!0-9]*) continue ;; esac
    [ "${available}" -ge "${required_kb}" ] || continue
    printf '%s\n' "${volume}"; return 0
  done
  return 1
}

# Readiness and network failures receive a bounded retry in this boot. The
# generated rc.d hook remains in place on every failure, so the next boot
# retries without blocking DSM startup indefinitely.
attempt=1
while [ "${attempt}" -le 3 ]; do
  if [ ! -d "$(prefix_path /var/packages)" ]; then
    log "DSM package services are not ready (attempt ${attempt}/3)"
  elif ! VOLUME="$(download_volume)"; then
    log "no mounted package volume has enough free space (attempt ${attempt}/3)"
  else
    CACHE="${VOLUME}/@tmp/mshell-spk-delivery"
    mkdir -p "${CACHE}" || log "cannot create cache on ${VOLUME}"
    SPK="${CACHE}/${NAME}"; PART="${SPK}.part"
    if [ -s "${SPK}" ] && [ "$(wc -c < "${SPK}" | tr -d ' ')" = "${SIZE}" ] && \
       [ "$(sha256sum "${SPK}" 2>/dev/null | awk '{print $1}')" = "${SHA}" ]; then
      log "verified cached package found on ${VOLUME}"; break
    fi
    rm -f "${PART}"
    log "downloading ${NAME} to mounted volume ${VOLUME} (attempt ${attempt}/3)"
    if curl --fail --location --silent --show-error --connect-timeout 20 --max-time 300 "${URL}" -o "${PART}"; then
      GOT_SIZE="$(wc -c < "${PART}" | tr -d ' ')"
      GOT_SHA="$(sha256sum "${PART}" 2>/dev/null | awk '{print $1}')"
      if [ "${GOT_SIZE}" = "${SIZE}" ] && [ "${GOT_SHA}" = "${SHA}" ]; then
        mv -f "${PART}" "${SPK}" || { log "atomic cache finalize failed"; rm -f "${PART}"; }
        [ -s "${SPK}" ] && break
      else
        log "download validation failed (size ${GOT_SIZE}/${SIZE}, sha ${GOT_SHA})"
        rm -f "${PART}" "${SPK}"
      fi
    else
      log "download failed; partial file discarded"; rm -f "${PART}"
    fi
  fi
  [ "${attempt}" -lt 3 ] && sleep "${MSHELL_SPK_RETRY_DELAY:-20}"
  attempt=$((attempt + 1))
done
[ -s "${SPK:-}" ] || { log "package remains pending; installer will retry next boot"; exit 0; }
if [ "$(wc -c < "${SPK}" | tr -d ' ')" != "${SIZE}" ] || [ "$(sha256sum "${SPK}" 2>/dev/null | awk '{print $1}')" != "${SHA}" ]; then
  log "cached package failed final validation; removed"; rm -f "${SPK}"; exit 0
fi

wait_attempt=1
log "allowing DSM package services to settle before synopkg install"
sleep "${MSHELL_SPK_SETTLE_DELAY:-30}"
while [ "${wait_attempt}" -le 8 ]; do
  result="$("${SYNOPKG}" install "${SPK}" 2>&1)"; status=$?
  printf '%s\n' "${result}" >> "${LOG}"
  [ "${status}" -eq 0 ] && break
  printf '%s' "${result}" | grep -Eq '"code":263|code.?263|activating/deactivating' || break
  log "synopkg transition (attempt ${wait_attempt}/8); retrying in 15 seconds"
  wait_attempt=$((wait_attempt + 1)); sleep "${MSHELL_SPK_RETRY_DELAY:-15}"
done
if [ "${status}" -ne 0 ]; then log "install failed; verified cache retained for next boot"; exit 0; fi
if [ "${KIND}" = manager ] && "${SYNOPKG}" version MshellManager >/dev/null 2>&1; then
  "${SYNOPKG}" stop MshellManager >> "${LOG}" 2>&1 || true
  "${SYNOPKG}" uninstall MshellManager >> "${LOG}" 2>&1 || { log "new package installed; legacy cleanup pending"; exit 0; }
fi
if [ "${KIND}" = manager ]; then
  if ! "${SYNOPKG}" start "${PKG}" >> "${LOG}" 2>&1; then
    log "installed but start failed; installer hook retained for next boot retry"
    exit 0
  fi
  log "${PKG} start command succeeded"
fi
if [ "${KIND}" = amdgpu ]; then "${SYNOPKG}" start "${PKG}" >> "${LOG}" 2>&1 || log "installed but start failed"; fi
log "${PKG} ${TARGET} installed successfully"
cleanup
exit 0
