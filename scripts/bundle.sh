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

# Use the stable self-signed identity if it exists; fall back to ad-hoc.
# A stable identity makes TCC remember the Screen Recording grant across rebuilds.
if security find-certificate -c "GhostTerm Local" >/dev/null 2>&1; then
    SIGN_AS="GhostTerm Local"
    echo "==> Signing with '$SIGN_AS' (stable identity)"
else
    SIGN_AS="-"
    echo "==> Signing ad-hoc — run ./scripts/create-signing-cert.sh once to fix TCC re-prompts"
fi
codesign --force --deep --sign "$SIGN_AS" --options runtime --identifier local.ghostterm "$APP" >/dev/null

echo
echo "Built: $APP"
echo "Run with: open '$APP'"
