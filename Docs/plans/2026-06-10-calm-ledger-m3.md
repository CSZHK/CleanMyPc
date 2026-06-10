# Calm Ledger 重设计 — M3 屏幕迁移 实施计划

> 批次 H→I→J→K→L→M 顺序执行；每批次「实施者 + 合并审查 + 客观门禁」。布局与状态机真相源 = 规格 v1.1 §2/§3（实施者直接读取），本计划承载：分解结构、模型契约、改名清单、批次门禁。

**Goal:** 8 屏 + 壳层全部迁移至 Calm Ledger 骨架；路由改名落地；№/回执上线；回归红线（扫描→复核→执行→恢复行为不变）守住。

**通用门禁（每批次收尾）:** `swift build --package-path Apps`（0 error）+ `swift test --package-path Packages | grep Executed`（不回退）+ `swift test --package-path Apps | grep Executed`（不回退）+ `node scripts/design/contrast-check.mjs`（ALL PASS）。Batch I 起加 `swift run` 烟测（启动 5s 无崩溃）。视觉人工矩阵留 M4（trace 记 human-pending，不伪装）。

**通用红线:** 协议层/Worker 零改动；Apps 不引入批量卸载；切屏往返不丢阶段/勾选（ViewState 挂 AtlasAppModel）；恢复承诺文案状态驱动（§1.6 fail-closed）；feature 视图文件 ≤350 行。

---

## Batch H — Token 增补 + 模型契约 + 路由改名 + 壳层

### H1 Token 增补（PER Backlog #9 决策落地）
- manifest 增 `AtlasOnBrand`（light `#FFFFFF` / dark `#0C1614`）、`AtlasBannerEnd`（light `#0C5F58` / dark `#2BC4B1`）；contrastPairs 增 2 对（OnBrand×AtlasBrand、OnBrand×AtlasBannerEnd，min 4.5）→ 生成器跑出 35 colorsets，gate 36 检查
- `AtlasColor` 增 `onBrand/bannerEnd`；`bannerGradient` 第二停 brandHover→bannerEnd；`AtlasPrimaryButtonStyle`、`AtlasActionBar` 主按钮、`AtlasNextActionBanner` 文字色 白→`onBrand`；fixture/count 35 同步
- 测试：既有 + gate 36/36

### H2 AtlasAppModel 工作流 ViewState（规格 §2.3 状态机宿主）
```swift
// Apps/AtlasApp/Sources/AtlasApp/AtlasWorkflowViewState.swift（新文件）
struct AtlasWorkflowViewState: Equatable {
    var displayedStage: Int = 0          // 正在查看的阶段（回看时 ≠ currentStage）
    var currentStage: Int = 0            // 真实工作流阶段
    var planNumber: Int?                 // №（扫描完成分配）
    var receiptCode: String?             // #XXXX（扫描摘要 SHA256 前 4 hex 大写）
    var selectedIDs: Set<String> = []    // 勾选（单一计划作用域：№ 变更即清空）
    var riskFilter: String? = nil
    var evidenceSelectionID: String? = nil
    var drawerPresented: Bool = false
}
// AtlasAppModel 增:
@Published private(set) var workflowStates: [AtlasRoute: AtlasWorkflowViewState] = [:]
func workflowState(for route: AtlasRoute) -> AtlasWorkflowViewState   // 读（缺省新建）
func updateWorkflowState(for route: AtlasRoute, _ mutate: (inout AtlasWorkflowViewState) -> Void)
```
- **阶段推导为纯函数**（可测）：`static func stage(for route:, model snapshot…) -> (current: Int, …)`，映射表照抄规格 §2.3（无计划→①；isScanning→①进行中；plan fresh→②；isExecuting→③；executionCompleted→④回执；0 发现→②空态；执行失败→③错误态）
- **№/回执派生**（PER Decision Log 细则）：`AtlasSettings` 增 `ledgerNextNumber: Int?`（decode 默认 nil；首次取号时初始化为「既有任务运行数+1」并持久化）；模型增 `assignPlanNumber(for:)`（扫描完成调用：取号自增 + receipt = SHA256(摘要稳定串).prefix(4)）与 `supersedePlan(for:)`（重扫确认：旧 № 状态→已作废）。AtlasSettings 改动走 D-011 版本化信封向后兼容（新字段 optional），AtlasSettings 在 AtlasDomain——**确认该改动不触协议**（settings 为客户端持久化）
- 测试（AtlasAppModelTests）：阶段映射表逐行、№ 自增与作废、receipt 确定性、ViewState 跨 route 往返保持、№ 变更清空勾选

### H3 路由改名（编译期清单，evidence: M1 评审）
`AtlasDomain.swift` case `.history`→`.ledger`（含 SidebarSection/icon/subtitle context）；`AppShellView.swift` 4 处；`AtlasAppCommands.swift` Cmd+5；`TaskCenterView.swift`「打开历史」→「打开台账」；删除未引用 `AtlasIcon.history`、增 `AtlasIcon.ledger = "list.bullet.rectangle"`（或近似 ≣）；契约测试 `testPrimaryRoutesMatchFrozenMVP` 期望值「历史」→「台账」（解冻已记录于 REQ）；新增 L10n 键 `route.ledger.title/subtitle` zh/en（旧 history.* 内容键的全量迁移留 M4）；`ReadmeAssetExporter.swift` 文件名 atlas-history→atlas-ledger
- 测试：Domain/Apps 既有测试更新后全绿

### H4 壳层（AppShellView + AtlasApp + 菜单 + 任务中心）
- 窗口：`AtlasApp.swift` defaultSize 1180×740、minWidth/minSize 980×640（两处同步；frame autosave 行为已接受——D-012）
- 侧栏：两组重组（工作=概览/智能清理/文件整理/应用；记录=台账/权限）+ 沉底 设置/关于；`ATLAS.` serif 字标（`AtlasTypography.ledgerFont(size: 15, weight: .bold)` + brand 句点）；选中态 brand 胶囊；动态副标题沿用
- 工具栏：搜索沿用；**回执芯片**（mono `dataCaption`，显示当前路由模块 `workflowStates[route].receiptCode`，无回执隐藏）；任务中心铃铛沿用
- Toast 容器与行动栏共存：读 `AtlasActionBarHeightKey`（G5 已上报）把 toast 底部 offset 上移
- 菜单：导航名随改名；Cmd+Shift+R 触发重扫确认（接 H2 supersede 流，菜单侧仅发意图，确认 UI 在屏幕层 Batch I）
- 任务中心弹层换装（surface 卡 + mono 数据 + 运行中行 № 前缀）
- 测试：AppShell 相关冒烟 + 侧栏分组纯函数

### H5 治理
PER #4 标 IN_PROGRESS 注 Batch H done；commit 序列每子任务一个。

## Batch I — 智能清理样板间（骨架首次全装配）

文件分解（`Packages/AtlasFeaturesSmartClean/`）：
- `SmartCleanFeatureView.swift`（协调 ≤350：装配 AtlasScreen(actionBar:) + 标题区(№/副标题) + AtlasStageBar + 阶段内容路由 + 证据面板/抽屉）
- `SmartCleanStageViews.swift`（①扫描进行中 mono 路径滚动 / ②复核列表（风险分组+过滤芯片+勾选，行尾 ⓘ 开抽屉）/ ③执行实时行流 / ②空态·③错误态）
- `SmartCleanReceiptView.swift`（④回执：AtlasLedgerSurface 卡 + 结果摘要 + AtlasStampBadge(事实文案) + 「在台账中查看 →」）
- `SmartCleanEvidenceBuilder.swift`（Finding → AtlasEvidenceContent/Aggregate 纯函数：why=解释字段、evidence=路径/大小/最近访问/来源签名 KV、recovery=按计划真实可恢复性，fail-closed）
行为要点：阶段条接 H2 状态机（回看只读 + 「返回当前阶段」；重扫确认对话「当前计划 №N 将作废」）；行动栏 promise 状态驱动三式（全部/部分/无 ⛨ 句）；执行完成发全局 Toast「已入账 №N · 撤销」——撤销动作：若模型已有直接恢复 API 则调用，否则导航台账详情（实施者考证 `onUndoExecution`/restore 路径后选择并报告）；<880 抽屉（非模态、点外收回、Esc、焦点归还）
测试：EvidenceBuilder 纯函数 ×3、promise 三式、回看只读谓词；门禁 + `swift run` 烟测 + `ReadmeAssetExporter` 跑一次导出智能清理截图（路径写报告，供人工目检）

## Batch J — 台账屏（暖面主场，1390 行拆解）

`Packages/AtlasFeaturesHistory/`（包名保留）：
- `LedgerFeatureView.swift`（协调：暖面页头 serif「维护台账」+ 导出按钮 + 统计行 + 过滤芯片 + 左右栏装配）
- `LedgerTimelineView.swift`（AtlasLedgerTimeline 装配：task runs + recovery items → AtlasLedgerEntryModel 映射纯函数；№ = 存储号或时间序计算号（Decision Log 规则）；进行中置顶）
- `LedgerDetailView.swift`（mono 执行数据 + 包含清单 + 还原全部/逐项还原（**沿用既有恢复调用，行为不变**）+ AtlasStampBadge(.watermark)）
- `LedgerArchiveView.swift`（「更早归档」折叠）
- `LedgerExportBuilder.swift`（导出 markdown 报告纯函数 + NSSavePanel 落盘；页脚「本报告由 Atlas 在本机生成，仅供个人参考」）
旧 `HistoryFeatureView.swift` 删除；文案经新键 `ledger.*`（M4 统一清旧键）
测试：Entry 映射 ×2、编号规则（存量时间序 vs 新计数器）、导出 builder；门禁 + 截图导出

## Batch K — 概览（指挥台 + 台账流）

`Packages/AtlasFeaturesOverview/`：
- `OverviewFeatureView.swift`（协调：问候+状态胶囊行 → 横幅 → 左指挥台/右台账流；<880 纵向堆叠）
- `OverviewRecommendation.swift`（**推荐优先级纯函数**：规格 §3 表 1–5 行逐条；输入 snapshot/permissions/plan 状态/磁盘占用/忽略表；输出 banner 配置或「状态良好」；rationale 带 mono 时效）
- `OverviewCommandColumn.swift`（健康环 AtlasCircularProgress + 模块入口行：智能清理/应用/文件整理/台账 状态+箭头）
- `OverviewLedgerFeed.swift`（AtlasLedgerSurface 内最近 3–5 条 № 条目 + 「查看完整台账 →」，逐条可点跳台账——回链红线）
- 忽略冷却：`AtlasSettings` 增 `recommendationSnooze: [String: Date]?`（7 天；optional 向后兼容）
- 一键开始落点：自动扫描 + 预选安全组 + 停在②复核（不跳过复核）
测试：推荐优先级表逐行（含冷却）、空推荐判定；门禁 + 截图导出

## Batch L — 应用 + 文件整理

Apps（`AtlasFeaturesApps`，简化骨架）：`AppsFeatureView`（协调）+ `AppsListView`（应用行：图标/名称/mono 大小/残留徽记；单选）+ `AppsEvidencePanelBuilder`（10 类证据足迹→EvidencePanel 分组 KV + 卸载计划预览 + 残留估计）+ 行动栏（选中且卸载计划就绪时浮现；卸载流程行为不变）；删除 `AtlasLegacyEvidenceGroupCard` 消费（弃用件随之删除）
FileOrganizer（五段）：`FileOrganizerFeatureView`（协调 + 五段 StageBar）+ `FileOrganizerStageViews`（①扫描 ②规则=现 RuleEditor 迁入 ③预演=dry-run 移动清单+冲突标记 ④执行 ⑤回执）+ `FileOrganizerEvidenceBuilder`（「此文件为何分类至 X」：规则命中链）；№/回执接 H2（与智能清理同序列）
测试：两个 EvidenceBuilder、五段映射；门禁 + 截图导出（apps + 整理）

## Batch M — 权限/设置/关于 + 壳层收尾 + M3 治理

- 权限：hero 环沿用换装；权限行接证据三段式展开（为什么需要/影响范围/如何授权——内容来自现有 rationale 字段重组）；限制模式 callout 换装
- 设置：三 tab 换装；恢复段增「恢复区占用」mono 行（数据=recovery items 总大小，现有 snapshot 字段）；文档 sheet 换装（ledgerTitle 标题）
- 关于：换装（版本 mono、更新按钮新样式、二维码不动）
- 壳层收尾：更新按钮/权限弹窗样式统一；StageBar VO 自定义 action（findings M3 polish 项）；EvidencePanel executing 行稳定 id（findings 项，若 Batch I 未顺手做）
- **M3 治理收口**：CHG-2026-06-calm-ledger-m3（brief/verify 真实 Result）；trace M3 行 PASS（含 Apps 测试数）+ Actual ×2 回填；tasks/m3-screens DONE；execplan M3 ✓ M4 ▶；PER #4 FIXED；`ReadmeAssetExporter` 全套截图导出存档（zh+en，路径入 verify）
