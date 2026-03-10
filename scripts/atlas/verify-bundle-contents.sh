#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/native/Atlas for Mac.app}"
HELPER_PATH="$APP_PATH/Contents/Helpers/AtlasPrivilegedHelper"
XPC_PATH="$APP_PATH/Contents/XPCServices/AtlasWorkerXPC.xpc"
PLIST_PATH="$APP_PATH/Contents/Info.plist"
XPC_PLIST_PATH="$XPC_PATH/Contents/Info.plist"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi
if [[ ! -x "$HELPER_PATH" ]]; then
  echo "Helper not found or not executable: $HELPER_PATH" >&2
  exit 1
fi
if [[ ! -d "$XPC_PATH" ]]; then
  echo "Embedded XPC service missing: $XPC_PATH" >&2
  exit 1
fi
if [[ ! -f "$PLIST_PATH" ]]; then
  echo "Missing Info.plist: $PLIST_PATH" >&2
  exit 1
fi
if [[ ! -f "$XPC_PLIST_PATH" ]]; then
  echo "Missing XPC Info.plist: $XPC_PLIST_PATH" >&2
  exit 1
fi
if ! /usr/bin/codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1; then
  echo "App bundle failed codesign verification: $APP_PATH" >&2
  exit 1
fi

bundle_id=$(/usr/bin/defaults read "$PLIST_PATH" CFBundleIdentifier 2>/dev/null || true)
display_name=$(/usr/bin/defaults read "$PLIST_PATH" CFBundleDisplayName 2>/dev/null || true)
xpc_bundle_id=$(/usr/bin/defaults read "$XPC_PLIST_PATH" CFBundleIdentifier 2>/dev/null || true)

if [[ "$bundle_id" != "com.atlasformac.app" ]]; then
  echo "Unexpected bundle identifier: ${bundle_id:-<empty>}" >&2
  exit 1
fi
if [[ "$display_name" != "Atlas for Mac" ]]; then
  echo "Unexpected display name: ${display_name:-<empty>}" >&2
  exit 1
fi
if [[ "$xpc_bundle_id" != "com.atlasformac.app.worker" ]]; then
  echo "Unexpected XPC bundle identifier: ${xpc_bundle_id:-<empty>}" >&2
  exit 1
fi

echo "Bundle verification succeeded"
echo "App: $APP_PATH"
echo "Helper: $HELPER_PATH"
echo "XPC: $XPC_PATH"
