#!/bin/bash
set -euo pipefail

require_env() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        echo "Missing required environment variable: $name" >&2
        exit 1
    fi
}

write_env() {
    local name="$1"
    local value="$2"

    if [[ -n "${GITHUB_ENV:-}" ]]; then
        printf '%s=%s\n' "$name" "$value" >> "$GITHUB_ENV"
    else
        printf 'export %s=%q\n' "$name" "$value"
    fi
}

append_keychain_search_list() {
    local keychain_path="$1"
    local current_keychains=()
    local line=""

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%\"}"
        line="${line#\"}"
        [[ -n "$line" ]] && current_keychains+=("$line")
    done < <(security list-keychains -d user 2> /dev/null || true)

    if printf '%s\n' "${current_keychains[@]}" | grep -Fx "$keychain_path" > /dev/null 2>&1; then
        return 0
    fi

    security list-keychains -d user -s "$keychain_path" "${current_keychains[@]}" > /dev/null
}

decode_base64_to_file() {
    local encoded="$1"
    local destination="$2"

    printf '%s' "$encoded" | base64 --decode > "$destination"
}

detect_identity() {
    local policy="$1"
    local prefix="$2"
    local keychain_path="$3"

    security find-identity -v -p "$policy" "$keychain_path" 2> /dev/null |
        sed -n "s/.*\"\\($prefix.*\\)\"/\\1/p" |
        head -1
}

require_env ATLAS_RELEASE_APP_CERT_P12_BASE64
require_env ATLAS_RELEASE_APP_CERT_P12_PASSWORD
require_env ATLAS_RELEASE_INSTALLER_CERT_P12_BASE64
require_env ATLAS_RELEASE_INSTALLER_CERT_P12_PASSWORD
require_env ATLAS_NOTARY_KEY_ID
require_env ATLAS_NOTARY_API_KEY_BASE64

KEYCHAIN_PATH="${ATLAS_RELEASE_KEYCHAIN_PATH:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/atlas-release.keychain-db}"
KEYCHAIN_PASSWORD="${ATLAS_RELEASE_KEYCHAIN_PASSWORD:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"
NOTARY_PROFILE="${ATLAS_NOTARY_PROFILE:-atlas-release}"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/atlas-release-signing.XXXXXX")"
cleanup() {
    rm -rf "$tmpdir"
}
trap cleanup EXIT

APP_CERT_PATH="$tmpdir/application-cert.p12"
INSTALLER_CERT_PATH="$tmpdir/installer-cert.p12"
NOTARY_KEY_PATH="$tmpdir/AuthKey.p8"

decode_base64_to_file "$ATLAS_RELEASE_APP_CERT_P12_BASE64" "$APP_CERT_PATH"
decode_base64_to_file "$ATLAS_RELEASE_INSTALLER_CERT_P12_BASE64" "$INSTALLER_CERT_PATH"
decode_base64_to_file "$ATLAS_NOTARY_API_KEY_BASE64" "$NOTARY_KEY_PATH"

if [[ -f "$KEYCHAIN_PATH" ]]; then
    rm -f "$KEYCHAIN_PATH"
fi

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" > /dev/null
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
append_keychain_search_list "$KEYCHAIN_PATH"

security import "$APP_CERT_PATH" \
    -k "$KEYCHAIN_PATH" \
    -P "$ATLAS_RELEASE_APP_CERT_P12_PASSWORD" \
    -f pkcs12 \
    -A \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/productbuild > /dev/null

security import "$INSTALLER_CERT_PATH" \
    -k "$KEYCHAIN_PATH" \
    -P "$ATLAS_RELEASE_INSTALLER_CERT_P12_PASSWORD" \
    -f pkcs12 \
    -A \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/productbuild > /dev/null

security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" > /dev/null

APP_IDENTITY="${ATLAS_CODESIGN_IDENTITY:-$(detect_identity codesigning 'Developer ID Application:' "$KEYCHAIN_PATH")}"
INSTALLER_IDENTITY="${ATLAS_INSTALLER_SIGN_IDENTITY:-$(detect_identity basic 'Developer ID Installer:' "$KEYCHAIN_PATH")}"

if [[ -z "$APP_IDENTITY" ]]; then
    echo "Developer ID Application identity was not imported successfully." >&2
    exit 1
fi

if [[ -z "$INSTALLER_IDENTITY" ]]; then
    echo "Developer ID Installer identity was not imported successfully." >&2
    exit 1
fi

notarytool_args=(
    store-credentials
    "$NOTARY_PROFILE"
    --key "$NOTARY_KEY_PATH"
    --key-id "$ATLAS_NOTARY_KEY_ID"
    --keychain "$KEYCHAIN_PATH"
    --validate
)

if [[ -n "${ATLAS_NOTARY_ISSUER_ID:-}" ]]; then
    notarytool_args+=(--issuer "$ATLAS_NOTARY_ISSUER_ID")
fi

xcrun notarytool "${notarytool_args[@]}" > /dev/null

write_env ATLAS_CODESIGN_KEYCHAIN "$KEYCHAIN_PATH"
write_env ATLAS_CODESIGN_IDENTITY "$APP_IDENTITY"
write_env ATLAS_INSTALLER_SIGN_IDENTITY "$INSTALLER_IDENTITY"
write_env ATLAS_NOTARY_PROFILE "$NOTARY_PROFILE"
write_env ATLAS_NOTARY_KEYCHAIN "$KEYCHAIN_PATH"

printf 'Configured Atlas release signing\n'
printf 'App identity: %s\n' "$APP_IDENTITY"
printf 'Installer identity: %s\n' "$INSTALLER_IDENTITY"
printf 'Notary profile: %s\n' "$NOTARY_PROFILE"
printf 'Keychain: %s\n' "$KEYCHAIN_PATH"
