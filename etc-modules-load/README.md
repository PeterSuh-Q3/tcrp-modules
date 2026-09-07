# etc-modules-load

## English

Loads optional system, CPU-temperature, and hardware-monitoring modules during the `modules` phase after the target module pack has been extracted. It also removes the KVM implementation that does not match the CPU virtualization flag, when that module is not in use.

CPU-temperature drivers are selected exclusively at runtime: `coretemp` for Intel and `k10temp` for AMD. If the matching `syno_*_temperature` symbol is already exported by the Synology kernel, the external module is skipped to prevent a duplicate-symbol load failure.

This extension complements EUDEV and DDSML. It does not stop `udevd`, add a boot delay, or replace event-driven device detection.

## 한국어

대상 모듈팩이 풀린 뒤 `modules` 단계에서 선택적인 시스템 모듈, CPU 온도센서 모듈, 하드웨어 모니터링 모듈을 적재합니다. CPU의 가상화 플래그와 맞지 않는 KVM 구현이 사용 중이 아닐 때만 제거합니다.

CPU 온도센서 드라이버는 런타임에 배타적으로 선택합니다. Intel은 `coretemp`, AMD는 `k10temp`만 후보로 삼고, Synology 커널이 해당 `syno_*_temperature` 심볼을 이미 export하면 중복 심볼 로드 실패를 막기 위해 외부 모듈을 건너뜁니다.

이 확장은 EUDEV와 DDSML을 보완합니다. `udevd`를 종료하지 않고, 임의의 부팅 지연을 추가하지 않으며, 이벤트 기반 장치 감지를 대체하지 않습니다.
