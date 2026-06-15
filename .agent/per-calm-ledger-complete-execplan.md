# PER: Calm Ledger 重设计全量收口（M2 → M3 → M4）

**Status:** IN_PROGRESS
**Created:** 2026-06-10
**Scope:** Packages/AtlasDesignSystem · Packages/AtlasFeatures* · Apps/AtlasApp · AtlasDomain（路由/L10n）· Docs/*（同步清单）
**Dimension:** 全量 · 深度: 标准（P0+P1）
**Canonical truth:** 规格 Docs/design/2026-06-10-frontend-redesign-calm-ledger.md (v1.1) · REQ iterations/REQ-calm-ledger-redesign/ · findings .agent/calm-ledger-redesign-findings.md（本文件只做编排跟踪，不复制内容）

## Progress
- [x] Phase 1: 范围确认（用户指令「全部干完」，无暂停点）
- [x] Phase 2/3: M2 组件层（Batch E 前置修复 + Batch F/G 组件；CHG-m2 6/6 PASS 已关闭）
- [ ] Phase 2/3: M3 屏幕迁移（Batch H 壳层/改名 → I 智能清理样板间 → J 台账 → K 概览 → L 应用/整理 → M 权限/设置/关于）
- [ ] Phase 2/3: M4 收尾（L10n / 文档同步 / 截图 / 门禁）
- [ ] Phase 4: 跨边界回归（全量测试 + 门禁 + 构建）
- [ ] Phase 5: 收口总结（trace 回填 + Close Gate）

## Backlog
| # | Severity | Category | Source | Description | Status |
|---|----------|----------|--------|-------------|--------|
| 1 | P0 | 测试阻塞 | findings L7 | Apps E2E 测试替身缺 scanFolders(_:destinationBasePath:recursive:)，阻塞 M3 门禁 | FIXED |
| 2 | P0 | 开发路径 | findings L6 | swift run 下 32 colorset 解析 nil → 生成式 Swift 回退表（同一 manifest，保单一真相源） | FIXED |
| 3 | P1 | M2 | 规格 §4.2/§4.3 | 9 新组件 + AtlasScreen actionBar/drawer 插槽 + 修改/吸收/扩展清单 | FIXED |
| 4 | P1 | M3 | 规格 §2/§3 | 壳层（侧栏/工具栏/菜单/任务中心/窗口）+ 路由改名 + ViewState + 8 屏迁移 | IN_PROGRESS（Batch H done：H1 tokens 103f672 · H2 ViewState/№/回执 188b422 · H3 改名 2cef84b · H4 壳层 134f0f6。Batch I done：I0 评审修复 93bc7e5 · 样板间 5b59e5d · 接线 e4f7dd0。Batch J done：台账屏四件套 + ExportBuilder（HistoryFeatureView 1390 行删除）· history.* 121×2 键清理（零交叉引用）· ledger.* 键新增 · № 时间序计算号纯函数 · 导出 builder 纯函数 + NSSavePanel · stamp 水印 fail-closed；门禁 Packages 437/0 · Apps 58/0 · contrast 36/36 · 0 warning · swift run 烟测过 · 文件 ≤350。Batch K done 95db338：概览四件套——OverviewRecommendation 纯函数（5 行优先级表 + snooze 冷却 + mono 时效）/ OverviewCommandColumn（健康环 + 模块入口行）/ OverviewLedgerFeed（№ 降级复用 Batch J 同款 +1 抗碰撞）/ OverviewFeatureView 协调（问候+胶囊行→AtlasNextActionBanner→左指挥台/右台账流，<880 纵向）；snooze UserDefaults `atlas.overview.snooze.<id>` 纯客户端（PER da8c42f）；一键开始落 ② 复核不跳过；AppShellView 仅改 :153 构造点 + 4 私有 helper；新键 overview.greeting/capsule/command.*/feed.*/recommend.*（zh+en 52×2），旧 overview.actions/activity/metric/risk/snapshot.optimizations/callout 孤儿键 M4 清；门禁 Packages 487/0（+50 测试：推荐 23 + snooze 7 + feed 12 + tone 4 + view-init 4）· Apps 58/0 · contrast 36/36 ALL PASS（基线文档写 36 实测 36，脚本未改）· 0 新 warning（AtlasCoreAdapters/AtlasFileOrganizerScanner.swift:25 旧 warning 来自 9aab570 非 Batch K）· swift run 烟测过 · 协调文件 337 ≤350。Batch L1 done：Apps 简化骨架——AppsFeatureView 重写 925→341（协调）/ AppsListView（应用行+单选+残留过滤芯片）/ AppsEvidencePanelBuilder（10 类证据足迹→AtlasEvidencePanel 三段式 KV + 卸载计划预览 ActionPlan→residual/recovery fail-closed）/ AppsActionBar + AppsRestoreRefreshSection（拆出 ≤350）；弃用件 AtlasEvidenceGroupCard.swift + typealias AtlasLegacyEvidenceGroupCard 删除（全仓零引用）；新键 apps.evidence.*/apps.actionbar.*（zh+en 13×2）；卸载流程行为不变（onPreviewAppUninstall→预览 / 计划就绪→确认 dialog→onExecuteAppUninstall）；AppShellView 仅改 AppsFeatureView 构造点（:306，签名零变化）；门禁 Packages 512/0（+25 测试）· Apps 58/0 · contrast 36/36 · 0 新 warning · swift run 烟测过 · 协调文件 341 ≤350。余 Batch L2 文件整理→M） |
| 5 | P1 | M4 | 规格 §0.4/§7 | L10n 键迁移（~120×2）+ 9 文档同步 + 截图基线 + 全量门禁 | TODO |
| 6 | P2 | 视觉 | findings L5 | 宋体粗体 face/traits（台账标题观感不足时） | FIXED（M2 Batch F 评审修复 068a4da：cascade 描述符按 weight 带 face，bold 实测解析 STSongti-SC-Bold，测试锁定） |
| 7 | P0 | 测试阻塞 | Batch E 发现 | AtlasAppModel.swift:696 `NSApp.appearance` 强解包——裸 swift test 无 NSApplication，29 测试全崩（来源 main 4ff6c08，此前被编译失败掩盖） | FIXED |
| 8 | P0 | 开发路径 | Batch E 发现 | 裸 swift-run 无 .app bundle，UNUserNotificationCenter 权限链抛 NSException 启动即崩（stash 基线证明 pre-existing） | FIXED |
| 9 | P0 | 可达性 | Batch G 发现 | 深色「白字 on brand」2.56:1 <AA——波及主按钮/横幅/行动栏主操作（gate 只测过反向 brand-on-surface） | FIXED（Batch H1 103f672：AtlasOnBrand/AtlasBannerEnd 落地，四向实测 5.47/7.19/7.52/8.45 全 ≥4.5，gate 36/36） |

## Decision Log
- 2026-06-10: swift-run 色彩缺口采用方案 a「生成式 Swift 回退表」——generate-colorsets.mjs 从同一 manifest 额外产出 AtlasColorFallback.swift，AtlasColor 经 atlasColor(_:) 解析（named 命中走 catalog，缺失走 dynamicProvider 回退）；保持单一真相源，发布路径行为不变。
- 2026-06-10: 评审模式调整——批次内「实施者 + 单合并审查者（spec+质量合一）+ 客观门禁（build/test/contrast）」，控制器核 diff；理由：M0/M1 六轮两段审查全 Approve，门禁已脚本化。
- 2026-06-10: Backlog #9 决策——新增 `AtlasOnBrand` token（light #FFFFFF / dark #0C1614，与视觉方向板深色稿一致：暗字亮底）+ `AtlasBannerEnd` 渐变端 token（light #0C5F58 加深 / dark #2BC4B1）；主按钮/横幅/行动栏主操作文字一律 onBrand，bannerGradient 第二停改 BannerEnd；新增 2 对比对（OnBrand×Brand、OnBrand×BannerEnd），四向预算 5.47/7.24/6.9/8.5 全 ≥4.5。落 Batch H；产品负责人不认可暗字亮底可单 token 回退。
- 2026-06-10: 台账编号与回执派生（规格 §1.6 落地细则）——`AtlasSettings` 增 `ledgerNextNumber: Int`（decode 默认按「既有任务运行数+1」一次性初始化，D-011 版本化信封内向后兼容）；扫描完成产出计划时分配 № 并自增，重扫作废旧 № 产新 №；历史任务运行无存储 № 者按时间序计算展示编号（仅限计数器引入前的存量，无碰撞）。回执 #XXXX = 扫描摘要稳定串 SHA256 前 4 hex，存于屏幕 ViewState，工具栏芯片显示当前路由模块最近回执。协议层零改动。
- 2026-06-10（**修订上一条**，Batch H BLOCKED 证据驱动）：AtlasSettings 实际经协议传输（AtlasProtocol.swift:35/:81）且持久化权威在 Worker，Worker `sanitized(settings:)` 逐字段重建、静默丢弃未枚举字段（AtlasScaffoldWorkerService.swift:1526-1536）——「存于 AtlasSettings」细则作废。**改为纯客户端持久化**：№ 计数器经 `UserDefaults`（key `atlas.ledger.nextNumber`，AtlasAppModel 封装读写，首次取号按既有任务运行数+1 初始化）；Batch K 推荐冷却同改 UserDefaults（key 前缀 `atlas.overview.snooze.`）。协议/Worker 红线保持完好；重装后编号重新起算——本地维护工具可接受，记入设计偏差。
- 2026-06-10: 存量缺陷记档（不入本 REQ，建议单独 CHG）——Worker `sanitized()` 漏传 `theme`：任一次设置保存回显会把显式主题重置为 .system。修复需触 Worker（本 REQ 红线外）；证据链已由 Batch H 实施者固化（file:line 见其报告）。

## Surprises & Discoveries
- 2026-06-10 ~18:0x: Batch E 实施子代理（agentId a185efceb1cc29996）撞会话用量上限（19:00 Asia/Shanghai 重置），24 次工具调用后中断。
- Batch E Part 1 进行中发现：Apps 测试漂移比 findings 记录的更广——不止两个 E2E 替身缺 `scanFolders(_:destinationBasePath:recursive:)`，`refreshFileOrganizerPreview()` 也已改签名为 `refreshFileOrganizerPreview(entryIDs:)`，多处调用点需机械同步（子代理已改约 4+ 处，未跑测试、未提交）。

## CHECKPOINT-2026-06-11-1405（Batch L2 中断 + 服务端 529 过载）
- glm-5.2 + sonnet 网关双双 529（服务端全面过载，重试无效）。L1(Apps) 审查两次撞 529 0 输出——L1 代码已提交（1e1fd0f，512/0），审查待 model 恢复重试。
- **L2(FileOrganizer) 中断点**（agentId a33d899a720f97271，76 工具调用后 529）：feature 包重写完成（FileOrganizerFeatureView 协调器 940→~254 + 5 新文件 FileOrganizerActionBarModel/EvidenceBuilder/StageMap/StageViews/SupportViews + zh L10n +46 键）。**缺**：① en.lproj 同步（L2 只改了 zh）② AppShell resolve-on-render 接线（新增 `fileOrganizerWorkflowState` 镜像 smartCleanWorkflowState :377，经 FileOrganizerStageMap.resolve 推导五段）③ 测试（StageMap 五段/EvidenceBuilder/resolve 一致性）④ 收尾验证+commit。WIP 在工作树保留（2 modified + 5 untracked）——**不要 checkout/clean**。
- **恢复**：服务端 529 恢复后，派 L2 resume（或新实施者读本 CHECKPOINT）——先 `swift build --package-path Packages` 看 en 缺键/AppShell 未接线编译缺口，补完 en+AppShell fileOrganizerWorkflowState+测试+验证+commit；再重派 L1 审查。
- 后续序：L2 收口 → L2 审查 → Batch M（权限/设置/关于）→ M3 治理收口 → M4 Batch N → Phase 4 全量回归 → Phase 5 收口。
- **门禁基线**（L1 收口，L2 WIP 编译不过）：Packages 512/0 · Apps 58/0 · contrast 36/36 · 0 新增 warning。

## CHECKPOINT（恢复指令，更新于 Batch K 收口后）
- **工作树状态**: Batch L1 已落地（待提交：AppsFeatureView 重写 925→341 + AppsListView/Builder/ActionBar/RestoreRefreshSection/UIMapping 新件 + AtlasEvidenceGroupCard.swift 删除 + L10n 13×2 + PER 4 项修正）。
- **Batch L1 接口备忘**（Batch L2/M 消费）: AppsFeatureView 公共 init 签名**零变化**（11 输入 + 4 回调保留，AppShellView:306 构造点不动）；卸载流程行为不变——主操作经 `handlePrimaryAction`：无 plan→`onPreviewAppUninstall`（建预览）/ plan 就绪→`.confirmationDialog`→`onExecuteAppUninstall`（执行）；apps 卸载**不走 SmartClean 的 Toast/№ 台账入账**（`executeAppUninstall` 直接落 workspaceController，无 `postSmartCleanExecutionToast`）——这是现状（pre-existing），Batch L1 不引入也不修复，Apps 台账入账接线留 M4（规格 §1.6 Apps 段未列 № 序列）；单选模型沿用 `currentPreviewedAppID`/`selectedAppID`，**不引入复选/批量**（规格 §2.3 Apps 段明确单选——回归红线）；证据面板 `AtlasEvidencePanel(state:)` 单选三段式（why/evidence KV/recovery ⛨ fail-closed）——10 类证据足迹映射：`AppFootprint.evidenceSummary: [AtlasAppEvidenceCategory: Int]?`（appBundle/supportFiles/caches/preferences/logs/launchItems/savedState/containers/groupContainers/miscLeftovers 共 10 类）逐类非零→KV 行（`AtlasAppEvidenceCategory.allCases` 稳定序），bundlePath/bytes 领先；残留估计 = `ActionPlan.estimatedBytes`（可恢复）+ `estimatedReviewOnlyBytes`（仅复核）；`AtlasLegacyEvidenceGroupCard` 弃用件文件 + typealias 已删除（grep 零引用确认）。
- **恢复后续序**: M3 计划（Docs/plans/2026-06-10-calm-ledger-m3.md）→ Batch L 应用/整理 → M 权限/设置/关于 + M3 治理收口 → M4 Batch N（L10n 孤儿键清理 + 文档同步 + 截图基线 + 全量门禁）→ Phase 4 全量回归 → Phase 5 收口。
- **门禁基线**（Batch L1 收口）: Packages 512/0（Batch K 487 +25：Apps evidence builder 25）· Apps 58/0（无回退）· contrast 36 checks ALL PASS（Batch J/K 文档曾写 37，实测 36——18 对 × 2 模式，ALL PASS 行不计；K 审查纠错回归 36）· Apps build 0 新 warning（1 旧 warning 来自 `Packages/AtlasCoreAdapters/Sources/AtlasCoreAdapters/AtlasFileOrganizerScanner.swift:25`，源自 commit 9aab570，非 Batch K/L）· swift run 烟测过 · 新/改源文件 wc -l 协调 ≤350（AppsFeatureView 341 / AppsListView 211 / AppsEvidencePanelBuilder 192 / AppsActionBar 48 / AppsRestoreRefreshSection 66 / AppsRestoreRefreshUIMapping 55）。Batch K 记录：OverviewRecommendation 361 行——纯 enum 非 SwiftUI View 文件，350 红线字面针对「feature 视图文件」，enum 作纯逻辑枚举属解释边界，记为可接受但非先例（不存在「Batch J 纯逻辑文件 ≤199」的先例——Batch J 纯逻辑文件 LedgerExportBuilder 等均 ≤199，但该先例不扩及 enum；诚实治理：可接受但需解释，不得作为后续超限默认依据）。
- **Batch K 接口备忘**（Batch L/M 消费）: OverviewRecommendation 为纯函数（输入 `Inputs` struct，输出 `BannerConfig?`）；snooze store 协议 `OverviewSnoozeStore`（默认 `OverviewUserDefaultsSnoozeStore` key 前缀 `atlas.overview.snooze.<id>`，测试用 `InMemorySnoozeStore`）；AppShellView 构造点 :153 新增 8 输入（requiredPermissionsGranted/Total、isCurrentSmartCleanPlanFresh、currentPlanReclaimableBytes/FindingCount/Number、latestScanReceiptCode、planNumberForRun 闭包）+ 4 新回调（onNavigateToApps/FileOrganizer/Ledger、onSelectLedgerEntry），4 私有 helper（overviewRequiredPerms/Granted/Total/PlanReclaimableBytes）；OverviewLedgerFeed 复用 Batch J № 降级规则（seedBase = max(count, storedMax) + 1，+1 抗碰撞）—— 重实现而非导入（feature-package 边界保持，spec §0.3）；孤儿键 overview.actions/activity/metric/risk/snapshot.optimizations/callout 全部零交叉引用，M4 Batch N 清。
- **Batch I 接口备忘**（Batch J/L 消费）: 裁决 A=resolve-on-render——AppShellView 渲染时经 `AtlasWorkflowStageMap.resolve` 推导 currentStage（输入含新增 `model.smartCleanExecutionCompleted`），ViewState 存储 currentStage 仅 bookkeeping（注释已锁），FileOrganizer Batch L 必须同模式；裁决 B=重扫确认单一路径——菜单/屏内按钮 → `rescanConfirmationPending` → 屏内 `.confirmationDialog`（`smartclean.rescan.*`）→ confirm=`supersedePlan`+scan / cancel=清标志；`supersedePlan(.smartClean)` 同步清 executionCompleted/Receipt/isCurrentSmartCleanPlanFresh；执行回执 `SmartCleanExecutionReceipt`（真实 recovery delta + 留存天数，StampBadge fail-closed）；Toast「已入账 №N · 撤销」undo=`undoSmartCleanExecution()` 串行 `restoreRecoveryItem`（与台账还原同一恢复点，真实文件回滚已测）；`refreshPlanPreview(findingIDs:)` 可选子集（执行已选 N 项路径，首个有项计划自动取 №）；Toast 容器 dwell 8s（§3.1）。
