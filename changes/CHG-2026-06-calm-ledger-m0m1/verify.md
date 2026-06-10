# Verify — CHG-2026-06-calm-ledger-m0m1

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | 治理工件齐备 | ls iterations/REQ-calm-ledger-redesign changes/CHG-2026-06-calm-ledger-m0m1 .agent | 3 处均存在对应文件 |
| 2 | 对比度门禁 | node scripts/design/contrast-check.mjs | `ALL PASS`，exit 0 |
| 3 | colorset 生成幂等 | node scripts/design/generate-colorsets.mjs && git status --porcelain Packages | 第二次运行无 diff |
| 4 | 包测试 | swift test --package-path Packages | 全绿（377 + M1 新增） |
| 5 | App 构建 | swift build --package-path Apps | Build complete! |
| 6 | 宋体 cascade | swift test --package-path Packages --filter AtlasDesignSystemTests.testLedgerFontCascade | PASS（FAIL 即触发规格 §1.3 降级决策点，升级人审） |
