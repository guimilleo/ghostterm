#!/usr/bin/env bash
# Build the SPM binary and wrap it into GhostTerm.app
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)"
APP="$BIN_PATH/GhostTerm.app"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN_PATH/ghostterm" "$APP/Contents/MacOS/ghostterm"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc sign so TCC (Screen Recording, etc.) can grant persistent permission to a stable identity.
codesign --force --deep --sign - "$APP" >/dev/null

echo
echo "Built: $APP"
echo "Run with: open '$APP'"
