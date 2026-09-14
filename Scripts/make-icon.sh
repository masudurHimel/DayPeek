#!/bin/bash
# Render the 1024px icon with CoreGraphics, build the .iconset, and pack it into
# Resources/DayPeek.icns. Re-run only when the icon design changes.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Rendering 1024px master…"
swift Scripts/make-icon.swift

SRC=".build/icon/DayPeek-1024.png"
SET=".build/icon/DayPeek.iconset"
rm -rf "$SET"; mkdir -p "$SET"

echo "==> Building iconset…"
sips -z 16 16     "$SRC" --out "$SET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$SRC" --out "$SET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$SRC" --out "$SET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$SRC" --out "$SET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$SRC" --out "$SET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$SRC" --out "$SET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC" --out "$SET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$SRC" --out "$SET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC" --out "$SET/icon_512x512.png"    >/dev/null
cp "$SRC" "$SET/icon_512x512@2x.png"

echo "==> Packing .icns…"
iconutil -c icns "$SET" -o Resources/DayPeek.icns
echo "==> Wrote Resources/DayPeek.icns"
