# P1 — 文案门禁建立与现状基线

- **状态**：DONE（2026-09-15）
- **交付**：`scripts/atlas/copy-gate.sh` + `scripts/atlas/copy_gate.py`
- **产出**：现状红清单 263 条阻断（C1 217 / C2 7 / C3 3 / C4 36）+ 报告维（C5 310 / C8 9）

## 为什么门禁先行

待办列表由机器生成，而不是靠人读 1166 条文案。三条收益：

1. **完备**：规则覆盖到的都进列表，不存在「读漏了」
2. **可计数**：完成判据是「红 = 0」，不是「我觉得改完了」。契合仓库「收口用脚本计数而非目测」的纪律
3. **抗守卫空转**：规则即判据，不存在「断言看着对但实际没测到」的空间（对照 `REQ-ux-friction-remediation` 复审中被判定空转的 I-5/I-8/I-10/I-11）

## 命令矩阵

| 命令 | 判据 |
|---|---|
| `./scripts/atlas/copy-gate.sh` | 退出 0 + `ATLAS_COPY_GATE=PASS` |
| `./scripts/atlas/copy-gate.sh -v` | 逐条明细（人读） |
| `./scripts/atlas/copy-gate.sh --json` | 机器消费（上游门禁接入） |
| `./scripts/atlas/copy-gate.sh --only C1` | 单维复算 |

## 停止条件

阻断维归零即本阶段完成。报告维（C5/C8）**不阻塞**，见 `requirement.md` 不做项 N-1。
