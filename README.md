# TCRP Modules

[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg)](https://paypal.me/PeterSuhQ3)

## English

### Overview

This repository provides kernel-module packs and loader extensions used by MSHELL/TinyCore RedPill. Module packs are selected by the Synology platform, DSM version, and kernel version; they are not selected from the physical CPU vendor of the host machine.

During loader creation, the matching extension recipes download the required packages. In Junior mode, `eudev` or `ddsml` loads only the modules needed by detected hardware. A module built for another platform or kernel must not be mixed into the selected pack.

### Directory roles

| Path | Role |
| --- | --- |
| `all-modules/` | Primary integrated driver pack. It contains the normal platform/DSM/kernel-specific modules used by the loader and is the default module source for general storage, network, USB, virtio, sensor, and other supported devices. Its release JSON files map each supported target to a downloadable module archive. |
| `amd-modules/` | AMD graphics supplement. It contains AMD GPU/AMDGPU-related release packages maintained separately from the primary pack because graphics drivers have larger dependency sets and platform-specific compatibility requirements. |
| `anodrm-modules/` | Non-DRM variant of the integrated module pack. It is used when graphics/DRM modules must be kept outside the main archive or supplied through a separate graphics package, reducing duplicate-symbol and incompatible-DRM risks. |
| `custom-modules/` | Independent custom module channel, primarily for Kernel 5.10.55 targets. These packages are produced separately from `all-modules` and may use their own kernel build context. They must not be assumed to be identical to the primary module pack. |
| `eudev/` | Dynamic device detection extension. It supplies the eudev userspace components and rules used in Junior mode to detect hardware and request the appropriate kernel modules automatically. |
| `ddsml/` | Detected Device Static Module Loading extension. It provides the alternative static loading path that uses `modprobe`/`insmod` for modules selected from detected hardware information. |
| `aeudev/` | MSHELL Manager installer extension. After DSM package services become available, it installs the pinned MSHELL Manager package only when the package is absent. Package installation is intentionally not performed from Junior/initrd. |
| `.github/workflows/` | Automation for synchronizing release metadata, package indexes, checksums, translations, and files copied from the private build repository. |

### Common files inside an extension

| Path | Role |
| --- | --- |
| `rpext-index.json` | Extension index. It maps supported platform/kernel identifiers to their release recipe JSON files. |
| `releases/*.json` | Target-specific recipes containing download URLs, checksums, and loader-stage actions. |
| `recipes/` | Shared or universal recipes used by extensions that do not require a unique package per platform. |
| `src/` | Installation and loader-stage scripts executed by the extension. |

### Release asset naming

The normal archive name is:

```text
<platform>-<DSM-version>-<kernel-version>.tgz
```

Examples:

```text
geminilake-7.4-4.4.302.tgz
epyc7002-7.3-5.10.55.tgz
```

Related suffixes have distinct purposes:

- `-drm.tgz`: separate DRM/iGPU graphics modules for the same target.
- `.lst`: modules imported from the upstream RR/ARPL module pack for that target.
- `files-chksum`: release-wide SHA-256 manifest used to verify downloaded assets.
- `firmware.tgz`: shared firmware package.
- `firmwarei915.tgz`: Intel i915-specific firmware package.

### Loading flow

1. The loader selects a target from the DSM platform, DSM version, and kernel version.
2. The extension index resolves the matching release recipe.
3. The corresponding module and firmware archives are added to the loader.
4. In Junior mode, `eudev` dynamically detects devices or `ddsml` follows the static detected-device list.
5. Only compatible modules required by the detected hardware are loaded.

## 한국어

### 개요

이 저장소는 MSHELL/TinyCore RedPill에서 사용하는 커널 모듈팩과 로더 확장을 제공합니다. 모듈팩은 호스트의 실제 CPU 제조사가 아니라 Synology 플랫폼, DSM 버전, 커널 버전 조합을 기준으로 선택합니다.

로더를 만들 때 대상 조합에 맞는 확장 레시피가 필요한 패키지를 내려받습니다. Junior 모드에서는 `eudev` 또는 `ddsml`이 감지된 하드웨어에 필요한 모듈만 적재합니다. 다른 플랫폼이나 커널용으로 빌드된 모듈을 선택된 팩에 혼합해서는 안 됩니다.

### 디렉터리별 역할

| 경로 | 역할 |
| --- | --- |
| `all-modules/` | 기본 통합 드라이버팩입니다. 로더가 일반적으로 사용하는 플랫폼/DSM/커널별 모듈을 제공하며 스토리지, 네트워크, USB, virtio, 센서 등 지원 장치용 모듈의 기본 공급원입니다. 릴리즈 JSON은 각 지원 대상과 다운로드할 모듈 압축파일을 연결합니다. |
| `amd-modules/` | AMD 그래픽 보조팩입니다. AMD GPU/AMDGPU 계열 모듈은 의존성이 크고 플랫폼별 호환성 관리가 필요하므로 기본 모듈팩과 분리해 배포합니다. |
| `anodrm-modules/` | DRM을 제외한 통합 모듈팩 변형입니다. 그래픽/DRM 모듈을 메인 압축파일에서 분리하거나 별도 그래픽팩으로 공급해야 할 때 사용하며, 중복 심볼과 비호환 DRM 모듈의 혼입 위험을 줄입니다. |
| `custom-modules/` | 주로 Kernel 5.10.55 대상을 위한 독립 커스텀 모듈 공급 경로입니다. `all-modules`와 별도로 생성되며 자체 커널 빌드 환경을 사용할 수 있으므로 두 모듈팩을 동일한 것으로 간주하면 안 됩니다. |
| `eudev/` | 동적 장치 감지 확장입니다. Junior 모드에서 하드웨어를 감지하고 필요한 커널 모듈을 자동 요청하는 eudev 사용자 공간 구성요소와 규칙을 제공합니다. |
| `ddsml/` | 감지 장치 정적 모듈 적재 확장입니다. 감지된 하드웨어 정보를 기준으로 선정한 모듈을 `modprobe`/`insmod`로 적재하는 대체 경로를 제공합니다. |
| `aeudev/` | MSHELL Manager 설치 확장입니다. DSM 패키지 서비스가 준비된 뒤 MSHELL Manager가 없을 때만 고정된 패키지를 설치합니다. Junior/initrd 단계에서는 DSM 패키지 설치를 수행하지 않습니다. |
| `.github/workflows/` | 비공개 빌드 저장소에서 복사된 파일, 릴리즈 메타데이터, 패키지 인덱스, 체크섬 및 번역을 동기화하는 자동화입니다. |

### 확장 내부의 공통 경로

| 경로 | 역할 |
| --- | --- |
| `rpext-index.json` | 확장 인덱스입니다. 지원 플랫폼/커널 식별자를 대상별 릴리즈 레시피 JSON과 연결합니다. |
| `releases/*.json` | 다운로드 URL, 체크섬, 로더 단계별 동작을 정의하는 대상별 레시피입니다. |
| `recipes/` | 플랫폼별 고유 패키지가 필요하지 않은 확장에서 사용하는 공용 또는 범용 레시피입니다. |
| `src/` | 확장이 로더 단계에서 실행하는 설치 및 처리 스크립트입니다. |

### 릴리즈 자산 이름 규칙

기본 모듈 압축파일의 이름은 다음 형식입니다.

```text
<플랫폼>-<DSM 버전>-<커널 버전>.tgz
```

예시:

```text
geminilake-7.4-4.4.302.tgz
epyc7002-7.3-5.10.55.tgz
```

관련 접미사와 파일의 역할은 다음과 같습니다.

- `-drm.tgz`: 같은 대상에 사용하는 별도 DRM/iGPU 그래픽 모듈팩입니다.
- `.lst`: 해당 대상에서 RR/ARPL 상위 모듈팩으로부터 가져온 모듈 목록입니다.
- `files-chksum`: 다운로드 자산 검증에 사용하는 릴리즈 전체 SHA-256 목록입니다.
- `firmware.tgz`: 플랫폼에서 공유하는 펌웨어팩입니다.
- `firmwarei915.tgz`: Intel i915 전용 펌웨어팩입니다.

### 모듈 적재 흐름

1. DSM 플랫폼, DSM 버전, 커널 버전으로 로더 대상 조합을 결정합니다.
2. 확장 인덱스에서 해당 조합의 릴리즈 레시피를 찾습니다.
3. 일치하는 모듈팩과 펌웨어팩을 로더에 포함합니다.
4. Junior 모드에서 `eudev`가 장치를 동적으로 감지하거나 `ddsml`이 감지 장치 정적 목록을 사용합니다.
5. 감지된 하드웨어에 필요하고 커널과 호환되는 모듈만 적재합니다.

## License

See [LICENSE](LICENSE).
