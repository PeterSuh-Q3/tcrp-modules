# etc-modules-load

## English

Loads optional system, CPU-temperature, and hardware-monitoring modules during the `modules` phase after the target module pack has been extracted. It also removes the KVM implementation that does not match the CPU virtualization flag, when that module is not in use.

CPU-temperature drivers are selected exclusively at runtime: `coretemp` for Intel and `k10temp` for AMD. If the matching `syno_*_temperature` symbol is already exported by the Synology kernel, the external module is skipped to prevent a duplicate-symbol load failure.

This extension complements EUDEV and DDSML. It does not stop `udevd`, add a boot delay, or replace event-driven device detection.

The `syno-superiotool` diagnostic binary is installed to `/usr/local/bin` during
the `modules` event and staged at `/tmpRoot/usr/local/bin` during `late`. It is
statically linked and can be invoked in the live event environment as
`/usr/local/bin/syno-superiotool` or from DSM after boot. Run it as root on the
physical host, and avoid probing while a Super I/O sensor driver is actively
accessing the same configuration ports.

## 한국어

대상 모듈팩이 풀린 뒤 `modules` 단계에서 선택적인 시스템 모듈, CPU 온도센서 모듈, 하드웨어 모니터링 모듈을 적재합니다. CPU의 가상화 플래그와 맞지 않는 KVM 구현이 사용 중이 아닐 때만 제거합니다.

CPU 온도센서 드라이버는 런타임에 배타적으로 선택합니다. Intel은 `coretemp`, AMD는 `k10temp`만 후보로 삼고, Synology 커널이 해당 `syno_*_temperature` 심볼을 이미 export하면 중복 심볼 로드 실패를 막기 위해 외부 모듈을 건너뜁니다.

이 확장은 EUDEV와 DDSML을 보완합니다. `udevd`를 종료하지 않고, 임의의 부팅 지연을 추가하지 않으며, 이벤트 기반 장치 감지를 대체하지 않습니다.

진단용 `syno-superiotool` 바이너리는 `modules` 이벤트에서 `/usr/local/bin`에
설치되고, `late` 이벤트에서는 `/tmpRoot/usr/local/bin`에 DSM용으로 배치됩니다.
정적 링크 바이너리이므로 해당 단계에서는 `/usr/local/bin/syno-superiotool`,
DSM 부팅 후에는 `syno-superiotool`로 실행할 수 있습니다.
물리 장비에서 root 권한으로 실행하고, Super I/O 센서 드라이버가 같은 설정
포트에 접근 중일 때는 진단하지 마십시오.
