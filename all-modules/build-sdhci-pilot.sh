#!/usr/bin/env bash
set -euo pipefail

# Build only the SDHCI module family from an extracted Synology GPL source
# tree.  By default, the first ../src-* directory is used; set SRC_DIR when
# more than one source tree exists.
#
# Example (DSM 7.4 / epyc7002):
#   SRC_DIR=../src-epyc7002-7.4 \
#   DSM_CONFIG=../runtime/.config \
#   MODULE_SYMVERS=../runtime/Module.symvers \
#   KREL=5.10.55+ \
#   ./build-sdhci-pilot.sh
#
# The config and Module.symvers must come from the same installed DSM build.
# A Synology platform config alone is insufficient when CONFIG_MODVERSIONS=y.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM="${PLATFORM:-epyc7002}"
KREL="${KREL:-5.10.55+}"
SRC_DIR="${SRC_DIR:-}"
DSM_CONFIG="${DSM_CONFIG:-}"
MODULE_SYMVERS="${MODULE_SYMVERS:-}"
OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}/releases/${PLATFORM}-7.4-${KREL%+}-sdhci}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

if [ -z "${SRC_DIR}" ]; then
  mapfile -t source_candidates < <(find "${SCRIPT_DIR}/.." -maxdepth 1 -type d -name 'src-*' -print | sort)
  case "${#source_candidates[@]}" in
    0) die "No ../src-* source directory found. Set SRC_DIR explicitly." ;;
    1) SRC_DIR="${source_candidates[0]}" ;;
    *) die "Multiple ../src-* source directories found. Set SRC_DIR explicitly." ;;
  esac
fi

SRC_DIR="$(cd -- "${SRC_DIR}" && pwd)"
if [ -f "${SRC_DIR}/Makefile" ]; then
  KSRC="${SRC_DIR}"
else
  mapfile -t kernel_candidates < <(find "${SRC_DIR}" -maxdepth 2 -type f -name Makefile -path '*/linux-*/Makefile' -print | sort)
  [ "${#kernel_candidates[@]}" -eq 1 ] ||
    die "Cannot identify one linux-* source directory below ${SRC_DIR}."
  KSRC="$(dirname -- "${kernel_candidates[0]}")"
fi

[ -n "${DSM_CONFIG}" ] || die "DSM_CONFIG must point to the running DSM build's .config."
[ -f "${DSM_CONFIG}" ] || die "DSM_CONFIG does not exist: ${DSM_CONFIG}"
if [ -z "${MODULE_SYMVERS}" ]; then
  for candidate in "${SRC_DIR}/Module.symvers" "${SRC_DIR}/modules-only.symvers" \
                   "${KSRC}/Module.symvers" "${KSRC}/modules-only.symvers"; do
    if [ -f "${candidate}" ]; then
      MODULE_SYMVERS="${candidate}"
      break
    fi
  done
fi
[ -n "${MODULE_SYMVERS}" ] || die "MODULE_SYMVERS is required; no suitable file was found."
[ -f "${MODULE_SYMVERS}" ] || die "MODULE_SYMVERS does not exist: ${MODULE_SYMVERS}"

if ! grep -q '^CONFIG_MMC_SDHCI_PCI=m$' "${DSM_CONFIG}"; then
  die "DSM_CONFIG does not enable CONFIG_MMC_SDHCI_PCI as a module."
fi

BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sdhci-${PLATFORM}.XXXXXX")"
cleanup() {
  if [ -f "${BUILD_DIR}/Makefile.original" ]; then
    cp "${BUILD_DIR}/Makefile.original" "${KSRC}/Makefile"
  fi
  rm -rf "${BUILD_DIR}"
}
trap cleanup EXIT

cp "${DSM_CONFIG}" "${BUILD_DIR}/.config"
cp "${MODULE_SYMVERS}" "${BUILD_DIR}/Module.symvers"

if [[ "${KREL}" == *+ ]]; then
  cp "${KSRC}/Makefile" "${BUILD_DIR}/Makefile.original"
  sed -i.bak 's/^EXTRAVERSION.*/EXTRAVERSION = +/' "${KSRC}/Makefile"
  rm -f "${KSRC}/Makefile.bak"
fi

make -C "${KSRC}" O="${BUILD_DIR}" olddefconfig
make -C "${KSRC}" O="${BUILD_DIR}" prepare modules_prepare

# These directories produce cqhci.ko, sdhci.ko, sdhci-pci.ko, and Synology's
# sdhci-pci-data.ko together, so provider and consumer use one source/config.
make -C "${KSRC}" O="${BUILD_DIR}" -j"${JOBS}" M=drivers/mmc/core modules
make -C "${KSRC}" O="${BUILD_DIR}" -j"${JOBS}" M=drivers/mmc/host modules

stage="${BUILD_DIR}/stage"
mkdir -p "${stage}"
for module in cqhci sdhci sdhci-pci sdhci-pci-data; do
  module_path="$(find "${BUILD_DIR}/drivers/mmc" -type f -name "${module}.ko" -print -quit)"
  [ -n "${module_path}" ] || die "Expected ${module}.ko was not built."
  cp "${module_path}" "${stage}/"
done

if ! nm "${stage}/sdhci-pci-data.ko" | grep -q '[[:space:]]sdhci_pci_get_data$'; then
  die "sdhci-pci-data.ko does not export sdhci_pci_get_data."
fi
if ! modinfo -F vermagic "${stage}/sdhci-pci.ko" | grep -qx "${KREL} SMP mod_unload"; then
  die "sdhci-pci.ko vermagic does not match expected ${KREL} SMP mod_unload."
fi

mkdir -p "${OUT_DIR}"
tar -C "${stage}" -czf "${OUT_DIR}/sdhci-${PLATFORM}-${KREL}.tgz" \
  cqhci.ko sdhci.ko sdhci-pci.ko sdhci-pci-data.ko
sha256sum "${OUT_DIR}/sdhci-${PLATFORM}-${KREL}.tgz" \
  > "${OUT_DIR}/sdhci-${PLATFORM}-${KREL}.tgz.sha256"
echo "Created ${OUT_DIR}/sdhci-${PLATFORM}-${KREL}.tgz"
