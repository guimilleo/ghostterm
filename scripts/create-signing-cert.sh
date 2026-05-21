#!/usr/bin/env bash
# Create a stable self-signed code-signing certificate for GhostTerm so TCC
# permissions (Screen Recording, etc.) persist across rebuilds. Run once.
#
# After this, codesign will use "GhostTerm Local" as the signing identity. The
# first build after creation will trigger a one-time macOS UI prompt asking
# whether codesign can use the new private key — click "Always Allow" and
# enter your login password.

set -euo pipefail

CERT_NAME="GhostTerm Local"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$CERT_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Certificate '$CERT_NAME' already exists in your login keychain. Nothing to do."
    exit 0
fi

TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

# Extensions file (OpenSSL 3.x reads -extfile separately from -subj).
cat > "$TMPDIR/ext.cnf" <<'EOF'
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:FALSE
EOF

echo "==> Generating private key + self-signed code-signing certificate"
openssl req -x509 -newkey rsa:2048 \
    -keyout "$TMPDIR/key.pem" \
    -out "$TMPDIR/cert.pem" \
    -days 3650 -nodes \
    -subj "/CN=$CERT_NAME" \
    -extensions v3_req \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:FALSE"

echo "==> Importing certificate and key into login keychain"
# macOS 'security' can import PEM files directly. Avoid PKCS12 entirely —
# OpenSSL 3.x and macOS disagree on the default MAC algorithm.
security import "$TMPDIR/cert.pem" \
    -k "$KEYCHAIN" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -A
security import "$TMPDIR/key.pem" \
    -k "$KEYCHAIN" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -A

echo
echo "Done. '$CERT_NAME' is installed."
echo
echo "Next step: rebuild with ./scripts/install.sh"
echo "macOS may show a one-time 'codesign wants to access ...' dialog."
echo "Click \"Always Allow\" (NOT just Allow), then enter your login password."
