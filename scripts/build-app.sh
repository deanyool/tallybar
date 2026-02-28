#!/usr/bin/env bash
# Builds TallyBar.app: a release binary inside a real bundle with LSUIElement set, so
# it runs from the menu bar with no Dock icon, and Launch at Login has a bundle to use.
#
# Usage: scripts/build-app.sh [output-dir] [extra swift build flags...]
# Set SWIFT to use a specific swift binary.
set -euo pipefail

cd "$(dirname "$0")/.."
output="${1:-dist}"
[[ $# -gt 0 ]] && shift
swift_bin="${SWIFT:-swift}"

version="$(sed -n 's/.*current = "\(.*\)"/\1/p' Sources/TallyCore/Version.swift)"
"$swift_bin" build -c release --product TallyBar "$@"
binary="$("$swift_bin" build -c release --show-bin-path "$@")/TallyBar"

app="$output/TallyBar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/TallyBar"
sed "s/__VERSION__/$version/g" Resources/Info.plist > "$app/Contents/Info.plist"
printf 'APPL????' > "$app/Contents/PkgInfo"

# Ad-hoc signature. Launch at Login and the hardened system frameworks need a signed
# bundle, and this needs no Apple Developer account. It is not notarized.
codesign --force --sign - --timestamp=none "$app"

echo "Built $app ($version)"
