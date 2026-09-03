# etc-modules-load

## English

Loads optional system, CPU-temperature, and hardware-monitoring modules during the `modules` phase after the target module pack has been extracted. It also removes the KVM implementation that does not match the CPU virtualization flag, when that module is not in use.

This extension complements EUDEV and DDSML. It does not stop `udevd`, add a boot delay, or replace event-driven device detection.

## 한국어

대상 모듈팩이 풀린 뒤 `modules` 단계에서 선택적인 시스템 모듈, CPU 온도센서 모듈, 하드웨어 모니터링 모듈을 적재합니다. CPU의 가상화 플래그와 맞지 않는 KVM 구현이 사용 중이 아닐 때만 제거합니다.

이 확장은 EUDEV와 DDSML을 보완합니다. `udevd`를 종료하지 않고, 임의의 부팅 지연을 추가하지 않으며, 이벤트 기반 장치 감지를 대체하지 않습니다.
