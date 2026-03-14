#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_FILE="$ROOT_DIR/project.yml"
APP_MODEL_FILE="$ROOT_DIR/Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift"
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"

usage() {
    cat << 'EOF'
Usage:
  ./scripts/atlas/prepare-release.sh <version> [build-number] [release-date]

Examples:
  ./scripts/atlas/prepare-release.sh 1.0.2
  ./scripts/atlas/prepare-release.sh 1.0.2 3
  ./scripts/atlas/prepare-release.sh 1.0.2 3 2026-03-14

Behavior:
  - updates MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.yml
  - updates AtlasApp fallback version/build strings
  - inserts a changelog section for the requested version if it does not already exist
EOF
}

if [[ $# -lt 1 || $# -gt 3 ]]; then
    usage >&2
    exit 1
fi

VERSION="$1"
BUILD_NUMBER="${2:-}"
RELEASE_DATE="${3:-$(date +%F)}"

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "Invalid version: $VERSION" >&2
    exit 1
fi

if [[ -n "$BUILD_NUMBER" && ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Build number must be numeric: $BUILD_NUMBER" >&2
    exit 1
fi

if [[ ! "$RELEASE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Release date must use YYYY-MM-DD: $RELEASE_DATE" >&2
    exit 1
fi

if [[ ! -f "$PROJECT_FILE" || ! -f "$APP_MODEL_FILE" || ! -f "$CHANGELOG_FILE" ]]; then
    echo "Expected release files are missing." >&2
    exit 1
fi

if [[ -z "$BUILD_NUMBER" ]]; then
    current_build="$(
        sed -n 's/.*CURRENT_PROJECT_VERSION: \([0-9][0-9]*\).*/\1/p' "$PROJECT_FILE" | head -1
    )"
    if [[ -z "$current_build" ]]; then
        echo "Could not determine current build number from project.yml" >&2
        exit 1
    fi
    BUILD_NUMBER="$((current_build + 1))"
fi

current_version="$(
    sed -n 's/.*MARKETING_VERSION: "\(.*\)"/\1/p' "$PROJECT_FILE" | head -1
)"

perl -0pi -e 's/MARKETING_VERSION: "[^"]+"/MARKETING_VERSION: "'"$VERSION"'"/g' "$PROJECT_FILE"
perl -0pi -e 's/CURRENT_PROJECT_VERSION: \d+/CURRENT_PROJECT_VERSION: '"$BUILD_NUMBER"'/g' "$PROJECT_FILE"
perl -0pi -e 's/(CFBundleShortVersionString"\] as\? String \?\? )"[^"]+"/${1}"'"$VERSION"'"/' "$APP_MODEL_FILE"
perl -0pi -e 's/(CFBundleVersion"\] as\? String \?\? )"[^"]+"/${1}"'"$BUILD_NUMBER"'"/' "$APP_MODEL_FILE"

if ! grep -Fq "## [$VERSION] - $RELEASE_DATE" "$CHANGELOG_FILE"; then
    tmpfile="$(mktemp "${TMPDIR:-/tmp}/atlas-changelog.XXXXXX")"
    awk -v version="$VERSION" -v date="$RELEASE_DATE" '
        BEGIN { inserted = 0 }
        {
            print
            if (!inserted && $0 == "## [Unreleased]") {
                print ""
                print "## [" version "] - " date
                print ""
                print "### Added"
                print ""
                print "### Changed"
                print ""
                print "### Fixed"
                print ""
                inserted = 1
            }
        }
    ' "$CHANGELOG_FILE" > "$tmpfile"
    mv "$tmpfile" "$CHANGELOG_FILE"
fi

printf 'Prepared Atlas release files\n'
printf 'Previous version: %s\n' "${current_version:-UNKNOWN}"
printf 'New version: %s\n' "$VERSION"
printf 'Build number: %s\n' "$BUILD_NUMBER"
printf 'Release date: %s\n' "$RELEASE_DATE"
printf 'Updated: %s\n' "$PROJECT_FILE"
printf 'Updated: %s\n' "$APP_MODEL_FILE"
printf 'Updated: %s\n' "$CHANGELOG_FILE"
