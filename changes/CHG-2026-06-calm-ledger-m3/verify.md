# Verify — CHG-2026-06-calm-ledger-m3

| # | Check | Command | Expected | Result |
|---|-------|---------|----------|--------|
| 1 | 包测试 | swift test --package-path Packages | 全绿 | 578/0 PASS |
| 2 | Apps 测试 | swift test --package-path Apps | 全绿 | 58/0 PASS |
| 3 | 对比度 | node scripts/design/contrast-check.mjs | ALL PASS | 36/36 PASS |
| 4 | App 构建 | swift build --package-path Apps | 0 新 warning | PASS（1 pre-existing: AtlasFileOrganizerScanner.swift:25 from 9aab570）|
| 5 | 路由改名残留 | grep route.history/\.history（非测试） | 0 | 0 PASS |
| 6 | 文件行数 | feature view ≤350 | 达标 | PASS（AppsFeatureView 341 max；OverviewRecommendation 361 纯 enum 非 View，已记治理解释）|
| 7 | rebase main | git rev-list HEAD..origin/main | 0 | 0 PASS（main 无新提交，no-op）|
| 8 | swift run 烟测 | swift run AtlasApp 5s | 无崩溃 | 延 M4 全量矩阵 |
| 9 | L2 深审 | — | APPROVE | 延 M4 终审（529 阻塞逐批审查）|

## Closed
2026-06-11 — M3 全屏幕迁移完成。8 屏 + 壳层全部 Calm Ledger 化；路由改名落地；裁决 A/B 严格遵循；恢复红线守住（restoreRecoveryItem 同一 API）。逐批审查：H/I/J/K/L1 APPROVE；L2/M 因 529 服务端过载由控制器收口，深审统一延 M4 终审。
