# Atlas for Mac — 前端全面重设计「Calm Ledger · 平静台账」设计规格

- **日期**: 2026-06-10（v1.1，含四视角评审修订：工程可行性 / 规格完整性 / 治理一致性 / UX·可达性·本地化）
- **状态**: 评审修订完成，待进入实施计划
- **范围**: 全部 8 个屏幕 + 壳层表面 + 设计系统 v3 + 信息架构调整，一次到位交付
- **决策来源**: 可视化共创会话（4 轮视觉对比 + 3 节设计评审 + 4 agent 评审）；样张存于 `.superpowers/brainstorm/`（gitignored，临时参考；本文档自包含全部规格）
- **取代关系**: 本文档落地后取代 `Docs/DESIGN_SPEC.md`（v2「Calm Authority」，其基线数值表已吸收进附录 A）成为设计真相源；受影响文档全量同步清单见 §0.4

---

## 0. 背景、目标与治理定位

### 0.1 动机（三层全动）

1. **视觉**: 现有界面工艺尚可但辨识度不足，圆体 + 通用卡片栅格呈「模板感」
2. **结构**: 所有屏幕都是「标题 + 指标卡 + 信息卡」的纵向堆叠，工作流（扫描→复核→执行）藏在长滚动页里；可解释性靠点开折叠，未成为结构本身
3. **战略**: 竞争策略第三支柱「Visible Differentiation——让信任架构在 UI 上可见」尚未兑现；Phase 2 新模块需要可扩展的工作台骨架

### 0.2 成功标准（可判定）

- 8 屏 + 壳层表面（任务中心、菜单命令、设置文档 sheet）全部迁移至新设计语言与骨架，无双轨并存
- 信任三要素成为**结构元素**：证据面板、恢复点徽记、台账时间线在主流程中常驻可见，且全部满足 §6「防噱头回链红线」
- 既有测试（Packages 377 + Apps 29 + Helpers 16）经必要更新后全绿，新组件均有单测
- §6 可达性红线逐项通过（含对比度脚本全检）
- 双语言 × 双外观 × 两档内容宽（≥880 双栏 / <880 抽屉，含侧栏隐藏态）手动矩阵通过，每屏按 §3 四态适用表过态

### 0.3 治理定位与中断协议（评审修订新增）

- **Mainline 定位**: 本重设计**不是** mainline epic；它借 EPIC-D（Release Readiness）外部阻塞（签名凭据缺失）的窗口执行，需在 `Docs/Backlog.md` 新增 EPIC 条目（建议 EPIC-E）并刷新 Now/Next/Later
- **中断协议**: 若签名凭据在分支期间到位 → 在**当前里程碑边界**暂停（最迟 48h 内收口当前 CHG），checkpoint 写入 `.agent/calm-ledger-redesign-progress.md`，EPIC-D 在 main 上全优先恢复；重设计分支定期 rebase main（每完成一个里程碑至少一次）
- **排序约束**: EPIC-D 的 ATL-267（UI 自动化稳定）与截图基线工作必须排在重设计**合并之后**，避免双倍返工；本重设计先于 Phase 2A（启动项管理）的**代码实现**（新模块基于新骨架开发），Phase 2A Week 0 用户验证可并行
- **决策记录**: 实施启动前在 `Docs/DECISIONS.md` 新增 D-012，一条覆盖：①历史→台账改名（zh 台账 / en Ledger）②设计真相源 v2→Calm Ledger v3 切换 ③窗口默认尺寸 1024×680→1180×740 ④File Organizer 模块的正式认定（既有治理缺位补登记）。侧栏「启动项」预留位标注 **contingent on D-010 更新批准**，未批准前不入侧栏
- **契约测试解冻**: `AtlasDomainTests.testPrimaryRoutesMatchFrozenMVP` 硬编码冻结路由名（含「历史」），按治理属 CONTRACT 变更——本次改名已获产品负责人会话确认，解冻决策须记入 REQ 的 requirement.md

### 0.4 文档同步清单（实施 M0/M4 执行）

| 文档 | 同步内容 |
|---|---|
| `Docs/DECISIONS.md` | 新增 D-012（§0.3 四项） |
| `Docs/Backlog.md` | EPIC-A/B/C 标记完成；新增重设计 EPIC（含中断协议与 ATL-267 排序约束） |
| `Docs/IA.md` | 侧栏两组重组、History→Ledger、补 File Organizer/About、Screen Responsibilities 按 §3 重写、Global Surfaces 增补（回执芯片/阶段条/证据面板/行动栏/ErrorState） |
| `Docs/COPY_GUIDELINES.md` | §5.4 对照表写入；Glossary 增「计划 №N」定义；「文书语气仅限台账面」containment 规则；恢复承诺状态驱动规则 |
| `Docs/DESIGN_SPEC.md` | 加 Superseded 头注指向本文档 |
| `Docs/PRD.md` / `Docs/ROADMAP.md` / `Docs/HELP_CENTER_OUTLINE.md` | History→Ledger 术语、模块清单补 File Organizer |
| `Docs/WORKSPACE_LAYOUT.md` | 补 AtlasFeaturesFileOrganizer/About 包；加「AtlasFeaturesHistory 包承载 Ledger」映射注记 |
| `Docs/product/next-stage-product-goals-2026-06.md` | **先提交入库**（当前 untracked，违反「长期真相受版本控制」）；§6.5 补「重设计先于 Phase 2A 实现」结论 |
| README（zh/en） | 截图基线更新；`atlas-history.png` → `atlas-ledger.png`（`ReadmeAssetExporter.swift:237` 同步） |

---

## 1. 设计语言

### 1.1 配方与命名

**「Calm Ledger · 平静台账」** = 平静权威的浅色壳（基底）× 等宽精密的数据层 × 台账文书的信任层。

三层分工：**气质柔和**（低饱和青绿、白卡、柔影）、**数据精确**（一切数字与路径用等宽字体）、**信任可见**（台账纸面、№ 编号、恢复点徽记、证据三段式）。

### 1.2 色彩 — 双气质表面系统

冷调「工作面」承载操作，暖调「台账面」承载记录与凭证。**暖面使用边界**：仅限台账屏、工作模块④回执视图、概览右栏台账流卡片；其余一律冷面。

#### 浅色模式（对比度已逐对计算达 WCAG AA）

| Token | 值 | 用途 |
|---|---|---|
| `canvas` | 渐变 `#EEF7F4 → #F8FBFA` (160°) | 窗口画布 |
| `surface` | `#FFFFFF`，边框 `border` `#E4EEEA` | 工作面卡片 |
| `surfaceSubdued` | `#F8FBFA`（行底）/ `surfaceInput` `#F4F8F6`（输入与代码底） | 行底、输入底 |
| `ledgerPaper` | `#FDFCF8`，边框 `ledgerBorder` `#E8E0CF` | 台账纸面 |
| `ledgerRule` | `#D8CFBA`（点状分隔线） | 台账条目分隔 |
| `brand` | `#0F766E`；hover `#149F8C`（**仅用于填充/边框 hover，不用于文字**） | 主操作、选中态 |
| `accent` | `#34D399`（**仅非文本用途**：进度、徽记、装饰） | 高亮 |
| `ink` | `#10302C` | 标题 |
| `inkData` | `#0F3C36` | 大号数据数字 |
| `textBody` | `#2C403B`；`textSecondary` `#5D736D`(5.07:1)；`textTertiary` `#637672`(4.81:1) | 正文层级 |
| `ledgerInk` | `#2A2620`；`ledgerSecondary` `#7A7160`(4.69:1) | 台账面文字 |
| `safe` | fg `#0F766E` bg `#E7F6EF`（4.91:1） | 安全 |
| `review` | fg `#8F5E0B` bg `#FDF3E3`（5.06:1） | 复核 |
| `danger` | fg `#B93330` bg `#FDECEA`（5.13:1） | 危险 |
| `info` | fg `#2B66AE` bg `#EAF2FB`（5.14:1） | 信息 |
| `actionBarBg` | `#10302C`；文字 `actionBarText` `#9FD4C9`(8.60:1)；数据 `actionBarData` `#52E2B5`(8.71:1) | 行动栏 |

#### 深色模式（全等价，墨绿石墨而非纯黑）

| Token | 值 |
|---|---|
| `canvas` | 渐变 `#0F1413 → #141A18` |
| `surface` | `#1A211F`，边框 `#2B3633`；`surfaceSubdued` `#202926`；`surfaceInput` `#161D1B` |
| `ledgerPaper` | `#221F19`，边框 `#3C3830`；`ledgerRule` `#4A4338` |
| `brand` | `#1FB5A3`；hover `#2BC4B1`（同浅色规则：不用于文字）；`accent` `#52E2B5`（非文本） |
| `ink` / `inkData` | `#E9F1ED` / `#E9F1ED` |
| `textBody` | `#D7E3DE`；`textSecondary` `#9FB3AC`(7.43:1)；`textTertiary` `#7E938C`(5.03:1) |
| `ledgerInk` | `#CFC8B8`；`ledgerSecondary` `#9C9482` |
| `safe` | fg `#4ADE9E` bg `#18342B` |
| `review` | fg `#E8A33D` bg `#3A2E18` |
| `danger` | fg `#F07B72` bg `#3A211F` |
| `info` | fg `#6FA8E8` bg `#1C2C40` |
| `actionBarBg` | `#0C2421`；文字/数据沿用 `#9FD4C9` / `#52E2B5` |

颜色资产：全量 colorset 化（浅深双值入 `AtlasColors.xcassets`，约 20+ colorset），不在代码硬编码 hex；借此移除 `cardRaised/heroSurface` 的 `@MainActor` 运行时外观查询属性。**M1 验收含对比度脚本全检**（全部 fg/bg 组合 ≥4.5:1，大字 ≥3:1）。

### 1.3 字型 — 三声部纪律

| 声部 | 字体 | SwiftUI | 用途 | 禁区 |
|---|---|---|---|---|
| ① 界面 | SF Pro | `.fontDesign(.default)` | 标题、正文、按钮、导航 | 去掉现有全局 `.rounded`（集中于 3 个 token + AtlasCircularProgress，M1 改 token 全局生效） |
| ② 数据 | SF Mono | `.fontDesign(.monospaced)` + `.monospacedDigit()` | 一切数字、容量、路径、时间戳、计数 | 不用于叙述文本 |
| ③ 台账 | 拉丁/数字: New York；**中文: Songti SC（显式 cascadeList 指定，不依赖系统回退）** | 自定义 `Font`（NSFontDescriptor cascade）封装为 `ledgerFont()` | **仅**台账工件：台账标题、№ 编号、`ATLAS.` 字标 | 不得用于普通标题/正文；serif 中文最小 13pt 且 bold |

> 评审实测：`.fontDesign(.serif)` 下中文回退 STSongti-SC（macOS 15 实测），但该回退是系统 cascade 行为、跨版本不保证——故必须显式指定。若样板间阶段宋体混排观感不达预期，**降级方案**：zh 台账声部改用界面声部 + 字重/字距差异化，serif 仅保留 №、数字与 `ATLAS.` 拉丁工件。№（U+2116）在 New York 的字形覆盖需在 M1 实测，缺失时 en 回退 "No."。

字号阶（替换 `AtlasTypography`）：

| Token | 规格 | 钳制 |
|---|---|---|
| `screenTitle` | 28 bold，tracking −0.3 | 上限 34 |
| `sectionTitle` | 17 semibold | — |
| `rowTitle` | 13 semibold；`body` 13；`bodySmall` 11；`caption` 11 semibold；`captionSmall` 10 | — |
| `dataHero` | mono 42 semibold | 上限 48 |
| `dataMetric` | mono 26 semibold | 上限 30 |
| `dataBody` | mono 12；`dataCaption` mono 10.5 | — |
| `ledgerTitle` | serif 19 bold | 上限 24 |
| `ledgerNumber` | serif 13 bold | — |

macOS 无 iOS 式全局 Dynamic Type：缩放采用**语义字体样式 + 辅助功能缩放实测**作为验收口径（§7 手动矩阵含放大档抽查）。**路径文本一律中段截断**（`.truncationMode(.middle)`）+ 悬停显示完整路径 + 可复制。

### 1.4 质感与高程

- 白卡 + 1px 细边 + 柔和青调投影；高程三档保留（基线值见附录 A），阴影整体调淡约 30%，去掉 prominent 内发光
- 台账面：暖纸底 + 1.5px 墨色标题底线 + 点状条目分隔线；不用投影（「纸上印刷」平面感）
- 圆角沿用 continuous 8 / 12 / 16 / 20 / 24；行动栏 12，徽记为正圆
- **无玻璃拟态**；侧栏维持 NavigationSplitView 默认材质

### 1.5 动效

沿用 `AtlasMotion` 三档 snappy 曲线（基线见附录 A），新增：

| Token | 规格 | 场景 |
|---|---|---|
| `stageTransition` | 0.30s snappy，水平 12pt 位移 + fade | 阶段切换 |
| `stampIn` | spring(response 0.45, damping 0.62)，scale 1.15→1 + 旋转至 −11° | 执行完成、恢复点入账 |
| `countUp` | `contentTransition(.numericText())`（已被现有代码验证可用） | 指标数字变化 |

全部尊重「减弱动态效果」（降级 opacity / 直接落定）。

### 1.6 信任的视觉语法

**统一名词**：扫描产出与可执行对象统一称「**计划 / Plan**」（与按钮动词「执行清理计划 / Run Cleanup Plan」一致，遵循 COPY_GUIDELINES prefer-plan 规则；不引入「提案/Proposal」第二名词）。

| 概念 | 视觉表达 | 数据来源（评审修订新增） |
|---|---|---|
| 计划编号 №N | serif №（双语统一视觉符号）；a11y 读法本地化：zh「计划编号 N」/ en "Plan number N" | **全局台账持久序列**：№ = 台账存储的单调递增序号，扫描产出计划时分配，执行后同号入账；跨模块共享同一序列 |
| 扫描回执 | mono 芯片 `扫描回执 #XXXX · HH:mm`（en: `Scan Receipt #XXXX`） | #XXXX = 扫描摘要内容哈希前 4 位 hex；**首次扫描前芯片隐藏**；多模块各自持有回执，工具栏芯片显示**当前路由**所属模块的最近回执 |
| 证据三段式 | 为什么安全 / 证据（mono）/ 恢复方案（青框 ⛨） | 现有 Finding 解释字段 + 扫描元数据 |
| 恢复点徽记 | 圆形描边 + −11° 旋转；文案**状态驱动、只述事实**：「恢复点已建立 · X GB · 保留 N 天」（en "Restore point created · X GB · kept for N days"）；teal 描边，禁用红色/五角星等公章特征 | **仅在恢复点真实创建时渲染**；X/N 取真实值（fail-closed，不得静态写死——对齐 D-009 与 ATL-205/223 文案口径） |
| 台账条目 | № + 标题 + mono 数据 + 状态（⛨ 有效 / ✓ 已验证 / 已归档） | 现有 task run / recovery 存储 |
| 行动承诺 | 行动栏承诺文案**由计划实际可恢复状态驱动**：全部可恢复→「⛨ 执行前自动建立恢复点 · 保留 N 天 · 全程录入台账」；部分→「⛨ X/Y 项可恢复 · …」；无→不显示 ⛨ 句 | 计划的 recovery 元数据 |

**防噱头回链红线**（同列 §6）：任何 № / 徽记出现处必须可达对应台账详情（点击跳转或悬停 mono 数据），唯一豁免 `ATLAS.` 字标；Toast「已入账 №N」必须可点击跳台账。

---

## 2. 信息架构与壳层

### 2.1 窗口与导航

- 窗口：默认 **1180×740**、最小 **980×640**（修改点：`AtlasApp.swift` 的 `.defaultSize` 与 `.frame(minWidth:)` + `window.minSize` 手动设置两处同步）。**已知行为**：WindowGroup frame autosave 使存量用户保留旧尺寸（约 1024×680 → 内容区约 770pt → 落入抽屉档）；**接受此行为**，抽屉档即存量用户首屏验收基准，不做窗口尺寸迁移
- `NavigationSplitView` 沿用；侧栏 200–230pt；折叠 = **标准整列显隐**（不做自定义图标轨——评审裁定范围外）
- 侧栏分组：**工作**（概览 · 智能清理 · 文件整理 · 应用 ·〔启动项：contingent on D-010 批准，未批准不入侧栏〕）/ **记录**（台账 · 权限）/ 沉底（设置 · 关于）
- 侧栏项 = 图标 + 名称 + 动态状态副标题（沿用 `AtlasSidebarContext`）；选中态 brand 胶囊；顶部 `ATLAS.` serif 字标
- 工具栏：逐屏过滤搜索沿用（**非全局跨屏搜索**；仅作用于当前屏列表/时间线，扫描/执行阶段中禁用）+ 扫描回执芯片（无回执时隐藏）+ 任务中心铃铛（角标沿用）

### 2.2 命名变更：历史 → 台账（已确认 + 评审修正）

- zh「台账」/ en「Ledger」；`AtlasRoute.history` → `.ledger`
- **评审修正**：路由选择**并未持久化**（`AtlasAppModel.selection` 纯内存态，全仓无 @AppStorage/SceneStorage），删除原「读取时映射」条款；改为**编译期改名清单**：`AtlasDomain.swift` case 定义、`AppShellView.swift`（4 处）、`AtlasAppCommands.swift`（Cmd+5 导航菜单）、`TaskCenterView.swift`（「打开历史」CTA）、`ReadmeAssetExporter.swift`（截图文件名）、删除未引用的 `AtlasIcon.history`
- `AtlasL10n` 键迁移：`history.*` 前缀约 120 键 × 2 语言，M4 脚本化处理 + 双语言键集合 diff 校验（AtlasL10n 缺键静默返回键名，必须脚本兜底）
- 协议层（AtlasCommand/Response/Event）**不变**；包名 `AtlasFeaturesHistory` 保留

### 2.3 工作模块骨架（智能清理 / 文件整理 /（未来）启动项）

```
┌ 标题区: 模块名 + 计划 №N 副标题              阶段条 ①扫描✓ ②复核 ③执行 ④回执 ┐
├──────────────────────────┬───────────────────────────┤
│ 列表区（风险分组 + 过滤芯片 + 复选）        │ 证据面板（常驻）                    │
├──────────────────────────┴───────────────────────────┤
│ 行动栏（吸底墨色）: [主操作 →] ⛨状态驱动承诺 ............ mono 合计          │
└────────────────────────────────────────────────────┘
```

**④ 更名「回执」**（评审修订）：④ = 本次计划的**模块内回执视图**（结果摘要 + 恢复点徽记 + 「在台账中查看 →」跳转全局台账屏），使用暖纸面卡片；与全局台账屏的关系：④ 是单次计划的回执，台账屏是全部历史的存档。

#### 阶段状态机（评审修订新增，三模块共用）

现有模型状态 → 阶段映射：

| 模型状态 | 阶段 | 列表区 | 行动栏 |
|---|---|---|---|
| 无计划（首次/已失效） | ① 扫描 | 空态引导「运行扫描」 | 主操作=运行扫描 |
| isScanning | ① 扫描（进行中） | 进度视图（mono 路径滚动 + 百分比） | 禁用 + 进度 |
| 计划就绪（plan fresh） | ② 复核 | 风险分组列表，可勾选/过滤 | 主操作=执行已选 N 项 |
| isExecuting | ③ 执行 | 实时行级状态流（已清理/失败/跳过） | 进度态（progress 参数） |
| executionCompleted | ④ 回执 | 回执视图 | 主操作=完成（回②已只读）/ 新扫描 |
| 扫描 0 发现 | ② 复核（空） | 「未发现可清理项」空态 + 重扫入口 | 主操作=重新扫描 |
| 执行中途失败 | ③ 执行（错误态） | 失败项红标可展开原因（AtlasErrorState 行内变体） | 主操作=查看回执（部分完成入台账） |

阶段转换规则：
- **回看 = 只读快照**：点已完成阶段回看，内容只读 + 顶部「返回当前阶段」入口；执行后（≥③）所有前序阶段一律只读
- **重新扫描 = 显式动作**：仅在①或②提供「重新扫描」按钮，触发确认（「当前计划 №N 将作废」）；新扫描产出新 №，旧计划以「已作废」状态入台账；菜单命令 Cmd+Shift+R 同走此确认
- **选择状态作用域 = 单一计划内**：同一 № 内跨阶段往返保留勾选/过滤；№ 变更即清空
- **ViewState 宿主 = `AtlasAppModel`**（按路由 keyed），因 AppShellView 以 `.id(route)` 重建视图，feature 内 `@State` 切屏即丢——阶段/勾选/过滤必须跨路由存活（§7 行为不变红线）

**Undo（评审修订）**：执行完成统一发全局 Toast「已入账 №N · [撤销]」——Toast 容器壳层常驻，跨屏可见；撤销与台账屏「还原全部/逐项还原」指向**同一恢复点**（双入口一份真相）；Toast 存续 8s，超时后台账屏仍可还原。智能清理现状 `onUndoExecution: nil // TODO` 在 M3 一并接通。

**Apps 模块**：简化骨架（无阶段条）；**逐应用单选**（沿用现状，不引入批量卸载——回归红线）；选中即更新证据面板；行动栏仅在有选中且卸载计划就绪时浮现。

### 2.4 响应式（按内容区宽度，经现有 `atlasContentWidth` 环境机制）

| 内容区宽 | 行为 |
|---|---|
| ≥880pt | 列表 + 证据面板双栏全显 |
| <880pt | 证据面板收为**非模态滑出抽屉** |

抽屉交互规格（评审修订新增）：行点击 = 选中并更新抽屉内容但**不自动弹出**；行尾 ⓘ「查看证据」按钮显式弹出；抽屉打开时列表保持可滚动可勾选；z 序在行动栏之上、底边让出行动栏高度；Esc / 点外收回，焦点归还触发行；行动栏在内容区 <740pt 时收缩为「主按钮 + ⛨ 徽记」（该收缩态独立于抽屉档，在抽屉档内随宽度触发）。

窗口最小 980 − 侧栏 230 ≈ 750pt 起步，两档均可达；各工作屏 `maxContentWidth ≥ 1080` 保证双栏档可达；取代 `browserSplitThreshold`（仅 Apps/History 两处消费，替换可控）。

---

## 3. 逐屏规格

| 屏幕 | 版式与要点 |
|---|---|
| **概览** | 问候 + 状态胶囊行（磁盘/恢复点/权限）→ 「下一步」横幅 → 左**指挥台**（健康环 + 模块入口行）/ 右**台账流**（最近 3–5 条 № 条目，暖面卡片，逐条可点跳台账） |
| **智能清理** | 完整骨架 + 阶段状态机（§2.3）。过滤芯片: 全部/安全/复核/高级 + 类别；证据面板含来源签名信息 |
| **文件整理** | 完整骨架。阶段: ①扫描 ②规则 ③预演 ④执行 ⑤回执（五段）；「规则」阶段主区为规则编辑器，证据面板回答「此文件为何被分类至 X」；预演=现 dry-run，列表显示将发生的移动 + 冲突标记 |
| **应用** | 简化骨架（§2.3 Apps 段）。列表: 应用行（图标/名称/mono 大小/残留徽记）；证据面板: 10 类证据足迹 + 卸载计划预览 + 残留估计 |
| **台账** | 暖纸面全页。serif 标题 + 「导出报告」（导出页脚注「本报告由 Atlas 在本机生成，仅供个人参考」）；统计行 + 过滤芯片（可恢复/全部/归档）；左时间线（进行中置顶钉住）/ 右详情面板（mono 执行数据 + 包含清单 + 还原全部/逐项还原 + 徽记水印变体）；底部「更早归档」折叠 |
| **权限** | 进度环 hero + 权限行 + 每行证据三段式展开（为什么需要/影响范围/如何授权）；限制模式 callout 换装 |
| **设置** | 三段 tab 沿用。恢复段强化: 保留天数 + 排除路径 + 恢复区占用量（mono）；信任段沿用 + 文档 sheet 换装（§3.1） |
| **关于** | 纯换装（版本 mono、二维码、更新检查） |

#### 概览「下一步」推荐优先级表（评审修订新增）

| 优先级 | 条件 | headline / 主按钮落点 |
|---|---|---|
| 1 | 必需权限缺失 | 「先授权以解锁完整功能」→ 权限屏 |
| 2 | 有就绪计划（fresh plan） | 「执行 №N：清理 X 项安全发现，释放 Y GB」→ 智能清理②复核（预选安全组，行动栏就绪——**一键开始不跳过复核**） |
| 3 | 无扫描 / 扫描过期（>7 天） | 「运行扫描，更新你的清理计划」→ 智能清理①并自动开扫 |
| 4 | 磁盘占用 >85% | 「磁盘空间紧张，建议深度扫描」→ 智能清理 |
| 5 | 以上皆无 | 「状态良好」静态卡（无按钮，显示最近台账条目） |

- rationale 段必须含数据时效 mono 时间戳（「基于 06-08 14:32 回执」）
- 第三动作「忽略」：本建议 7 天内不再出现（持久化于设置存储）；横幅渐变 = `brand → brandHover`（`#0F766E → #149F8C`，135°）

#### 3.1 壳层表面（评审修订新增）

- **任务中心弹层**（`TaskCenterView`）：换新装（surface 卡 + mono 数据）；「打开历史」CTA 改「打开台账」；运行中任务行加 № 前缀
- **设置文档 sheet**（`SettingsDocumentSheet`）：换装为 surface 容器 + `ledgerTitle` 标题，内容排版沿用
- **菜单命令**（`AtlasAppCommands`）：Cmd+1–7 导航名随改名更新；Cmd+Shift+R 运行扫描走 §2.3 重扫确认；菜单项文案入 §5.4 对照表
- **Toast 队列**：沿用现有容器与队列逻辑（已在壳层常驻——评审修正：并非闲置），新增「已入账 №N · 撤销」场景（可点击跳台账）；并发上限沿用现状，停留 8s
- **更新按钮 / 权限弹窗**：换装，行为不变
- **首次启动 onboarding：范围外**（由概览 empty 态承担引导）

#### 四态适用表（评审修订新增）

| 屏幕 | loading | empty | error | degraded |
|---|---|---|---|---|
| 概览/智能清理/文件整理/应用/台账 | ✓ 骨架屏 | ✓ | ✓ | ✓ 限制模式横幅 |
| 权限 | ✓ | N/A（始终有行） | ✓ | N/A（自身即权限屏） |
| 设置/关于 | N/A | N/A | ✓（仅持久化失败提示） | N/A |

---

## 4. 设计系统 v3 工程规格（AtlasDesignSystem）

### 4.1 Token 变更

- `AtlasColor`: §1.2 全表（浅深逐 token 对应，入 xcassets）；高程阴影调淡 30%
- `AtlasTypography`: §1.3 三声部 + 字号阶 + `ledgerFont()` cascade 封装；token 迁移 heroMetric→dataHero、cardMetric→dataMetric（各约 4 处调用）
- `AtlasMotion`: 新增 3 token（§1.5）
- `AtlasSpacing`/`AtlasRadius`: 不变（附录 A）；`AtlasLayout` 新增 `evidencePanelMinWidth = 300`、断点 880/740，移除 `browserSplitThreshold`

### 4.2 新增组件（9 项，评审修订补全参数）

| 组件 | 职责 / 接口要点 |
|---|---|
| `AtlasStageBar` | `stages:[Stage], current, completed:Set, onSelect`；已完成可点回看（只读语义由宿主执行）；紧凑态触发 = 容器宽 <520pt（「②/④ 复核」式）；**键盘**: 单 Tab stop + ←→ 移动 + Return 激活；focus ring: brand 2pt / offset 2pt / 跟随胶囊圆角；禁用段可聚焦并朗读原因；a11y value:「第 N 阶段，共 M 个：X，当前/已完成/不可用」；圈号仅视觉 |
| `AtlasEvidencePanel` | 三态：**单选**=三段式（why/evidence mono KV/recovery⛨）+ 行级操作槽；**多选**=聚合视图（N 项 · mono 合计 · 风险分布 + 共同恢复方案 + 「逐项查看」）；**执行中**=实时行级状态流（失败项可展开原因）；空态「选择一项查看证据」 |
| `AtlasActionBar` | `primary, promise(状态驱动), metric(mono), progress: Double?`；执行中显示进度；放大档/窄宽让位顺序: 承诺省略 → 合计保留 → 主按钮永不截断 |
| `AtlasLedgerTimeline` / `AtlasLedgerEntry` | № serif + 标题 + mono 数据 + 状态徽记；进行中条目置顶钉住；每条带显式 a11y label（zh「计划编号 N」/ en "Plan number N"）；点击必达详情（回链红线） |
| `AtlasStampBadge` | 圆形描边徽记，−11° 旋转，teal 描边；`style: .badge / .watermark`（台账详情用水印变体）；文案事实驱动（§1.6）；`accessibilityHidden(true)`（信息由相邻文本承载） |
| `AtlasLedgerSurface` | 暖纸面容器（底色/边框/标题底线/点状分隔环境）；使用边界见 §1.2 |
| `AtlasNextActionBanner` | headline + rationale(含时效) + 主/次按钮 + **忽略**（7 天冷却）；渐变 brand→hover 135° |
| `AtlasErrorState` | **无码版**（评审裁定：协议冻结、无错误码分类法）：图标 + 标题 + 详情（映射自 executionIssue/planIssue 字符串）+ 建议动作 + 可选帮助链接；行内紧凑变体供执行列表用 |
| `.atlasData()` 修饰符 | mono + monospacedDigit 一致入口 |

### 4.3 修改 / 吸收 / 扩展

- **`AtlasScreen` 结构性扩展**（评审修订，原「换画布」不足）：新增 `actionBar` 与 `drawerOverlay` 插槽——经 `.safeAreaInset(edge:.bottom)` 挂在私有 ScrollView 之外（行动栏全宽、内容仍受 maxContentWidth 钳制；与顶部工具栏 `.searchable` 无冲突）；`AtlasToastContainer` 与行动栏共存规则：行动栏在场时 toast 上移其高度
- **修改**: MetricCard/HeroCard（数字切 mono）；三档按钮、StatusChip、FilterChip、SegmentedControl（新 token）；侧栏项；Skeleton/Callout/EmptyState/LoadingState 换装；AtlasCircularProgress 改 AngularGradient（conic）+ 清理内部 2 处 rounded，注意 0%/100% 渐变接缝
- **吸收**: `AtlasEvidenceGroupCard` 并入 `AtlasEvidencePanel`
- **扩展既有**（评审修正措辞——二者并非闲置）: Toast 新增「已入账 №N · 撤销」场景；Tooltip 用于阶段条/徽记悬停说明

---

## 5. 工程组织

### 5.1 包结构与拆分纪律

- 包架构不变；**每视图文件 ≤ 350 行**：History(1390) → `LedgerFeatureView`(协调) + `LedgerTimelineView` + `LedgerDetailView` + `LedgerArchiveView`；SmartClean/FileOrganizer/Apps 按「标题阶段区/列表/证据面板内容/行动栏配置」拆文件
- 包名 `AtlasFeaturesHistory` 保留，内部类型与文案改 Ledger（WORKSPACE_LAYOUT 加映射注记）

### 5.2 状态管理立场

沿用 `AtlasAppModel` + binding，不引入新框架；每工作屏一个 `ViewState` struct **挂在 `AtlasAppModel`（按路由 keyed）**——评审修订：AppShellView 以 `.id(route)` 重建视图，feature 内 `@State` 不满足跨路由存活要求（§2.3 状态机）。

### 5.3 路由改名（评审修正：编译期清单，无持久化迁移）

见 §2.2。无障碍 ID（`route.history`→`route.ledger`）、`AtlasL10n` 键、测试固定值同步替换；契约测试解冻按 §0.3 记录。

### 5.4 本地化与文书语气

zh-Hans / en 全量过一遍（M4 脚本 + 键集合 diff 校验）。对照表（写入 COPY_GUIDELINES）：

| zh | en |
|---|---|
| 计划 №42（视觉同用 №；a11y：计划编号 42 / Plan number 42） | Plan №42 |
| 扫描回执 #A1F3 | Scan Receipt #A1F3 |
| 台账 | Ledger（空态附一句解释定位） |
| 恢复点已建立 · X GB · 保留 7 天 | Restore point created · X GB · kept for 7 days |
| 已验证 ✓ | Verified ✓ |
| 已作废（重扫后旧计划） | Superseded |
| 文书语气仅限台账面；工作面按钮动词直白（执行清理计划 / Run Cleanup Plan）；不使用「签署」类法律联想词 | |

---

## 6. 可达性红线

- 对比度 WCAG AA 全检**脚本化**（M1 验收项）：正文 ≥4.5:1、大字 ≥3:1，定稿值见 §1.2（已逐对计算）
- 徽记、时间线轨等装饰元素 `accessibilityHidden`，信息由相邻文本承载；№ 一律配显式本地化 a11y label
- 三声部接语义字体样式；serif 中文 ≥13pt bold；路径中段截断 + 悬停完整 + 可复制；钳制清单见 §1.3
- 阶段条键盘/焦点规格见 §4.2；过滤芯片、台账时间线键盘可导航；证据面板/抽屉有 VoiceOver 容器结构，抽屉 Esc 收回焦点归还
- 减弱动态：stageTransition→opacity、stampIn/countUp→直接落定
- **防噱头回链红线**：任何 № / 徽记可达台账详情（点击或悬停 mono 数据），豁免仅 `ATLAS.` 字标

---

## 7. 测试与验收

- **迁移**: 既有测试 Packages 377 + Apps 29 + Helpers 16 经更新后全绿（预算约 100 个机械更新：feature view 冒烟测试构造签名、DesignSystem 精确值断言约 10 个、19 条硬编码中文断言、契约测试解冻）；新组件各补单测；`ViewState` 状态机补逻辑测试（含回看只读、重扫作废、选择作用域）
- **截图基线**: `ATLAS_EXPORT_README_ASSETS_DIR` 重导全套（zh+en）；`atlas-history.png`→`atlas-ledger.png` 并同步 README 引用
- **手动矩阵**: 双语言 × 双外观 × 两档内容宽（含侧栏隐藏态、<740 行动栏收缩态、放大档抽查）；每屏按 §3 四态适用表过态；**zh/en 台账声部截图对比**专项验收（宋体混排观感）
- **回归红线**: 扫描→复核→执行→恢复全链路行为不变（纯前端重构，Worker/协议零改动）；Apps 不引入批量卸载；切屏往返不丢阶段/勾选状态

---

## 8. 交付策略（已确认：一次到位 + 评审补充治理协议）

- 长分支 `redesign/calm-ledger`，全部完成后整体合并；期间 main 仅接 hotfix；**中断协议与排序约束见 §0.3**
- 分支内里程碑（每个里程碑分支内可构建、测试绿，且为中断协议的合法暂停点）：
  - **M0 治理**: D-012 决策入档、Backlog EPIC 条目、REQ/CHG/.agent 工件建立、`Docs/product/` 入库
  - **M1 Token 层**: AtlasColor/Typography/Motion v3 + xcassets + 对比度脚本 + serif 中文 cascade 实测（含降级决策点）+ № 字形实测
  - **M2 组件层**: 9 新组件 + AtlasScreen 插槽 + 修改/吸收/扩展清单
  - **M3 屏幕迁移**: 智能清理（骨架样板间，含阶段状态机）→ 台账 → 概览 → 应用 → 文件整理 → 权限 → 设置/关于 + 壳层表面
  - **M4 收尾**: 路由/L10n 脚本迁移 + 文档同步清单（§0.4）+ 可达性全检 + 截图基线 + 手动矩阵
- 合并门禁: 构建 + 全量测试 + §6 红线 + §7 手动矩阵 + 截图更新 + REQ 验收协议（`bin/ato-iter` 当前缺失——若实施时仍缺失，按 CLAUDE.md 治理以手工等价流程执行并升级人确认）

## 9. 范围外（明确不做）

- Liquid Glass 材质 / NSVisualEffectView 改造；自定义侧栏图标轨（评审裁定）
- 新模块功能实现（启动项/存储可视化/开发者深清——骨架预留其位，启动项侧栏位 contingent on D-010）
- Storage 占位实装（不入侧栏）；菜单栏工具、自动化（D-010 冻结）
- 首次启动 onboarding（概览 empty 态承担）
- Go 后端、Worker、XPC 协议层、错误码分类法（ErrorState 走无码版）

## 10. 决策记录（共创与评审轨迹）

| 决策点 | 结论 |
|---|---|
| 重设计动机 | 视觉 + 结构 + 战略全部 |
| 视觉基调 | D 平静权威 2.0 基底 + B 等宽数据层 + C 台账信任层（点击轨迹显示 B/C 强吸引，融合确认） |
| 工作模块骨架 | 阶段条 + 证据面板 + 行动栏（B+C 混合） |
| 概览定位 | 下一步横幅 + 指挥台 + 台账流融合 |
| 历史改名台账 | 确认（zh 台账 / en Ledger）；契约测试解冻记入 REQ |
| 交付策略 | 一次到位（长分支 + M0–M4 里程碑 + EPIC-D 中断协议） |
| 评审修订（v1.1） | 4 agent 评审：补阶段状态机、№/回执派生规则、对比度定稿值、中文宋体 cascade、抽屉交互、推荐优先级表、壳层表面、治理协议；名词统一「计划/Plan」；「Scan Credential」→「Scan Receipt / 扫描回执」；删除虚构的路由持久化迁移；放弃图标轨 |

---

## 附录 A — 自 v2 继承的基线数值（保持不变）

| 体系 | 值 |
|---|---|
| `AtlasSpacing` | xxs 4 / xs 6 / sm 8 / md 12 / lg 16 / xl 20 / xxl 24 / screenH 28 / section 32 |
| `AtlasRadius` | sm 8 / md 12 / lg 16 / xl 20 / xxl 24（continuous） |
| `AtlasMotion` 基线 | fast snappy 0.15s / standard snappy 0.22s / slow snappy 0.35s / spring(0.45, 0.7) |
| 高程基线（调淡 30% 前的 v2 值） | flat 无影 / raised r18 y10 @5% / prominent r28 y16 @9%（内发光移除） |
| 按钮三层级原则 | atlasPrimary（每屏唯一最重要 CTA）/ atlasSecondary / atlasGhost；`.contentShape(Capsule())` 命中区修复保留 |
| 布局 | maxReadingWidth 920（设置/关于/权限滚动页适用）/ maxWorkflowWidth 1080 / maxWorkspaceWidth 1200 / sidebarMin 180 ideal 220 |
| 组件 a11y 约定 | `accessibilityElement(children: .ignore)` + label/value/hint 模式沿用 |
| 权限深链 | v2 §4.5 的系统设置 URL 沿用 |
