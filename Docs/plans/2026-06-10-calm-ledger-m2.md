# Calm Ledger 重设计 — M2 组件层 实施计划

> **For agentic workers:** 按批次（F → G）由控制器派发实施；每批次实施后过合并审查（spec+质量）+ 客观门禁。任务给出**接口契约与行为清单**而非全量实现代码——token 词汇与视觉规则以规格 v1.1 §1/§4.2/§4.3 为准，实现者按契约编写 SwiftUI。

**Goal:** 落地 9 个新组件 + AtlasScreen 结构插槽 + 既有组件修改清单，全部带单测，构建与门禁全绿。

**真相源:** `Docs/design/2026-06-10-frontend-redesign-calm-ledger.md` (v1.1) §4.2/§4.3；token 层（M1，已落地）；`.agent/calm-ledger-redesign-findings.md`（M2 必读：宋体 weight、banner 角度决策、textTertiary 画布约束）。

**通用约束（每个任务都适用）:**
- 文件放 `Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/Components/`，一组件一文件，≤350 行
- 颜色/字号/间距/圆角/动效一律 token（`AtlasColor.*` / `AtlasTypography.*` / `AtlasSpacing.*` / `AtlasRadius.*` / `AtlasMotion.*`），禁止裸 hex/字号
- 用户可见字符串过 `AtlasL10n`（键加进 `Packages/AtlasDomain/.../zh-Hans.lproj/Localizable.strings` + `en.lproj`，键名前缀 `ds.<component>.`）
- 动画全部尊重 `accessibilityReduceMotion`；装饰元素 `accessibilityHidden(true)`
- 每组件至少 2 个单测加入 `AtlasDesignSystemTests`（状态映射/逻辑函数优先，渲染冒烟其次）
- 每任务收尾: `swift build --package-path Packages && swift test --package-path Packages --filter AtlasDesignSystemTests` 绿后 commit（信息 `feat(design-system): add Atlas<X> — <一句话>`）

---

## Batch F — 核心交互组件

### F1 `AtlasStageBar.swift`

```swift
public struct AtlasStage: Identifiable, Equatable, Sendable {
    public let id: Int            // 阶段序号（0-based）
    public let title: String      // 已本地化标题（调用方传入）
}
public struct AtlasStageBar: View {
    public init(stages: [AtlasStage], currentIndex: Int, completedIndices: Set<Int>,
                onSelect: @escaping (Int) -> Void)
}
```
行为清单（规格 §2.3/§4.2）：
- 胶囊分段条：completed=可点击、`successFill` 底 + `①✓` 前缀；current=`brand` 底白字 bold；future=禁用 `textTertiary`
- 紧凑态：容器宽 <520pt 时收为「②/④ 复核」（GeometryReader 或 ViewThatFits；圈号仅视觉）
- 键盘：整条单 Tab stop（`focusable()` + `FocusState`），←→ 在可达阶段间移动，Return/Space 触发 onSelect；focus ring：brand 2pt、offset 2pt、胶囊圆角（`focusEffectDisabled` + 自绘 overlay）
- a11y：`accessibilityElement(children:.ignore)` + value「第 N 阶段，共 M 个：X，当前/已完成/不可用」（L10n 键 `ds.stagebar.value.*`）；禁用段可聚焦并朗读原因
- 切换动效 `AtlasMotion.stageTransition`，reduce-motion 降级 opacity
测试：`testStageBarStateMapping`（completed/current/future 分类函数）、`testStageBarCompactThreshold`、`testStageBarA11yValueString`

### F2 `AtlasEvidencePanel.swift`（吸收 AtlasEvidenceGroupCard 的职责）

```swift
public struct AtlasEvidenceItem: Identifiable, Equatable, Sendable {  // mono KV 行
    public let id: String; public let label: String; public let value: String
}
public struct AtlasEvidenceContent {       // 单选三段式
    public let title: String
    public let whyText: String
    public let evidence: [AtlasEvidenceItem]
    public let recoveryText: String?       // nil ⇒ 不渲染 ⛨ 框（fail-closed，规格 §1.6）
}
public struct AtlasEvidenceAggregate {     // 多选聚合
    public let count: Int; public let totalText: String   // mono
    public let riskBreakdown: [(label: String, count: Int, tone: AtlasTone)]
    public let commonRecoveryText: String?
}
public enum AtlasEvidenceState { case empty, single(AtlasEvidenceContent),
    aggregate(AtlasEvidenceAggregate), executing(rows: [(title: String, status: AtlasTone, detail: String?)]) }
public struct AtlasEvidencePanel<Actions: View>: View {
    public init(state: AtlasEvidenceState, @ViewBuilder actions: () -> Actions)
}
```
行为：三段式（为什么=surface 卡 / 证据=`dataBody` mono on `surfaceInput` / 恢复=⛨ brand 框）；empty=「选择一项查看证据」（`ds.evidence.empty`）；executing=实时行级状态流，失败行可展开 detail；min 宽 `AtlasLayout.evidencePanelMinWidth`；路径文本 `.truncationMode(.middle)` + help tooltip 全路径
测试：`testEvidencePanelStateExhaustive`（四态构造）、`testEvidenceRecoveryNilHidesShieldBox`

### F3 `AtlasActionBar.swift`

```swift
public struct AtlasActionBar: View {
    public init(primaryTitle: String, primaryEnabled: Bool, onPrimary: @escaping () -> Void,
                promise: String?,        // 状态驱动承诺文案；nil ⇒ 不显示 ⛨ 句（规格 §1.6）
                metricText: String?,     // mono 合计
                progress: Double?)       // 非 nil ⇒ 执行进度态（主按钮替换为进度）
}
```
行为：`actionBarBg` 墨色条、radius `AtlasRadius.md`、阴影同 §1.4；主按钮胶囊 `bannerGradient` 白字；promise 用 `actionBarText`、metric 用 `actionBarData` mono；让位序（规格 §4.2）：内容宽 <`actionBarCompactBreakpoint` 时 promise 收为 ⛨ 图标徽记，metric 保留，主按钮永不截断（读 `atlasContentWidth` 环境）
测试：`testActionBarCompactDropsPromiseKeepsPrimary`、`testActionBarProgressMode`

### F4 `AtlasLedgerTimeline.swift`（含 Entry）

```swift
public enum AtlasLedgerEntryStatus: Equatable, Sendable {
    case inProgress, recoverable(daysLeft: Int), verified, archived, superseded
}
public struct AtlasLedgerEntryModel: Identifiable, Equatable, Sendable {
    public let id: String; public let number: Int; public let title: String
    public let detail: String; public let metricText: String?; public let status: AtlasLedgerEntryStatus
}
public struct AtlasLedgerTimeline: View {
    public init(entries: [AtlasLedgerEntryModel], selection: Binding<String?>)
}
```
行为：左轨时间线（选中/inProgress 轨为 `brand` 1.5pt，其余 `ledgerRule`）+ 圆点；№ 用 `ledgerNumber` serif `brand` 色；inProgress 条目**置顶钉住**（排序函数独立可测）；状态徽记文案（⛨ 恢复点·N 天 / ✓ 已验证 / 已归档 / 已作废，L10n `ds.ledger.status.*`）；每条 a11y label「计划编号 N，<title>」（`ds.ledger.entry.a11y`）；整条可点（回链红线——selection 绑定）
测试：`testLedgerPinningOrder`（inProgress 置顶 + 其余按 number 降序）、`testLedgerStatusBadgeMapping`、`testLedgerEntryA11yLabel`

### F5 `AtlasStampBadge.swift`

```swift
public struct AtlasStampBadge: View {
    public enum Style { case badge, watermark }
    public init(title: String, subtitle: String?, numberText: String?, style: Style = .badge)
}
```
行为：正圆 2.5pt `brand` 描边、内容 serif、`rotationEffect(.degrees(-11))`；watermark 变体 opacity 0.45、尺寸 ×1.4、禁止交互；出现动效 `AtlasMotion.stampIn`（reduce-motion 直接落定）；**整体 `accessibilityHidden(true)`**（信息由相邻文本承载，规格 §6）；teal 描边、无红色/五角星元素（findings 公章约束）
测试：`testStampBadgeStyleVariants`（badge/watermark 参数差异）

---

## Batch G — 表面、横幅与基建

### G1 `AtlasLedgerSurface.swift`

```swift
public struct AtlasLedgerSurface<Content: View>: View {
    public init(title: String? = nil, @ViewBuilder content: () -> Content)
}
public extension View { func atlasLedgerRule() -> some View }  // 点状分隔线 divider
```
行为：`ledgerPaper` 底 + `ledgerBorder` 1px + radius `AtlasRadius.md`；可选 serif `ledgerTitle` 标题 + 1.5pt `ledgerInk` 底线；`atlasLedgerRule()` 输出点状（dash [1,3]）`ledgerRule` 色分隔；**无阴影**（纸上印刷，§1.4）；使用边界注释（§1.2：仅台账屏/回执/概览台账流）
测试：`testLedgerSurfaceExists`（含 title/无 title 两构造）

### G2 `AtlasNextActionBanner.swift`

```swift
public struct AtlasNextActionBanner: View {
    public init(headline: String, rationale: String,            // rationale 含 mono 时间戳由调用方拼
                primaryTitle: String, onPrimary: @escaping () -> Void,
                secondaryTitle: String?, onSecondary: (() -> Void)?,
                onDismiss: (() -> Void)?)                        // 忽略（7 天冷却由调用方持久化）
}
```
行为：`bannerGradient` 底（**决策落地**：接受 topLeading→bottomTrailing 对角线，不做 UnitPoint 角度计算——在组件 doc 注明）；白字 headline bold 15 / rationale 白 85% 11；主按钮白底 brand 字胶囊；忽略=右上 ghost 白 60%（`ds.banner.dismiss`）
测试：`testBannerCallbacks`（三个回调触发）

### G3 `AtlasErrorState.swift`

```swift
public struct AtlasErrorState: View {
    public enum Layout { case block, inlineRow }
    public init(title: String, message: String, suggestion: String? = nil,
                actionTitle: String? = nil, onAction: (() -> Void)? = nil, layout: Layout = .block)
}
```
行为：无码版（规格 §4.2 评审裁定）：`danger` 图标 `exclamationmark.octagon.fill` + `dangerFill` 软底；block=居中块（对应 EmptyState 排版）、inlineRow=执行列表行内紧凑变体；suggestion 用 `textSecondary`
测试：`testErrorStateLayoutVariants`

### G4 数据声部基建 `AtlasDataText.swift`

```swift
public extension View {
    func atlasData() -> some View          // dataBody mono + monospacedDigit
    func atlasDataCaption() -> some View   // dataCaption
}
public struct AtlasCountUpText: View {     // contentTransition(.numericText()) + reduce-motion 降级
    public init(text: String, font: Font = AtlasTypography.dataMetric)
}
```
测试：`testCountUpTextExists`（构造冒烟）

### G5 `AtlasScreen` 插槽（修改 `AtlasDesignSystem.swift` 内 AtlasScreen）

```swift
// 新增可选参数（保持既有调用点源兼容——带默认值）:
//   actionBar: (() -> AnyView)? = nil
// 实现要点:
//   - actionBar 经 .safeAreaInset(edge: .bottom) 挂在私有 ScrollView 之外（行动栏全宽，
//     内容仍受 maxContentWidth 钳制；与顶部 toolbar/.searchable 无冲突）
//   - 行动栏实际高度经 PreferenceKey `AtlasActionBarHeightKey` 上报（M3 AppShell 用于 toast 上移）
//   - 证据抽屉不在本层：M3 由屏幕层用 overlay 实现（本任务只保证 safeAreaInset 不挡 overlay）
```
测试：`testAtlasScreenActionBarSlotCompiles`（带/不带 actionBar 两构造）+ 既有 AtlasScreen 测试不回归

### G6 既有组件修改清单（一个任务，多文件小改）

| 文件 | 改动 |
|---|---|
| `AtlasCircularProgress.swift` | trim+LinearGradient → `AngularGradient`（conic）；处理 0%/100% 渐变接缝（起止同色或 round cap 规避） |
| `AtlasToast.swift` | item 增 `actionTitle/onAction`（撤销）与 `onTap`（已入账 №N 跳台账）；既有调用点默认值兼容 |
| `AtlasStatusChip.swift` / `AtlasFilterChip.swift` | 软底改语义 fill token（`successFill` 等），去 opacity 拼色 |
| `AtlasCallout.swift` / `AtlasEmptyState.swift` / `AtlasLoadingState.swift` / `AtlasSkeleton.swift` | token 复核 pass（M1 已自动继承大部分；删残留 opacity 拼色） |
| `AtlasEvidenceGroupCard.swift` | 文件头加 `@available(*, deprecated, message: "Absorbed by AtlasEvidencePanel — remove with M3 Apps migration")`（保留实现，M3 删） |
| `AtlasTooltip` | 无 API 改动；F1 阶段条用 `.atlasTooltip` 提供阶段说明 |
测试：既有测试全绿 + `testToastActionSupport`

---

## M2 验收（CHG-2026-06-calm-ledger-m2）

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | 包测试 | `swift test --package-path Packages` | 386 + 新增全绿，0 failures |
| 2 | App 构建 | `swift build --package-path Apps` | Build complete! |
| 3 | Apps 测试 | `swift test --package-path Apps` | 全绿（prework 已解锁） |
| 4 | 对比度 | `node scripts/design/contrast-check.mjs` | ALL PASS |
| 5 | L10n 键 | 新增 `ds.*` 键 zh/en 数量一致（diff 脚本或 grep 计数） | 一致 |
| 6 | 行数纪律 | 新组件文件均 ≤350 行 | 达标 |

完成后：trace M2 行 → PASS + Actual 回填；tasks/m2-components.md → DONE；execplan 里程碑 M2 ✓；PER backlog #3 → FIXED。
