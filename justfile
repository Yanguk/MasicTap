# MagicTap monorepo task runner
# Usage: just <recipe>
# Install: brew install just

# 기본: 전체 빌드
default: run-client

# ── Backend (Zig) ────────────────────────────────────────────────

# 백엔드 빌드
build-backend:
    cd src/backend && NIX_CFLAGS_COMPILE="" zig build

# 백엔드 실행
run-backend:
    cd src/backend && NIX_CFLAGS_COMPILE="" zig build run

# 백엔드 테스트
test-backend:
    cd src/backend && NIX_CFLAGS_COMPILE="" zig build test

# ── Client (Swift) ───────────────────────────────────────────────

# 클라이언트 빌드
build-client:
    cd src/client && env -u SDKROOT -u DEVELOPER_DIR swift build

# 클라이언트 실행
run-client:
    cd src/client && env -u SDKROOT -u DEVELOPER_DIR swift run

# 클라이언트 테스트
test-client:
    cd src/client && env -u SDKROOT -u DEVELOPER_DIR swift test

# ── Monorepo ─────────────────────────────────────────────────────

# 전체 빌드 (백엔드 → 클라이언트)
build: build-backend build-client

# 전체 테스트
test: test-backend test-client

# 릴리스 빌드 (버전 예: just release v0.2.0)
release version="v0.1.0":
    bash scripts/build-release.sh {{ version }}

# 릴리스 업로드
upload version="v0.1.0":
    bash scripts/upload-release.sh {{ version }}

# 릴리스 (서명 + 공증 포함)
# 사용 예:
#   export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export APPLE_ID="your@email.com"
#   export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#   export TEAM_ID="XXXXXXXXXX"
#   just release-signed v0.2.0
release-signed version="v0.1.0":
    bash scripts/build-release.sh {{ version }}
