# REQ-ui-ux-overhaul

## Title
Atlas macOS 全面 UI/UX 改进

## Change Class
MAJOR — 跨 6+ Feature 包的大规模 UI 层重构

## Status
DONE

## Priority
P0→P3 分级执行

## Truth Sources
- 设计系统: Packages/AtlasDesignSystem
- 领域模型: Packages/AtlasDomain
- 各 Feature 包: Packages/AtlasFeatures*
- App 层: Apps/AtlasApp

## Description
对 Atlas macOS 应用执行全面的 UI/UX 改进，覆盖信息架构、视觉层次、交互体验、设计系统补齐和性能优化共 6 大类 22 项改进。按 P0→P3 优先级顺序执行，每完成一个阶段向用户汇报进展。

## Project Constraints
- Swift 6.0 strict concurrency，macOS 14.0+
- 所有用户可见字符串必须通过 AtlasL10n 本地化（zh-Hans 默认 + en）
- 只能依赖 AtlasDesignSystem + AtlasDomain，Feature 包之间不能互相依赖
- 设计系统 token 不可修改（AtlasColor/AtlasTypography/AtlasSpacing/AtlasRadius/AtlasElevation/AtlasMotion），但可以新增组件
- 修改 AtlasAppModel 的 public API 签名时需同步更新 AppShellView 的调用点
- 每个改动必须考虑 accessibility（VoiceOver、reduceMotion、Dynamic Type）
- 不引入第三方依赖

## Execution Rules
1. 每个 P 级别内的任务按编号顺序执行
2. 每完成一个 P 级别，暂停汇报进展，等待确认后继续
3. 每个改动完成后运行 swift build 验证编译通过
4. 新增的 AtlasDesignSystem 组件需要同步更新 AtlasDesignSystem.swift 的 re-export
5. 涉及 AtlasAppModel 新增属性时，需同步更新 AtlasAppModelTests 的 fixture

---

## P0 — 必须完成

### P0-1: Overview 仪表盘重设计
当前: OverviewFeatureView 是一个超长线性滚动（Callout → HeroCard → Metrics → QuickActions → SystemSnapshot → RecommendedActions → RecentActivity），信息密度低、首屏价值不足。
目标: 将 Overview 改造为真正的仪表盘网格布局。
方案:
- Hero 区域（顶部通栏）: 保留 AtlasHeroCard，将 Quick Action 按钮整合到 Hero 区域右侧或下方，形成 hero + CTA 组合
- 仪表盘网格（Hero 下方）: 使用 LazyVGrid 构建不对称布局（宽屏 3 列，窄屏 2 列或 1 列）
  - System Snapshot 合并为 1 张紧凑卡片（Memory / Disk / Uptime 用 inline 小指标而非独立 MetricCard）
  - Recommended Actions 保留为 1 张卡片，最多显示 4 条 findings + "View All" 链接
  - Recent Activity 保留为 1 张卡片，最多显示 3 条 task runs + "View All" 链接
  - Permissions 状态卡（如未就绪）: 单独 1 张紧凑 warning 卡
- 宽屏时 Recommended Actions 与 Recent Activity 并排（2 列），窄屏时垂直堆叠
- 预期效果: 首屏可见 Hero + CTA + 4 张卡片，减少 ~40% 垂直滚动
- 文件: Packages/AtlasFeaturesOverview/Sources/AtlasFeaturesOverview/OverviewFeatureView.swift

### P0-2: Callout 泛滥治理
当前: 几乎每个屏幕都以 AtlasCallout 开头（Overview、SmartClean、Apps、History、Permissions、Settings），用户学会忽略。
目标: Callout 只在状态变化时出现，常态下隐藏或合并。
方案:
- Overview: 删除顶部独立 Callout，将状态信息合并到 Hero 区域的 subtitle
- SmartClean: 保留 Callout，因为它是状态机（scanning/ready/executing/failed）的核心展示
- Apps: 仅在 previewPlan != nil 或 restoreRefreshStatus != nil 时显示 Callout，默认态隐藏
- History: 仅在有 expiring items 或 active tasks 时显示 Callout
- Permissions: 删除顶部独立 Callout（与 HeroCard 内容重复），状态信息合并到 HeroCard subtitle
- Settings: 删除 Callout（Settings 页面不需要状态横幅）
- 文件: 各 AtlasFeatures*/Sources/*FeatureView.swift

### P0-3: 最小窗口尺寸
当前: 无最小窗口尺寸，用户可以把窗口缩小到导致 split-view 崩溃。
方案:
- 在 AtlasApp.swift 中给 WindowGroup 添加 `.defaultSize(width: 1024, height: 680)` 修饰符
- 在 AppShellView 或 AtlasApp 中通过 NSWindow 设置 minSize
- 文件: Apps/AtlasApp/Sources/AtlasApp/AtlasApp.swift

---

## P1 — 应该完成

### P1-1: 侧边栏动态信息
当前: SidebarRouteRow subtitle 是静态文案，不传递动态状态。
方案:
- AtlasRoute 扩展一个 `func dynamicSubtitle(snapshot:) -> String` 方法
- SmartClean: 显示 findings 数量和可回收空间
- Apps: 显示 apps 数量
- History: 显示 recovery items 数量
- Permissions: 显示 granted/required 或 ✓
- Overview: 显示 disk 使用率
- 在 AppShellView 的 SidebarRouteRow 中调用此方法传入 model.filteredSnapshot
- 文件: Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift, Packages/AtlasDomain 中 AtlasRoute 扩展

### P1-2: 卡片嵌套治理
当前: Apps detail 页面出现 InfoCard > Callout > InfoCard 3-4 层嵌套，padding 累积导致内容区过窄。
方案:
- 制定规则: 最多 2 层卡片嵌套
- AppsFeatureView 的 review-only section: 移除外层 AtlasInfoCard，改用 AtlasSectionDisclosure 扁平展示
- AppsFeatureView 的 preview plan: 内层 InfoCard 改为 VStack + AtlasSectionDisclosure
- SmartClean 的 plan preview 内部同理
- 文件: Packages/AtlasFeaturesApps, Packages/AtlasFeaturesSmartClean

### P1-3: 键盘快捷键增强
当前: 仅 ⌘↵ 和 ⌘⌥S。
方案:
- ⌘1~6: 切换侧边栏路由（overview/smartClean/fileOrganizer/apps/history/permissions）
- ⌘,: 打开 Settings（已有 AtlasAppCommands）
- 在 AtlasAppCommands.swift 中添加这些快捷键绑定
- 文件: Apps/AtlasApp/Sources/AtlasApp/AtlasAppCommands.swift, AppShellView.swift

### P1-4: Skeleton Loading
当前: AtlasLoadingState 显示 spinner，首次加载时整个页面布局跳变。
方案:
- 在 AtlasDesignSystem 中新增 AtlasSkeletonCard 和 AtlasSkeletonRow 组件
- 使用 shimmer 动画（线性渐变动画扫过灰色区域）
- Overview 和 SmartClean 首次加载时使用 skeleton 替代空白或 spinner
- 数据到达后通过 transition 平滑切换到真实内容
- 文件: Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/Components/ 新增

### P1-5: File Organizer Metric Cards 响应式修复
当前: 使用 HStack 排列 3 张 metric cards，窄窗口不换行。
方案:
- 替换为 LazyVGrid(columns: AtlasLayout.adaptiveMetricColumns(for: contentWidth))
- 与其他屏幕保持一致
- 文件: Packages/AtlasFeaturesFileOrganizer/.../FileOrganizerFeatureView.swift (line 373-396)

---

## P2 — 建议完成

### P2-1: Toast/Inline Notification 组件
在 AtlasDesignSystem 新增 AtlasToast 组件。用于扫描完成、恢复成功、设置已保存等瞬时反馈。支持 auto-dismiss (3s) 和手动关闭。在 AtlasAppModel 中添加 toast state，在 AppShellView 底部 overlay 呈现。

### P2-2: Undo 机制统一
SmartClean 执行完成后，在页面顶部显示与 File Organizer 一致的 undo/restore banner。将 File Organizer 的 undoBanner 提取为共享组件 AtlasUndoBanner，放入 AtlasDesignSystem。

### P2-3: File Organizer 控制面板拆分
将当前单一 AtlasInfoCard 中的 folder selector + destination + recursive toggle + scan/preview/execute 全部拆为:
- **配置区** (AtlasSectionDisclosure, 默认收起): Folder selector + Destination + Recursive toggle + Rules
- **操作区** (常驻): Scan → Preview → Execute 的 step indicators

### P2-4: Filter Chips
- SmartClean: 在 Findings 上方添加 filter chips (All / Safe / Review / Advanced)
- Apps: 添加 leftover-only filter toggle
- 这些 filter 与已有的 searchText 组合使用

### P2-5: Settings 嵌套 ScrollView 修复
Settings 使用 AtlasScreen(useScrollView: false)，完全自己管理滚动。将 panel tabs 固定在 InfoCard 顶部，只滚动下方内容。

### P2-6: 图片缓存
为 FileOrganizerFeatureView 的 FileThumbnailView 引入 NSCache-based 图片缓存，避免大量文件时重复磁盘读取。

---

## P3 — 锦上添花

### P3-1: 统一 Tab/Segment 组件
新增 AtlasSegmentedControl 组件，统一 Settings 和 History 中的 segmented picker 风格。

### P3-2: Tooltip 组件
新增 AtlasTooltip modifier，用于 metric card 细节说明和 icon 功能解释。

### P3-3: 可访问性增强
- AtlasStatusChip 内增加 icon (success→✓, warning→△, danger→✕)
- 所有 withAnimation 调用前检查 reduceMotion
- 路由切换后管理 VoiceOver 焦点

### P3-4: Dynamic Type 支持
对 AtlasTypography 中的固定字号添加 @ScaledMetric 包装或设置 upper bound，确保极端字号下不破坏布局。
