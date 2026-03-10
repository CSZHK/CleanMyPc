# Atlas for Mac — Design Specification v2

> **Status**: Ready for implementation
> **Brand Token 文件**: `Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/AtlasBrand.swift` (已创建并编译通过)

---

## 1. Brand Identity

### 1.1 品牌概念：Calm Authority（沉稳的权威感）

Atlas — 如同制图师为你的系统绘制地形图。精确、可信、从容不迫。

### 1.2 色彩体系

| Token | Light Mode | Dark Mode | 用途 |
|-------|-----------|-----------|------|
| `AtlasColor.brand` | `#0F766E` 深青绿 | `#148F85` 亮青绿 | 主色调、主要按钮、激活状态 |
| `AtlasColor.accent` | `#34D399` 清新薄荷绿 | `#52E2B5` 明亮薄荷绿 | 高亮、徽章、品牌点缀 |
| `AtlasColor.success` | systemGreen | systemGreen | 安全、已授权、已完成 |
| `AtlasColor.warning` | systemOrange | systemOrange | 需审查、运行中 |
| `AtlasColor.danger` | systemRed | systemRed | 失败、高级风险 |
| `AtlasColor.card` | controlBackgroundColor | controlBackgroundColor | 卡片基底 |
| `AtlasColor.cardRaised` | `white @ 65%` | `white @ 6%` | 浮起卡片的玻璃质感层 |
| `AtlasColor.border` | `primary @ 8%` | `primary @ 8%` | 普通卡片描边 |
| `AtlasColor.borderEmphasis` | `primary @ 14%` | `primary @ 14%` | 高亮卡片/焦点态描边 |

### 1.3 字体标尺

| Token | 定义 | 使用场景 |
|-------|------|---------|
| `AtlasTypography.heroMetric` | 40pt bold rounded | Dashboard 最重要的单一数值 |
| `AtlasTypography.screenTitle` | 34pt bold rounded | 每个屏幕的大标题 |
| `AtlasTypography.cardMetric` | 28pt bold rounded | 网格中的指标卡数值 |
| `AtlasTypography.sectionTitle` | title3 semibold | InfoCard 内的分区标题 |
| `AtlasTypography.label` | subheadline semibold | 指标标题、侧边栏主文本 |
| `AtlasTypography.rowTitle` | headline | DetailRow 标题 |
| `AtlasTypography.body` | subheadline | 正文说明 |
| `AtlasTypography.caption` | caption semibold | Chip、脚注、overline |

### 1.4 间距网格 (4pt base)

| Token | 值 | 场景 |
|-------|-----|------|
| `AtlasSpacing.xxs` | 4pt | 最小内边距 |
| `AtlasSpacing.xs` | 6pt | Chip 内边距 |
| `AtlasSpacing.sm` | 8pt | 行间距紧凑 |
| `AtlasSpacing.md` | 12pt | 元素间默认间距 |
| `AtlasSpacing.lg` | 16pt | 卡片内边距、分区间距 |
| `AtlasSpacing.xl` | 20pt | 宽卡片内边距 |
| `AtlasSpacing.xxl` | 24pt | 屏幕级垂直节奏 |
| `AtlasSpacing.screenH` | 28pt | 屏幕水平边距 |
| `AtlasSpacing.section` | 32pt | 大分区间隔 |

### 1.5 圆角

| Token | 值 | 场景 |
|-------|-----|------|
| `AtlasRadius.sm` | 8pt | Chip、Tag |
| `AtlasRadius.md` | 12pt | Callout、内嵌卡片 |
| `AtlasRadius.lg` | 16pt | DetailRow、紧凑卡片 |
| `AtlasRadius.xl` | 20pt | 标准 InfoCard/MetricCard |
| `AtlasRadius.xxl` | 24pt | 高亮/英雄卡片 |

### 1.6 三级高程（Elevation）

| 级别 | 阴影 | 圆角 | 描边 | 用途 |
|------|------|------|------|------|
| `.flat` | 无 | 16pt | 4% opacity | 嵌套内容、行内子卡片 |
| `.raised` | r18 y10 @5% | 20pt | 8% opacity | 默认卡片（AtlasInfoCard/MetricCard） |
| `.prominent` | r28 y16 @9% + 内发光 | 24pt | 12% opacity, 1.5pt | 英雄指标、主操作区 |

### 1.7 动画曲线

| Token | 值 | 场景 |
|-------|-----|------|
| `AtlasMotion.fast` | snappy 0.15s | hover、按压、chip |
| `AtlasMotion.standard` | snappy 0.22s | 选择、切换、卡片状态 |
| `AtlasMotion.slow` | snappy 0.35s | 页面转场、英雄揭示 |
| `AtlasMotion.spring` | spring(0.45, 0.7) | 完成庆祝、弹性反馈 |

### 1.8 按钮层级

| 样式 | 外观 | 场景 |
|------|------|------|
| `.atlasPrimary` | 品牌色填充胶囊 + 投影 + 按压缩放 | 每屏唯一最重要 CTA |
| `.atlasSecondary` | 品牌色描边胶囊 + 淡底 | 辅助操作 |
| `.atlasGhost` | 纯文字 + hover 淡底 | 低频操作 |

---

## 2. 设计系统组件迁移

> 所有修改在 `AtlasDesignSystem.swift` 中进行。`AtlasBrand.swift` 已包含新 Token，不需要修改。

### 2.1 AtlasScreen — 约束阅读宽度 + 移除冗余 overline

**文件**: `Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/AtlasDesignSystem.swift`

**当前问题**:
- line 100: `.frame(maxWidth: .infinity)` 导致宽窗口下文本行过长
- line 109: 每屏都显示 "Atlas for Mac" overline，冗余

**改动**:

```swift
// body 中 ScrollView 内的 VStack 改为：
ScrollView {
    VStack(alignment: .leading, spacing: AtlasSpacing.xxl) {
        header
        content
    }
    .frame(maxWidth: AtlasLayout.maxReadingWidth, alignment: .leading)
    .padding(.horizontal, AtlasSpacing.screenH)
    .padding(.vertical, AtlasSpacing.xxl)
    .frame(maxWidth: .infinity, alignment: .leading) // 外层居中容器
}
```

**header 改为**:
- 移除 "Atlas for Mac" overline（line 109-113 整块删除）
- 使用 `AtlasTypography.screenTitle` 替换 line 117 的硬编码字号

```swift
private var header: some View {
    VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
        Text(title)
            .font(AtlasTypography.screenTitle)

        Text(subtitle)
            .font(AtlasTypography.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
```

### 2.2 AtlasMetricCard — 支持 elevation 参数 + 使用 Token

**文件**: `AtlasDesignSystem.swift`

**改动**:
- 新增 `elevation: AtlasElevation = .raised` 参数
- 替换 line 165 硬编码字号为 `AtlasTypography.cardMetric`
- 替换 line 160 硬编码字号为 `AtlasTypography.label`
- 替换 line 175 硬编码 `padding(18)` 为 `padding(AtlasSpacing.xl)`
- 替换 line 176-177 的 `cardBackground`/`cardBorder` 为 `atlasCardBackground`/`atlasCardBorder`（传入 elevation）

```swift
public struct AtlasMetricCard: View {
    private let title: String
    private let value: String
    private let detail: String
    private let tone: AtlasTone
    private let systemImage: String?
    private let elevation: AtlasElevation  // 新增

    public init(
        title: String,
        value: String,
        detail: String,
        tone: AtlasTone = .neutral,
        systemImage: String? = nil,
        elevation: AtlasElevation = .raised  // 新增
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.tone = tone
        self.systemImage = systemImage
        self.elevation = elevation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            HStack(alignment: .center, spacing: AtlasSpacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(tone.tint)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AtlasTypography.label)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(elevation == .prominent ? AtlasTypography.heroMetric : AtlasTypography.cardMetric)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(detail)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.xl)
        .background(atlasCardBackground(tone: tone, elevation: elevation))
        .overlay(atlasCardBorder(tone: tone, elevation: elevation))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text(detail))
    }
}
```

### 2.3 AtlasInfoCard — 使用 Token

**文件**: `AtlasDesignSystem.swift`

**改动**:
- 替换 line 204 `spacing: 18` → `AtlasSpacing.xl`
- 替换 line 209 `.title3.weight(.semibold)` → `AtlasTypography.sectionTitle`
- 替换 line 214 `.subheadline` → `AtlasTypography.body`
- 替换 line 224 `padding(22)` → `padding(AtlasSpacing.xxl)`
- 替换 line 225-226 为 `atlasCardBackground`/`atlasCardBorder`

### 2.4 AtlasCallout — 使用 Token

**文件**: `AtlasDesignSystem.swift`

**改动**:
- 替换 line 249 `spacing: 14` → `AtlasSpacing.lg`
- 替换 line 256 `spacing: 6` → `AtlasSpacing.xs`
- 替换 line 258 `.headline` → `AtlasTypography.rowTitle`
- 替换 line 261 `.subheadline` → `AtlasTypography.body`
- 替换 line 266 `padding(16)` → `padding(AtlasSpacing.lg)`
- 替换 line 269 `cornerRadius: 16` → `AtlasRadius.lg`
- 替换 line 273 `cornerRadius: 16` → `AtlasRadius.lg`

### 2.5 AtlasDetailRow — 使用 Token + 添加 hover 效果

**文件**: `AtlasDesignSystem.swift`

**改动**:
- line 307 `spacing: 14` → `AtlasSpacing.lg`
- line 312 `frame(width: 36, height: 36)` → `frame(width: AtlasLayout.sidebarIconSize + 4, height: AtlasLayout.sidebarIconSize + 4)`
- line 321 `spacing: 6` → `AtlasSpacing.xs`
- line 338 `Spacer(minLength: 16)` → `Spacer(minLength: AtlasSpacing.lg)`
- line 343 `padding(16)` → `padding(AtlasSpacing.lg)`
- line 345-347 替换为 `.fill(AtlasColor.cardRaised)` 并使用 `AtlasRadius.lg`
- line 350 `Color.primary.opacity(0.06)` → `AtlasColor.border`
- **新增**: 在 `.overlay` 之后添加 `.atlasHover()`

### 2.6 AtlasStatusChip — 使用 Token

**文件**: `AtlasDesignSystem.swift`

**改动**:
- line 421 `.caption.weight(.semibold)` → `AtlasTypography.caption`
- line 422 `padding(.horizontal, 10)` → `padding(.horizontal, AtlasSpacing.md)`
- line 423 `padding(.vertical, 6)` → `padding(.vertical, AtlasSpacing.xs)`

### 2.7 AtlasEmptyState — 更有个性

**文件**: `AtlasDesignSystem.swift`

**改动**:
- 图标容器从 56x56 放大到 72x72
- 圆形背景改为渐变填充
- 添加外圈装饰环
- 增加整体 padding

```swift
public var body: some View {
    VStack(spacing: AtlasSpacing.lg) {
        ZStack {
            // 外圈装饰环
            Circle()
                .strokeBorder(tone.border, lineWidth: 0.5)
                .frame(width: 80, height: 80)

            // 渐变填充背景
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tone.softFill, tone.softFill.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)

            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tone.tint)
                .accessibilityHidden(true)
        }

        VStack(spacing: AtlasSpacing.xs) {
            Text(title)
                .font(AtlasTypography.rowTitle)

            Text(detail)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    .frame(maxWidth: .infinity)
    .padding(AtlasSpacing.section)
    .background(
        RoundedRectangle(cornerRadius: AtlasRadius.xl, style: .continuous)
            .fill(Color.primary.opacity(0.03))
    )
    .overlay(
        RoundedRectangle(cornerRadius: AtlasRadius.xl, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(title))
    .accessibilityValue(Text(detail))
}
```

### 2.8 AtlasLoadingState — 添加脉冲动画 + 使用 Token

**文件**: `AtlasDesignSystem.swift`

**改动**:

```swift
public struct AtlasLoadingState: View {
    private let title: String
    private let detail: String
    private let progress: Double?
    @State private var pulsePhase = false

    public init(title: String, detail: String, progress: Double? = nil) {
        self.title = title
        self.detail = detail
        self.progress = progress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            HStack(spacing: AtlasSpacing.md) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)

                Text(title)
                    .font(AtlasTypography.rowTitle)
            }

            Text(detail)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let progress {
                ProgressView(value: progress, total: 1)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(Color.primary.opacity(pulsePhase ? 0.05 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(progress.map { "\(Int(($0 * 100).rounded())) percent complete" } ?? detail))
        .accessibilityHint(Text(detail))
    }
}
```

### 2.9 删除旧的私有辅助函数

**文件**: `AtlasDesignSystem.swift`

删除 line 540-560 的旧 `cardBackground` 和 `cardBorder` 函数。它们被 `AtlasBrand.swift` 中的 `atlasCardBackground` 和 `atlasCardBorder` 替代。

**注意**: 确保所有引用点都已迁移到新函数后再删除。也删除旧的 `AtlasPalette` 枚举（line 66-73），因为它被 `AtlasColor` 替代。对 `AtlasScreen` 中引用 `AtlasPalette.canvasTop`/`canvasBottom` 的地方，改为 `AtlasColor.canvasTop`/`AtlasColor.canvasBottom`。

---

## 3. App Shell 改进

### 3.1 侧边栏行视觉升级

**文件**: `Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift`

**当前** (line 162-186): 标准 Label + VStack，无视觉亮点。

**改为**:

```swift
private struct SidebarRouteRow: View {
    let route: AtlasRoute

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(route.title)
                    .font(AtlasTypography.rowTitle)

                Text(route.subtitle)
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            // Apple System Settings 风格：圆角矩形图标背景
            ZStack {
                RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                    .fill(AtlasColor.brand.opacity(0.1))
                    .frame(width: AtlasLayout.sidebarIconSize, height: AtlasLayout.sidebarIconSize)

                Image(systemName: route.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AtlasColor.brand)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, AtlasSpacing.sm)
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("route.\(route.id)")
        .accessibilityLabel("\(route.title). \(route.subtitle)")
        .accessibilityHint(AtlasL10n.string("sidebar.route.hint", route.shortcutNumber))
    }
}
```

### 3.2 工具栏图标增强

**文件**: `AppShellView.swift`

**当前** (line 28-61): 标准 toolbar 按钮，无视觉层次。

**改动**:
- 对所有 toolbar `Image(systemName:)` 添加 `.symbolRenderingMode(.hierarchical)`
- 给 TaskCenter 按钮添加活跃任务计数徽章

```swift
ToolbarItemGroup {
    Button {
        model.openTaskCenter()
    } label: {
        Label(AtlasL10n.string("toolbar.taskcenter"), systemImage: AtlasIcon.taskCenter)
            .symbolRenderingMode(.hierarchical)
    }
    // ... 其他修饰符不变

    Button {
        model.navigate(to: .permissions)
        Task { await model.inspectPermissions() }
    } label: {
        Label(AtlasL10n.string("toolbar.permissions"), systemImage: AtlasIcon.permissions)
            .symbolRenderingMode(.hierarchical)
    }
    // ... 其他修饰符不变

    Button {
        model.navigate(to: .settings)
    } label: {
        Label(AtlasL10n.string("toolbar.settings"), systemImage: AtlasIcon.settings)
            .symbolRenderingMode(.hierarchical)
    }
    // ... 其他修饰符不变
}
```

### 3.3 详情页转场动画

**文件**: `AppShellView.swift`

**当前** (line 24): `detailView(for:)` 无转场效果。

**改动**: 在 detail 闭包中添加视图标识和转场：

```swift
} detail: {
    detailView(for: model.selection ?? .overview)
        .id(model.selection)  // 关键：强制视图切换时触发转场
        .transition(.opacity)
        .searchable(...)
        .toolbar { ... }
        .animation(AtlasMotion.slow, value: model.selection)
}
```

---

## 4. Feature Screen 改进

### 4.1 OverviewFeatureView — 英雄指标 + 共享列定义

**文件**: `Packages/AtlasFeaturesOverview/Sources/AtlasFeaturesOverview/OverviewFeatureView.swift`

**改动 1** — 英雄指标差异化 (line 31-53):

将"可回收空间"指标升级为 `.prominent` 高程，其余保持 `.raised`：

```swift
LazyVGrid(columns: AtlasLayout.metricColumns, spacing: AtlasSpacing.lg) {
    AtlasMetricCard(
        title: AtlasL10n.string("overview.metric.reclaimable.title"),
        value: AtlasFormatters.byteCount(snapshot.reclaimableSpaceBytes),
        detail: AtlasL10n.string("overview.metric.reclaimable.detail"),
        tone: .success,
        systemImage: "sparkles",
        elevation: .prominent  // 英雄指标
    )
    AtlasMetricCard(
        title: AtlasL10n.string("overview.metric.findings.title"),
        value: "\(snapshot.findings.count)",
        detail: AtlasL10n.string("overview.metric.findings.detail"),
        tone: .neutral,
        systemImage: "line.3.horizontal.decrease.circle"
        // elevation 默认 .raised
    )
    AtlasMetricCard(
        title: AtlasL10n.string("overview.metric.permissions.title"),
        value: "\(grantedPermissionCount)/\(snapshot.permissions.count)",
        detail: grantedPermissionCount == snapshot.permissions.count
            ? AtlasL10n.string("overview.metric.permissions.ready")
            : AtlasL10n.string("overview.metric.permissions.limited"),
        tone: grantedPermissionCount == snapshot.permissions.count ? .success : .warning,
        systemImage: "lock.shield"
        // elevation 默认 .raised
    )
}
```

**改动 2** — 删除私有 `columns` 属性 (line 185-191)，全部替换为 `AtlasLayout.metricColumns`。

**改动 3** — 所有 `spacing: 16` 替换为 `AtlasSpacing.lg`，所有 `spacing: 12` 替换为 `AtlasSpacing.md`。

### 4.2 SmartCleanFeatureView — 解决双 CTA 竞争

**文件**: `Packages/AtlasFeaturesSmartClean/Sources/AtlasFeaturesSmartClean/SmartCleanFeatureView.swift`

**核心问题**: line 85 和 line 112 同时使用 `.borderedProminent`，导致两个主要按钮视觉权重相同。

**改动**: 根据当前状态动态切换按钮层级。

```swift
HStack(spacing: AtlasSpacing.md) {
    // Run Scan 按钮
    Button(action: onStartScan) {
        Label(AtlasL10n.string("smartclean.action.runScan"), systemImage: "sparkles")
    }
    .buttonStyle(plan.items.isEmpty ? .atlasPrimary : .atlasSecondary)
    .disabled(isScanning || isExecutingPlan)
    .keyboardShortcut(plan.items.isEmpty ? .defaultAction : KeyEquivalent("s"), modifiers: plan.items.isEmpty ? [] : [.command, .option])
    .accessibilityIdentifier("smartclean.runScan")
    .accessibilityHint(AtlasL10n.string("smartclean.action.runScan.hint"))

    // Refresh Preview 按钮
    Button(action: onRefreshPreview) {
        Label(AtlasL10n.string("smartclean.action.refreshPreview"), systemImage: "arrow.clockwise")
    }
    .buttonStyle(.atlasGhost)
    .disabled(isScanning || isExecutingPlan)
    .accessibilityIdentifier("smartclean.refreshPreview")
    .accessibilityHint(AtlasL10n.string("smartclean.action.refreshPreview.hint"))

    Spacer()

    // Execute 按钮 — 仅当 plan 有内容时为主要按钮
    Button(action: onExecutePlan) {
        Label(AtlasL10n.string("smartclean.action.execute"), systemImage: "play.fill")
    }
    .buttonStyle(plan.items.isEmpty ? .atlasSecondary : .atlasPrimary)
    .disabled(isScanning || isExecutingPlan || plan.items.isEmpty)
    .keyboardShortcut(plan.items.isEmpty ? nil : .defaultAction)
    .accessibilityIdentifier("smartclean.executePreview")
    .accessibilityHint(AtlasL10n.string("smartclean.action.execute.hint"))
}
```

> **注意**: `.keyboardShortcut` 条件赋值在 SwiftUI 中需要用 `if/else` 包裹两个完整的 `Button`，不能直接三元。保持现有的 `Group { if ... else ... }` 结构，但把内部的 `.buttonStyle` 改为条件化。

**实际可编译方案**（考虑 SwiftUI 限制）:

```swift
HStack(spacing: AtlasSpacing.md) {
    Group {
        if plan.items.isEmpty {
            Button(action: onStartScan) {
                Label(AtlasL10n.string("smartclean.action.runScan"), systemImage: "sparkles")
            }
            .keyboardShortcut(.defaultAction)
        } else {
            Button(action: onStartScan) {
                Label(AtlasL10n.string("smartclean.action.runScan"), systemImage: "sparkles")
            }
        }
    }
    .buttonStyle(plan.items.isEmpty ? .borderedProminent : .bordered)  // 关键改动
    .controlSize(.large)
    .disabled(isScanning || isExecutingPlan)
    .accessibilityIdentifier("smartclean.runScan")

    Button(action: onRefreshPreview) {
        Label(AtlasL10n.string("smartclean.action.refreshPreview"), systemImage: "arrow.clockwise")
    }
    .buttonStyle(.bordered)
    .controlSize(.large)
    .disabled(isScanning || isExecutingPlan)
    .accessibilityIdentifier("smartclean.refreshPreview")

    Spacer()

    Group {
        if !plan.items.isEmpty {
            Button(action: onExecutePlan) {
                Label(AtlasL10n.string("smartclean.action.execute"), systemImage: "play.fill")
            }
            .keyboardShortcut(.defaultAction)
        } else {
            Button(action: onExecutePlan) {
                Label(AtlasL10n.string("smartclean.action.execute"), systemImage: "play.fill")
            }
        }
    }
    .buttonStyle(!plan.items.isEmpty ? .borderedProminent : .bordered)  // 关键改动
    .controlSize(.large)
    .disabled(isScanning || isExecutingPlan || plan.items.isEmpty)
    .accessibilityIdentifier("smartclean.executePreview")
}
```

**额外改动**: 删除私有 `columns` (line 231-237)，替换为 `AtlasLayout.metricColumns`。所有 `spacing: 16` → `AtlasSpacing.lg`。

### 4.3 AppsFeatureView — 行内按钮水平化

**文件**: `Packages/AtlasFeaturesApps/Sources/AtlasFeaturesApps/AppsFeatureView.swift`

**当前问题**: line 181-208 的 trailing 区域是 VStack，包含 byteCount + chip + HStack(两个按钮)，导致每行非常高。

**改动**: 将 trailing 重构为更紧凑的布局：

```swift
// line 181 trailing 改为：
VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
    HStack(spacing: AtlasSpacing.sm) {
        AtlasStatusChip(
            AtlasL10n.string("apps.list.row.leftovers", app.leftoverItems),
            tone: app.leftoverItems > 0 ? .warning : .success
        )
        Text(AtlasFormatters.byteCount(app.bytes))
            .font(AtlasTypography.label)
            .foregroundStyle(.secondary)
    }

    HStack(spacing: AtlasSpacing.sm) {
        Button(activePreviewAppID == app.id ? AtlasL10n.string("apps.preview.running") : AtlasL10n.string("apps.preview.action")) {
            onPreviewAppUninstall(app.id)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(isRunning)

        Button(activeUninstallAppID == app.id ? AtlasL10n.string("apps.uninstall.running") : AtlasL10n.string("apps.uninstall.action")) {
            onExecuteAppUninstall(app.id)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isRunning)
    }
}
```

**额外改动**: 删除私有 `columns`，替换为 `AtlasLayout.metricColumns`。

### 4.4 SettingsFeatureView — 轻量化设置页

**文件**: `Packages/AtlasFeaturesSettings/Sources/AtlasFeaturesSettings/SettingsFeatureView.swift`

**当前问题**: 5 个 `AtlasInfoCard` 连续堆叠，视觉过重。

**改动**:
1. **General 区域** (line 35): 保留 `AtlasInfoCard`，不变
2. **Exclusions 区域** (line 118): 保留，不变
3. **Trust & Transparency** (line 143): 保留，不变
4. **Acknowledgement** (line 177): 改为 `DisclosureGroup`
5. **Notices** (line 187): 改为 `DisclosureGroup`

```swift
// 替换 line 177-195 的两个 AtlasInfoCard 为：
AtlasInfoCard(
    title: AtlasL10n.string("settings.legal.title"),  // 新增合并标题："法律信息"
    subtitle: AtlasL10n.string("settings.legal.subtitle")
) {
    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
        DisclosureGroup(AtlasL10n.string("settings.acknowledgement.title")) {
            Text(settings.acknowledgementText)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, AtlasSpacing.sm)
        }

        Divider()

        DisclosureGroup(AtlasL10n.string("settings.notices.title")) {
            Text(settings.thirdPartyNoticesText)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, AtlasSpacing.sm)
        }
    }
}
```

> **注意**: 需要在 Localizable.strings 中新增 `settings.legal.title` 和 `settings.legal.subtitle` 两个 key。中文值分别为 "法律信息" 和 "致谢与第三方声明"。英文值分别为 "Legal" 和 "Acknowledgements and third-party notices"。

### 4.5 PermissionsFeatureView — 添加授权入口

**文件**: `Packages/AtlasFeaturesPermissions/Sources/AtlasFeaturesPermissions/PermissionsFeatureView.swift`

**当前问题**: 未授权的权限行只显示 "Needed Later" chip，无操作入口。

**改动**: 在 line 109-113 的 trailing 区域添加条件按钮：

```swift
// line 109 trailing 改为：
VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
    AtlasStatusChip(
        state.isGranted ? AtlasL10n.string("common.granted") : AtlasL10n.string("common.neededLater"),
        tone: state.isGranted ? .success : .warning
    )

    if !state.isGranted {
        Button(AtlasL10n.string("permissions.grant.action")) {
            openSystemPreferences(for: state.kind)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
```

添加跳转函数：

```swift
private func openSystemPreferences(for kind: PermissionKind) {
    let urlString: String
    switch kind {
    case .fullDiskAccess:
        urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    case .accessibility:
        urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    case .notifications:
        urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications"
    }
    if let url = URL(string: urlString) {
        NSWorkspace.shared.open(url)
    }
}
```

**额外改动**: 删除私有 `columns`，替换为 `AtlasLayout.metricColumns`。

### 4.6 HistoryFeatureView — 使用 Token

**文件**: `Packages/AtlasFeaturesHistory/Sources/AtlasFeaturesHistory/HistoryFeatureView.swift`

**改动**: 仅 Token 替换，无结构性变化。
- 所有 `spacing: 12` → `AtlasSpacing.md`
- 所有 `spacing: 10` → `AtlasSpacing.md`

### 4.7 TaskCenterView — 使用 Token + 添加分隔线

**文件**: `Apps/AtlasApp/Sources/AtlasApp/TaskCenterView.swift`

**改动**:
- line 11 `spacing: 18` → `AtlasSpacing.xl`
- line 12 `spacing: 8` → `AtlasSpacing.sm`
- line 14 `.title2.weight(.semibold)` → `AtlasTypography.sectionTitle`
- line 17 `.subheadline` → `AtlasTypography.body`
- line 38 `spacing: 10` → `AtlasSpacing.md`
- line 62 `padding(20)` → `padding(AtlasSpacing.xl)`
- 在标题和 callout 之间添加 `Divider()`

---

## 5. 全局搜索替换清单

以下是可以安全地在所有 Feature View 文件中批量替换的模式：

| 搜索 | 替换 | 范围 |
|------|------|------|
| `spacing: 16)` (在 LazyVGrid/VStack 中) | `spacing: AtlasSpacing.lg)` | 所有 Feature View |
| `spacing: 12)` (在 VStack 中) | `spacing: AtlasSpacing.md)` | 所有 Feature View |
| `spacing: 8)` (在 VStack 中) | `spacing: AtlasSpacing.sm)` | 所有 Feature View |
| `spacing: 10)` | `spacing: AtlasSpacing.md)` | TaskCenterView |
| `.font(.subheadline)` (非 `.weight`) | `.font(AtlasTypography.body)` | 所有文件 |
| `.font(.subheadline.weight(.semibold))` | `.font(AtlasTypography.label)` | 所有文件 |
| `.font(.headline)` | `.font(AtlasTypography.rowTitle)` | 所有文件（非 icon 处） |
| `.font(.caption.weight(.semibold))` | `.font(AtlasTypography.caption)` | 所有文件 |
| 私有 `columns` 属性 | `AtlasLayout.metricColumns` | Overview/SmartClean/Apps/Permissions |

---

## 6. 新增本地化字符串

在 `zh-Hans.lproj/Localizable.strings` 和 `en.lproj/Localizable.strings` 中添加：

| Key | 中文 | English |
|-----|------|---------|
| `settings.legal.title` | 法律信息 | Legal |
| `settings.legal.subtitle` | 致谢与第三方声明 | Acknowledgements and third-party notices |
| `permissions.grant.action` | 前往授权 | Grant Access |

---

## 7. 实施顺序

### Phase 1 — 设计系统核心迁移
1. 在 `AtlasDesignSystem.swift` 中删除 `AtlasPalette`，所有引用改为 `AtlasColor.*`
2. 删除旧的 `cardBackground`/`cardBorder` 函数，所有引用改为 `atlasCardBackground`/`atlasCardBorder`
3. 用 Token 重写 `AtlasScreen`（§2.1）
4. 用 Token 重写 `AtlasMetricCard`（§2.2）
5. 用 Token 重写 `AtlasInfoCard`（§2.3）
6. 用 Token 重写 `AtlasCallout`（§2.4）
7. 用 Token 重写 `AtlasDetailRow`（§2.5）
8. 用 Token 重写 `AtlasStatusChip`（§2.6）
9. 用 Token 重写 `AtlasEmptyState`（§2.7）
10. 用 Token 重写 `AtlasLoadingState`（§2.8）

### Phase 2 — App Shell
11. 侧边栏行升级（§3.1）
12. 工具栏图标增强（§3.2）
13. 详情页转场动画（§3.3）

### Phase 3 — Feature Screen 优化
14. Overview 英雄指标（§4.1）
15. SmartClean 双 CTA 修复（§4.2）
16. Apps 行内按钮（§4.3）
17. Settings 轻量化（§4.4）
18. Permissions 授权入口（§4.5）
19. History Token 替换（§4.6）
20. TaskCenter Token 替换（§4.7）

### Phase 4 — 全局清理
21. 批量替换 spacing/font 硬编码（§5）
22. 新增本地化字符串（§6）
23. 编译验证 + 全量 UI 测试

---

## 8. 文件清单

| 文件 | 改动类型 |
|------|---------|
| `Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/AtlasBrand.swift` | ✅ 已创建 |
| `Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/AtlasDesignSystem.swift` | 重构 |
| `Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift` | 修改 |
| `Apps/AtlasApp/Sources/AtlasApp/TaskCenterView.swift` | 修改 |
| `Packages/AtlasFeaturesOverview/Sources/.../OverviewFeatureView.swift` | 修改 |
| `Packages/AtlasFeaturesSmartClean/Sources/.../SmartCleanFeatureView.swift` | 修改 |
| `Packages/AtlasFeaturesApps/Sources/.../AppsFeatureView.swift` | 修改 |
| `Packages/AtlasFeaturesHistory/Sources/.../HistoryFeatureView.swift` | 修改 |
| `Packages/AtlasFeaturesPermissions/Sources/.../PermissionsFeatureView.swift` | 修改 |
| `Packages/AtlasFeaturesSettings/Sources/.../SettingsFeatureView.swift` | 修改 |
| `Packages/AtlasDomain/Sources/.../Resources/zh-Hans.lproj/Localizable.strings` | 新增 3 个 key |
| `Packages/AtlasDomain/Sources/.../Resources/en.lproj/Localizable.strings` | 新增 3 个 key |
