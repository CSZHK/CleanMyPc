# Atlas for Mac — 前端全面重设计「Calm Ledger · 平静台账」设计规格

- **日期**: 2026-06-10
- **状态**: 已与产品负责人逐节确认（视觉基调 / 骨架与逐屏 / 组件与工程），待最终审阅
- **范围**: 全部 8 个屏幕 + 设计系统 v3 + 信息架构调整，一次到位交付
- **决策来源**: 可视化共创会话（4 轮视觉对比 + 3 节设计评审），样张存于 `.superpowers/brainstorm/`（gitignored，临时参考；本文档自包含全部规格）
- **取代关系**: 本文档落地后取代 `Docs/DESIGN_SPEC.md`（v2「Calm Authority」）成为设计真相源；`Docs/IA.md` 与 `Docs/COPY_GUIDELINES.md` 需按 §2 / §5.4 同步更新

---

## 0. 背景与目标

### 0.1 动机（三层全动）

1. **视觉**: 现有界面工艺尚可但辨识度不足，圆体 + 通用卡片栅格呈「模板感」
2. **结构**: 所有屏幕都是「标题 + 指标卡 + 信息卡」的纵向堆叠，工作流（扫描→复核→执行）藏在长滚动页里；可解释性靠点开折叠，未成为结构本身
3. **战略**: 竞争策略第三支柱「Visible Differentiation——让信任架构在 UI 上可见」尚未兑现；Phase 2 新模块（启动项管理、存储可视化）需要一个可扩展的工作台骨架

### 0.2 成功标准

- 8 屏全部迁移至新设计语言与骨架，无双轨并存
- 信任三要素（可解释 / 可恢复 / 可审计）成为**结构元素**：证据面板、恢复点印章、台账时间线在主流程中常驻可见
- 现有 377 个测试全绿；可达性不回退（VoiceOver / Dynamic Type / 减弱动态）
- 双语言（zh-Hans / en）× 双外观（浅色 / 深色）× 三档窗宽 全覆盖

---

## 1. 设计语言

### 1.1 配方与命名

**「Calm Ledger · 平静台账」** = 平静权威的浅色壳（基底）× 等宽精密的数据层 × 台账文书的信任层。

三层分工：**气质柔和**（低饱和青绿、白卡、柔影）、**数据精确**（一切数字与路径用等宽字体）、**信任可见**（台账纸面、№ 编号、印章、证据三段式）。

### 1.2 色彩 — 双气质表面系统

冷调「工作面」承载操作，暖调「台账面」承载记录与凭证，形成「操作 vs 存档」的直觉区分。

#### 浅色模式

| Token | 值 | 用途 |
|---|---|---|
| `canvas` | 渐变 `#EEF7F4 → #F8FBFA` (160°) | 窗口画布 |
| `surface` | `#FFFFFF`，边框 `#E4EEEA` | 工作面卡片 |
| `surfaceSubdued` | `#F8FBFA` / `#F4F8F6` | 行底、输入底 |
| `ledgerPaper` | `#FDFCF8`，边框 `#E8E0CF` | 台账纸面 |
| `ledgerRule` | `#D8CFBA`（点状分隔线） | 台账条目分隔 |
| `brand` | `#0F766E`，hover `#149F8C` | 主操作、选中态 |
| `accent` | `#34D399` | 高亮、进度、徽记 |
| `ink` | `#10302C` | 标题（取代纯黑） |
| `inkData` | `#0F3C36` | 大号数据数字 |
| `textBody` | `#2C403B` / 次要 `#5D736D` / 三级 `#7D8F89` | 正文层级 |
| `ledgerInk` | `#2A2620`，次要 `#7A7160`* | 台账面文字 |
| `safe` | fg `#0F766E` bg `#E7F6EF` | 安全 |
| `review` | fg `#C07F1D` bg `#FDF3E3` | 复核 |
| `danger` | fg `#D64541` bg `#FDECEA` | 危险 |
| `info` | fg `#3478C8` bg `#EAF2FB` | 信息 |
| `actionBarBg` | `#10302C`，文字 `#9FD4C9`，数据 `#52E2B5` | 行动栏 |

\* 样张曾用 `#8A8170`，与 `#FDFCF8` 对比度不足 WCAG AA，定稿收深为 `#7A7160`，实现时以对比度检查为准。

#### 深色模式（全等价，墨绿石墨而非纯黑）

| Token | 值 |
|---|---|
| `canvas` | 渐变 `#0F1413 → #141A18` |
| `surface` | `#1A211F`，边框 `#2B3633` |
| `ledgerPaper` | `#221F19`，边框 `#3C3830`（深色羊皮纸） |
| `brand` | `#1FB5A3`；`accent` `#52E2B5` |
| `text` | `#E9F1ED` / 次要 `#9FB3AC` / 三级 `#6E817B` |
| `ledgerText` | `#CFC8B8` |
| 语义四色 | 沿用系统色深色变体，软底用 10% 不透明度 |

颜色资产：`AtlasColors.xcassets` 全量 colorset 化（含台账系），不在代码里硬编码 hex。

### 1.3 字型 — 三声部纪律

| 声部 | 字体 | SwiftUI | 用途 | 禁区 |
|---|---|---|---|---|
| ① 界面 | SF Pro（系统默认设计） | `.fontDesign(.default)` | 标题、正文、按钮、导航 | **去掉现有全局 `.rounded`** |
| ② 数据 | SF Mono | `.fontDesign(.monospaced)` + `.monospacedDigit()` | 一切数字、容量、路径、时间戳、计数 | 不用于叙述文本 |
| ③ 台账 | New York | `.fontDesign(.serif)` | **仅**台账工件：提案标题、№ 编号、印章、`ATLAS.` 字标 | 不得用于普通标题/正文 |

字号阶（替换 `AtlasTypography`）：

| Token | 规格 | 备注 |
|---|---|---|
| `screenTitle` | 28 bold，tracking −0.3 | 从 34 rounded 收紧 |
| `sectionTitle` | 17 semibold | |
| `rowTitle` | 13 semibold；`body` 13；`bodySmall` 11；`caption` 11 semibold；`captionSmall` 10 | |
| `dataHero` | mono 42 semibold | 概览/英雄数字 |
| `dataMetric` | mono 26 semibold | 指标卡 |
| `dataBody` | mono 12；`dataCaption` mono 9.5 | 路径、时间戳、凭据 |
| `ledgerTitle` | serif 19 bold | 台账页标题、详情标题、提案标题 |
| `ledgerNumber` | serif 13 bold | № 编号 |

全部接 Dynamic Type（大号档位钳制沿用现有策略：hero/screenTitle 设上限）。

### 1.4 质感与高程

- 白卡 + 1px 细边 + 柔和青调投影；高程三档保留（flat / raised / prominent），阴影整体调淡约 30%，去掉 prominent 的内发光
- 台账面：暖纸底 + 1.5px 墨色标题底线 + 点状条目分隔线；不用投影，用「纸上印刷」的平面感
- 圆角沿用 continuous 8 / 12 / 16 / 20 / 24；行动栏 12，印章为正圆
- **无玻璃拟态**：不引入 `NSVisualEffectView` / 重 blur；侧栏维持 NavigationSplitView 默认材质

### 1.5 动效

沿用 `AtlasMotion` 快/标准/慢三档 snappy 曲线，新增：

| Token | 规格 | 场景 |
|---|---|---|
| `stageTransition` | 0.30s snappy，水平 12pt 位移 + fade | 阶段条切换内容区 |
| `stampIn` | spring(response 0.45, damping 0.62)，scale 1.15→1 + 旋转到 −11° | 执行完成、恢复点入账 |
| `countUp` | 0.6s 数字滚动（`contentTransition(.numericText())`） | 指标数字变化 |

全部尊重「减弱动态效果」（降级为 opacity 过渡，数字直接落定）。

### 1.6 信任的视觉语法

| 概念 | 视觉表达 | 出现位置 |
|---|---|---|
| 提案 | 「提案 №N」serif 编号；扫描产出即提案 | 智能清理/文件整理标题区 |
| 扫描凭据 | mono 芯片 `扫描凭据 #XXXX · HH:mm` | 工具栏右侧、台账详情 |
| 证据三段式 | 为什么安全 / 证据（mono）/ 恢复方案（青框 ⛨） | 证据面板、权限行展开 |
| 恢复点印章 | 圆形描边 + −11° 旋转 +「全量备份 · 可恢复 N 日」 | 台账详情、执行完成态 |
| 台账条目 | № + 标题 + mono 数据 + 状态（⛨ 有效 / ✓ 已验证 / 已归档） | 台账时间线、概览台账流 |
| 行动承诺 | 行动栏固定文案「⛨ 执行前自动建立恢复点 · 保留 N 天 · 全程录入台账」 | 所有破坏性操作前 |

---

## 2. 信息架构与壳层

### 2.1 窗口与导航

- 窗口：默认 **1180×740**（原 1024×680），最小 **980×640**；隐藏标题栏沿用
- `NavigationSplitView` 沿用；侧栏 200–230pt，可折叠为图标轨
- 侧栏分组重组：
  - **工作**: 概览 · 智能清理 · 文件整理 · 应用 ·（Phase 2 预留：启动项）
  - **记录**: 台账 · 权限
  - 沉底: 设置 · 关于
- 侧栏项 = 图标 + 名称 + **动态状态副标题**（沿用现有 `AtlasSidebarContext` 机制，如「16 项就绪 · 12.5 GB」）；选中态 brand 胶囊
- 侧栏顶部 `ATLAS.` serif 字标（句点 brand 青）
- 工具栏：全局搜索（沿用 `.searchable`，设置/关于除外）+ mono 扫描凭据芯片 + 任务中心铃铛（带角标）；更新提示与 Toast 容器沿用、换新装

### 2.2 命名变更：历史 → 台账（已确认）

- zh-Hans「台账」/ en「Ledger」；`AtlasRoute.history` → `AtlasRoute.ledger`
- 持久化的路由选择值做一次性迁移映射（旧值 `history` 读入时映射为 `ledger`）；`AtlasL10n` 键名、无障碍标识符、测试同步更新
- 协议层（AtlasCommand/AtlasResponse/AtlasEvent）**不变**——此为纯前端命名

### 2.3 工作模块骨架（智能清理 / 文件整理 /（未来）启动项）

```
┌ 标题区: 模块名 + 提案 №N 副标题            阶段条 ①扫描✓ ②复核 ③执行 ④台账 ┐
├──────────────────────────┬───────────────────────────┤
│ 列表区（风险分组 + 过滤芯片 + 复选）        │ 证据面板（常驻）                    │
│   分组头: 安全 14 项 · mono 合计           │   为什么安全 / 证据 mono / 恢复方案⛨  │
│   行: 选框 + 名称 + mono 路径 + mono 大小  │   行级操作: 排除此项 / 访达中显示      │
├──────────────────────────┴───────────────────────────┤
│ 行动栏（吸底墨色）: [主操作 →] ⛨恢复承诺 ............... mono 合计           │
└────────────────────────────────────────────────────┘
```

- 阶段条为**状态指示 + 可回退导航**：已完成阶段可点击回看；未达阶段禁用
- 扫描中：列表区显示进度（mono 路径滚动 + 百分比）；执行中：行动栏变进度态；完成：台账阶段显示结果摘要 + 印章 + Undo（沿用 UndoBanner，移入台账阶段视图）
- 应用（Apps）模块用**简化骨架**：无阶段条（卸载是逐应用流程），列表 + 证据面板两栏，行动栏仅在有选择时浮现

### 2.4 响应式（按内容区宽度，经现有 `contentWidth` 环境机制）

| 内容区宽 | 行为 |
|---|---|
| ≥880pt | 列表 + 证据面板双栏全显 |
| <880pt | 证据面板收为滑出抽屉（点条目滑出，点外收回） |
| <740pt | 同上，且行动栏收缩为「主按钮 + ⛨ 徽记」 |

窗口最小 980×640、侧栏 200–230pt 折叠可得内容区约 750–980pt，两档均可达；取代 `AtlasLayout.browserSplitThreshold` 单一阈值。

---

## 3. 逐屏规格

| 屏幕 | 版式与要点 |
|---|---|
| **概览** | 问候 + 状态胶囊行（磁盘/恢复点/权限）→ 「下一步」横幅（brand 渐变，一句话建议 + 为什么 + 一键开始/先看明细）→ 左**指挥台**（健康环 + 模块入口行，每行带状态与箭头）/ 右**台账流**（最近 3–5 条 № 条目 + 「查看完整台账 →」）。首次使用：横幅变「运行首次扫描」引导；推荐为空时横幅显示「状态良好」+ 最近台账 |
| **智能清理** | 完整骨架（§2.3）。阶段: 扫描→复核→执行→台账。过滤芯片: 全部/安全/复核/高级 + 类别（如开发缓存）。证据面板含来源签名信息 |
| **文件整理** | 完整骨架。阶段: 扫描→规则→预演→执行→台账。「规则」阶段主区为规则编辑器（现 RuleEditor 迁入），证据面板回答「此文件为何被分类至 X」；「预演」即现 dry-run，列表显示将发生的移动 + 冲突标记 |
| **应用** | 简化骨架（无阶段条）。列表: 应用行（图标/名称/mono 大小/残留徽记）；证据面板: 10 类证据足迹分组 + 卸载计划预览 + 残留估计；卸载主操作入行动栏（选中时浮现），完成后台账入账 + Toast |
| **台账** | 暖纸面全页（§1.6 主场）。顶部: serif 标题 + 「导出报告」；统计行（本月活动/运行中/可恢复+mono 容量）+ 过滤芯片（可恢复/全部/归档）；左**时间线**（№ 条目，进行中任务置顶钉住）/ 右**详情面板**（mono 执行数据 + 包含清单 + 还原全部/逐项还原 + 印章水印）；底部「更早归档」折叠 |
| **权限** | 保留进度环 hero + 权限行；每行可展开证据三段式（为什么需要/影响范围/如何授权）；「打开系统设置」保留；限制模式 callout 换新装 |
| **设置** | 三段 tab 保留（通用/恢复/信任）。恢复段强化: 保留天数 stepper + 排除路径 + **恢复区占用量（mono）**；信任段: 分发信息 + 文档按钮沿用 |
| **关于** | 纯换装（版本 mono、二维码、更新检查按钮新样式） |

每屏四态齐备：**loading**（骨架屏，沿用 AtlasSkeleton 换新装）/ **empty**（首次引导，接「下一步」语法）/ **error**（新 `AtlasErrorState`）/ **degraded**（权限缺失 → 限制模式横幅 + 可继续的部分照常）。

---

## 4. 设计系统 v3 工程规格（AtlasDesignSystem）

### 4.1 Token 变更

- `AtlasColor`: 新增 `ink / inkData / ledgerPaper / ledgerInk / ledgerBorder / ledgerRule / actionBarBg` 系（§1.2 全表，深浅双值，入 xcassets）；高程阴影值调淡
- `AtlasTypography`: 按 §1.3 重构（三声部 + 新字号阶）；移除全局 rounded
- `AtlasMotion`: 新增 `stageTransition / stampIn / countUp`
- `AtlasSpacing` / `AtlasRadius`: 数值不变；新增 `AtlasLayout.evidencePanelMinWidth = 300`、三档断点常量

### 4.2 新增组件（9 项）

| 组件 | 职责 / 接口要点 |
|---|---|
| `AtlasStageBar` | `stages: [Stage], current, onSelect`；胶囊分段；已完成可点回看；键盘可导航；窄宽收缩为「②/④ 复核」紧凑态 |
| `AtlasEvidencePanel` | 三段容器（why / evidence(mono KV) / recovery+⛨）+ 行级操作槽；无选中时空态「选择一项查看证据」 |
| `AtlasActionBar` | `primary, promiseText, metric(mono)`；吸底墨色条；执行中变进度态；窄宽收缩 |
| `AtlasLedgerTimeline` / `AtlasLedgerEntry` | № serif 编号 + 标题 + mono 数据 + 状态徽记；左侧时间线轨；selection 绑定 |
| `AtlasStampBadge` | 圆形描边印章，−11° 旋转；`accessibilityHidden(true)`（信息由相邻文本承载） |
| `AtlasLedgerSurface` | 暖纸面容器（底色/边框/标题底线/点状分隔环境） |
| `AtlasNextActionBanner` | brand 渐变横幅：headline + rationale + 主/次按钮 |
| `AtlasErrorState` | 错误码 + 信息 + 建议动作 + 可选帮助链接（补现有空缺，取代裸 `executionIssue` 字符串展示） |
| `.atlasData()` 修饰符 | mono + monospacedDigit 一致入口，杜绝散落的字体声明 |

### 4.3 修改 / 吸收 / 启用

- **修改**: MetricCard、HeroCard（数字切 mono）；三档按钮、StatusChip、FilterChip、SegmentedControl（去圆体、新 token）；AtlasScreen（新画布渐变）；侧栏项（状态副标题样式）；Skeleton/Callout/EmptyState/LoadingState 换装
- **吸收**: `AtlasEvidenceGroupCard` 并入 `AtlasEvidencePanel`
- **启用**: `AtlasToast`（完成时刻 +「已入账 №N」提示）与 `AtlasTooltip`（阶段条/印章悬停说明）——现已定义但闲置

---

## 5. 工程组织

### 5.1 包结构与拆分纪律

- 包架构不变：Apps → Features → DesignSystem/Domain → Application/Infrastructure/Adapters/Protocol
- **每视图文件 ≤ 350 行**。拆分基线：
  - `AtlasFeaturesHistory`（1390 行）→ `LedgerFeatureView`（协调）+ `LedgerTimelineView` + `LedgerDetailView` + `LedgerArchiveView` + `LedgerViewState`
  - SmartClean / FileOrganizer / Apps 按「标题阶段区 / 列表 / 证据面板内容 / 行动栏配置」拆文件
- 包名 `AtlasFeaturesHistory` 保留（避免 SPM 摩擦），内部类型与文案改 Ledger

### 5.2 状态管理立场

沿用现有 `AtlasAppModel` + binding 模式，**不引入新状态框架**（一次到位的范围控制）。每屏新增轻量 `ViewState` struct 聚合本地 UI 态（选中项、阶段、过滤器），替代散落的 `@State`。

### 5.3 路由迁移

`AtlasRoute.history` → `.ledger`：rawValue 持久化做读取时映射；无障碍 ID、`AtlasL10n` 键、测试固定值同步替换。协议层不动。

### 5.4 本地化与文书语气

zh-Hans / en 全量过一遍。对照表（写入 `Docs/COPY_GUIDELINES.md`）：

| zh | en |
|---|---|
| 提案 №42 | Proposal #42 |
| 扫描凭据 #A1F3 | Scan Credential #A1F3 |
| 台账 | Ledger |
| 恢复点 · 保留 7 天 | Recovery Point · kept 7 days |
| 全量备份 · 可恢复 | Fully backed up · Recoverable |
| 已验证 ✓ | Verified ✓ |
| 签署语气仅限台账面；工作面按钮保持动词直白（执行清理计划 / Run Cleanup Plan） | |

---

## 6. 可达性红线

- 印章、时间线轨等装饰元素 `accessibilityHidden`，信息由相邻文本承载
- 三声部全部接 Dynamic Type；mono 大数字设上限档
- 阶段条、过滤芯片、台账时间线键盘可导航；证据面板有 VoiceOver 容器结构
- 减弱动态：stageTransition→opacity、stampIn→直接落定、countUp→直接落定
- 对比度全检 WCAG AA（重点：台账面次要文字、行动栏 `#9FD4C9` on `#10302C`、深色模式软底）

---

## 7. 测试与验收

- **迁移**: 现有 377 测试全绿（更新断言与无障碍 ID）；新组件各补单测；`LedgerViewState` 等新 state struct 补逻辑测试
- **截图基线**: `ATLAS_EXPORT_README_ASSETS_DIR` 重新导出 README 全套截图（zh + en）
- **手动矩阵**: 双语言 × 双外观 × 两档内容宽（≥880 双栏 / <880 抽屉，含侧栏折叠态），每屏过四态
- **回归红线**: 扫描→复核→执行→恢复 全链路行为不变（纯前端重构，Worker/协议零改动）

---

## 8. 交付策略（已确认：一次到位）

- 长分支 `redesign/calm-ledger`，全屏幕完成后整体合并；期间 main 仅接 hotfix
- 分支内里程碑（顺序执行，每个里程碑分支内可构建、测试绿）：
  1. **M1 Token 层**: AtlasColor/Typography/Motion v3 + xcassets（旧组件暂时兼容渲染）
  2. **M2 组件层**: 9 新组件 + 修改/吸收/启用清单
  3. **M3 屏幕迁移**: 智能清理（骨架样板间）→ 台账 → 概览 → 应用 → 文件整理 → 权限 → 设置/关于
  4. **M4 收尾**: 路由迁移、本地化全检、可达性全检、截图基线、手动矩阵
- 合并门禁: 构建 + 全测试 + 手动矩阵 + 截图更新 + `bin/ato-iter` 验收流程（REQ/CHG 按仓库治理在实施计划中建立）

## 9. 范围外（明确不做）

- Liquid Glass 材质 / NSVisualEffectView 重血统改造（已评估，未选）
- 新模块功能本身（启动项管理、存储可视化、开发者深清的**功能实现**——骨架已预留其位）
- Storage 占位模块实装（保持占位，仅随设计系统换装；不入侧栏）
- 菜单栏工具、自动化（D-010 冻结边界）
- Go 后端、Worker、XPC 协议层改动

## 10. 决策记录（共创轨迹）

| 决策点 | 选项 | 结论 |
|---|---|---|
| 重设计动机 | 视觉 / 结构 / 战略 / 全部 | **全部** |
| 视觉基调 | Liquid Glass / 精密暗色 / 信任台账 / 平静权威 2.0 | **D 基底 + B 数据层 + C 信任层**（点击轨迹显示 B/C 强吸引，融合确认） |
| 工作模块骨架 | 精进单栏 / 证据三栏 / 流程驱动 / 混合 | **混合（阶段条 + 证据面板 + 行动栏）** |
| 概览定位 | 仪表盘 / 下一步驱动 / 指挥台+台账流 | **下一步横幅 + 指挥台 + 台账流融合** |
| 历史改名台账 | — | **确认**（zh 台账 / en Ledger） |
| 交付策略 | 样板间先行 / 一次到位 / 换肤先行 | **一次到位**（长分支整体切换，内部四里程碑） |
