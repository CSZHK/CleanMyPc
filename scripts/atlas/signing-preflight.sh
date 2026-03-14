#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/atlas/signing-common.sh"

APP_IDENTITY_OVERRIDE="${ATLAS_CODESIGN_IDENTITY:-}"
INSTALLER_IDENTITY_OVERRIDE="${ATLAS_INSTALLER_SIGN_IDENTITY:-}"
NOTARY_PROFILE_OVERRIDE="${ATLAS_NOTARY_PROFILE:-}"
NOTARY_KEYCHAIN_OVERRIDE="${ATLAS_NOTARY_KEYCHAIN:-}"

codesign_output="$(security find-identity -v -p codesigning 2> /dev/null || true)"
basic_output="$(security find-identity -v -p basic 2> /dev/null || true)"

app_identity_detected="$(printf '%s\n' "$codesign_output" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)"
installer_identity_detected="$(printf '%s\n' "$basic_output" | sed -n 's/.*"\(Developer ID Installer:.*\)"/\1/p' | head -1)"

app_identity="${APP_IDENTITY_OVERRIDE:-$app_identity_detected}"
installer_identity="${INSTALLER_IDENTITY_OVERRIDE:-$installer_identity_detected}"
local_identity=""
if atlas_local_identity_exists; then
    local_identity="$(atlas_local_signing_identity_name)"
fi

printf 'Atlas signing preflight\n'
printf '======================\n'
printf 'Developer ID Application: %s\n' "${app_identity:-MISSING}"
printf 'Developer ID Installer:   %s\n' "${installer_identity:-MISSING}"
printf 'Notary profile:           %s\n' "${NOTARY_PROFILE_OVERRIDE:-MISSING}"
if [[ -n "$NOTARY_KEYCHAIN_OVERRIDE" ]]; then
    printf 'Notary keychain:          %s\n' "$NOTARY_KEYCHAIN_OVERRIDE"
fi
if [[ -n "$local_identity" ]]; then
    printf 'Stable local app identity: %s\n' "$local_identity"
else
    printf 'Stable local app identity: MISSING\n'
fi

status=0
if [[ -z "$app_identity" ]]; then
    echo '✗ Missing Developer ID Application identity'
    status=1
fi
if [[ -z "$installer_identity" ]]; then
    echo '✗ Missing Developer ID Installer identity'
    status=1
fi
if [[ -z "$NOTARY_PROFILE_OVERRIDE" ]]; then
    echo '✗ Missing notarytool keychain profile name in ATLAS_NOTARY_PROFILE'
    status=1
fi

if [[ -n "$NOTARY_PROFILE_OVERRIDE" ]]; then
    notarytool_args=(history --keychain-profile "$NOTARY_PROFILE_OVERRIDE")
    if [[ -n "$NOTARY_KEYCHAIN_OVERRIDE" ]]; then
        notarytool_args+=(--keychain "$NOTARY_KEYCHAIN_OVERRIDE")
    fi

    if xcrun notarytool "${notarytool_args[@]}" > /dev/null 2>&1; then
        echo '✓ notarytool profile is usable'
    else
        echo '✗ notarytool profile could not be validated'
        status=1
    fi
fi

if [[ $status -eq 0 ]]; then
    echo '✓ Release signing prerequisites are present'
    echo "export ATLAS_CODESIGN_IDENTITY='$app_identity'"
    echo "export ATLAS_INSTALLER_SIGN_IDENTITY='$installer_identity'"
    echo "export ATLAS_NOTARY_PROFILE='$NOTARY_PROFILE_OVERRIDE'"
else
    echo
    echo 'To unblock signed/notarized release packaging, provide or install:'
    echo '  1. Developer ID Application certificate'
    echo '  2. Developer ID Installer certificate'
    echo '  3. notarytool keychain profile name via ATLAS_NOTARY_PROFILE'
    if [[ -z "$local_identity" ]]; then
        echo
        echo 'For stable local TCC-friendly builds without Apple release credentials, run:'
        echo '  ./scripts/atlas/ensure-local-signing-identity.sh'
    fi
fi

exit $status
