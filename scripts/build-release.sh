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

# 5. zip 패키징
echo "==> Packaging..."
cd "$DIST"
zip -r "MagicTap-${VERSION}-arm64.zip" "MagicTap.app"

echo ""
echo "Done! → $DIST/MagicTap-${VERSION}-arm64.zip"
ls -lh "$DIST/MagicTap-${VERSION}-arm64.zip"
