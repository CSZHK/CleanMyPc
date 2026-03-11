#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/atlas/signing-common.sh"

DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/native}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/atlas-native/DerivedData}"
APP_NAME="Atlas for Mac.app"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME"
HELPER_BINARY="$ROOT_DIR/Helpers/.build/release/AtlasPrivilegedHelper"
ZIP_PATH="$DIST_DIR/Atlas-for-Mac.zip"
DMG_PATH="$DIST_DIR/Atlas-for-Mac.dmg"
PKG_PATH="$DIST_DIR/Atlas-for-Mac.pkg"
SHA_PATH="$DIST_DIR/Atlas-for-Mac.sha256"
PACKAGED_APP_PATH="$DIST_DIR/$APP_NAME"
DMG_STAGING_DIR="$DIST_DIR/dmg-root"
REQUESTED_APP_SIGN_IDENTITY="${ATLAS_CODESIGN_IDENTITY:-}"
APP_SIGN_IDENTITY="$(atlas_resolve_app_signing_identity)"
APP_SIGNING_KEYCHAIN="$(atlas_resolve_app_signing_keychain "$APP_SIGN_IDENTITY")"
APP_SIGNING_MODE="$(atlas_signing_mode_for_identity "$APP_SIGN_IDENTITY")"
INSTALLER_SIGN_IDENTITY="$(atlas_resolve_installer_signing_identity)"
NOTARY_PROFILE="${ATLAS_NOTARY_PROFILE:-}"

mkdir -p "$DIST_DIR"

sign_app_component() {
    local path="$1"
    local args=(--force --sign "$APP_SIGN_IDENTITY")
    local entitlements_file=""

    if [[ -n "$APP_SIGNING_KEYCHAIN" ]]; then
        args+=(--keychain "$APP_SIGNING_KEYCHAIN")
    fi

    if [[ "$APP_SIGNING_MODE" == "developer-id" ]]; then
        args+=(--options runtime --timestamp)
    fi

    entitlements_file="$(mktemp "${TMPDIR:-/tmp}/atlas-entitlements.XXXXXX")"
    if /usr/bin/codesign -d --entitlements :- "$path" > "$entitlements_file" 2> /dev/null && /usr/bin/grep -q '<plist' "$entitlements_file"; then
        args+=(--entitlements "$entitlements_file")
    else
        rm -f "$entitlements_file"
        entitlements_file=""
    fi

    codesign "${args[@]}" "$path"

    if [[ -n "$entitlements_file" ]]; then
        rm -f "$entitlements_file"
    fi
}

if [[ -n "$APP_SIGNING_KEYCHAIN" ]]; then
    atlas_unlock_local_signing_keychain
fi

printf 'App signing identity: %s (%s)\n' "$APP_SIGN_IDENTITY" "$APP_SIGNING_MODE"
if [[ -n "$APP_SIGNING_KEYCHAIN" ]]; then
    printf 'App signing keychain: %s\n' "$APP_SIGNING_KEYCHAIN"
fi
printf 'Installer signing identity: %s\n' "${INSTALLER_SIGN_IDENTITY:-UNSIGNED}"

swift build --package-path "$ROOT_DIR/Helpers" -c release
"$ROOT_DIR/scripts/atlas/build-native.sh"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Built app not found at $APP_PATH" >&2
    exit 1
fi

python3 - "$PACKAGED_APP_PATH" "$DMG_STAGING_DIR" "$DMG_PATH" << 'PY'
from pathlib import Path
import shutil, sys
for raw in sys.argv[1:]:
    path = Path(raw)
    if path.exists():
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()
PY

cp -R "$APP_PATH" "$PACKAGED_APP_PATH"
mkdir -p "$PACKAGED_APP_PATH/Contents/Helpers"
cp "$HELPER_BINARY" "$PACKAGED_APP_PATH/Contents/Helpers/AtlasPrivilegedHelper"
chmod +x "$PACKAGED_APP_PATH/Contents/Helpers/AtlasPrivilegedHelper"

while IFS= read -r xpc; do
    sign_app_component "$xpc"
done < <(find "$PACKAGED_APP_PATH/Contents/XPCServices" -maxdepth 1 -name '*.xpc' -type d 2> /dev/null | sort)
sign_app_component "$PACKAGED_APP_PATH/Contents/Helpers/AtlasPrivilegedHelper"
sign_app_component "$PACKAGED_APP_PATH"
codesign --verify --deep --strict --verbose=2 "$PACKAGED_APP_PATH"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PACKAGED_APP_PATH" "$ZIP_PATH"

mkdir -p "$DMG_STAGING_DIR"
cp -R "$PACKAGED_APP_PATH" "$DMG_STAGING_DIR/$APP_NAME"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create -volname "Atlas for Mac" -srcfolder "$DMG_STAGING_DIR" -ov -format UDZO "$DMG_PATH" > /dev/null

productbuild_args=(--component "$PACKAGED_APP_PATH" /Applications "$PKG_PATH")
if [[ -n "$INSTALLER_SIGN_IDENTITY" ]]; then
    productbuild_args=(--sign "$INSTALLER_SIGN_IDENTITY" --component "$PACKAGED_APP_PATH" /Applications "$PKG_PATH")
fi
/usr/bin/productbuild "${productbuild_args[@]}"

(
    cd "$DIST_DIR"
    /usr/bin/shasum -a 256 \
        "$(basename "$ZIP_PATH")" \
        "$(basename "$DMG_PATH")" \
        "$(basename "$PKG_PATH")" > "$SHA_PATH"
)

echo "Packaged app: $PACKAGED_APP_PATH"
echo "Zip artifact: $ZIP_PATH"
echo "DMG artifact: $DMG_PATH"
echo "Installer package: $PKG_PATH"
echo "Checksums: $SHA_PATH"

if [[ -n "$NOTARY_PROFILE" && "$APP_SIGNING_MODE" == "developer-id" && -n "$INSTALLER_SIGN_IDENTITY" ]]; then
    xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PKG_PATH"
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PACKAGED_APP_PATH"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PACKAGED_APP_PATH" "$ZIP_PATH"
    (
        cd "$DIST_DIR"
        /usr/bin/shasum -a 256 \
            "$(basename "$ZIP_PATH")" \
            "$(basename "$DMG_PATH")" \
            "$(basename "$PKG_PATH")" > "$SHA_PATH"
    )
    echo "Notarization complete"
fi
