# IML late 단계 Synology 순정 모듈 복원 설계

작성일: 2026-11-04 (Asia/Seoul)

상태: Update 0 단독 복원 구현 이후의 확장 설계. smallfix 묶음과 추출기 전환은 아직 구현되지 않았다.

## 목적과 범위

대상은 `all-modules/src/install.sh`의 late 단계다. PML 복사 실패 후 마커 누락, 오염된 모듈의 BAK 재수집 가능성에 대응하여 검증된 Synology 원본을 IML 복원에 우선 사용한다.

복원 대상은 `/tmpRoot/lib/modules`뿐이다. firmware 및 다른 DSM 파일은 hda1에서 복원하지 않는다. 기존 late 펌웨어 전개는 별도 동작이다. PML 백업 구조 전면 재설계는 이번 확정 범위에 포함하지 않는다.

## 원본 공급 기반

`tinycore-redpill/functions_t.sh`의 `c0ffae02`, `7e49cb01`은 `general.synology_module_restore=true`일 때 빌드마다 원본 PAT를 다운로드하고 설정의 MD5를 검증한다. PAT에서 hda1.tgz를 추출하여 XZ/gzip 매직 바이트에 따라 tar 목록을 검사하고 `/addons/hda1.tgz`에 포함한다. 같은 빌드의 재귀 호출에서는 다운로드를 재사용한다.

현재 전용 버전 메타데이터는 없다. 빌드 시 압축 검증 성공은 설치 DSM과의 버전 일치를 의미하지 않는다.

SA6400 DSM 7.4.1-90080 Update 1 실물 PAT는 완성된 `hda1.tgz` 대신 `hda1-epyc7002_7.4-90080-s1.tar`와 `hda1-sa6400_7.4-90080-s1.tar`를 담고 있다. 전자의 `content.txz`는 `usr/lib/modules/nfsd.ko`를 교체하며, 후자에는 모듈 파일이 없다. Update 0과 Update 1의 `nfsd.ko` SHA-256은 서로 다르다. 따라서 Update 1 DSM에 Update 0 hda1만 복원할 수 없다.

Synology SA6400 릴리스 노트 페이지는 `/api/releaseNote/findChangeLog?identify=DSM&lang=en-us&model=SA6400`에서 버전 목록을 가져온다. 확인 당시 `7.4.1-90080`에는 Update 0과 Update 1이 있었다. Update 1 실물 PAT의 원래 URL은 `https://global.synologydownload.com/download/DSM/criticalupdate/update_pack/90080-1/synology_epyc7002_sa6400.pat`였다. 릴리스 노트의 Update 번호만으로 PAT의 존재나 무결성을 단정하지 않는다.

## 빌드 시 smallfix 묶음 준비

구현 대상은 `tinycore-redpill/functions_t.sh`이다. 사용자의 별도 승인이 있기 전에는 `functions.sh`를 수정하지 않는다. 이 명시적 제한은 저장소의 paired functions 지침보다 우선한다.

1. `general.synology_module_restore=true`인 빌드에서 정확한 모델과 DSM productversion/buildnumber의 Update 번호를 Synology 릴리스 노트 목록에서 수집한다. 숫자 URL을 순차 추측해 마지막 Update를 결정하지 않는다.
2. 기존 방식대로 Update 0 정식 PAT를 새로 받아 설정된 MD5를 확인한다. `hda1.tgz` 안의 VERSION과 모델 식별자, 압축 무결성을 확인한다.
3. 목록의 각 smallfix PAT를 공식 다운로드 경로에서 받는다. 다운로드 URL의 최종 결정 방법은 Synology 다운로드 목록과 응답을 확인해 구현한다. 각 PAT를 `SynoXtract`로 열어 내부 INFO의 archive_type, platform, productversion, buildnum, smallfixnum, unique가 요청한 대상과 일치하는지 확인한다. 필요한 Update 파일이 없거나 검증에 실패하면 복원 옵션을 켠 빌드를 실패시킨다.
4. 각 PAT의 `hda1-<platform>...tar` 및 `hda1-<model>...tar`에서 `content.txz`를 추출한다. 두 콘텐츠에서 `usr/lib/modules`에 속하는 변경 파일과 삭제 지시만 선별한다. 플랫폼 변경분을 먼저, 모델 변경분을 나중에 적용할 수 있도록 순서를 기록한다. 삭제 표현이 존재하는지 실제 Update PAT로 확인하고, 이해할 수 없는 작업은 조용히 무시하지 않는다.
5. `/addons/hda1.tgz`와 `/addons` 아래의 smallfix 모듈 변경분 및 데이터 manifest를 initrd-dsm에 포함한다. manifest에는 스키마, 원본 모델·플랫폼·DSM 버전, 포함된 Update 번호, 적용 순서, 각 파일 SHA-256을 기록한다. 빌드 시 확인한 최신 Update보다 설치 DSM이 높아지면 새 빌드가 필요하다.

### 추출기 전환

`functions_t.sh`의 기존 `extractor.gz`/`scemd`와 관련 공유 라이브러리 설치, 구형 PAT에서 추출 도구를 마련하는 경로를 `extractor-new/synoxtract`로 교체한다. 이 바이너리는 정적 링크된 Linux x86-64 실행 파일이며, 확인된 SHA-256은 `66503d9d61e99cd2534e6ab39b880c83d5466322ea294efb700e9ac2e90cbe90`이다. 정식 PAT의 `hda1.tgz`와 smallfix PAT의 선택 파일 모두 `SynoXtract`의 목록 조회 및 선택 추출로 처리하고 종료 코드와 추출 결과를 확인한다. `pigz`는 다른 빌드 압축 작업에도 쓰이므로 유지한다. 구형 CPU에서의 실제 실행 가능성은 별도 검증 항목이다.

실기에서 확인된 45.90 표본의 `/dev/shm/hda1.tgz`는 파일명과 달리 XZ 압축이었다. 내부 `etc.defaults/VERSION`에서 DSM 7.4.1, build 90080, smallfix 0 (Update 0), builddate `2026/07/22`를 읽었다. `etc.defaults/synoinfo.conf`에는 `upnpmodelname="SA6400"`, `unique="synology_epyc7002_sa6400"`가 있었다. 이 관찰은 해당 hda1 표본에 한정되며, 모든 PAT에 같은 형식과 항목이 있다는 보장은 아니다. `etc.defaults/model.dtb`는 DT 모델만 담을 수 있으므로 모델 판별 근거로 사용하지 않는다.

late 단계에서는 DSM의 `/tmpRoot/usr/bin`, `/tmpRoot/usr/sbin` 등의 명령 및 sha256sum을 사용할 수 있다고 전제한다. DSM 바이너리는 필요한 경우 chroot를 통해 해당 라이브러리 환경에서 실행한다.

## 확정 분기

모드 마커는 `/addons/pml_on`이다. 있으면 PML, 없으면 IML이다. `modules.pml_active`는 기존 오염 기록이며 모드 판정용이 아니다.

| 조건 | 처리 |
| --- | --- |
| PML | 기존 PML 분기 유지 |
| IML, hda1 및 필요한 smallfix 변경분 존재, DSM 버전 일치 확인 | 매 IML 부팅마다 설치된 Update 번호까지 재구성해 전체 교체 |
| IML, hda1 존재, 버전 불일치·변경분 누락 또는 확인 불가 | 오류 로그만 기록. 모듈 유지. BAK 대체 복원 금지 |
| IML, hda1 없음 | 기존 BAK 복원 루틴 실행 |

hda1 복원은 오염 마커 유무와 무관하다. 읽을 수 없거나 손상된 아카이브를 부재로 간주하지 않는다. hda1 검증·추출 실패도 BAK로 자동 대체하지 않는다.

기존 BAK 분기의 조건은 오염 마커 존재, 마커 지문 일치, 비어 있지 않은 BAK, BAK 지문 일치다. 조건 미충족 시 복원하지 않는다.

## 버전 및 무결성

- 실제 hda1 내부의 `etc.defaults/VERSION` 및 `etc.defaults/synoinfo.conf`를 확인한다. 45.90 표본에서는 VERSION의 productversion/buildnumber/smallfixnumber와 synoinfo.conf의 upnpmodelname/unique를 읽을 수 있었다. 다른 PAT에서도 이 경로와 값이 제공되는지 개별 검증한다.
- `etc.defaults/model.dtb`는 DT 모델만 존재할 수 있으므로 모델 식별 또는 일치 판정에 사용하지 않는다.
- 원본 hda1의 productversion/buildnumber는 설치 DSM과 일치하고 smallfixnumber는 0이어야 한다. 설치 DSM의 smallfixnumber까지 필요한 변경분이 순서대로 준비되어야 한다. 누락값은 일치로 간주하지 않는다.
- 내부 VERSION 또는 `synoinfo.conf` 정보가 없거나 부족하면 원본 PAT에서 확인한 값을 `/addons/hda1.meta` 같은 별도 파일로 전달한다. 빌드 설정의 추정값을 원본 확인값으로 대체하지 않는다.
- 별도 메타데이터에는 스키마 버전, DSM 버전 필드, 확인 가능한 모델/플랫폼, hda1 SHA-256을 기록한다. 해시로 해당 아카이브와 메타데이터의 결합을 확인한다. 확인한 식별자에 충돌이 있으면 복원을 허용하지 않는다.
- SHA-256 일치만으로 DSM 버전 일치를 판단하지 않는다. 메타데이터는 source하지 않고 데이터로 파싱한다.

메타데이터 최종 형식은 구현 시 정한다. 45.90 표본의 내부 경로는 확인했지만 다른 PAT에서도 확인해야 한다. 버전이나 모델 일치 확인이 불가능하면 복원을 생략하는 정책은 확정이다.

## 복원 절차

1. 모드, 아카이브 존재, 버전과 무결성을 확인한다. 버전 오류는 대상 변경 전에 로그를 남기고 복원을 생략한다.
2. `/tmpRoot/lib/modules`를 DSM 루트 기준으로 해석한다. `/lib`가 `/usr/lib` 링크인 경우 링크 자체를 보존한다. 절대 링크를 initrd 루트 기준으로 잘못 해석하지 않는다.
3. 같은 파일시스템의 임시 디렉터리에 Update 0 모듈 트리만 추출한다. 내부 `usr/lib/modules` 경로는 대상에 맞게 매핑한다. 아카이브 전체를 `/tmpRoot`에 풀지 않는다.
4. manifest와 각 변경분의 버전·모델·SHA-256을 확인한 뒤 U1부터 설치 DSM의 smallfix 번호까지 플랫폼·모델 순서로 작업 트리에 적용한다. 누락, 손상, 알 수 없는 삭제 지시 또는 빌드에 포함되지 않은 Update가 있으면 원래 대상은 유지한다.
5. 경로 이탈 방지, 추출·적용 성공, 비어 있지 않은 모듈 트리, 권한 보존을 확인한다. 준비 완료 전에 현재 트리를 삭제하지 않는다.
6. 교체 전 작업 상태를 기록하고 기존 트리를 롤백용으로 보존한 뒤 준비된 트리로 전체 교체한다. 덮어쓰기만 하여 PML 추가 파일을 남기지 않는다. 각 이동 및 상태 기록 결과를 확인한다.
7. 필요한 modules.order/modules.builtin 처리 및 `chroot /tmpRoot /sbin/depmod -a`를 복원된 DSM 트리에만 수행한다.
8. 전체 성공 후 완료를 기록하고 PML 오염 마커를 제거한 뒤 성공 로그를 남긴다.

두 번의 rename 전체는 원자적이지 않다. 교체 전, 기존 트리 이동 후, 새 트리 설치 후, depmod 후 중단 상태를 식별하여 다음 실행에서 복구해야 한다. 작업 상태는 모듈 트리 외부에 둔다. 작업용 상태/롤백 자료는 복원 범위 확장을 의미하지 않는다.

추출 실패는 현재 트리를 유지한다. 교체·depmod 실패는 기존 트리로 롤백을 시도하고 결과를 기록한다. 실패 시 성공 로그를 남기거나 마커를 먼저 제거하지 않는다. 오류 반환이 전체 부팅에 미치는 영향은 addon 호출부와 함께 구현 시 검증한다.

## 실행 중 모듈 보호

IML modules 이벤트는 모듈팩을 initrd 메모리 파일시스템에 전개하고 일부 모듈을 적재한다. 파일 전개와 커널 적재는 서로 다르다.

- 현재 initrd `/lib/modules`와 그 의존성 인덱스는 수정하지 않는다.
- 복원 과정에서 modprobe, insmod, rmmod 등 적재·해제 명령을 실행하지 않는다.
- depmod는 chroot 안의 DSM 트리와 인덱스에만 적용한다. 이미 커널에 적재된 모듈을 초기화하거나 재적재하지 않는다.
- DSM 루트 전환 이후 새로 적재되는 모듈은 순정 파일과 새 인덱스를 사용한다. 이는 기존 적재 모듈 보존과 구분한다.

## 로그 계약

콘솔과 `/dev/kmsg`에 `[TCRP][IML-RESTORE]` 접두사로 기록한다.

| 결과 | 필수 내용 |
| --- | --- |
| 시작 | 출처(hda1/BAK), 대상, 설치 DSM 버전 |
| VERSION_MISMATCH / VERSION_UNKNOWN | 원인, 확인 가능한 원본/설치 버전, 복원 생략, BAK 대체 없음 |
| 작업 실패 | 실패 단계(검증/추출/교체/depmod), 원인, 롤백 시도 및 결과 |
| SUCCESS | 출처, 대상, DSM 버전, 적용한 Update 범위, hda1 및 변경분 SHA-256, 복원 및 depmod 완료 |
| BAK 조건 미충족 | 복원하지 않은 사유 |

SUCCESS는 전체 복원 및 depmod 성공 후에만 기록한다. 기존 BAK 경로에서도 depmod 실패를 완전한 성공으로 표시하지 않는다.

## 구현 검증 기준

- pml_on 유무로 모드 판정 및 PML 분기 유지.
- 유효한 hda1은 오염 마커 없이도 매 IML 부팅 복원하며 PML 추가 파일 제거.
- XZ/gzip 처리 및 DSM 루트 기준 링크 보존.
- 릴리스 노트에 나온 Update 전부를 `SynoXtract`로 검증해 묶으며, U0/U1의 `nfsd.ko` 차이를 정확히 재현.
- 설치 DSM보다 높은 Update는 적용하지 않고, 필요한 Update가 누락되면 대상 변경 없이 오류 기록.
- 정적 추출기의 정식·smallfix PAT 처리와 구형 CPU 실행 가능성 확인.
- 버전 불일치·누락, 필요한 메타데이터 누락, 해시 불일치 시 대상 유지 및 BAK 대체 금지.
- hda1 부재 시 기존 BAK 네 조건 유지.
- 추출·이동·depmod 실패 및 교체 단계별 중단 후 복구.
- initrd 모듈 트리/인덱스 보존 및 기존 커널 모듈 해제·재적재 없음.
- 콘솔/커널 로그에서 성공과 실패를 명확히 확인.
- firmware 등 대상 밖 파일을 hda1에서 복원하지 않음.
