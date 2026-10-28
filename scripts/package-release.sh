#!/usr/bin/env bash
# Builds the signed app and the release download: Tallybar-<version>.zip and SHA256SUMS.
#
# Usage: scripts/package-release.sh [output-dir] [extra swift build flags...]
set -euo pipefail

cd "$(dirname "$0")/.."
output="${1:-dist/release}"
[[ $# -gt 0 ]] && shift
version="$(sed -n 's/.*current = "\(.*\)"/\1/p' Sources/TallyCore/Version.swift)"

work="$(mktemp -d)"
scripts/build-app.sh "$work" "$@"
codesign --verify --strict "$work/TallyBar.app"

mkdir -p "$output"
zip="Tallybar-$version.zip"
ditto -c -k --keepParent "$work/TallyBar.app" "$output/$zip"
(cd "$output" && shasum -a 256 "$zip" > SHA256SUMS)
echo "Packaged $output/$zip"
