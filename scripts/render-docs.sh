#!/usr/bin/env bash
# Regenerates the README screenshots and sample files from the real views, using the
# fictional ledger in Sources/tally-render.
set -euo pipefail

cd "$(dirname "$0")/.."
"${SWIFT:-swift}" run "$@" tally-render docs/images
