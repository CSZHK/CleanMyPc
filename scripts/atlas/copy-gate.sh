#!/bin/bash
# Atlas 文案门禁 —— 薄包装，规则实现在 copy_gate.py。
#
# 退出码语义（门禁卫生规则：必须区分「跳过」与「通过」）：
#   0 = PASS（全绿）
#   1 = FAIL（有红条目，数目见哨兵 ATLAS_COPY_GATE=FAIL:N）
#   2 = NOT_RUN（文案源缺失 —— 这是配置缺陷，**不得计为通过**）
#
# 哨兵（机器可读，供 full-acceptance.sh 之类的上游消费）：
#   ATLAS_COPY_GATE=PASS | FAIL:N | NOT_RUN
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

exec python3 scripts/atlas/copy_gate.py "$@"
