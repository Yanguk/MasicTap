#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>  (e.g. v0.1.0)"
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$REPO_ROOT/dist"
DMG="$DIST/MagicTap-${VERSION}-arm64.dmg"
ZIP="$DIST/MagicTap-${VERSION}-arm64.zip"

if [[ ! -f "$DMG" && ! -f "$ZIP" ]]; then
  echo "Error: no artifact found in $DIST for $VERSION"
  echo "Run scripts/build-release.sh $VERSION first."
  exit 1
fi

# 릴리스가 없으면 생성, 있으면 파일만 추가
if gh release view "$VERSION" &>/dev/null; then
  echo "==> Release $VERSION already exists, uploading assets..."
else
  echo "==> Creating release $VERSION..."
  gh release create "$VERSION" \
    --title "MagicTap $VERSION" \
    --notes "## 설치 방법

1. \`MagicTap-${VERSION}-arm64.dmg\` 다운로드
2. DMG를 열고 \`MagicTap.app\`을 \`/Applications\`로 드래그

### ⚠️ \"damaged\" 오류 발생 시

Apple 공증이 없는 오픈소스 앱입니다. 터미널에서 아래 명령어를 실행하세요:

\`\`\`bash
xattr -d com.apple.quarantine /Applications/MagicTap.app
\`\`\`

이후 앱을 정상 실행할 수 있습니다."
fi

for FILE in "$DMG" "$ZIP"; do
  [[ -f "$FILE" ]] || continue
  echo "==> Uploading $(basename "$FILE")..."
  gh release upload "$VERSION" "$FILE" --clobber
done

echo ""
echo "Done! → $(gh release view "$VERSION" --json url -q .url)"
