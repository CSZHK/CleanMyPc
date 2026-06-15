# PER: Calm Ledger branch-review 修复（全部问题）

**Status:** COMPLETED
**Created:** 2026-06-11
**Scope:** branch review（main..HEAD）发现的 P1 token 纪律违规（5 处裸字号）
**Dimension:** 全量 · 深度: 标准（P1 本轮修；P2 carry-forward；pre-existing 不动）
**Source:** branch review（.agent/per-calm-ledger-complete-execplan.md M4 closeout 后的 /review branch）

## Progress
- [x] Phase 1: 范围确认（branch review findings，P1 only 本轮）
- [x] Phase 2: 证据链核实（5 处 grep 已确认，本轮读上下文定 token 映射）
- [x] Phase 3: 实施修复（5 处裸字号 → AtlasTypography token）
- [x] Phase 4: 回归验证（build + test + contrast）
- [x] Phase 5: 收口总结

## Backlog
| # | Severity | File:Line | Description | Status |
|---|----------|-----------|-------------|--------|
| 1 | P1 | FileOrganizerStageViews.swift:265 | `.font(.system(size: 18))` 裸字号 → token | FIXED |
| 2 | P1 | FileOrganizerSupportViews.swift:37 | `.font(.system(size: 14))` 裸字号 → token | FIXED |
| 3 | P1 | FileOrganizerSupportViews.swift:160 | `.font(.system(size: 11, weight: .bold))` → caption token | FIXED |
| 4 | P1 | OverviewCommandColumn.swift:139 | `.font(.system(size: 16, weight: .medium))` → token | FIXED |
| 5 | P1 | SmartCleanSupportViews.swift:100 | `.font(.system(size: 11, weight: .bold))` → caption token | FIXED |

## Carry-Forward（P2，本轮不修）
| # | Severity | Description | Next Step |
|---|----------|-------------|-----------|
| C1 | P2 | AppShellView 647 行（壳层协调器偏大，本分支引入） | 可拆 workflowState/构造点到独立文件；功能正确非阻塞 |
| C2 | P2 | SettingsFeatureView 382 / SmartCleanFeatureView 367 略超 350 | M 换装/I 评审修复导致；已知接受或轻微 |
| C3 | P2 | FileOrganizerRuleEditorView 496 行 + print(:90) | pre-existing（main 带来，L2 未重写）；不动 |

## Decision Log
- 2026-06-11: PER 硬约束「不修 P2+」——用户「全部问题」在 PER 框架下 = 本轮修 P1（token 纪律），P2 行数超限记 carry-forward（C1/C2 本分支引入可后续拆，C3 pre-existing 不动）。Infrastructure 守卫（PER#8 已批准）非问题不动。
