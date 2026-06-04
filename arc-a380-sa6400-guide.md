# Intel Arc A380 on Synology SA6400 (DSM 7.3.2) — i915 DRM 시도 가이드

> **대상**: SA6400 / DSM 7.3.2 / 커널 5.10.55  
> **상태**: 미검증 실험적 시도 — 동작 보장 없음, 하지만 시도할 근거는 있음

---

## 먼저 알아야 할 것

### ✅ 준비된 것

| 항목 | 내용 |
|---|---|
| **i915 드라이버** | MT_65(mainline v6.5 기반) 백포트 — DG2/Arc 코드 포함 |
| **펌웨어 3종** | `dg2_guc_70.9.1.bin`(명령처리) / `dg2_huc_7.10.3_gsc.bin`(미디어가속) / `dg2_dmc_ver2_08.bin`(전력관리) 모두 `firmwarei915.tgz`에 포함 |
| **플랫폼** | SA6400 = EPYC7002(x86_64) — Arc A380 PCI 슬롯 제공 가능 |

### ⚠️ 불확실한 것

| 항목 | 이유 |
|---|---|
| **LMEM(전용 VRAM) 초기화** | Arc A380은 4GB 독립 VRAM 탑재. 이 관리체계가 원래 Linux 6.x 인프라에 의존 — 5.10.55에서 동작 여부 **미검증** |
| **GuC 커맨드 submission** | DG2는 GuC 방식만 지원(구형 ExecList 불가). 5.10.55 스케줄러와 호환성 **미확인** |
| **VAAPI 트랜스코딩** | 위 두 가지가 먼저 통과해야 의미있음 |

> 쉽게 말하면: **드라이버와 펌웨어는 준비됐고**, PCI 인식까지는 갈 가능성이 있지만,
> **그 다음 단계(VRAM 초기화)에서 막힐 수 있습니다.** 막혀도 시스템 자체가 망가지진 않습니다.

---

## 시도 절차

### Step 1 — Arc A380 카드 장착

- SA6400의 PCIe 슬롯에 Arc A380 장착
- 보조전원 연결 확인 (75W PCIe 슬롯 + 6핀 보조)

### Step 2 — i915 모듈팩 + 펌웨어 설치

MSHELL/TCRP 부트로더의 애드온 설치 방식을 따릅니다.

```
모듈팩: epyc7002i915 (MT_65 베이스 빌드)
펌웨어: firmwarei915.tgz
```

부트로더 UI에서 **epyc7002i915 애드온**을 설치하면 자동으로
`/lib/modules/`와 `/lib/firmware/i915/`에 배포됩니다.

### Step 3 — 부팅 후 PCI 인식 확인 (첫 번째 관문)

DSM SSH 접속 후:

```bash
# Arc A380 PCI 인식 여부 (PCI ID: 8086:56a0)
lspci | grep -i "arc\|display\|VGA\|3D\|8086:56"

# i915 드라이버 적재 여부
lsmod | grep i915

# 핵심 — 여기서 결과가 나뉩니다
dmesg | grep -i "i915\|dg2\|arc\|lmem" | head -30
```

**✅ 좋은 신호:**
```
[i915] DG2 detected
[i915] Loading firmware dg2_guc_70.9.1.bin
[i915] GuC firmware ... fetch ongoing
```

**❌ 막히는 신호 (예상 가능):**
```
[i915] LMEM init failed
[i915] probe error -ENOMEM / -EIO
```

### Step 4 — LMEM 초기화 확인 (두 번째 관문)

```bash
dmesg | grep -iE "lmem|stolen|probe|firmware|guc|huc" | head -40
```

이 단계를 통과하면 사실상 동작하는 것입니다.

### Step 5 — (통과 시) VAAPI 확인

```bash
# /dev/dri 생성 여부
ls -l /dev/dri/

# Docker Jellyfin 등에서
# LIBVA_DRIVER_NAME=iHD vainfo
```

---

## 결과 시나리오별 대응

| 결과 | 의미 | 대응 |
|---|---|---|
| `dmesg`에 DG2 detected + firmware loaded | ✅ 1관문 통과 | Step 4 계속 |
| LMEM init 통과 + `/dev/dri/card0` 생성 | ✅ 동작 확정 | VAAPI 검증 진행 |
| LMEM init failed / probe error | ⚠️ 예상된 한계 | 드라이버 패치 필요, 현재로선 미지원 |
| i915 모듈 자체 Unknown symbol | ❌ 빌드 문제 | `dmesg \| grep "Unknown symbol"` 로그 공유 |

---

## 한 줄 요약

> **펌웨어(dg2 GuC/HuC/DMC)는 완비, 드라이버(MT_65 백포트)도 DG2 코드 포함 —
> 시도할 근거는 충분합니다. LMEM(전용 VRAM) 초기화가 5.10.55에서 동작하는지가
> 유일한 미지수이며, Step 3~4 dmesg 결과가 성패를 가릅니다.**

결과 로그를 공유해 주시면 다음 단계를 같이 분석하겠습니다. 🚀
