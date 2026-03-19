# MagicTap

![Status: WIP](https://img.shields.io/badge/status-WIP-yellow)

---

**🚧 Under Construction 🚧**  
This project is still in development. Features may change.

---

매직마우스에서 탭하여 클릭이 가능하도록 해주는 앱

## TODO

- [x] 탭하여 클릭하기
- [ ] 더블 탭하여 더블 클릭
- [ ] 세손가락 터치시 드래그 모드 활성화

## 동작 기준

- 탭 시작: 이전 프레임 대비 손가락 수가 +1 증가할 때 새 손가락을 탭 후보로 등록합니다.
- 탭 인정: 손가락이 `0.05s` 이상 `0.5s` 이하로 짧게 닿았다 떨어지면 클릭을 발생시킵니다.
- 이동 허용치: 탭 중 이동량이 `TAP_MAX_MOVE`를 넘으면 탭으로 보지 않습니다.

## 릴리스 빌드 & 배포

```bash
# 빌드 (dist/ 에 .app + .dmg 생성)
bash scripts/build-release.sh v0.1.0

# GitHub Release에 업로드
bash scripts/upload-release.sh v0.1.0
```

- `build-release.sh` — Zig 백엔드와 Swift 클라이언트를 `MagicTap.app`으로 패키징하고 DMG를 생성합니다.
- `upload-release.sh` — `dist/` 의 아티팩트를 GitHub Release에 업로드합니다. 릴리스가 없으면 자동 생성됩니다.

## 개발 실행 방법

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
