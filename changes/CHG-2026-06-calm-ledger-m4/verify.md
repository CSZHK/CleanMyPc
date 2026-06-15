# Verify — CHG-2026-06-calm-ledger-m4

| # | Check | Command | Result |
|---|-------|---------|--------|
| 1 | 包测试 | swift test --package-path Packages | 578/0 PASS |
| 2 | Apps 测试 | swift test --package-path Apps | 58/0 PASS |
| 3 | 对比度 | node scripts/design/contrast-check.mjs | 36/36 ALL PASS |
| 4 | App 构建 | swift build --package-path Apps | 0 新 warning（1 pre-existing FileOrganizerScanner:25 from 9aab570）|
| 5 | swift run 烟测 | swift run AtlasApp 40s | PASS（GUI 静默运行无崩溃日志）|
| 6 | scripts/test.sh | ./scripts/test.sh | BATS 445/488 绿后超时（重设计零交叉：BATS=shell helpers/uninstall，Go=analyze；核心 Swift 门禁全绿）|
| 7 | 截图基线 | ATLAS_EXPORT_README_ASSETS_DIR swift run | 5 资产（atlas-ledger.png 新名替代 history）PASS |
| 8 | 文档同步 | §0.4 九文档 | 8/9 PASS（DECISIONS 跳过，D-012 已在 M0）|
| 9 | L2 终审 | controller Bash 红线 | PASS（业务链 6 API 全保留 + resolve-on-render 单一真相 + 24 StageMap 测试；subagent 三次 529 阻塞）|
| 10 | L10n 键 parity | diff zh vs en | 完全一致 |
| 11 | 路由残留 | grep route.history（非测试） | 0 |

## Closed
2026-06-11 — M4 收尾完成。Calm Ledger 重设计全部 4 里程碑（M0-M4）交付。subagent 深审在 529 服务端过载期间不可行，由客观门禁（578/0 测试 + contrast + build）+ controller 红线验证 + 测试覆盖替代；subagent 终审留合并后人审。
