# P1 —— 导出器双语化 + 封面纳入重导链路

- **状态**：完成
- **产出**：`Apps/AtlasApp/Sources/AtlasApp/ReadmeAssetExporter.swift` · `scripts/atlas/export-readme-assets.sh`

## 做了什么

1. `screenshotLanguage: AtlasLanguage = .en` 常量 → `for language in AtlasLanguage.allCases` 循环。
   - 语言是**进程级全局状态**（`AtlasL10n.setCurrentLanguage`），所以必须在构造视图**之前**设置，且同一语言的「构造 → 渲染」之间不得插入另一种语言 —— 视图 body 是在 `cacheDisplay` 时才求值的。这是本次最容易踩错的地方，已在代码注释里写明。
2. 产物命名 `atlas-{stem}-{lang}.png`，`lang` 取 `AtlasLanguage.rawValue`（`en` / `zh-Hans`）。
3. 每条路由的视图构造抽成 `screenshotView(for:state:canExecuteSmartCleanPlan:)`；`default:` 分支走 `preconditionFailure` —— 静默返回别的路由的图比崩溃更糟，那张图会「看起来正常」。
4. 新增 `verifyWrittenAssets(_:)`：逐条确认产物落盘且非空。
   - **刻意不写** `exportedFileNames.count == 预期` —— 那个数由同一段代码算出来，永远成立，属自证断言（本仓 `I-8` 同型）。真正的独立预期在门禁的 Python 常量表里。
5. `export-readme-assets.sh` 补两步：先结束在跑的 `AtlasApp`（两个 debug 实例会抢渲染上下文），末尾用 Chrome 无头渲染 `fig01-cover.png`。
6. **去掉自定义输出目录参数**。脚本原先收 `$1` 当输出目录，但 manifest 与门禁都锚在仓库根的 `Docs/Media/README/`（指纹也是相对仓库根算的）—— 传了自定义目录就会「渲染到 A、清单建在 B」，静默错位。查过全仓**无调用方传参**，故直接去掉这个半坏的口子，而不是留着它假装可用。
   - 封面**必须**在这里渲染：封面源 `cover.html` 在指纹范围内，只改源不重渲会让指纹更新而封面仍旧 —— 门禁照样绿，封面静默烂掉，正是当年那起事故的形状。
   - 找不到 Chrome 时**硬失败**（`exit 1`），不静默跳过。

## 实际验证

- `swift build --package-path Apps` 通过。
- `./scripts/atlas/export-readme-assets.sh` 产出 9 条资产 + 重渲封面（1,293,521 字节）。
- **双语渲染人工抽样**：`atlas-ledger-zh-Hans.png` 实际渲染为「历史记录 / 概览 / 智能清理 / 权限 / 当前记录 / 最近更新 4 分钟前」；`-en` 为「History / Overview / Smart Clean / Permissions / Visible events / Latest update 4 minutes ago」。像素统计判不了语言，这一步只能人眼看。
