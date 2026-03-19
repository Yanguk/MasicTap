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
    --notes "MagicTap $VERSION"
fi

for FILE in "$DMG" "$ZIP"; do
  [[ -f "$FILE" ]] || continue
  echo "==> Uploading $(basename "$FILE")..."
  gh release upload "$VERSION" "$FILE" --clobber
done

echo ""
echo "Done! → $(gh release view "$VERSION" --json url -q .url)"
