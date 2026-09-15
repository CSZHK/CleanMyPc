# README 媒体资产 —— 渲染输入指纹范围
#
# 每行一个相对仓库根的 glob（`**` 递归）；`#` 开头为注释；空行忽略。
# 顺序无关 —— 指纹内部按路径排序。
#
# 语义：任何命中本范围的文件内容变化 → 指纹变化 → 门禁报红
#       → 要求重跑 `./scripts/atlas/export-readme-assets.sh`。
#
# 判据来源：Docs/design/2026-09-15-readme-media-lifecycle.md「指纹范围」节。
#
# ⚠️ 本范围是**故意取宽**的：全部两只 Localizable.strings 都在内，
#    因此任意一条文案改动都会要求重导截图。这是设计要求，不是缺陷 ——
#    见设计文档里「已知看不到的载体」一节的取舍说明。

# ⚠️ App 层源文件 —— 取**整个目录**，不逐个点名。（AtlasDomain 同理，见下。）
#
# 这里踩过一个大坑：初版只登记了 `AppShellView.swift`，并注释说「导出器里
# `AtlasScreenshotShell` 是它的手抄副本，会静默漂移」。但**真正被渲染的是那份
# 副本**，它连同画布尺寸 `screenshotSize`、侧栏宽度都定义在
# `ReadmeAssetExporter.swift` 里 —— 而那个文件**根本不在范围内**。
# 后果：改画布尺寸或侧栏宽度，截图会变，门禁却全绿。（对抗审查实测证伪。）
#
# 教训：**逐文件点名 = 黑名单穷举**，漏一个就静默瞎。而这里的代价是不对称的 ——
# 多纳一个文件最多多要一次重导（一条命令），漏一个则是截图静默过期。
# 所以取整个目录。
#
# 残留局限（未闭合）：本范围能发现「AppShellView 变了」，但**发现不了
# 「副本与原版已不一致」** —— 因为副本不变，重导产出的图也不变。
# 根治要么让导出器复用真实 shell（决断 D3 否掉了），要么人工核对。
Apps/AtlasApp/Sources/AtlasApp/**/*.swift

# 被渲染的 4 个 feature view
Packages/AtlasFeaturesOverview/Sources/**/*.swift
Packages/AtlasFeaturesSmartClean/Sources/**/*.swift
Packages/AtlasFeaturesApps/Sources/**/*.swift
Packages/AtlasFeaturesHistory/Sources/**/*.swift

# 设计系统 token 与组件
Packages/AtlasDesignSystem/Sources/**/*.swift

# AtlasDomain 的 **Swift 全部**。
#
# 这里原本是逐文件点名（`AtlasDomain.swift` + `AtlasLocalization.swift`）。改成整目录
# 是因为它**当场就漏了一次**：为修「截图不可复现」新增的 `AtlasRenderClock.swift`
# 影响渲染（它决定 fixture 与相对时间的「现在」），却没被点名进去 —— 改它不会触发
# 漂移红。同一个「逐项点名 = 黑名单穷举」的错误，我在同一次改动里犯了第二遍。
#
# 判据不变：多纳一个文件最多多要一次重导（一条命令），漏一个则是截图静默过期。
Packages/AtlasDomain/Sources/AtlasDomain/**/*.swift

# 路由定义 + 侧栏分组 + 截图用的脚手架 fixture → 已由上面的整目录覆盖

# 两份文案源 —— 渲染进截图的文字全部来自这里
Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings
Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings

# 传入导出器的 workspace 状态构造
Packages/AtlasApplication/Sources/AtlasApplication/**/*.swift

# 封面源。它内嵌一张截图（`atlas-overview-en.png`）与品牌 logo（`atlas-logo.png`），
# 改它就得重渲染 fig01-cover.png —— 所以必须进指纹，否则封面会静默烂在原地
# （它当年就是这么变成 98.5% 纯色还挂了很久的）。
Docs/Media/README/cover.html
