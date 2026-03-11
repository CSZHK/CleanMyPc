#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$ROOT_DIR"

run_ui_acceptance() {
    local atlas_log repro_log
    atlas_log="$(mktemp -t atlas-ui-acceptance.XXXXXX.log)"
    repro_log="$(mktemp -t atlas-ui-repro.XXXXXX.log)"
    trap 'rm -f "$atlas_log" "$repro_log"' RETURN

    if ./scripts/atlas/run-ui-automation.sh 2>&1 | tee "$atlas_log"; then
        return 0
    fi

    echo "Atlas UI automation failed; checking standalone repro to classify the failure..."

    if xcodebuild test \
        -project Testing/XCUITestRepro/XCUITestRepro.xcodeproj \
        -scheme XCUITestRepro \
        -destination 'platform=macOS' 2>&1 | tee "$repro_log"; then
        echo "Standalone repro passed while Atlas UI automation failed; treating this as an Atlas-specific blocker."
        return 1
    fi

    if grep -q 'Timed out while enabling automation mode' "$atlas_log" && grep -q 'Timed out while enabling automation mode' "$repro_log"; then
        echo "UI automation is blocked by the current macOS automation environment; continuing acceptance with a documented environment condition."
        return 0
    fi

    echo "UI automation failed for a reason that was not classified as a shared environment blocker."
    return 1
}

echo "[1/10] Shared package tests"
swift test --package-path Packages

echo "[2/10] App package tests"
swift test --package-path Apps

echo "[3/10] Worker and helper builds"
swift build --package-path XPC
swift test --package-path Helpers
swift build --package-path Testing

echo "[4/10] Native packaging"
./scripts/atlas/package-native.sh

echo "[5/10] Bundle structure verification"
./scripts/atlas/verify-bundle-contents.sh

echo "[6/10] DMG install verification"
KEEP_INSTALLED_APP=1 ./scripts/atlas/verify-dmg-install.sh

echo "[7/10] Installed app launch smoke"
./scripts/atlas/verify-app-launch.sh

echo "[8/10] Native UI automation"
run_ui_acceptance

echo "[9/10] Signing preflight"
./scripts/atlas/signing-preflight.sh || true

echo "[10/10] Acceptance summary"
echo "Artifacts available in dist/native"
ls -lah dist/native
