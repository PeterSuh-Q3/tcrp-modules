#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
INSTALLER="${ROOT_DIR}/aeudev/releases/install.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT HUP INT TERM
mkdir -p "${TMP}/addons" "${TMP}/dsm/usr" "${TMP}/dsm/volume1" \
  "${TMP}/dsm/var/packages" "${TMP}/bin"

PAYLOAD="${TMP}/payload.spk"
printf 'mock signed package payload\n' > "${PAYLOAD}"
SIZE="$(wc -c < "${PAYLOAD}" | tr -d ' ')"
SHA="$(sha256sum "${PAYLOAD}" | awk '{print $1}')"

write_meta() {
  file="$1" name="$2" id="$3" version="$4" url="$5" extra="${6:-}"
  printf '{"name":"%s","package_id":"%s","version":"%s","url":"%s","size":%s,"sha256":"%s"%s}\n' \
    "${name}" "${id}" "${version}" "${url}" "${SIZE}" "${SHA}" "${extra}" > "${file}"
}
write_meta "${TMP}/addons/mshell-manager.json" mshellmanager-x86_64-1.5.1.spk mshellmanager 1.5.1 https://example.invalid/mshellmanager-x86_64-1.5.1.spk
write_meta "${TMP}/addons/synosmartinfo.json" Synosmartinfo-x86_64-2.0.8.spk Synosmartinfo 2.0.8 https://example.invalid/Synosmartinfo-x86_64-2.0.8.spk
write_meta "${TMP}/addons/amdgpu-driver.json" syno-amdgpu-runtime-0.5.4-7.4-x86_64-kernel5.10.55.spk syno-amdgpu-runtime 0.5.4 https://example.invalid/syno-amdgpu-runtime-0.5.4-7.4-x86_64-kernel5.10.55.spk ',"platform":"epyc7002","kernel":"5.10.55","dsm_version":"7.4.1"'

TMPROOT="${TMP}/dsm" AEUDEV_ADDONS_ROOT="${TMP}/addons" sh "${INSTALLER}" late
RCD="${TMP}/dsm/usr/local/etc/rc.d"
LIBEXEC="${TMP}/dsm/usr/local/libexec/mshell-postboot-spk-install.sh"
[ -x "${LIBEXEC}" ]
[ -x "${RCD}/S99mshell-manager-install.sh" ]
[ -x "${RCD}/S99synosmartinfo-install.sh" ]
[ -x "${RCD}/S99amdgpu-runtime-install.sh" ]
[ -s "${RCD}/mshell-manager.json" ]
[ -s "${RCD}/synosmartinfo.json" ]
[ -s "${RCD}/amdgpu-driver.json" ]
for generated in "${LIBEXEC}" "${RCD}/S99mshell-manager-install.sh" \
  "${RCD}/S99synosmartinfo-install.sh" "${RCD}/S99amdgpu-runtime-install.sh"; do
  sh -n "${generated}"
done
if find "${RCD}" -type f -name '*.spk' | grep -q .; then
  echo "unexpected SPK payload copied into DSM root staging" >&2
  exit 1
fi
# Running the late hook twice must produce the same independent jobs without
# ever copying a payload into the DSM system tree.
TMPROOT="${TMP}/dsm" AEUDEV_ADDONS_ROOT="${TMP}/addons" sh "${INSTALLER}" late >/dev/null
[ -x "${RCD}/S99mshell-manager-install.sh" ] && [ -x "${RCD}/S99synosmartinfo-install.sh" ]

cat > "${TMP}/bin/curl" <<'MOCK_CURL'
#!/bin/sh
echo "$*" >> "${MOCK_CURL_LOG}"
[ "${MOCK_CURL_FAIL:-0}" = 0 ] || exit 22
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then shift; cp "${MOCK_PAYLOAD}" "$1"; exit $?; fi
  shift
done
exit 2
MOCK_CURL
cat > "${TMP}/bin/synopkg" <<'MOCK_SYNOPKG'
#!/bin/sh
echo "$*" >> "${MOCK_SYNOPKG_LOG}"
case "$1" in
  version)
    [ "${2:-}" != MshellManager ] || [ "${MOCK_LEGACY_INSTALLED:-0}" = 1 ] || exit 1
    [ -z "${MOCK_INSTALLED_VERSION:-}" ] || { printf '%s\n' "${MOCK_INSTALLED_VERSION}"; exit 0; }
    [ "${2:-}" = MshellManager ] && printf '1.0.0\n'
    exit 0 ;;
  install) [ "${MOCK_INSTALL_FAIL:-0}" = 0 ] && exit 0; echo '{"code":263}'; exit 1 ;;
  start|stop|uninstall) exit 0 ;;
esac
exit 0
MOCK_SYNOPKG
chmod +x "${TMP}/bin/curl" "${TMP}/bin/synopkg"
: > "${TMP}/synopkg.log"
: > "${TMP}/curl.log"

run_hook() (
  kind="$1" meta="$2" hook="$3"
  installed="${4:-}" legacy="${5:-0}" curl_fail="${6:-0}" install_fail="${7:-0}"
  synopkg_bin="${TMP}/bin/synopkg"
  [ "${8:-0}" = 0 ] || synopkg_bin="${TMP}/bin/no-synopkg"
  PATH="${TMP}/bin:${PATH}" MSHELL_SPK_TEST_ROOT="${TMP}/dsm" \
    MSHELL_SYNPKG_BIN="${synopkg_bin}" MSHELL_SPK_RETRY_DELAY=0 \
    MSHELL_SPK_SETTLE_DELAY=0 MOCK_PAYLOAD="${PAYLOAD}" \
    MOCK_SYNOPKG_LOG="${TMP}/synopkg.log" MOCK_CURL_LOG="${TMP}/curl.log" \
    MOCK_CURL_FAIL="${curl_fail}" MOCK_INSTALL_FAIL="${install_fail}" \
    MOCK_INSTALLED_VERSION="${installed}" MOCK_LEGACY_INSTALLED="${legacy}" \
    "$LIBEXEC" "$kind" "$meta" "$hook" start
)

# If DSM's package manager is not available yet, keep metadata/hook pending and
# do not attempt a download or installation.
before="$(grep -c '^install ' "${TMP}/synopkg.log" || true)"
run_hook manager /usr/local/etc/rc.d/mshell-manager.json /usr/local/etc/rc.d/S99mshell-manager-install.sh '' 0 0 0 1
after="$(grep -c '^install ' "${TMP}/synopkg.log" || true)"
[ "${before}" = "${after}" ] && [ -s "${RCD}/mshell-manager.json" ]

# Successful post-boot fetch is verified and passed to synopkg from a volume.
run_hook manager /usr/local/etc/rc.d/mshell-manager.json /usr/local/etc/rc.d/S99mshell-manager-install.sh
grep -q '^install .*volume1/@tmp/mshell-spk-delivery/mshellmanager-x86_64-1.5.1.spk$' "${TMP}/synopkg.log"
[ ! -e "${RCD}/mshell-manager.json" ]
[ ! -e "${RCD}/S99mshell-manager-install.sh" ]
[ ! -e "${TMP}/dsm/volume1/@tmp/mshell-spk-delivery/mshellmanager-x86_64-1.5.1.spk" ]

# An already-current Manager is not re-downloaded, and its legacy package ID
# is removed only after the replacement is confirmed current.
write_meta "${RCD}/mshell-manager.json" mshellmanager-x86_64-1.5.1.spk mshellmanager 1.5.1 https://example.invalid/mshellmanager-x86_64-1.5.1.spk
touch "${RCD}/S99mshell-manager-install.sh"; chmod +x "${RCD}/S99mshell-manager-install.sh"
before_curl="$(wc -l < "${TMP}/curl.log" | tr -d ' ')"
run_hook manager /usr/local/etc/rc.d/mshell-manager.json /usr/local/etc/rc.d/S99mshell-manager-install.sh 1.5.1 1
after_curl="$(wc -l < "${TMP}/curl.log" | tr -d ' ')"
[ "${before_curl}" = "${after_curl}" ]
grep -q '^uninstall MshellManager$' "${TMP}/synopkg.log"
[ ! -e "${RCD}/mshell-manager.json" ]

# If DSM has no mounted volume, leave the pinned job for a later boot and do
# not hand any file to synopkg.
write_meta "${RCD}/mshell-manager.json" mshellmanager-x86_64-1.5.1.spk mshellmanager 1.5.1 https://example.invalid/mshellmanager-x86_64-1.5.1.spk
touch "${RCD}/S99mshell-manager-install.sh"
chmod +x "${RCD}/S99mshell-manager-install.sh"
mv "${TMP}/dsm/volume1" "${TMP}/dsm/offline-volume1"
before="$(grep -c '^install ' "${TMP}/synopkg.log" || true)"
run_hook manager /usr/local/etc/rc.d/mshell-manager.json /usr/local/etc/rc.d/S99mshell-manager-install.sh
after="$(grep -c '^install ' "${TMP}/synopkg.log" || true)"
[ "${before}" = "${after}" ]
[ -s "${RCD}/mshell-manager.json" ] && [ -x "${RCD}/S99mshell-manager-install.sh" ]
mv "${TMP}/dsm/offline-volume1" "${TMP}/dsm/volume1"

# Failed network delivery retains the job and never leaves a partial SPK.
run_hook manager /usr/local/etc/rc.d/mshell-manager.json /usr/local/etc/rc.d/S99mshell-manager-install.sh '' 0 1 0
[ -s "${RCD}/mshell-manager.json" ] && [ -x "${RCD}/S99mshell-manager-install.sh" ]
if find "${TMP}/dsm/volume1" -name '*.part' | grep -q .; then exit 1; fi

# A synopkg transient/failure retains the checksum-verified volume cache. The
# next run consumes that cache rather than redownloading the SPK.
before_curl="$(wc -l < "${TMP}/curl.log" | tr -d ' ')"
run_hook manager /usr/local/etc/rc.d/mshell-manager.json /usr/local/etc/rc.d/S99mshell-manager-install.sh '' 0 0 1
[ -s "${TMP}/dsm/volume1/@tmp/mshell-spk-delivery/mshellmanager-x86_64-1.5.1.spk" ]
after_curl="$(wc -l < "${TMP}/curl.log" | tr -d ' ')"
run_hook manager /usr/local/etc/rc.d/mshell-manager.json /usr/local/etc/rc.d/S99mshell-manager-install.sh
final_curl="$(wc -l < "${TMP}/curl.log" | tr -d ' ')"
[ "${after_curl}" = "${final_curl}" ]
[ ! -e "${RCD}/mshell-manager.json" ]

# AMD metadata is constrained to the supported K5 path, and successful
# installation explicitly asks DSM to start the runtime package.
run_hook amdgpu /usr/local/etc/rc.d/amdgpu-driver.json /usr/local/etc/rc.d/S99amdgpu-runtime-install.sh
grep -q '^install .*syno-amdgpu-runtime-0.5.4-7.4-x86_64-kernel5.10.55.spk$' "${TMP}/synopkg.log"
grep -q '^start syno-amdgpu-runtime$' "${TMP}/synopkg.log"

# A checksum error must never reach synopkg and must preserve metadata/hook for
# a later boot retry. Use a Smart Info manifest with a deliberately wrong hash.
write_meta "${RCD}/synosmartinfo.json" Synosmartinfo-x86_64-2.0.8.spk Synosmartinfo 2.0.8 https://example.invalid/Synosmartinfo-x86_64-2.0.8.spk
sed 's/"sha256":"[a-f0-9]*"/"sha256":"0000000000000000000000000000000000000000000000000000000000000000"/' \
  "${RCD}/synosmartinfo.json" > "${TMP}/bad.json"
cp "${TMP}/bad.json" "${RCD}/synosmartinfo.json"
before="$(grep -c '^install ' "${TMP}/synopkg.log" || true)"
run_hook smartinfo /usr/local/etc/rc.d/synosmartinfo.json /usr/local/etc/rc.d/S99synosmartinfo-install.sh
after="$(grep -c '^install ' "${TMP}/synopkg.log" || true)"
[ "${before}" = "${after}" ]
[ -s "${RCD}/synosmartinfo.json" ]
[ -x "${RCD}/S99synosmartinfo-install.sh" ]
if find "${TMP}/dsm/volume1" -name '*.part' | grep -q .; then exit 1; fi

# Valid Smart Info metadata installs through the same verified worker.
cp "${TMP}/addons/synosmartinfo.json" "${RCD}/synosmartinfo.json"
run_hook smartinfo /usr/local/etc/rc.d/synosmartinfo.json /usr/local/etc/rc.d/S99synosmartinfo-install.sh
grep -q '^install .*Synosmartinfo-x86_64-2.0.8.spk$' "${TMP}/synopkg.log"
[ ! -e "${RCD}/synosmartinfo.json" ]

# Unsupported AMD kernel is safely skipped without network or synopkg calls.
sed 's/5.10.55/4.4.302/g' "${TMP}/addons/amdgpu-driver.json" > "${TMP}/old-kernel.json"
cp "${TMP}/old-kernel.json" "${RCD}/amdgpu-driver.json"
before="$(wc -l < "${TMP}/synopkg.log")"
run_hook amdgpu /usr/local/etc/rc.d/amdgpu-driver.json /usr/local/etc/rc.d/S99amdgpu-runtime-install.sh
after="$(wc -l < "${TMP}/synopkg.log")"
[ "${before}" = "${after}" ]
[ ! -e "${RCD}/amdgpu-driver.json" ]

echo "post-boot SPK delivery tests passed"
