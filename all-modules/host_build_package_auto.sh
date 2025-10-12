#!/usr/bin/env bash
set -euo pipefail

# USAGE
#export UPLOAD_TO_DSM=true
#export NAS_HOST=192.168.45.200
#export NAS_USER=admin2
#export NAS_PORT=22
#export NAS_OUT_DIR=/volume1/build
#export KERNEL_TXZ_URL="https://global.synologydownload.com/download/ToolChain/Synology%20NAS%20GPL%20Source/7.2-72806/epyc7002/linux-5.10.x.txz"
#bash ./host_build_package_auto.sh

### ===== 사용자 입력 =====
DSM_RUNTIME_TGZ="${DSM_RUNTIME_TGZ:-}"
PLATFORM="${PLATFORM:-epyc7002}"
KERNEL_TXZ_URL="${KERNEL_TXZ_URL:-https://global.synologydownload.com/.../epyc7002/linux-5.10.x.txz}"

UPLOAD_TO_DSM="${UPLOAD_TO_DSM:-false}"
NAS_HOST="${NAS_HOST:-192.168.45.200}"
NAS_USER="${NAS_USER:-admin2}"
NAS_PORT="${NAS_PORT:-22}"
NAS_OUT_DIR="${NAS_OUT_DIR:-/volume1/build}"
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=no}"
NAS_SSH="ssh ${SSH_OPTS} -p ${NAS_PORT} ${NAS_USER}@${NAS_HOST}"
NAS_SCP="scp ${SSH_OPTS} -P ${NAS_PORT}"

### ===== 준비물 설치 =====
sudo apt-get update
sudo apt-get install -y build-essential bc libssl-dev libncurses-dev curl xz-utils rsync kmod

WORK="$(mktemp -d)"
RUNTIME="${WORK}/runtime"
mkdir -p "${RUNTIME}"

### ===== DSM 런타임 번들 해제 및 KREL 결정 =====
KREL="${KREL:-}"
if [ -n "${DSM_RUNTIME_TGZ}" ]; then
  tar -xzf "${DSM_RUNTIME_TGZ}" -C "${RUNTIME}"
  if [ -f "${RUNTIME}/_manifest.txt" ]; then
    KREL="$(grep '^krel=' "${RUNTIME}/_manifest.txt" | cut -d= -f2-)"
  fi
fi

if [ -z "${KREL}" ]; then
  echo "NOTE: KREL not provided; trying to read from NAS via SSH..."
  KREL="$(${NAS_SSH} 'uname -r' | tr -d "\r")" || true
  [ -n "${KREL}" ] && echo "Auto-detected KREL=${KREL} from NAS"
fi

if [ -z "${KREL}" ]; then
  echo "ERROR: KREL(uname -r) is not set. Provide DSM runtime or set KREL manually."
  exit 1
fi
echo "KREL=${KREL}, PLATFORM=${PLATFORM}"

### ===== 커널 소스 다운로드 및 전개 =====
KROOT="${WORK}/kernel-src"
mkdir -p "${KROOT}"
curl -L --retry 3 -o "${KROOT}/linux-5.10.x.txz" "${KERNEL_TXZ_URL}"
tar -xJf "${KROOT}/linux-5.10.x.txz" -C "${KROOT}"
KSRC="${KROOT}/linux-5.10.x"

### ===== .config 설정 =====
if [ -f "${RUNTIME}/.config" ]; then
  cp -f "${RUNTIME}/.config" "${KSRC}/.config"
  echo "Using runtime .config"
elif [ -f "${KSRC}/synology/synoconfigs/${PLATFORM}" ]; then
  cp -f "${KSRC}/synology/synoconfigs/${PLATFORM}" "${KSRC}/.config"
  echo "Using synology/synoconfigs/${PLATFORM} as .config"
elif [ -f "${KSRC}/SynoBuildConf/_kconfig" ]; then
  echo "Fallback to SynoBuildConf/_kconfig via KCONFIG_ALLCONFIG"
  ( cd "${KSRC}" && make mrproper )
  KCONFIG_ALLCONFIG="${KSRC}/SynoBuildConf/_kconfig" \
  make -C "${KSRC}" ARCH=x86_64 alldefconfig
  yes "" | make -C "${KSRC}" ARCH=x86_64 olddefconfig
else
  echo "ERROR: No valid .config source found."
  exit 1
fi

### ===== EXTRAVERSION 설정 =====
if [[ "${KREL}" == *"+" ]]; then
  sed -i 's/^EXTRAVERSION.*/EXTRAVERSION = +/' "${KSRC}/Makefile"
fi

### ===== 커널 빌드 준비 및 모듈 빌드 =====
yes "" | make -C "${KSRC}" olddefconfig || true
make -C "${KSRC}" prepare
make -C "${KSRC}" modules_prepare
make -C "${KSRC}" -j"$(nproc)" modules

### ===== 결과물 패키징 =====
OUT_DIR="${WORK}/out"
mkdir -p "${OUT_DIR}/kernel-inject"

if [ -f "${KSRC}/Module.symvers" ]; then
  cp -f "${KSRC}/Module.symvers" "${OUT_DIR}/kernel-inject/Module.symvers"
elif [ -f "${KSRC}/modules-only.symvers" ]; then
  cp -f "${KSRC}/modules-only.symvers" "${OUT_DIR}/kernel-inject/Module.symvers"
  echo "Using modules-only.symvers as Module.symvers"
else
  echo "ERROR: No symvers file found."
  exit 1
fi

rsync -a "${KSRC}/include/" "${OUT_DIR}/kernel-inject/include/"

OUT_TGZ="${OUT_DIR}/kernel-inject-${KREL}.tar.gz"
tar -czf "${OUT_TGZ}" -C "${OUT_DIR}/kernel-inject" Module.symvers include
echo "Created: ${OUT_TGZ}"

### ===== NAS 업로드 (옵션) =====
if [ "${UPLOAD_TO_DSM}" = "true" ]; then
  ${NAS_SSH} "mkdir -p '${NAS_OUT_DIR}'" || true
  ${NAS_SCP} "${OUT_TGZ}" "${NAS_USER}@${NAS_HOST}:${NAS_OUT_DIR}/"
  echo "Uploaded to: ${NAS_HOST}:${NAS_OUT_DIR}/$(basename "${OUT_TGZ}")"
fi

echo "✅ All done. Use this tarball as KSRC injection for LKM build."
