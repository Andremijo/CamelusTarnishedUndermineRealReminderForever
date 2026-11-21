#!/usr/bin/env bash
# Build releases/Camelus' Tarnished Undermine Real Reminder v<version>.zip
# from the version in the .toc. Run from anywhere: tools/build_zip.sh
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(sed -n 's/^## Version: *//p' TarnishedRealReminder/TarnishedRealReminder.toc | tr -d '\r')
[ -n "$version" ] || { echo "No ## Version in the .toc" >&2; exit 1; }
out="releases/Camelus' Tarnished Undermine Real Reminder v${version}.zip"
mkdir -p releases
[ -e "$out" ] && { echo "$out already exists: bump ## Version in the .toc first" >&2; exit 1; }
zip -qrX "$out" TarnishedRealReminder -x '*.DS_Store'
echo "$out"
