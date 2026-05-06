#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-v$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)}"
APP_NAME="Stash"
APP="${APP_NAME}.app"
DIST_DIR="dist"
STAGE_DIR="$DIST_DIR/dmg-stage"
DMG="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"

for tool in hdiutil codesign; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

./scripts/build.sh release

rm -rf "$STAGE_DIR" "$DMG"
mkdir -p "$STAGE_DIR"
cp -R "$APP" "$STAGE_DIR/$APP"
ln -s /Applications "$STAGE_DIR/Applications"

echo "creating $DMG"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG"

rm -rf "$STAGE_DIR"

echo "created $DMG"
echo "unsigned DMG: users may need right-click Open on first launch"
