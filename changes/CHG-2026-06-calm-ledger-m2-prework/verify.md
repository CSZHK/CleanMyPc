# Verify — CHG-2026-06-calm-ledger-m2-prework
| # | Check | Command | Expected | Result |
|---|-------|---------|----------|--------|
| 1 | Apps 测试 | swift test --package-path Apps | 编译通过且全绿 | 编译 PASS（0 error，conformance 修复生效）；运行 0/29 — 套件被 pre-existing 崩溃挡住：AtlasAppModel.swift:696 `NSApp.appearance` 强解包在裸 swift test 环境 NSApp 为 nil（main 4ff6c08 引入，此前被编译失败掩盖；29 测试全部构造 AtlasAppModel，首测即中止）。按范围红线只报告不修 |
| 2 | 包测试 | swift test --package-path Packages | 386 / 0 | PASS — Executed 386 tests, with 0 failures（384+2 新增） |
| 3 | 回退幂等 | node scripts/design/generate-colorsets.mjs ×2 | 第二次无 diff | PASS — 两次运行间 `git status --porcelain | wc -l` 保持 5，无新 diff |
| 4 | 对比度 | node scripts/design/contrast-check.mjs | ALL PASS | PASS — ALL PASS |
| 5 | dev 运行 | swift run AtlasApp 启动 3s 无崩溃 | 启动成功 | pre-existing FAIL（与本变更无关）— UNUserNotificationCenter `bundleProxyForCurrentProcess is nil`：裸 swift-run 可执行无 .app bundle，权限检查链触发 NSException。已用 git stash 在 HEAD 基线复现同一崩溃，确认非本 CHG 引入。色彩回退路径的功能性证明由新增 testAtlasColorFallbackPathProducesRenderableColor 端到端覆盖（CLI 环境实际走表并锁定 sRGB 分量）；颜色目测仍无法自动化。→ Batch E2 修复后转 PASS，见 #6/#7 |
| 6 | Apps 套件执行（Batch E2 后） | swift test --package-path Apps | 29 执行全绿 | PASS — Executed 29 tests, with 0 failures（`NSApp?.appearance` 可选链后套件解锁；Fix 2 改动 AtlasAppModel 后复跑仍 29/0） |
| 7 | dev 运行存活（Batch E2 后） | swift run AtlasApp 启动 ≥3s 无崩溃 | 启动成功 | PASS — bundle 守卫（`Bundle.main.bundleIdentifier != nil`，两触点：AtlasPermissionInspector.swift:76 / AtlasAppModel.swift:117）后 app 存活 >18s 直至显式 kill，运行日志 0 处 NSException/Terminating；Packages 复跑 386/0 无回退 |
