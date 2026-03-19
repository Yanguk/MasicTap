#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-v0.1.0}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$REPO_ROOT/dist"
APP="$DIST/MagicTap.app"

echo "==> Building MagicTap $VERSION"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 1. Zig 백엔드 빌드
echo "==> Building Zig backend..."
cd "$REPO_ROOT"
zig build -Doptimize=ReleaseSafe
cp "$REPO_ROOT/zig-out/bin/zig_my_mouse" "$APP/Contents/MacOS/zig_my_mouse"

# 2. Swift 클라이언트 빌드
echo "==> Building Swift client..."
cd "$REPO_ROOT/mac-client"
swift build -c release 2>&1
SWIFT_BIN="$(swift build -c release --show-bin-path 2>/dev/null)/MagicTapClient"
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

# 5. DMG 생성
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

echo ""
echo "Done! → $DIST/$DMG_NAME"
ls -lh "$DIST/$DMG_NAME"
