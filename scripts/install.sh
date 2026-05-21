#!/usr/bin/env bash
# Build GhostTerm in release configuration and install it into /Applications.
#
# Usage:  ./scripts/install.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

# --- Preflight: Swift toolchain ------------------------------------------------

if ! command -v swift >/dev/null 2>&1; then
    cat >&2 <<'EOF'
error: Swift toolchain not found.

Install Apple Command Line Tools (this includes Swift):

    xcode-select --install

Then re-run this script.
EOF
    exit 1
fi

SWIFT_VER=$(swift --version 2>&1 | head -1)
echo "==> Using $SWIFT_VER"

# --- Preflight: stable code-signing identity -----------------------------------
# Without this, every rebuild changes the binary signature and macOS TCC keeps
# re-prompting for Screen Recording on every screenshot. The cert lives only in
# your login keychain — each user generates their own.

if ! security find-certificate -c "GhostTerm Local" \
        ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    echo "==> No 'GhostTerm Local' code-signing cert found. Creating one (first-time setup)."
    ./scripts/create-signing-cert.sh
    echo
fi

# --- Build release -------------------------------------------------------------

echo "==> Building GhostTerm.app (release)"
./scripts/bundle.sh release >/dev/null

APP_SRC="$(swift build -c release --show-bin-path)/GhostTerm.app"
APP_DST="/Applications/GhostTerm.app"

if [ ! -d "$APP_SRC" ]; then
    echo "error: build did not produce $APP_SRC" >&2
    exit 1
fi

# --- Confirm overwrite ---------------------------------------------------------

if [ -d "$APP_DST" ]; then
    echo
    read -r -p "An existing GhostTerm.app is installed at $APP_DST. Overwrite? [y/N] " ans
    case "$ans" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted."; exit 1 ;;
    esac
    # Quit a running instance so we can replace the bundle cleanly
    osascript -e 'tell application "GhostTerm" to quit' 2>/dev/null || true
    sleep 1
    rm -rf "$APP_DST"
fi

# --- Install -------------------------------------------------------------------

echo "==> Copying to $APP_DST"
cp -R "$APP_SRC" "$APP_DST"

# Strip macOS quarantine so the user doesn't get a Gatekeeper prompt for an
# app they just built locally.
xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true

echo
echo "Installed: $APP_DST"
echo
echo "Launch with:    open '$APP_DST'"
echo "Uninstall with: rm -rf '$APP_DST' ~/.config/ghostterm ~/Documents/GhostTermShots"
echo
echo "First run will prompt for Screen Recording permission. Grant it in"
echo "System Settings -> Privacy & Security -> Screen Recording, then relaunch."
