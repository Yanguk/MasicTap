#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-v0.1.0}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$REPO_ROOT/dist"
APP="$DIST/MagicTap.app"

# 코드 서명 설정 (환경 변수로 제어)
# Developer ID 서명 + 공증을 원하면:
#   export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export APPLE_ID="your@email.com"
#   export APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # App-specific password
#   export TEAM_ID="XXXXXXXXXX"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
APPLE_ID="${APPLE_ID:-}"
APP_PASSWORD="${APP_PASSWORD:-}"
TEAM_ID="${TEAM_ID:-}"

echo "==> Building MagicTap $VERSION"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 1. Zig 백엔드 빌드
echo "==> Building Zig backend..."
cd "$REPO_ROOT/src/backend"
NIX_CFLAGS_COMPILE="" zig build -Doptimize=ReleaseSafe
cp "$REPO_ROOT/src/backend/zig-out/bin/zig_my_mouse" "$APP/Contents/MacOS/zig_my_mouse"

# 2. Swift 클라이언트 빌드
echo "==> Building Swift client..."
cd "$REPO_ROOT/src/client"
env -u SDKROOT -u DEVELOPER_DIR swift build -c release 2>&1
SWIFT_BIN="$(env -u SDKROOT -u DEVELOPER_DIR swift build -c release --show-bin-path 2>/dev/null)/MagicTapClient"
cp "$SWIFT_BIN" "$APP/Contents/MacOS/MagicTapClient"

# 3. Info.plist 생성
SHORT_VERSION="${VERSION#v}"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MagicTapClient</string>
    <key>CFBundleIdentifier</key>
    <string>com.yanguk.magictap</string>
    <key>CFBundleName</key>
    <string>MagicTap</string>
    <key>CFBundleDisplayName</key>
    <string>MagicTap</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>${SHORT_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 Yanguk. All rights reserved.</string>
</dict>
</plist>
PLIST

# 4. 실행 권한 설정
chmod +x "$APP/Contents/MacOS/MagicTapClient"
chmod +x "$APP/Contents/MacOS/zig_my_mouse"

# 5. 코드 서명
if [[ -n "$CODESIGN_IDENTITY" ]]; then
    echo "==> Signing with Developer ID: $CODESIGN_IDENTITY"

    # Entitlements 파일 생성 (Hardened Runtime 필수)
    ENTITLEMENTS="$DIST/entitlements.plist"
    cat > "$ENTITLEMENTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF

    # 바이너리 먼저 서명 후 앱 번들 서명 (순서 중요)
    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$CODESIGN_IDENTITY" \
        "$APP/Contents/MacOS/zig_my_mouse"

    codesign --force --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$CODESIGN_IDENTITY" \
        "$APP/Contents/MacOS/MagicTapClient"

    codesign --force --deep --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign "$CODESIGN_IDENTITY" \
        "$APP"

    echo "==> Verifying signature..."
    codesign --verify --deep --strict "$APP"
    spctl --assess --type exec "$APP" && echo "    Gatekeeper: PASS" || echo "    Gatekeeper: FAIL (공증 필요)"
else
    echo "==> CODESIGN_IDENTITY 미설정 → ad-hoc 서명 적용 (인터넷 배포 시 Gatekeeper 경고 발생)"
    codesign --force --deep --sign - "$APP"
fi

# 6. DMG 생성
echo "==> Creating DMG..."
DMG_STAGING="$DIST/dmg-staging"
DMG_NAME="MagicTap-${VERSION}-arm64.dmg"
mkdir -p "$DMG_STAGING"
cp -r "$APP" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "MagicTap ${VERSION}" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DIST/$DMG_NAME"

rm -rf "$DMG_STAGING"

# 7. DMG 서명
if [[ -n "$CODESIGN_IDENTITY" ]]; then
    echo "==> Signing DMG..."
    codesign --force --sign "$CODESIGN_IDENTITY" "$DIST/$DMG_NAME"
fi

# 8. 공증 (Apple ID + App Password + Team ID 모두 설정된 경우)
if [[ -n "$CODESIGN_IDENTITY" && -n "$APPLE_ID" && -n "$APP_PASSWORD" && -n "$TEAM_ID" ]]; then
    echo "==> Submitting for notarization..."
    xcrun notarytool submit "$DIST/$DMG_NAME" \
        --apple-id "$APPLE_ID" \
        --password "$APP_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$DIST/$DMG_NAME"
    echo "    Notarization stapled successfully"
else
    if [[ -n "$CODESIGN_IDENTITY" ]]; then
        echo ""
        echo "  공증을 하려면 APPLE_ID, APP_PASSWORD, TEAM_ID 환경 변수도 설정하세요."
    fi
fi

echo ""
echo "Done! → $DIST/$DMG_NAME"
ls -lh "$DIST/$DMG_NAME"
