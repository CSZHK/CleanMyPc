# Verify — CHG-2026-06-calm-ledger-m2

| # | Check | Command | Expected | Result |
|---|-------|---------|----------|--------|
| 1 | 包测试 | swift test --package-path Packages | 386 + 新增全绿，0 failures | PASS — Executed 411 tests, with 0 failures（Batch F 收口 400 + Batch G 新增 11：G1×2 / G2×2 / G3×2 / G4×2 / G5×2 / G6×1） |
| 2 | App 构建 | swift build --package-path Apps | Build complete! | PASS — Build complete!（AtlasScreen 插槽 + Toast 模型扩展后既有调用点零改动编译） |
| 3 | Apps 测试 | swift test --package-path Apps | 全绿（prework 已解锁） | PASS — Executed 29 tests, with 0 failures |
| 4 | 对比度 | node scripts/design/contrast-check.mjs | ALL PASS | PASS — 32 checks ALL PASS（colorset 集合不变 33；新增组件未引入新色对）。组件层自查补充：neutral→successFill 4.91:1 light（门禁对）/ 5.24:1 dark（手算）；banner rationale 白 85% 实测 4.42:1 <AA → 提至 90%（4.76:1） |
| 5 | L10n 键 | ds.* 键 zh/en 数量一致 | 一致 | PASS — zh 26 = en 26（19 存量 + 7 新增：ds.banner.dismiss / ds.toast.dismiss / ds.toast.open / ds.tone.×4） |
| 6 | 行数纪律 | 新组件文件均 ≤350 行 | 达标 | PASS — Batch G: LedgerSurface 96 / NextActionBanner 143 / ErrorState 167 / DataText 52；Batch F: StageBar 272 / EvidencePanel 281 / EvidenceModels 98 / ActionBar 193 / LedgerTimeline 255 / StampBadge 117 |

## Closed
2026-06-10 — M2 全部 verify PASS。Batch F（5 组件，commit 95c7b03 等 + 评审修复 3 笔，至 ea147dd）+ Batch G（4 组件 + AtlasScreen 插槽 + 修改清单，58839ec → 78ad788）。
偏离记录: ① banner rationale 白 85%→90%（AA 实测）；② AtlasEvidenceGroupCard 弃用标记落在 typealias（struct 直标会在 2 个 pre-M3 消费处产生 warning，实测验证后采用计划允许的 typealias 方案）；③ AtlasTone.neutral fill 映射 successFill（brand 与 safe 前景同色族，浅色同 hex；infoFill 会青蓝撞色）。
