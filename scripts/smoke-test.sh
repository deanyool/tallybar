#!/usr/bin/env bash
# Checks a built app without clicking anything: bundle layout, signature, then the
# built-in self check for the hotkey, the idle clock and login item status.
#
# Usage: scripts/smoke-test.sh path/to/TallyBar.app
set -euo pipefail

app="${1:?usage: smoke-test.sh path/to/TallyBar.app}"
plist="$app/Contents/Info.plist"

[[ "$(plutil -extract LSUIElement raw "$plist")" == "true" ]] || { echo "LSUIElement is not set"; exit 1; }
codesign --verify --strict "$app"

data_dir="$(mktemp -d)"
TALLYBAR_DATA_DIR="$data_dir" "$app/Contents/MacOS/TallyBar" --self-check
echo "Smoke test passed"
