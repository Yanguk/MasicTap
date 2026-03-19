# MagicTap

<p align="center">
  <img src="./assets/logo.svg" width="160" alt="MagicTap Logo"/>
</p>

Apple Magic Mouse에서 **탭하여 클릭**, **더블 탭하여 더블 클릭**을 가능하게 해주는 macOS 앱입니다.

---

## 기능

| 동작                              | 결과                 |
| --------------------------------- | -------------------- |
| 한 손가락으로 탭                  | 마우스 왼쪽 클릭     |
| ~~한 손가락으로 빠르게 두 번 탭~~ | ~~마우스 더블 클릭~~ |

- Magic Mouse 전용 (내장 트랙패드에는 반응하지 않음)
- 메뉴바에서 간편하게 켜기/끄기 가능
- 탭으로 인식되지 않으려면 손가락을 살짝 움직이면 됩니다 (이동 허용치 초과 시 탭 취소)

---

## 다운로드 및 설치

### 1. 앱 다운로드

[Releases 페이지](../../releases)에서 최신 버전의 `MagicTap.dmg`를 다운로드합니다.

### 2. 앱 설치

1. 다운로드한 `.dmg` 파일을 열기
2. `MagicTap.app`을 `/Applications` 폴더로 드래그
3. 앱 실행

> **참고:** 앱이 개발자 서명되어 있지 않은 경우, `시스템 설정 > 개인정보 보호 및 보안`에서 "확인 없이 열기"를 허용해야 할 수 있습니다.

### 3. 권한 허용

앱이 클릭 이벤트를 전송하려면 macOS 권한이 필요합니다. 앱 첫 실행 시 자동으로 안내가 표시됩니다.

- **손쉬운 사용 (Accessibility):** `시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용`에서 `MagicTap` 허용
- **입력 모니터링 (Input Monitoring):** 환경에 따라 추가로 필요할 수 있음

### 4. 사용 시작

- 메뉴바의 MagicTap 아이콘을 클릭하여 백엔드를 켜기/끄기
- Magic Mouse로 탭하여 클릭이 되는지 확인

---

## 로드맵

- [x] 탭하여 클릭하기
- [ ] 더블 탭하여 더블 클릭
- [ ] 세 손가락 터치 시 드래그 모드 활성화

---

## 개발자 정보

빌드 방법, 아키텍처, 릴리스 스크립트 등 개발 관련 내용은 [DEVELOP.md](./DEVELOP.md)를 참고하세요.

---

## References

- https://github.com/mhuusko5/M5MultitouchSupport
- https://github.com/Kyome22/OpenMultitouchSupport
