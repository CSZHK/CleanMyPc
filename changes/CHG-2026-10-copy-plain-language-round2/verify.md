# verify — CHG-2026-10-copy-plain-language-round2

验收命令矩阵（全部须在本轮 fresh run，禁止引用历史输出）：

| # | 门 | 命令 | 通过判据 | Result |
|---|-----|------|----------|--------|
| 1 | 文案门禁 | `./scripts/atlas/copy-gate.sh` | exit 0（C1/C1b/C2/C3/C4/C6/C7/C9/C10 全绿；C5/C8 报告维不阻断） | ✅ PASS（2026-10-22 00:0x，zh=en=1161 键；C5=301/C8=6 报告维） |
| 2 | 共享库测试 | `swift test --package-path Packages` | 全部 pass | ✅ 619/619，0 failures（4e 注释修改后补跑 `swift build --package-path Packages` → Build complete） |
| 3 | App 层测试 | `swift test --package-path Apps` | 全部 pass | ✅ 72/72，0 failures |
| 4 | 键集合对账 | `git diff` 人工核对 + gate C7 | zh/en 删除键集合一致、新增键集合一致 | ✅ C7 绿；4e 审查者独立逐键 diff 复核 parity 成立，11 个删键全仓 Swift 零引用（含动态拼接点排查） |
| 5 | README 媒体门禁 | `./scripts/atlas/export-readme-assets.sh`（本机重导 8 张截图）后跑 full-acceptance 第 [5/13] 步或指纹检查 | 指纹一致，exit 0 | ✅ 跑通：[1/3] `swift run`（重建后渲染）八图 + manifest 重写（00:06），脚本末尾 `readme_media_gate.py --build-manifest` → `ATLAS_README_MEDIA_GATE=PASS` |

## 已知边界（如实记录，不计 PASS）

- XCUITest（`run-ui-automation.sh`）本轮不跑：改文案前已 grep 证实 UITests 零断言将改文案（仅 identifier + 「概览」）。发版候选机收口前须补跑。
- 第 5 步若环境无法构建 .app，如实记 BLOCKED 并列为 Carry-Forward，不伪装通过。

## 变异检验说明

本轮未新增/修改任何门禁规则（copy_gate.py 与 C1–C10 判据零改动，仅增补词条数据）→ 按 COPY_GUIDELINES §10 的触发条件，变异检验不适用。
