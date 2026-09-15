# Issue #3: 独立构造的 formatter 绕过环境 locale

**修复日期**: 2026-09-15
**类别**: frontend
**关联模块**: `Packages/AtlasDesignSystem`
**严重等级**: P2（体验问题）

---

## 问题本质 (≤3行)
UI 语言为 English、系统为 zh-CN 时，历史记录屏渲染「4分钟前」「2026年9月15日」——界面全英文、日期全中文。
触发条件：app 内选择的语言 ≠ 系统语言。

## 根因分析 (≤5行)
`AtlasFormatters.relativeDate/shortDate` 独立构造 `RelativeDateTimeFormatter()`、独立调用
`formatted(...)`，读的是 `Locale.current`（系统）；而 app 的 `.environment(\.locale, …)`
（`Apps/AtlasApp/Sources/AtlasApp/AtlasApp.swift:17`）只覆盖**视图树内**的格式化，管不到独立构造的实例。
影响面 10 处调用点（`FindingRowView` / `SmartCleanReceiptView` / `LedgerDetailView` 等）。

## 解决方案 (≤5行)
两个函数改为显式传 `AtlasL10n.currentLanguage.locale`。
- 关键代码: `Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/AtlasDesignSystem.swift:83-95`
新增回归守卫 `Packages/AtlasDesignSystem/Tests/AtlasDesignSystemTests/AtlasFormattersLocaleTests.swift`（2 条）。

## 关键决策 (≤3行)
不注入环境 locale 而读全局 `AtlasL10n.currentLanguage`：与 `AtlasL10n.string` 的既有取值方式一致，改动面最小。
守卫断言「切语言后输出必须变」，而非断言具体日期串，避免绑定系统区域格式。

## 预防措施 (≤2行)
不要用视觉工具验语言——真机截图才发现此缺陷。新增独立构造的格式化器时，locale 必须显式传入。
守卫已做变异检验：把 locale 改回 `Locale.current` 即 2 条断言变红。
