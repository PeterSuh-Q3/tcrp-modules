#!/bin/sh
#
# aeudev - MSHELL Manager package bootstrapper.
# The loader build places the verified SPK in /addons. This addon injects an
# rc.d hook while /tmpRoot is mounted; synopkg runs after DSM starts.

SPK_NAME="MshellManager-x86_64-1.0.0.spk"

[ "$1" = "late" ] || exit 0

TR="${TMPROOT:-/tmpRoot}"
[ -d "${TR}/usr" ] || { echo "aeudev: ${TR} is unavailable" >&2; exit 0; }

RCD="${TR}/usr/local/etc/rc.d"
mkdir -p "${RCD}"
cp -f "/addons/${SPK_NAME}" "${RCD}/${SPK_NAME}" 2>/dev/null || true

cat > "${RCD}/S99mshell-manager-install.sh" <<'RC'
#!/bin/sh
# Installed by the loader's aeudev addon. Runs after DSM is operational.

PKG="MshellManager"
SPK="/usr/local/etc/rc.d/MshellManager-x86_64-1.0.0.spk"
SHA="c4646c62a14e58773cb204a757af2fe33ff14665cf71ae1a499da94dc830a0d9"
URL="https://raw.githubusercontent.com/PeterSuh-Q3/tinycore-redpill/alpine-redpill/tools/MshellManager-x86_64-1.0.0.spk"
LOG="/var/log/mshell-manager-install.log"
SYNOPKG="/usr/syno/bin/synopkg"

log() { echo "$(date '+%F %T') mshell-manager: $*" >> "${LOG}"; }

[ -x "${SYNOPKG}" ] || { log "synopkg is not ready; retrying next boot"; exit 0; }
if [ -d "/var/packages/${PKG}" ] || "${SYNOPKG}" status "${PKG}" >/dev/null 2>&1; then
  log "${PKG} is already installed"
  rm -f "${SPK}" "$0"
  exit 0
fi

if [ ! -s "${SPK}" ]; then
  log "cached SPK is absent; downloading public release asset"
  curl -kfL --retry 3 --connect-timeout 20 "${URL}" -o "${SPK}.tmp" \
    && mv -f "${SPK}.tmp" "${SPK}" || { rm -f "${SPK}.tmp"; log "download failed; retrying next boot"; exit 0; }
fi

if command -v sha256sum >/dev/null 2>&1; then
  GOT="$(sha256sum "${SPK}" | awk '{print $1}')"
  [ "${GOT}" = "${SHA}" ] || { log "checksum mismatch; discarding SPK"; rm -f "${SPK}"; exit 0; }
fi

log "installing ${PKG}"
if "${SYNOPKG}" install "${SPK}" >> "${LOG}" 2>&1; then
  log "installation completed"
  rm -f "${SPK}" "$0"
else
  log "installation failed; retrying next boot"
fi
RC
chmod 755 "${RCD}/S99mshell-manager-install.sh"
echo "aeudev: queued MSHELL Manager installation via DSM rc.d"
exit 0
