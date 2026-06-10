# Verify — CHG-2026-06-calm-ledger-m0m1

| # | Check | Command | Expected | Result |
|---|-------|---------|----------|--------|
| 1 | 治理工件齐备 | ls iterations/REQ-calm-ledger-redesign changes/CHG-2026-06-calm-ledger-m0m1 .agent | 3 处均存在对应文件 | PASS |
| 2 | 对比度门禁 | node scripts/design/contrast-check.mjs | `ALL PASS`，exit 0 | PASS（32 checks） |
| 3 | colorset 生成幂等 | node scripts/design/generate-colorsets.mjs && git status --porcelain Packages | 第二次运行无 diff | PASS |
| 4 | 包测试 | swift test --package-path Packages | 全绿（377 + M1 新增） | PASS（384 tests） |
| 5 | App 构建 | swift build --package-path Apps | Build complete! | PASS |
| 6 | 宋体 cascade | swift test --package-path Packages --filter AtlasDesignSystemTests.testLedgerFontCascadeResolvesSongtiForChinese | PASS（FAIL 即触发规格 §1.3 降级决策点，升级人审） | PASS |

注: rows 2/3/6 的被测物由计划 Task 8–10 创建；M0 边界仅 row 1 可运行。

## Closed
2026-06-10 — M0+M1 全部 verify PASS，评审（spec ×3 + quality ×3）全部 Approve；评审驱动修复 3 笔（411c166 / 9093995 / 2005359）。
