#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$ROOT_DIR"

run_ui_acceptance() {
    local atlas_log repro_log rc=0
    atlas_log="$(mktemp -t atlas-ui-acceptance.XXXXXX.log)"
    repro_log="$(mktemp -t atlas-ui-repro.XXXXXX.log)"
    trap 'rm -f "$atlas_log" "$repro_log"' RETURN

    ./scripts/atlas/run-ui-automation.sh 2>&1 | tee "$atlas_log" || rc=$?

    # —— 「跳过」不是「通过」——
    # run-ui-automation.sh 在 AX 未授权时打印跳过标记并 `exit 0`。若在此把它当成功，
    # 全部 UI 层断言会静默不执行，而门禁照常放行（未授权环境下 UI 覆盖实际为零）。
    # 故先判「是否真的跑了」，再判「是否通过」——顺序不可颠倒。
    if grep -q 'Skipping native UI automation' "$atlas_log"; then
        if [[ "${ATLAS_ALLOW_UI_SKIP:-0}" == "1" ]]; then
            echo "⚠️  UI automation SKIPPED (NOT RUN) — explicitly allowed by ATLAS_ALLOW_UI_SKIP=1."
            echo "    UI-layer assertions did NOT execute; this run's UI coverage is zero."
            return 0
        fi
        local kept_log="${TMPDIR:-/tmp}/atlas-ui-automation-NOT-RUN.log"
        cp "$atlas_log" "$kept_log" 2>/dev/null || true
        echo "✗ UI automation SKIPPED (NOT RUN) — no UI-layer assertion executed. This is not a pass." >&2
        echo "  Cause: Accessibility permission is not granted to this process." >&2
        echo "  Log preserved at: $kept_log" >&2
        echo "  Fix one of:" >&2
        echo "    • grant Accessibility to your terminal (System Settings → Privacy & Security → Accessibility)" >&2
        echo "    • set ATLAS_ALLOW_UI_SKIP=1 to explicitly accept the coverage gap for this run" >&2
        return 1
    fi

    if [[ "$rc" -eq 0 ]]; then
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

echo "[1/11] Shared package tests"
swift test --package-path Packages

echo "[2/11] App package tests"
swift test --package-path Apps

echo "[3/11] Worker and helper builds"
swift build --package-path XPC
swift test --package-path Helpers
swift build --package-path Testing

echo "[4/11] Fixture automation scripts"
bash -n ./scripts/atlas/smart-clean-manual-fixtures.sh
bash -n ./scripts/atlas/apps-manual-fixtures.sh
bash -n ./scripts/atlas/apps-evidence-acceptance.sh

echo "[5/11] Native packaging"
./scripts/atlas/package-native.sh

echo "[6/11] Bundle structure verification"
./scripts/atlas/verify-bundle-contents.sh

echo "[7/11] DMG install verification"
KEEP_INSTALLED_APP=1 ./scripts/atlas/verify-dmg-install.sh

echo "[8/11] Installed app launch smoke"
./scripts/atlas/verify-app-launch.sh

echo "[9/11] Native UI automation"
run_ui_acceptance

echo "[10/11] Signing preflight"
./scripts/atlas/signing-preflight.sh || true

echo "[11/11] Acceptance summary"
echo "Artifacts available in dist/native"
ls -lah dist/native
