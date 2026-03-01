# MagicTap

![Status: WIP](https://img.shields.io/badge/status-WIP-yellow)

---

**🚧 Under Construction 🚧**  
This project is still in development. Features may change.

---

매직마우스에서 탭하여 클릭/더블클릭이 가능하도록 해주는 앱

## TODO

- [x] 탭하여 클릭하기
- [x] 더블 탭하여 더블 클릭
- [ ] 세손가락 터치시 드래그 모드 활성화

## 동작 기준

- 단일 탭: 손가락이 `0.05s` 이상 `0.5s` 이하로 짧게 닿았다 떨어지면 클릭 후보가 됩니다.
- 이동 허용치: 탭 중 이동량이 `TAP_MAX_MOVE`를 넘으면 탭으로 보지 않습니다.
- 더블 탭: 첫 탭 이후 `0.30s` 내에 두 번째 탭이 들어오면 더블클릭으로 처리합니다.
- 단일 클릭 확정: 더블 탭 대기 시간(`0.30s`)이 지나면 단일 클릭으로 확정됩니다.

## 실행 방법

### 1) 백엔드 실행

```bash
zig build run
```

### 2) macOS 클라이언트 실행 (SwiftUI)

```bash
cd mac-client
swift run
```

클라이언트에서:
- `Backend Binary`에 백엔드 실행 파일 경로를 입력
- 기본값은 `../zig-out/bin/zig_my_mouse`
- `Start` 버튼으로 백엔드 시작, `Stop` 버튼으로 종료
- 로그 영역에서 탭/클릭 이벤트 출력 확인

## macOS 권한

이 앱이 클릭 이벤트를 보내려면 macOS 권한이 필요합니다.

- `시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용(Accessibility)`에서 실행 주체(터미널 또는 빌드된 앱)를 허용
- 환경에 따라 `입력 모니터링(Input Monitoring)` 허용이 추가로 필요할 수 있음

# References
- https://github.com/mhuusko5/M5MultitouchSupport
- https://github.com/Kyome22/OpenMultitouchSupport
