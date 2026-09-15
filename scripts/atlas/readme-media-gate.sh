#!/bin/bash
# Atlas README 媒体资产门禁 —— 薄包装，规则实现在 readme_media_gate.py。
#
# 六维：存在性 / 尺寸 / 像素健康 / 引用完整性 / 漂移指纹 / 零孤儿。
#
# 退出码语义（与 copy-gate.sh 一致，见迭代治理「门禁卫生规则」）：
#   0 = PASS
#   1 = FAIL（红条目数见哨兵 ATLAS_README_MEDIA_GATE=FAIL:N）
#   2 = NOT_RUN（清单或 README 缺失 —— 这是配置缺陷，**不得计为通过**）
#
# 哨兵（机器可读，供 full-acceptance.sh 之类的上游消费）：
#   ATLAS_README_MEDIA_GATE=PASS | FAIL:N | NOT_RUN
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

exec python3 scripts/atlas/readme_media_gate.py "$@"
