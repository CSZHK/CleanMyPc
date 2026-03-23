#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"

usage() {
    cat << 'EOF'
Usage:
  ./scripts/atlas/generate-release-body.sh <version> <packaging-mode> [output-file]

Examples:
  ./scripts/atlas/generate-release-body.sh 1.0.3 development
  ./scripts/atlas/generate-release-body.sh 1.0.3 developer-id /tmp/RELEASE_BODY.md
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage >&2
    exit 1
fi

VERSION="$1"
PACKAGING_MODE="$2"
OUTPUT_FILE="${3:-$ROOT_DIR/RELEASE_BODY.md}"

if [[ ! -f "$CHANGELOG_FILE" ]]; then
    echo "Missing changelog: $CHANGELOG_FILE" >&2
    exit 1
fi

if [[ "$PACKAGING_MODE" != "development" && "$PACKAGING_MODE" != "developer-id" ]]; then
    echo "Unsupported packaging mode: $PACKAGING_MODE" >&2
    exit 1
fi

extract_changelog_section() {
    local version="$1"
    awk -v version="$version" '
        $0 ~ "^## \\[" version "\\] - " {
            printing = 1
        }
        printing {
            if ($0 ~ "^## \\[" version "\\] - ") {
                print "# Atlas for Mac " version
                print ""
                next
            }
            if ($0 ~ "^## \\[" && $0 !~ "^## \\[" version "\\] - ") {
                exit
            }
            print
        }
    ' "$CHANGELOG_FILE"
}

CHANGELOG_SECTION="$(extract_changelog_section "$VERSION")"

if [[ -z "${CHANGELOG_SECTION//[$'\n\r\t ']/}" ]]; then
    {
        echo "# Atlas for Mac $VERSION"
        echo
        echo "Release notes for this version were not found in CHANGELOG.md."
    } > "$OUTPUT_FILE"
else
    printf '%s\n' "$CHANGELOG_SECTION" > "$OUTPUT_FILE"
fi

{
    echo
    echo "## Packaging Status"
    echo
    if [[ "$PACKAGING_MODE" == "development" ]]; then
        echo "Native macOS assets in this tag were packaged in development mode because Developer ID release-signing credentials were not configured for this run."
        echo
        echo "These \`.zip\`, \`.dmg\`, and \`.pkg\` files are intended for internal testing or developer use. macOS Gatekeeper may require \`Open Anyway\` or a right-click \`Open\` flow before launch."
    else
        echo "Native macOS assets in this tag were packaged in CI using Developer ID signing and notarization, then uploaded alongside the existing command-line release artifacts."
    fi
} >> "$OUTPUT_FILE"

printf 'Generated release body for %s (%s) at %s\n' "$VERSION" "$PACKAGING_MODE" "$OUTPUT_FILE"
