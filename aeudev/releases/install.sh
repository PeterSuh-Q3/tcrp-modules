#!/bin/sh
# aeudev queues DSM post-boot package installers from pinned metadata only.
# Large SPK payloads are downloaded later to a mounted DSM volume.
[ "$1" = late ] || exit 0

TR="${TMPROOT:-/tmpRoot}"
[ -d "${TR}/usr" ] || { echo "aeudev: ${TR} is unavailable" >&2; exit 0; }
RCD="${TR}/usr/local/etc/rc.d"
LIBEXEC="${TR}/usr/local/libexec"
ADDONS_ROOT="${AEUDEV_ADDONS_ROOT:-/addons}"
mkdir -p "${RCD}" "${LIBEXEC}"

# Remove stale payloads and old hooks from earlier aeudev versions. The DSM
# package manager remains the only component that installs/uninstalls SPKs.
rm -f "${RCD}/S99mshell-manager-install.sh" \
      "${RCD}/S99synosmartinfo-install.sh" \
      "${RCD}/S99amdgpu-packages-install.sh" \
      "${RCD}/S99amdgpu-runtime-install.sh" \
      "${RCD}/mshell-postboot-spk-install.sh" \
      "${RCD}/mshell-manager.json" "${RCD}/synosmartinfo.json" \
      "${RCD}/amdgpu-driver.json" "${RCD}"/MshellManager-x86_64-*.spk \
      "${RCD}"/mshellmanager-x86_64-*.spk \
      "${RCD}"/Synosmartinfo-x86_64-*.spk \
      "${RCD}"/syno-amdgpu-runtime-*.spk \
      "${RCD}/S99intel-gpu-top-install.sh" \
      "${RCD}/S99amdgpu-packages-install.sh" \
      "${RCD}/amdgpu-top.json" "${RCD}/intel-gpu-top.json" \
      "${RCD}"/syno-amdgpu-top-*.spk "${RCD}"/syno-intel-gpu-top-*.spk

SELF_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)"
HELPER_SOURCE="${SELF_DIR}/postboot-spk-install.sh"
if [ -s "${HELPER_SOURCE}" ]; then
  cp -f "${HELPER_SOURCE}" "${LIBEXEC}/mshell-postboot-spk-install.sh"
  chmod 755 "${LIBEXEC}/mshell-postboot-spk-install.sh"
else
  echo "aeudev: post-boot installer helper is missing; hooks will not be queued" >&2
  exit 0
fi

queue_package() {
  meta_name="$1" hook_name="$2" kind="$3"
      source="${ADDONS_ROOT}/${meta_name}"
  [ -s "${source}" ] || { echo "aeudev: ${meta_name} absent; package skipped" >&2; return 0; }
  cp -f "${source}" "${RCD}/${meta_name}" || return 1
  cat > "${RCD}/${hook_name}" <<EOF
#!/bin/sh
[ "\$1" = "start" ] || exit 0
exec /usr/local/libexec/mshell-postboot-spk-install.sh "${kind}" \
  "/usr/local/etc/rc.d/${meta_name}" "\$0" "\$1"
EOF
  chmod 755 "${RCD}/${hook_name}"
  echo "aeudev: queued ${kind} post-boot installer from pinned metadata"
}

queue_package mshell-manager.json S99mshell-manager-install.sh manager
queue_package synosmartinfo.json S99synosmartinfo-install.sh smartinfo
queue_package amdgpu-driver.json S99amdgpu-runtime-install.sh amdgpu
exit 0
