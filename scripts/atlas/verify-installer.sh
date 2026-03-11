#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PKG_PATH="${PKG_PATH:-$ROOT_DIR/dist/native/Atlas-for-Mac.pkg}"
INSTALL_ROOT="${INSTALL_ROOT:-$HOME}"
APP_PATH="$INSTALL_ROOT/Applications/Atlas for Mac.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
KEEP_INSTALLED_APP="${KEEP_INSTALLED_APP:-0}"

cleanup() {
    if [[ "$KEEP_INSTALLED_APP" != "1" && -d "$APP_PATH" ]]; then
        python3 - << 'PY'
from pathlib import Path
import shutil, os
app = Path(os.environ['APP_PATH'])
if app.exists():
    shutil.rmtree(app)
PY
    fi
}
trap cleanup EXIT

if [[ ! -f "$PKG_PATH" ]]; then
    echo "Installer package not found: $PKG_PATH" >&2
    exit 1
fi

mkdir -p "$INSTALL_ROOT/Applications"
installer -allowUntrusted -pkg "$PKG_PATH" -target CurrentUserHomeDirectory > /dev/null

if [[ ! -d "$APP_PATH" ]]; then
    echo "Installed app not found at $APP_PATH" >&2
    exit 1
fi

APP_DISPLAY_NAME=$(/usr/bin/defaults read "$INFO_PLIST" CFBundleDisplayName 2> /dev/null || echo "")
if [[ "$APP_DISPLAY_NAME" != "Atlas for Mac" ]]; then
    echo "Unexpected installed app display name: ${APP_DISPLAY_NAME:-<empty>}" >&2
    exit 1
fi

echo "Installer validation succeeded"
echo "Installed app path: $APP_PATH"
