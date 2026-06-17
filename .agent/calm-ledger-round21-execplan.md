# PER: Calm Ledger Round-21 全量验收（review→fix→verify，零 P2+）

**Status:** COMPLETED
**Created:** 2026-06-17
**Closed:** 2026-06-17（commit b7442e3，本地未 push）
**Scope:** `redesign/calm-ledger` 全部未 push 提交（origin/main..HEAD = 98 commits / 181 文件 / +19,466）
**Dimension:** 全量 · 深度: 穷尽（P0+P1+P2 全修，P3 carry-forward）
**Source:** 用户指令「全量功能 case 验收，包括 UI 交互 case；审查未 push 提交，修复验收，确保没有 p2 以及以上 bug」
**Plan:** `/Users/zhukang/.claude/plans/case-ui-case-push-p2-bug-enumerated-boot.md`

## 约束（用户已确认）
- UI 交互 case 深度 = 穷尽式代码审查（14 维 bug 分类）+ 现有 4 个 XCUI 用例 + `swift run` 冒烟。沿用 round 1–20 打法。
- 提交 = 本地 commit（round-N 模式），**不 push**。
- 只修 P0/P1/P2；P3 记 carry-forward。
- 命中 UC/INV/CONTRACT/infra → 升级给人。

## Phase A — 基线门禁（2026-06-17）✓ GREEN
- `swift test --package-path Packages` → **595/0**
- `swift test --package-path Apps` → **62/0**
- `swift test --package-path Helpers` → **3/0**
- `node scripts/design/contrast-check.mjs` → **36/36 ALL PASS**
- `make`（Go analyze/status）→ built
- `swift build --package-path Apps` → Build complete，0 新 warning
- `swift run --package-path Apps AtlasApp` 冒烟 → **BOOT_OK**（>25s 无崩，无 crash 签名）

**回归基线：Packages 595 · Apps 62 · Helpers 3 · contrast 36。**

## Phase B — 穷尽式 review（Workflow 扇出 + 对抗验证）✓
- Workflow `wf_e45b63d5-055`（10 surface × 14 维 review + 对抗验证，43 agents / 1.79M tok）。
- 失败 2 agent（429）：`review:overview` 全失 + `verify:appshell:D1` 丢 1 票 → 主循环直读 Overview(4 文件 clean) + SmartClean gap 复核补 1 个 execute-progress P2。
- critic 3 盲区（filter/total 耦合、re-scan 状态漂移、render-IO）→ 全部处置（见 findings）。
- 结论：**0 P0 / 0 P1 / 11 P2**（+ gap 补 1 = 12 P2 修复）+ 2 P3 carry-forward。

## Phase C — 修复（commit b7442e3，12 P2 全修 + 1 回归测试）✓
按根因聚类全部修复（详见 round21-findings.md）：
- 指标诚实(D4/D9)：Apps 库存读全量、Settings 恢复区读未过滤总量、Ledger 可恢复项排除 expired。
- a11y/触达(D3/D7)：FO 规则编辑器三键 44pt、SegmentedControl minHeight 44、FilterChip VO 计数本地化(+ds.chip.count)。
- FileOrganizer(D4/D14/D1)：execute 环不再回显 stale scanProgress(同修 SmartClean)、conflictingEntryIDs 移出 render body 入异步 .task、re-scan 清 planNumber/receipt 使 gating 重分配。
- 回执/证据(D12/D9)：导出 entries 纳入 recovery items(带 bytes+expired 状态)、权限状态 KV 行改「状态」label(+permissions.evidence.section.status)。
- 回归测试：LedgerModelTests 新增 testExportBuilderListsRecoveryItemsWithBytesAndStatus。

## Phase D — 终态门禁 ✓（2026-06-17）
- `swift test --package-path Packages` → **596/0**（基线 595 + 1 新回归测试）
- `swift test --package-path Apps` → **62/0**
- `swift test --package-path Helpers` → **3/0**
- `node scripts/design/contrast-check.mjs` → **36/36 ALL PASS**
- `swift build --package-path Apps` → 0 新 warning
- `swift run --package-path Apps AtlasApp` 冒烟 → **BOOT_OK**
- 本地 commit b7442e3，**未 push**（`git log origin/main..HEAD` = 99 = 98 + round-21）。

## Backlog（confirmed 12 P2，全 FIXED）
| # | Sev | Dim | File | Fix | Status |
|---|-----|-----|------|-----|--------|
| 1 | P2 | D4 | AppsFeatureView:135 | 库存卡读全量不过滤 | FIXED |
| 2 | P2 | D9 | SettingsFeatureView:169 (AppShellView:397) | 恢复区读未过滤总量 | FIXED |
| 3 | P2 | D4 | LedgerFeatureView:115 | 可恢复项排除 expired | FIXED |
| 4 | P2 | D3 | FileOrganizerRuleEditorView:207 | 三键 44pt frame | FIXED |
| 5 | P2 | D3 | AtlasSegmentedControl:31 | minHeight 44 | FIXED |
| 6 | P2 | D7 | AtlasFilterChip:72 | VO 计数本地化 | FIXED |
| 7 | P2 | D4 | FileOrganizerStageViews:480 | execute 环不回显 stale | FIXED |
| 8 | P2 | D4 | SmartCleanStageViews:294 | (同 7，gap 补) | FIXED |
| 9 | P2 | D14 | FileOrganizerEvidenceBuilder:126 (FeatureView) | conflictingEntryIDs 异步缓存 | FIXED |
| 10 | P2 | D1 | AtlasAppModel (runFileOrganizerScan) | re-scan 清 №/receipt 重分配 | FIXED |
| 11 | P2 | D12 | LedgerExportBuilder:151 | 导出纳入 recovery items | FIXED |
| 12 | P2 | D9 | PermissionEvidenceBuilder:48 | 状态行改 status label | FIXED |

## Carry-Forward（P3，本轮不修，已记录）
- C1 LedgerFeatureView:219 — 导出忽略 active filter（承诺「当前可见」却导出全量）。
- C2 Localizable.strings — 6 个 history→ledger 改名残留孤儿键（零 swift 引用，parity 完好，无可见缺陷）。

## 完成判据 ✓
- 客观门禁复跑全绿（596+62+3 / contrast 36 / build 0 warning / smoke BOOT_OK）。
- confirmed[] 12 条 P2 全 FIXED + 回归测试 + 复测通过。
- 本地 commit，未 push（99 commits vs origin/main）。
