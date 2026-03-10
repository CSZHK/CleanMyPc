#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/dist/native/Atlas-for-Mac.dmg}"
MOUNT_POINT="${MOUNT_POINT:-$ROOT_DIR/.build/atlas-dmg-verify/mount}"
INSTALL_ROOT="${INSTALL_ROOT:-$HOME}"
APP_NAME="Atlas for Mac.app"
SOURCE_APP_PATH="$MOUNT_POINT/$APP_NAME"
INSTALLED_APP_PATH="$INSTALL_ROOT/Applications/$APP_NAME"
INFO_PLIST="$INSTALLED_APP_PATH/Contents/Info.plist"
KEEP_INSTALLED_APP="${KEEP_INSTALLED_APP:-0}"

cleanup() {
  if mount | grep -q "on $MOUNT_POINT "; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  if [[ "$KEEP_INSTALLED_APP" != "1" && -d "$INSTALLED_APP_PATH" ]]; then
    python3 - "$INSTALLED_APP_PATH" <<'PY'
from pathlib import Path
import shutil, sys
app = Path(sys.argv[1])
if app.exists():
    shutil.rmtree(app)
PY
  fi
}
trap cleanup EXIT

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH" >&2
  exit 1
fi

python3 - "$MOUNT_POINT" <<'PY'
from pathlib import Path
import shutil, sys
mount_path = Path(sys.argv[1])
if mount_path.exists():
    shutil.rmtree(mount_path)
mount_path.mkdir(parents=True, exist_ok=True)
PY

mkdir -p "$INSTALL_ROOT/Applications"
hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

if [[ ! -d "$SOURCE_APP_PATH" ]]; then
  echo "Mounted app not found at $SOURCE_APP_PATH" >&2
  exit 1
fi

python3 - "$SOURCE_APP_PATH" "$INSTALLED_APP_PATH" <<'PY'
from pathlib import Path
import shutil, sys
src = Path(sys.argv[1])
dst = Path(sys.argv[2])
if dst.exists():
    shutil.rmtree(dst)
shutil.copytree(src, dst, symlinks=True)
PY

APP_DISPLAY_NAME=$(/usr/bin/defaults read "$INFO_PLIST" CFBundleDisplayName 2>/dev/null || echo "")
if [[ "$APP_DISPLAY_NAME" != "Atlas for Mac" ]]; then
  echo "Unexpected installed app display name: ${APP_DISPLAY_NAME:-<empty>}" >&2
  exit 1
fi

echo "DMG install validation succeeded"
echo "Installed app path: $INSTALLED_APP_PATH"
