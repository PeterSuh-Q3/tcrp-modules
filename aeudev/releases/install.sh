#!/bin/sh
#
# aeudev - MSHELL Manager package bootstrapper.
# The loader build supplies a verified SPK plus its release metadata in
# /addons.  This addon queues a DSM rc.d hook; synopkg is only usable after
# DSM has completed startup.

[ "$1" = "late" ] || exit 0

TR="${TMPROOT:-/tmpRoot}"
[ -d "${TR}/usr" ] || { echo "aeudev: ${TR} is unavailable" >&2; exit 0; }

SPK_SOURCE="$(find /addons -maxdepth 1 -type f -name 'MshellManager-x86_64-*.spk' -print -quit 2>/dev/null)"
META_SOURCE="/addons/mshell-manager.json"
[ -s "${SPK_SOURCE}" ] && [ -s "${META_SOURCE}" ] || {
  echo "aeudev: MSHELL Manager SPK or metadata is absent; skipped" >&2
  exit 0
}

RCD="${TR}/usr/local/etc/rc.d"
mkdir -p "${RCD}"
cp -f "${SPK_SOURCE}" "${RCD}/$(basename "${SPK_SOURCE}")"
cp -f "${META_SOURCE}" "${RCD}/mshell-manager.json"

cat > "${RCD}/S99mshell-manager-install.sh" <<'RC'
#!/bin/sh
# Installed by aeudev. Runs only after DSM is operational.

# DSM invokes rc.d scripts for both start and stop.  An update is a startup
# action only; running it while packages are shutting down can leave synopkg
# with the same transient state as an early-boot update.
[ "$1" = "start" ] || exit 0

PKG="MshellManager"
RCD="/usr/local/etc/rc.d"
META="${RCD}/mshell-manager.json"
LOG="/var/log/mshell-manager-install.log"
SYNOPKG="/usr/syno/bin/synopkg"

log() { echo "$(date '+%F %T') mshell-manager: $*" >> "${LOG}"; }
meta() {
  python3 - "$META" "$1" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        value = json.load(f)[sys.argv[2]]
    print(value if isinstance(value, str) else "")
except Exception:
    pass
PY
}
version_is_newer() {
  awk -v installed="$1" -v candidate="$2" '
    BEGIN {
      n=split(installed, a, "."); m=split(candidate, b, ".");
      max=(n>m?n:m);
      for (i=1; i<=max; i++) {
        x=(i in a ? a[i]+0 : 0); y=(i in b ? b[i]+0 : 0);
        if (y>x) exit 0;
        if (y<x) exit 1;
      }
      exit 1;
    }'
}
start_package() {
  "${SYNOPKG}" start "${PKG}" >> "${LOG}" 2>&1 && log "package started"
}
wait_for_package_manager() {
  # pkg-rclocal runs before DSM starts third-party package units in parallel.
  # Let that wave finish before asking synopkg to stop/replace this package.
  # The fixed delay also covers DSM versions where pkg-ready is already
  # active when its package-unit jobs are still queued.
  log "waiting for DSM package services to settle"
  sleep 30
}
install_with_retry() {
  attempt=1
  while [ "${attempt}" -le 8 ]; do
    result="$("${SYNOPKG}" install "${SPK}" 2>&1)"
    status=$?
    printf '%s\n' "${result}" >> "${LOG}"
    [ "${status}" -eq 0 ] && return 0

    # During boot synopkg returns 263 while the existing package's systemd
    # unit is activating/deactivating.  This condition is transient; retain
    # the verified payload and retry after package startup has progressed.
    if printf '%s' "${result}" | grep -Eq '"code":263|code.?263|activating/deactivating'; then
      log "synopkg is transitioning ${PKG} (attempt ${attempt}/8); retrying in 15 seconds"
      attempt=$((attempt + 1))
      sleep 15
      continue
    fi

    return "${status}"
  done
  return 1
}

[ -x "${SYNOPKG}" ] || { log "synopkg is not ready; retrying next boot"; exit 0; }
[ -s "${META}" ] || { log "release metadata is absent; retrying next boot"; exit 0; }

SPK_NAME="$(meta name)"
URL="$(meta url)"
SHA="$(meta sha256)"
TARGET_VERSION="$(printf '%s' "${SPK_NAME}" | sed -n 's/^MshellManager-x86_64-\([0-9][0-9.]*\)\.spk$/\1/p')"
SPK="${RCD}/${SPK_NAME}"

if ! echo "${SPK_NAME}" | grep -Eq '^MshellManager-x86_64-[0-9]+\.[0-9]+\.[0-9]+\.spk$' || \
   [ "${URL##*/}" != "${SPK_NAME}" ] || \
   ! echo "${SHA}" | grep -Eq '^[a-f0-9]{64}$'; then
  log "release metadata is invalid; retrying next boot"
  exit 0
fi

INSTALLED_VERSION="$("${SYNOPKG}" version "${PKG}" 2>/dev/null | tr -d '\r\n')"
if [ -n "${INSTALLED_VERSION}" ]; then
  if ! version_is_newer "${INSTALLED_VERSION}" "${TARGET_VERSION}"; then
    log "${PKG} ${INSTALLED_VERSION} is current; ensuring it is started"
    start_package && rm -f "${SPK}" "${META}" "$0"
    exit 0
  fi
  log "upgrading ${PKG} from ${INSTALLED_VERSION} to ${TARGET_VERSION}"
fi

if [ ! -s "${SPK}" ]; then
  log "cached SPK is absent; downloading ${TARGET_VERSION}"
  curl -kfL --retry 3 --connect-timeout 20 "${URL}" -o "${SPK}" || {
    rm -f "${SPK}"; log "download failed; retrying next boot"; exit 0;
  }
fi

GOT="$(sha256sum "${SPK}" 2>/dev/null | awk '{print $1}')"
[ "${GOT}" = "${SHA}" ] || {
  log "checksum mismatch; discarding SPK"; rm -f "${SPK}"; exit 0;
}

wait_for_package_manager
log "installing ${PKG} ${TARGET_VERSION}"
if install_with_retry; then
  log "installation completed"
  start_package && rm -f "${SPK}" "${META}" "$0"
else
  log "installation failed; retrying next boot"
fi
RC
chmod 755 "${RCD}/S99mshell-manager-install.sh"
echo "aeudev: queued MSHELL Manager installation/update via DSM rc.d"
exit 0
