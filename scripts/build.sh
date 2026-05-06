#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
APP="Stash.app"

echo "→ swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN=".build/$CONFIG/Stash"
if [[ ! -x "$BIN" ]]; then
  echo "✗ binary not found: $BIN" >&2
  exit 1
fi

echo "→ bundling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Stash"
cp Resources/Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/Stash"

# Ad-hoc codesign so accessibility/notification permissions persist across rebuilds.
codesign --force --deep --sign - "$APP" 2>&1 | tail -1 || true

echo "✓ built $APP"
echo "  open $APP            # launch"
echo "  pkill -x Stash       # kill"
