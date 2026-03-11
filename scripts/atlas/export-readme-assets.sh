#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="${1:-$ROOT_DIR/Docs/Media/README}"

mkdir -p "$OUTPUT_DIR"

ATLAS_EXPORT_README_ASSETS_DIR="$OUTPUT_DIR" \
swift run --package-path "$ROOT_DIR/Apps" AtlasApp

echo "README assets exported to: $OUTPUT_DIR"
