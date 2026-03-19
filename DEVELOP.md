# MagicTap — 개발자 문서

## 프로젝트 구조

MagicTap은 두 개의 컴포넌트로 구성됩니다.

1. **Zig 백엔드** (`src/main.zig`): 프라이빗 `MultitouchSupport` 프레임워크를 통해 멀티터치 이벤트를 수신하고, 탭을 감지하여 `CGEvent` 마우스 클릭을 발생시킵니다.
2. **Swift 메뉴바 클라이언트** (`mac-client/`): SwiftUI `MenuBarExtra` 앱으로, Zig 백엔드 프로세스를 실행하고 관리합니다.

## 요구 사항

- Zig ≥ 0.15.2
- `local_frameworks/MultitouchSupport.framework` (프라이빗 Apple 프레임워크, 저장소에 포함되지 않음)
- macOS 14+

## 개발 실행 방법

### 백엔드 (Zig)

```bash
zig build              # 빌드 → zig-out/bin/zig_my_mouse
zig build run          # 빌드 후 바로 실행
zig build test         # 테스트 실행
```

### Swift 클라이언트

```bash
cd mac-client
swift run
```

클라이언트 실행 후:
- 백엔드 바이너리 기본 경로: `../zig-out/bin/zig_my_mouse`
- 메뉴바 아이콘을 통해 켜기/끄기
- 로그에서 탭/클릭 이벤트 확인 가능

## 탭 감지 로직

백엔드 (`src/main.zig`)의 `touchCallback`에서 동작:

- Magic Mouse 기기만 연결 (PID `0x030D`, `0x0269`), 내장 트랙패드는 제외
- 각 손가락을 `identifier`로 추적, `finger_states[MAX_FINGERS]` 배열에 저장
- 손가락이 `TAP_MAX_MOVE` (0.045, 정규화 좌표) 이상 이동하면 탭 취소
- 손가락이 `TAP_MIN_DURATION`–`TAP_MAX_DURATION` (0.05s–0.5s) 이내에 닿았다 떨어지면 탭 후보로 등록
- 두 번째 탭이 `DOUBLE_TAP_MAX_INTERVAL` (0.30s) 이내에 들어오면 더블 클릭, 아니면 단일 클릭 확정
- `flushPendingSingleTap()`이 매 콜백 프레임 시작 시 호출되어 더블 탭 대기 시간 경과 후 단일 클릭을 확정

## 릴리스 빌드 & 배포

```bash
# 빌드 (dist/ 에 .app + .dmg 생성)
bash scripts/build-release.sh v0.1.0

# GitHub Release에 업로드
bash scripts/upload-release.sh v0.1.0
```

- `build-release.sh` — Zig 백엔드와 Swift 클라이언트를 `MagicTap.app`으로 패키징하고 DMG를 생성합니다.
- `upload-release.sh` — `dist/` 의 아티팩트를 GitHub Release에 업로드합니다. 릴리스가 없으면 자동 생성됩니다.

## macOS 권한

- **손쉬운 사용 (Accessibility):** `CGEvent` 클릭 전송에 필요
- **입력 모니터링 (Input Monitoring):** 환경에 따라 추가로 필요할 수 있음

터미널에서 개발 실행 시, 터미널 앱 자체에 위 권한을 부여해야 합니다.
