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

    # —— 零 UI 覆盖的三条路径，一律先于「是否通过」判定 ——
    # 顺序不可颠倒：先判「是否真的跑了」，再判「是否通过」。

    # (a) 配置缺陷导致的零覆盖 —— **不可豁免**。
    #     用例被改名 / `-only-testing` 目标写错时，`xcodebuild` 收集到 0 个用例却返回 0。
    if grep -q 'ATLAS_UI_GATE=ZERO_TESTS' "$atlas_log"; then
        local zero_log="${TMPDIR:-/tmp}/atlas-ui-automation-ZERO-TESTS.log"
        cp "$atlas_log" "$zero_log" 2>/dev/null || true
        echo "✗ UI automation executed ZERO tests — no UI-layer assertion ran. This is not a pass." >&2
        echo "  This is a configuration defect (target membership / -only-testing), not an environment limit," >&2
        echo "  so ATLAS_ALLOW_UI_SKIP does NOT apply. Log preserved at: $zero_log" >&2
        return 1
    fi

    # (b) 环境限制导致的跳过（AX 未授权）—— 可经显式豁免放行。
    #     判定用**机器可读哨兵**，不匹配人类可读英文句子：改一个词就会静默退回假绿。
    if grep -q 'ATLAS_UI_GATE=NOT_RUN' "$atlas_log"; then
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

    # (c) 环境级阻断（atlas 与独立 repro 双双 timeout）—— UI 层断言**零执行**。
    #     与 (b) 同属「环境限制导致零覆盖」，因此走**同一道**显式豁免闸，
    #     不得硬编码放行：否则 `ATLAS_ALLOW_UI_SKIP` 就成了唯一被认真对待的缺口。
    if grep -q 'Timed out while enabling automation mode' "$atlas_log" && grep -q 'Timed out while enabling automation mode' "$repro_log"; then
        if [[ "${ATLAS_ALLOW_UI_SKIP:-0}" == "1" ]]; then
            echo "⚠️  UI automation BLOCKED by the macOS automation environment (0 UI-layer assertions ran)"
            echo "    — explicitly allowed by ATLAS_ALLOW_UI_SKIP=1. This run's UI coverage is zero."
            return 0
        fi
        local blocked_log="${TMPDIR:-/tmp}/atlas-ui-automation-BLOCKED.log"
        cp "$atlas_log" "$blocked_log" 2>/dev/null || true
        echo "✗ UI automation BLOCKED by the macOS automation environment — no UI-layer assertion ran." >&2
        echo "  Both Atlas and the standalone repro timed out enabling automation mode," >&2
        echo "  so this is an environment condition, not an Atlas defect — but it is still zero UI coverage." >&2
        echo "  Log preserved at: $blocked_log" >&2
        echo "  Set ATLAS_ALLOW_UI_SKIP=1 to explicitly accept the coverage gap for this run." >&2
        return 1
    fi

    echo "UI automation failed for a reason that was not classified as a shared environment blocker."
    return 1
}

echo "[1/13] Shared package tests"
swift test --package-path Packages

echo "[2/13] App package tests"
swift test --package-path Apps

echo "[3/13] Worker and helper builds"
swift build --package-path XPC
swift test --package-path Helpers
swift build --package-path Testing

echo "[4/13] Copy gate (L10n 文案判据)"
# 判据源：Docs/COPY_GUIDELINES.md §6/§9 · REQ-copy-plain-language 的 terminology-baseline.md
# 阻断维全零才通过；报告维（孤儿键 / 长句）打印但不参与判定。
# 注意：NOT_RUN（文案源缺失）返回 2，**不是通过** —— 见 copy-gate.sh 的退出码语义。
./scripts/atlas/copy-gate.sh

echo "[5/13] README media assets gate (截图 判据)"
# 判据源：Docs/design/2026-09-15-readme-media-lifecycle.md
# 六维：存在性 / 尺寸 / 像素健康 / 引用完整性 / 漂移指纹 / 零孤儿。
# 纯 Python + 纯标准库，可移植，CI runner 上照样跑。
# 同样：NOT_RUN（清单或 README 缺失）返回 2，**不是通过** —— 见 readme-media-gate.sh。
# 报红时的解药是**一条命令**：./scripts/atlas/export-readme-assets.sh
./scripts/atlas/readme-media-gate.sh

echo "[6/13] Fixture automation scripts"
bash -n ./scripts/atlas/smart-clean-manual-fixtures.sh
bash -n ./scripts/atlas/apps-manual-fixtures.sh
bash -n ./scripts/atlas/apps-evidence-acceptance.sh

echo "[7/13] Native packaging"
./scripts/atlas/package-native.sh

echo "[8/13] Bundle structure verification"
./scripts/atlas/verify-bundle-contents.sh

echo "[9/13] DMG install verification"
KEEP_INSTALLED_APP=1 ./scripts/atlas/verify-dmg-install.sh

echo "[10/13] Installed app launch smoke"
./scripts/atlas/verify-app-launch.sh

echo "[11/13] Native UI automation"
run_ui_acceptance

echo "[12/13] Signing preflight"
./scripts/atlas/signing-preflight.sh || true

echo "[13/13] Acceptance summary"
echo "Artifacts available in dist/native"
ls -lah dist/native
