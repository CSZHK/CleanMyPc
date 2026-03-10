#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Atlas.xcodeproj"
SCHEME="AtlasApp"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.build/atlas-native/DerivedData}"

if [[ -f "$ROOT_DIR/project.yml" ]]; then
  if command -v xcodegen >/dev/null 2>&1; then
    (cd "$ROOT_DIR" && xcodegen generate)
  elif [[ ! -d "$PROJECT_PATH" || "$ROOT_DIR/project.yml" -nt "$PROJECT_PATH/project.pbxproj" ]]; then
    echo "Atlas.xcodeproj is missing or stale, but xcodegen is not installed." >&2
    exit 1
  fi
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build
