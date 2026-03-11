#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/atlas/signing-common.sh"

KEYCHAIN_PATH="$(atlas_local_signing_keychain_path)"
KEYCHAIN_PASSWORD="$(atlas_local_signing_keychain_password)"
IDENTITY_NAME="$(atlas_local_signing_identity_name)"
VALID_DAYS="${ATLAS_LOCAL_SIGNING_VALID_DAYS:-3650}"
P12_PASSWORD="${ATLAS_LOCAL_SIGNING_P12_PASSWORD:-atlas-local-signing-p12}"

if atlas_local_identity_usable; then
    atlas_unlock_local_signing_keychain
    printf 'Atlas local signing identity ready\n'
    printf 'Identity: %s\n' "$IDENTITY_NAME"
    printf 'Keychain: %s\n' "$KEYCHAIN_PATH"
    exit 0
fi

if [[ -f "$KEYCHAIN_PATH" ]]; then
    rm -f "$KEYCHAIN_PATH"
fi

mkdir -p "$(dirname "$KEYCHAIN_PATH")"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/atlas-local-signing.XXXXXX")"
cleanup() {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

cat > "$tmpdir/openssl.cnf" << EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $IDENTITY_NAME
[ ext ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

/usr/bin/openssl req \
    -new \
    -x509 \
    -nodes \
    -newkey rsa:2048 \
    -days "$VALID_DAYS" \
    -keyout "$tmpdir/identity.key" \
    -out "$tmpdir/identity.crt" \
    -config "$tmpdir/openssl.cnf" > /dev/null 2>&1

/usr/bin/openssl pkcs12 \
    -export \
    -inkey "$tmpdir/identity.key" \
    -in "$tmpdir/identity.crt" \
    -out "$tmpdir/identity.p12" \
    -passout "pass:$P12_PASSWORD" > /dev/null 2>&1

if [[ ! -f "$KEYCHAIN_PATH" ]]; then
    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" > /dev/null
fi

security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security import "$tmpdir/identity.p12" \
    -k "$KEYCHAIN_PATH" \
    -P "$P12_PASSWORD" \
    -f pkcs12 \
    -A \
    -T /usr/bin/codesign \
    -T /usr/bin/security > /dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" > /dev/null
atlas_unlock_local_signing_keychain

if ! atlas_local_identity_usable; then
    echo "Failed to provision local Atlas signing identity." >&2
    exit 1
fi

printf 'Created Atlas local signing identity\n'
printf 'Identity: %s\n' "$IDENTITY_NAME"
printf 'Keychain: %s\n' "$KEYCHAIN_PATH"
printf 'Use: ./scripts/atlas/package-native.sh\n'
