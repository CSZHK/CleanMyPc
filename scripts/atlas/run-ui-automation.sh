#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$ROOT_DIR"

# —— 「跳过」的机器可读哨兵 ——
# 消费方（`full-acceptance.sh`）**不得**靠匹配上面那句人类可读英文来判定跳过：
# 改一个词就会静默退回「假绿」。哨兵与判定都以本常量为唯一来源。
NOT_RUN_SENTINEL="ATLAS_UI_GATE=NOT_RUN"

if ! ./scripts/atlas/ui-automation-preflight.sh > /dev/null; then
    echo "Skipping native UI automation: Accessibility / automation permissions are not ready."
    echo "$NOT_RUN_SENTINEL reason=no-accessibility-permission"
    exit 0
fi

run_once() {
    pkill -f 'Atlas for Mac.app/Contents/MacOS/Atlas for Mac' > /dev/null 2>&1 || true
    pkill -f 'AtlasAppUITests-Runner|XCTRunner|xcodebuild test -project Atlas.xcodeproj -scheme AtlasApp' > /dev/null 2>&1 || true
    sleep 2

    xcodegen generate > /dev/null
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
        # —— 「跑了 0 个测试」不是「通过」——
        # `xcodebuild test` 在**收集到 0 个用例**时返回 0 并打印 `** TEST SUCCEEDED **`：
        # 用例被改名、或 `-only-testing` 目标写错，都会走到这里。此时 UI 层覆盖为零，
        # 而退出码看起来完全正常 —— 与 preflight 跳过同属「零覆盖却放行」。
        # 该类缺口**不可豁免**（它是配置缺陷，不是环境限制），故用独立哨兵。
        if grep -qE 'Executed 0 tests' "$LOG_FILE" || ! grep -qE 'Executed [1-9][0-9]* tests' "$LOG_FILE"; then
            echo "✗ UI automation executed ZERO tests — this is not a pass." >&2
            echo "  xcodebuild returns 0 when its selection collects no test cases." >&2
            echo "  Check the AtlasAppUITests target membership and the -only-testing filter." >&2
            echo "ATLAS_UI_GATE=ZERO_TESTS"
            exit 1
        fi
        exit 0
    fi

    if grep -q 'Timed out while enabling automation mode' "$LOG_FILE" && [[ "$attempt" -lt 2 ]]; then
        echo "UI automation timed out while enabling automation mode; retrying after cleanup..."
        sleep 3
        continue
    fi

    exit 1
done
