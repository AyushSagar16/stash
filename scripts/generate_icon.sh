#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

for tool in rsvg-convert sips iconutil; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "missing required tool: $tool" >&2
    exit 1
  fi
done

SRC="Resources/AppIcon.svg"
PNG="Resources/AppIcon.png"
ICNS="Resources/AppIcon.icns"
TMP_DIR="$(mktemp -d)"
ICONSET="$TMP_DIR/AppIcon.iconset"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$ICONSET"

echo "rendering $PNG"
rsvg-convert -w 1024 -h 1024 "$SRC" -o "$PNG"

make_icon() {
  local size="$1"
  local scale="$2"
  local pixels="$((size * scale))"
  local suffix=""
  if [[ "$scale" == "2" ]]; then
    suffix="@2x"
  fi
  sips -z "$pixels" "$pixels" "$PNG" --out "$ICONSET/icon_${size}x${size}${suffix}.png" >/dev/null
}

make_icon 16 1
make_icon 16 2
make_icon 32 1
make_icon 32 2
make_icon 128 1
make_icon 128 2
make_icon 256 1
make_icon 256 2
make_icon 512 1
make_icon 512 2

echo "writing $ICNS"
iconutil -c icns "$ICONSET" -o "$ICNS"
echo "done"
