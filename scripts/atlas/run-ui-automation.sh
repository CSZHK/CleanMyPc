#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$ROOT_DIR"

if ! ./scripts/atlas/ui-automation-preflight.sh >/dev/null; then
  echo "Skipping native UI automation: Accessibility / automation permissions are not ready."
  exit 0
fi

run_once() {
  pkill -f 'Atlas for Mac.app/Contents/MacOS/Atlas for Mac' >/dev/null 2>&1 || true
  pkill -f 'AtlasAppUITests-Runner|XCTRunner|xcodebuild test -project Atlas.xcodeproj -scheme AtlasApp' >/dev/null 2>&1 || true
  sleep 2

  xcodegen generate >/dev/null
  xcodebuild test \
    -project Atlas.xcodeproj \
    -scheme AtlasApp \
    -destination 'platform=macOS' \
    -only-testing:AtlasAppUITests
}

LOG_FILE="$(mktemp -t atlas-ui-automation.XXXXXX.log)"
trap 'rm -f "$LOG_FILE"' EXIT

for attempt in 1 2; do
  echo "UI automation attempt $attempt/2"
  if run_once 2>&1 | tee "$LOG_FILE"; then
    exit 0
  fi

  if grep -q 'Timed out while enabling automation mode' "$LOG_FILE" && [[ "$attempt" -lt 2 ]]; then
    echo "UI automation timed out while enabling automation mode; retrying after cleanup..."
    sleep 3
    continue
  fi

  exit 1
done
