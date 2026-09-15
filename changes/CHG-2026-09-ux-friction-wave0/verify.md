# Verify — CHG-2026-09-ux-friction-wave0

| # | Check | Command | Result |
|---|-------|---------|--------|
| 1 | 核心术语表计数 | 脚本：`terminology-baseline.md` 中 `T-\d` 去重计数 | 19 / 期望 19 — **PASS** |
| 2 | 拆词/改词计数 | 脚本：`S-\d` 去重计数 | 10 / 期望 10 — **PASS** |
| 3 | 新词计数 | 脚本：`N-\d` 去重计数 | 10 / 期望 10 — **PASS** |
| 4 | 落点对齐清单计数 | 脚本：`4-A` 表格 `A-\d` 行计数 | 8 / 期望 8 — **PASS** |
| 5 | 开放项计数 | 脚本：`R-\d` 去重计数 | 6 / 期望 6 — **PASS** |
| 6 | finding → 契约 闭合复算 | 脚本：§8 六契约合计 | 40 / 去重后 40 / 重复 0 — **PASS** |
| 7 | finding → 波次 闭合复算 | 脚本：Wave1 14 + Wave2 11 + Wave3 15，与 §8 取差集 | 合计 40 / 漏 0 / 多 0 — **PASS** |
| 8 | 不变量 → 载体 闭合复算 | 脚本：§7 的 `I-\d` 提取 + 逐条载体映射 | 12/12，无缺载体 — **PASS** |
| 9 | S-1 双载体重载回源 | `sed -n '156,172p' LedgerTimelineView.swift` | 两个 overload 均 `return .archived`（`:162-163` 与 `:171-172`），与规格附录 A 的更正一致 — **PASS** |
| 10 | S-5 冲突行为回源 | `sed -n '777,795p' AtlasScaffoldWorkerService.swift` | 确认冲突时**自动重命名、不覆盖**；`failedMoves` 只收真失败，与冲突无关 — **PASS** |
| 11 | S-8 双落点回源 | `grep -rn 'fixture.permission\|infrastructure.permission'` | 两 key 均为真实落点（`AtlasPermissionInspector.swift:95-99` / `AtlasApplication.swift:123`）→ 记入 §4-B 并**报告**，未擅自调和 — **PASS（报告项）** |
| 12 | 占位符 | `grep -n 'TODO\|TBD\|XXX\|<待填' terminology-baseline.md` | 0 — **PASS** |
| 12b | **跨维一致性**：术语落点 → 波次 vs finding → 波次 | 脚本：10 条 `S-*` 的源 finding 波次 + 8 行 `4-A` 的 `Wave` 列与期望对撞 | 首轮 **抓到 1 处不一致**（`A-5` 标 Wave 2，而 `P2-2` 属 Wave 3）；已修，复算 18/18 全一致 — **PASS** |
| 13 | 三条门禁命令 | — | **不适用（NOT RUN）** —— 本 CHG 无代码改动，无增量可验 |
| 14 | 产品负责人签字 | — | **PASS（2026-09-14）** —— `Wave 0 术语基线通过，准予开 Wave 1`；R-1–R-6 逐项裁定 + D-012 显式确认，记录在 `requirement.md` 的 `## Contract Unfreeze Record` § 签字记录 1 |

**复算方式**：第 1–8 项由脚本执行（正则计数 + 集合差集），**非目测**。这是 `iteration-governance` Validation Gate「覆盖性逐维独立核验」的落实——finding→契约、finding→波次、不变量→载体**三维分别复算**，任一维 100% 不代言其他维。

## NOT RUN / 覆盖缺口（如实记录）

- **第 13 项不适用**：Wave 0 是纯决策，规格 §9 纪律第 2 条明文「只产出决策，不产出代码」。**不得**把「无代码可验」写成「门禁通过」。
- **第 14 项已完成**（2026-09-14 签字）。
- **未做**：本轮无子代理委派，全部结论第一手回源。

## Closed
2026-09-14 — Wave 0 完成并签字。术语基线定稿；Wave 1 依据该签字开工。本 CHG 无代码改动，第 13 项按 **NOT RUN（不适用）** 记录，**不计入通过**。
