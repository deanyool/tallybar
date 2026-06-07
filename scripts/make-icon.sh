#!/usr/bin/env bash
# Rebuilds Resources/AppIcon.icns from the 1024px render of the icon view.
#
# Usage: scripts/make-icon.sh path/to/app-icon.png
set -euo pipefail

cd "$(dirname "$0")/.."
source_png="${1:?usage: make-icon.sh path/to/app-icon.png}"
iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source_png" --out "$iconset/icon_${size}x${size}.png" > /dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$source_png" --out "$iconset/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$iconset" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
