# Atlas for Mac — 体验摩擦修复设计规格

- **日期**：2026-09-14
- **状态**：**已通过设计评审**（2026-09-14，`Decision = Pass`，产品负责人终审已过）——记录见 `Docs/Execution/UX-Friction-Remediation-Design-Gate-Review-2026-09-14.md`。可开 `REQ` / `CHG`
- **范围**：`Docs/Execution/UX-Friction-Audit-2026-09-14.md` 全部 40 条 finding（39 条原始 + 1 条二次核验补报 `NEW-1`）
- **上游**：`Docs/Execution/UX-Friction-Audit-2026-09-14.md`（诊断，无实现方案）、`Docs/COPY_GUIDELINES.md`、`Docs/IA.md`、`Docs/design/2026-06-10-frontend-redesign-calm-ledger.md`（设计语言 v3）、`Docs/Backlog.md`
- **性质**：**实现方案**。本文只设计，不含代码改动；执行走 `changes/CHG-*`
- **取代关系**：不取代任何既有文档。落地后需向 `Docs/COPY_GUIDELINES.md` §Glossary 回写双语术语表（见契约四）

---

## 0. 背景、目标与治理定位

### 0.1 问题定义

`UX-Friction-Audit-2026-09-14.md` 从**非技术 Mac 用户**视角审查了全部用户可达面，产出 39 条 finding。该文档明确定位为**只诊断、不含实现方案**。本规格补上实现方案，并在回源核验中补报第 40 条（`NEW-1`，已回写审计正文——故**审计现为 40 条**）。

审计发现的问题不是「审美不够」，而是四类**产品承诺与实现不符**：

1. **控件说谎** —— 撤销/恢复按钮存在但点了没反应
2. **破坏性动作的后果在执行前不可读** —— 弹窗不说文件会去哪、能不能撤回
3. **受限模式（Limited Mode）的界面表达与它的定义相反** —— `COPY_GUIDELINES.md` 定义 Limited Mode 为「只在特定工作流需要时才索取更多权限」，而首页横幅是无条件、不可忽略的
4. **同一概念在不同位置给出互相矛盾的表述** —— 同一计数两种口径、同一冲突三种后果、同一个词兼指两个状态

### 0.2 成功标准（可判定）

- 40 条 finding（审计 39 条原始 + 1 条补报 `NEW-1`）全部有归属契约，无漏项
- §7 的 12 条不变量全部可判定，且**每条至少有一条回归守卫**（模型单测 / `AtlasAppUITests` XCUITest / AX 断言）。**I-5 是唯一例外**——其真实时序不可自动观测，守卫已降级为模型层静态断言 + 人工验收项（§7.1）
- 契约四的 zh/en 术语表定稿并回写 `Docs/COPY_GUIDELINES.md`；**且产品内存在可读入口**（首次遇见解释 + 可查术语表，§4.2(2)）——只回写文档不算达标
- 破坏性确认弹窗的 ①②③ 字段**在组件 API 层面不可缺省**（缺项编译不过，而非靠评审发现）；**④ 不走 optionality**——它是条件性必需，由类型区分保证（§7.1）
- 不新增第三方依赖；不修改设计系统既有 token（`AtlasColor` / `AtlasTypography` / `AtlasSpacing` / `AtlasRadius` / `AtlasElevation` / `AtlasMotion`）

### 0.3 治理定位

**这不是一次视觉重设计。** Calm Ledger v3（`Docs/design/2026-06-10-*.md`）已确立设计语言与骨架，本规格**不动设计语言**，只在既有语言内修正交互契约、状态表达与文案。

**CONTRACT 升级（必须人工批准）**：

| 项 | 内容 | 处理 |
|---|---|---|
| 契约四 术语体系 | 重建 zh/en 术语表，可能触及路由名与 `COPY_GUIDELINES.md` | 规格出提案 → 开 `REQ` 时立 `## Contract Unfreeze Record`（沿用 `iterations/REQ-calm-ledger-redesign/requirement.md` 先例） |
| 契约六 P1-18 | Settings 补菜单入口与 ⌘, ——需修改 `AtlasAppCommands.swift` 的 `preconditionFailure("Non-sidebar routes have no shortcut key")` 分支并触及 `AtlasRoute.sidebarRoutes` 的语义 | 同上 |
| 契约一 | `AtlasAppModel` 公开 API 变更（新增结构化 outcome，废弃 per-module summary strings） | 非 CONTRACT，但需同步 `AppShellView` 调用点与 `AtlasAppModelTests` fixture |

`D-012`（`历史`→`台账` 改名决定）可能被契约四重开。**不得由 agent 自主合入**——须产品负责人签字。

**审计与规格的分工**：审计是**诊断真相源**，本规格是**实现方案真相源**。契约四定稿后，`COPY_GUIDELINES.md` 成为**术语真相源**。三者不双写。

### 0.4 本次对上游审计的更正

写规格前对审计做了逐引用回源核验（抽验 44 处）。**4 处引用需更正、1 条漏报、1 处证据强度修正**，已并入下文。详见附录 A。

---

## 1. 契约一 —— 操作结果契约

**覆盖**：`P0-1` `P0-2` `P1-8` `P1-11` `P1-14` `P1-17` + 新增 `NEW-1`
**性质**：本契约是全部契约里唯一需要改动模型层公开 API 的

### 1.1 现状证据

**根因：`String` 没有来源标识，所以无法路由。**

`AtlasAppModel` 现有五条模块级摘要串：`latestScanSummary` / `latestAppsSummary` / `latestPermissionsSummary` / `fileOrganizerScanSummary` / `updateCheckError`。**台账（Ledger）没有自己的槽位**——所以台账恢复失败时错误被写进隔壁模块的 `latestScanSummary`：

- 写入点：`Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift:828`（`latestScanSummary = error.localizedDescription`，位于恢复流程的 `catch` 内）
- 渲染点：`Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift:196`（`scanSummary: model.latestScanSummary`，在 Smart Clean 分支）

台账屏对该失败**零呈现**。用户点「恢复」→ 画面无变化 → 得出「文件已回来」的结论。

**控件门控不一致**：

| 模块 | 渲染条件 | 位置 |
|---|---|---|
| Smart Clean 回执撤销 | `if receipt.hasRestorePoint, let onUndo` | `SmartCleanReceiptView.swift:136`（`hasRestorePoint` = `!recoveryItemIDs.isEmpty && recoveryBytes > 0`，`:53-54`） |
| File Organizer 回执撤销 | `if let onUndo` —— **无门控** | `FileOrganizerStageViews.swift:586` |

而 `onUndoExecution` 在 `AppShellView.swift:321-323` 是**无条件**传入的，所以 FO 撤销按钮**总是渲染**；点击后 `undoFileOrganizerExecution()` 首步 `guard let recoveryItem = ... else { return }` —— 找不到恢复项就直接返回，**无任何反馈**。

**失败后出口不可达**：Smart Clean 与 FO 的「查看回执」均 `isEnabled: inputs.hasReceipt`，而进入回执页同样要求 `hasReceipt`；失败发生在 worker 返回 receipt 之前时按钮置灰，且 `onViewReceipt` 只改 `displayedStage`、被 `effectiveStage` 退回——界面不动（`SmartCleanActionBarModel.swift:133`、`SmartCleanEvidenceBuilder.swift:95-97`；FO 同构：`FileOrganizerActionBarModel.swift:155`、`FileOrganizerStageMap.swift:161-163`）。

**恢复成功的反馈同构**：无论磁盘还原还是仅状态还原，恢复项都被 `removeAll` 移除、指标同步下降、台账留下 `.completed` 任务，**两种恢复的成功信号完全相同**（`AtlasScaffoldWorkerService.swift:377-396`、`:421`）。用户会去访达找从未被还原的文件。

**新增 `NEW-1`：非错误信息走在错误通道上。** `AtlasAppModel.swift:387-390` 的注释自述「受限模式软提示（**非阻断**）」，却赋给 `smartCleanPlanIssue`；而 `SmartCleanStageViews.swift:45-49` 把 `planIssue` 一律渲染为

```swift
AtlasErrorState(
    title: AtlasL10n.string("smartclean.status.revalidationFailed"),  // 「未能更新当前计划」
    message: planIssue,                                               // 「…扫描可能较慢且范围受限…」
    layout: .inlineRow
)
```

未授权用户在整个扫描期间看到的是**失败标题配非失败正文**，且该值只在扫描成功后才被清（`AtlasAppModel.swift:414`）。

> 审计 `P1-3` 曾把这句文案**当作「铺垫」正面引用**，未发现它挂在失败标题下。

### 1.2 契约条款

**（1）模型层：结构化 action outcome，取代模块级摘要串**

引入按来源标识的结果模型：

```
AtlasActionOutcome {
    source   : AtlasActionSource   // .smartClean / .fileOrganizer / .ledger / .apps / .permissions
    kind     : .succeeded / .failed / .advisory / .unavailable(reason)
    message  : String
    recovery : AtlasActionRecovery?   // 可撤销性 / 可重试 / 去向
}
```

各屏**只订阅自己 source 的结果**。跨屏泄漏在类型层面变得不可表达。

`kind` 必须区分 `.failed` 与 `.advisory`——`NEW-1` 的直接修复就是把受限模式提示归入 `.advisory`，并为其提供**非错误态**的渲染路径。

保留既有渲染形态：`.advisory` 走 `AtlasCallout`（tone: `.warning`），`.failed` 才走 `AtlasErrorState`。

**（2）控件层：可撤销性三态**

任何撤销/恢复控件在**执行前**即处于以下三态之一，且**三态都可读**：

| 态 | 渲染 | **判定规则：什么条件落这个态** |
|---|---|---|
| `.available` | 渲染可点按钮 | 前置条件满足 |
| `.unavailable(reason)` | 渲染**禁用控件 + 理由** | 动作**可恢复**，但本次**无可恢复项**——**这是默认态** |
| 不存在 | **必须在同屏渲染缺席说明** | **仅当该控件对本屏的动作类型根本不适用**（例：非可恢复动作的回执，「撤销」这个概念不存在） |

**判定规则（本节新增，用以消除原欠定义）**：

> **「条件不满足」≠「控件不适用」。** 凡「动作可恢复但本次无可恢复项」，**一律落 `.unavailable(reason)`**（禁用 + 理由），**不得隐藏**。`.available` ↔ `.unavailable` 之间是**状态切换**，控件位置不得跳动；只有动作类型不适用时才允许进入「不存在」态，且此时必须渲染缺席说明。

这条规则同时封住两个方向的退化：FO 的**无门控渲染**（永远可点）与 Smart Clean 的**静默消失**（点了找不到）。审计 `P1-8` 的表述是「在不满足条件时是**不存在**，不是置灰」——本节据此**明确选择「置灰 + 理由」**，而非「隐藏 + 说明」。

明确禁止的两种现状：**无门控渲染**（FO 现状）与**静默消失**（Smart Clean 现状）。

> 门控本身是 fail-closed 的刻意设计，**保留**。本条只要求缺失可读。

**（3）出口层：失败态必须至少有一条可达出口**

「查看回执」在 `hasReceipt == false` 时**不再渲染**，改为渲染「本次未生成回执」+ 最少可用信息（已处理 / 未处理计数）。**禁止渲染一个点了不动的控件。**

**（4）反馈层：两种恢复必须产出不同种的 outcome**

磁盘还原（`restoreMappings` 非空）与仅状态还原（`atlasOnly`）必须映射到**不同的 `kind` 或不同的 `recovery` 载荷**，而非仅文案不同。用户必须能区分「文件回到了磁盘」与「Atlas 只是标记了状态」。

### 1.3 边界（不做什么）

- 不引入全局 Toast 作为失败反馈载体。`AtlasToastContainer` 已存在但**默认 3 秒自动消失**——不适合「你的恢复失败了，文件没回来」这类需要持续可读的信息。Toast 仅可用于 `.succeeded` 且无需后续动作的场景。
- 不改动 `AtlasScaffoldWorkerService` 的恢复语义与 fail-closed 判定。

---

## 2. 契约二 —— 破坏性确认四问

**覆盖**：`P0-3` `P0-4` `P0-5` `P1-10`

### 2.1 现状证据

三条 `role: .destructive` 的最终确认弹窗，正文均**不回答用户按下按钮前唯一需要知道的后果**：

| 条目 | 弹窗文案（zh-Hans 原文） | 缺什么 |
|---|---|---|
| `P0-3` 卸载 | 「将移除 %@ 应用包。仅供复核的残留证据会继续显示在计划里，本次卸载也会记录到台账中。」（`:746`） | **只字未提能否找回、多久内、从哪儿找**。同款 Smart Clean 版却写了 |
| `P0-4` 文件整理 | 「将按分类计划移动文件。可在台账中恢复原始位置。」（`:965`） | **标题、正文、按钮三处都不含目标位置**。默认目标是 `~/Organized`（`FileOrganizerFeatureView.swift:70`），一个普通用户没听过的路径 |
| `P0-5` 智能清理 | 「将按复核后的计划执行清理。可恢复项目会保留在台账中；只有具备受支持恢复路径的项目，才支持磁盘级恢复。」（`:744`） | 通篇讲「台账」「磁盘级恢复路径」；真正能回答后果的数字（**本次选中 N 项里有几项可恢复**）只在主按钮下方的 promise 行（`SmartCleanEvidenceBuilder.swift:113-120`），**弹窗把它丢了** |

**`P1-10` 单独问题**：Smart Clean ② 空态按钮文案是「重新扫描」（`SmartCleanStageViews.swift:126-127`），动作走 `rescanTapped()` → `state.planNumber != nil ? onRequestRescan() : onStartScan()`（`SmartCleanFeatureView.swift:348`）。只要存在计划编号就弹出 `role: .destructive` 的「作废并重新扫描」对话框（`SmartCleanFeatureView.swift:151`）。**标签与后果不匹配**——用户想「再扫一遍」，收到的是「你要作废一个计划吗」+ 红色按钮。

### 2.2 契约条款

**（1）四问约束**

所有 `role: .destructive` 的执行确认弹窗，正文必须回答：

1. **会动什么** —— 作用对象（哪些应用 / 哪些文件 / 哪些项）
2. **动到哪去** —— 目标位置（P0-4 的 `~/Organized` 必须出现在弹窗里）
3. **能不能撤回 / 多久内 / 从哪撤** —— 恢复窗口与入口（P0-3 缺失项）
4. **这次有几项可恢复** —— 当且仅当该动作作用于可恢复项集合时必需（P0-5，把 promise 行的 `N/M` 带进弹窗）

**这不是文案模板，是弹窗构造的字段约束**：`AtlasDestructiveConfirmation`（或等价组件）的 ①②③ 字段为**非可选**，缺项编译不过。④ 由动作类型决定是否必需。

**（2）标签—后果一致**

任何触达破坏性对话框的入口控件，其标签必须描述**该对话框的后果**，而非用户的上位意图。`P1-10` 的直接修复：空态按钮文案改为描述后果的表述，或使无计划时该路径不触发作废确认。

### 2.3 边界（不做什么）

- 不统一三条弹窗的**措辞风格**——工作面用直白动词、台账面用文书语气，这是 `COPY_GUIDELINES.md` §Containment Rules 的既定纪律。本契约只约束**信息完整性**。
- 不新增第五个问题（如「是否确认」类冗余确认）。

---

## 3. 契约三 —— 权限分级索取

**覆盖**：`P1-1` `P1-2` `P1-3` `P1-5` `P1-6` `P2-8`

### 3.1 现状证据

**核心矛盾**：`Docs/COPY_GUIDELINES.md:48` 定义

> `Limited Mode` — Atlas works with partial permissions and **asks for more access only when a specific workflow needs it**.

而首页横幅的行为与之相反：`Packages/AtlasFeaturesOverview/Sources/AtlasFeaturesOverview/OverviewRecommendation.swift:127-141` 的第一条分支在缺必需权限时无条件返回，`isSnoozeable: false` —— 用户**不能忽略、不能绕过**。

**关键事实（本规格审校修正）**：受限模式**不是**一个 first-class 概念——全仓 `limitedMode` / `isLimited` 在模型层与领域层 **0 命中**。它只是一处布尔判断 + 一条 ad-hoc 字符串：

```swift
// 受限模式软提示（非阻断）：未授权完全磁盘访问时扫描可能缓慢且范围受限。
if !smartCleanRequiredPermissionsReady {
    smartCleanPlanIssue = AtlasL10n.string("model.scan.limited.permissions")
}
```

`AtlasAppModel.swift:388-390`。注释明言**非阻断**——**扫描确实会跑**，只是更慢、范围受限。

> 所以本契约的实质是：**扫描本来就非阻断，是 UI 在阻断式索要权限。**

**其余缺项**：

- `P1-2`：首页渲染顺序为「问候语（硬编码 morning 变体）→ 三枚状态胶囊 → 下一步横幅」（`OverviewFeatureView.swift:164-194`）。且 `overview.callout.limited.title/detail`（zh `:250-251`）**在全部 Swift 源码零引用**——唯一一句解释受限模式的现成文案没被渲染
- `P1-3`：文件整理①扫描一点「扫描文件夹」立刻弹出裸的系统 TCC 弹窗，**弹窗之前 app 内没有任何前置说明**
- `P1-5`：权限行副标题直接绑定 `state.rationale`（`PermissionRowView.swift:28`），实机渲染原文含 `Library` 与「系统级缓存」（`fixture.permission.fullDiskAccess.rationale`，zh `:80`）
- `P1-6`：点「打开系统设置」只做 `NSWorkspace.shared.open(url)` 就结束（`PermissionsFeatureView.swift:283-285`）；回来只靠 `scenePhase == .active` 被动触发一次 `onRefresh()`（`:158-161`），无回执、无二次引导
- `P2-8`：File Organizer 无权限受限态。**证据修正**：审计以「FO 包内 `permission|权限` 零命中」作证——但对照组 SmartClean 包内**同样为 0**（那条文案住在 app 层），故该 zero-hit 单独不构成证据。真正的差异在接线：`fileOrganizerPlanIssue` 的赋值只有 `nil` 与 `error.localizedDescription`（`AtlasAppModel.swift:1123/1128/1195/1215/1327`），**无权限分支**；`smartCleanPlanIssue` 有一条（`:390`）

### 3.2 契约条款

**（1）横幅可推迟**

首页权限横幅补「稍后」出口，文案改为说明「现在不做也能用」+ 受限范围。

**（2）首页顺序：下一步优先于问候**

「下一步」横幅的优先级高于问候语与状态胶囊。接上零引用的 `overview.callout.limited.title/detail` 作为受限模式解释。

**（3）就地索取 + TCC 前置说明**

权限改为在真正需要它的工作流现场提出。**任何系统级授权请求之前，app 内必须已经渲染过一句作用域说明**——「系统接下来会问 X，因为 Y，你可以先拒绝」。

**（4）权限行去技术黑话**

`PermissionRowView` 的副标题不得直接暴露 `Library`、「系统级缓存」一类内部概念。三段式证据文案（为什么需要 / 影响范围 / 如何授权）保留。

**（5）跳转后二次引导**

从系统设置返回且状态未变时，给出「你去过了但仍未生效，可能是 X」的回执与下一步。

**（6）FO 补权限受限态**

`fileOrganizerPlanIssue` 增加权限分支（与 `smartCleanPlanIssue:390` 对齐），且**不得**把权限受限渲染成 `fileorganizer.status.executionFailed`（「文件整理未能完成」，`FileOrganizerStageViews.swift:50`）。

### 3.3 边界（不做什么）

- **不新增受限模式的领域概念。** 现有布尔判断足够；本契约只修正 UI 表达与接线。
- 不放宽权限的**真实性**要求——不承诺受限模式能完成需要完全磁盘访问的工作。受限就是受限。

---

## 4. 契约四 —— 术语体系

**覆盖**：`P1-4` `P1-13` `P1-15` `P2-1` `P2-2` `P2-3` `P2-4` `P2-5`
**治理**：**CONTRACT 级**。本规格出提案，解冻记录走 `REQ`

### 4.1 现状证据

`Docs/COPY_GUIDELINES.md` §Glossary（`:35-48`）**已有一套 en 术语表**（`Scan` / `Plan` / `Review` / `Reclaimable Space` / `Recoverable` / `Ledger` / `Scan Receipt` / `App Footprint` / `Leftover Files` / `Limited Mode`）。**问题不是没有术语表，是术语表只在文档里，产品内零解释。**

七条 finding 分属三类**性质完全不同**的问题，不可用同一手段处理：

| 类 | 条目 | 证据 | 性质 |
|---|---|---|---|
| **翻译错误** | `P2-4` | zh `:1207` `"evidence.safety.conditional" = "需确认"` ｜ en `:1188` = `"Conditional"`。en 是形容词（风险等级），zh 译成了动作 | 不是设计选择，是译错 |
| **同屏同名** | `P2-2` | `risk.review` = 「复核」（zh `:25`）与 `smartclean.stage.review` = 「复核」（zh `:1146`）同屏渲染（阶段条在 `SmartCleanSupportViews.swift:48`）。点阶段条是切步骤，点 chips 是筛风险 | 解释救不了，必须消歧 |
| **量纲冲突** | `P2-3` | 权限语境 `permissions.optionalSection.count.other` = 「%d 项待处理」（zh `:646`）；文件语境 `smartclean.summary.findingCount` = 「%d 个发现项」（zh `:421`）。中文「项」在两种语境字形相同 | 需要量词分离 |
| **一词两义** | `P1-15` | `LedgerTimelineView.swift` 中 `status(for run: TaskRun)`（`:156`）的 `.failed/.cancelled` 与 `status(for item:now:)`（`:167`）的「已过期」**都**返回 `.archived`，渲染为「已归档」（`ds.ledger.status.archived`，zh `:1237`）。用户读「已归档」＝「已安全保存」，实为**不可恢复的终态** | 两个概念挤一个词 |
| **口径不一** | `P1-13` | 同一「冲突」三处三种后果暗示：②「目标位置已存在同名文件：%@」（zh `:1012`，听感＝会覆盖）③「执行时将自动重命名冲突文件…取消选中可跳过」（zh `:1014`，听感＝自动无损）回执「%d 项失败（可重试）」（zh `:1091`，听感＝失败了且无处重试） | 需统一口径 |
| **呈现错误** | `P1-4` | 权限概览卡 `title: permissions.metric.later.title`（「暂不需要」，zh `:634`）配 `value: "\(optionalMissingCount)"`（`PermissionsFeatureView.swift:81-82`）——**缺失计数挂在读作类别名的标题下**；同一批权限在下方列表又叫「%d 项待处理」 | 计数不能用类别名做标题 |
| **缺解释** | `P2-1` | `apps.evidence.why.idle` 原文含「残留足迹」（zh `:513`）；`apps.metric.leftovers.title` = 「残留文件」（zh `:442`）。用户不知道「残留」是卸载后留下的配置文件、「证据」是扫到但本次不移除的清单 | 这才是真·缺解释 |

**另附 `P2-5`**：`AtlasLanguage.displayName` 硬编码返回 `"简体中文"` / `"English"`（`AtlasLocalization.swift:24,26-29`），**绕过 `AtlasL10n`**（对比同文件 `AtlasTheme.displayName` 走 `AtlasL10n.string`）。而 `language.zhHans` / `language.en` 两个 key 在两份 strings 中都有，**Swift 引用数为 0**。英文用户在这一行看到一半中文。

### 4.2 契约条款

**（1）分层处理，不用同一手段**

| 类 | 手段 |
|---|---|
| 翻译错误 | **改词**——`Conditional` 类形容词不得译成动作 |
| 同屏同名 | **消歧**——同名两控件至少其一改名 |
| 量纲冲突 | **量词分离**——权限语境与文件语境不得共用「项」 |
| 一词两义 | **拆词**——「已归档」拆为「已过期（不可恢复）」与「已结束（失败/取消）」两个表述 |
| 口径不一 | **统一**——三处冲突文案收敛为一套一致口径，且「可重试」在回执上必须有对应入口，否则删去该措辞 |
| 呈现错误 | **改结构**——缺失计数不得挂在类别名标题下 |
| 缺解释 | **保留词 + 建产品内解释** |

**（2）术语表双语化并进产品**

把 `COPY_GUIDELINES.md` §Glossary 从「en 单语、仅文档」扩为 **zh/en 双语**，并在产品内建立可读入口（首次遇见解释 / 可查术语表）。`残留` / `足迹` / `台账` / `证据` 四个体系词**保留**，补解释。

**（3）`P2-5` 修复**

`AtlasLanguage.displayName` 改走 `AtlasL10n`，启用两个零引用 key。

**（4）孤儿键勾稽**

`route.history.title` / `route.history.subtitle` / `sidebar.history.dynamic` × 2 语言 = **6 条目，Swift 引用数全部为 0**（`AtlasRoute.title` 用显式 switch 而非字符串插值，故不可能是动态引用——见 `AtlasDomain.swift:147`）。已在 `ATL-272` 跟踪，**本规格只做勾稽，不重复上报**。

### 4.3 治理与边界

- **本契约是全规格唯一需要产品负责人签字的 CONTRACT 项**，且在 Wave 1 的关键路径上（P0 的三条弹窗文案要用定稿词汇）
- `D-012`（`历史`→`台账`）可能被重开。**不得由 agent 自主合入**
- 不追求术语的"统一美学"——工作面直白、台账面文书，这是既定纪律，保留

---

## 5. 契约五 —— 状态可见性

**覆盖**：`P1-9` `P1-12` `P1-16` `P2-6` `P2-7` `P2-10` `P2-11` `P2-13` `P2-14` `P2-15` `P2-16`

### 5.1 现状证据

| 条目 | 证据 |
|---|---|
| `P1-9` | Smart Clean ③ 执行中是**故意的不确定态**：`progress: isExecuting ? 0 : progress,`（`SmartCleanStageViews.swift:301`）+ 空弧 + `smartclean.loading.execute`（`:309`），action bar 为 `progress: nil, intent: .none`（`SmartCleanActionBarModel.swift:100`）。破坏性操作进行中却给不出「到哪了/还剩多久」，且 action bar 无任何可点动作 |
| `P1-12` | FO ① 折叠区标题取自 `smartclean.controls.title`（=「扫描与计划」，zh `:352`）——**智能清理的字符串被文件整理复用**（`FileOrganizerSupportViews.swift:229-230`，`defaultExpanded: false`）。折叠态下不透出「文件将被整理到哪里」 |
| `P1-16` | `pruneExpiredRecoveryItemsIfNeeded` 执行 `state.snapshot.recoveryItems.removeAll { expiredIDs.contains($0.id) }`（`AtlasScaffoldWorkerService.swift:995`）并落盘（`:996`）。用户上次看到「即将到期」的记录凭空消失，无任何提示 |
| `P2-6` | 回执事实行里「预计释放」（`smartclean.receipt.estimated.label`，zh `:1180`）由 `if receipt.estimatedFreedBytes > 0` 守卫（`SmartCleanReceiptView.swift:163`），与「执行项目 N 项」「完成时间」等**实测值等权并排** |
| `P2-7` | FO ② 显示「已选 %d / %d 项」（`FileOrganizerStageViews.swift:170`，zh `:1003`）与全选控件，但**169 条 `fileorganizer.*` 文案逐条读完，无任何一条说明未选中文件的去向** |
| `P2-10` | Apps 一进屏即自动选中第一个应用：`_selectedAppID = State(initialValue: initialSelectedAppID ?? Self.sortedApps(apps).first?.id)`（`AppsFeatureView.swift:76`）+ `syncSelection` 的 `if selectedApp == nil { selectedAppID = sortedApps.first?.id }`（`:350-351`）。而列表副标题承诺的是「**选择一个**应用」 |
| `P2-11` | `apps.restore.refresh.refreshed.detail`（zh `:501`）并排两个不同口径的计数：记录侧 `max(bestItemCount, payload.app.leftoverItems)`（`AtlasAppModel.swift:777,783`），当前清单侧 `refreshedLeftoverItems: refreshedApp.leftoverItems`（`:1526`） |
| `P2-13` | About 首屏是开发者卡（`AboutFeatureView.swift:14-40`）+ `SocialGrid()` 二维码卡（`:42` 调用，定义自 `:92`）。对 `AboutFeatureView.swift` grep `version` / `appVersion` **零命中**；版本号实际在 `AboutUpdateToolbarButton.swift:44` |
| `P2-14` | 任务中心 `ForEach(taskRuns.prefix(5))`（`TaskCenterView.swift:47`），容器是 `VStack` 非 `ScrollView`，全文 136 行**无任何截断提示**。而同一时刻状态文件里 `taskRuns = 147` |
| `P2-15` | 空态同时渲染两个标题：`taskcenter.callout.empty.title`（「当前没有匹配的任务活动」，zh `:230`）与 `taskcenter.empty.title`（「还没有任务」，zh `:234`）；detail 为「**试试新的搜索词**…」（zh `:235`），而该文件 `searchable` / `searchText` **零命中** |
| `P2-16` | 工具栏 `ReceiptChip`（`AppShellView.swift:571-588`）渲染 `Text("#\(code)")`（`:575`），唯一解释是 `.help(toolbar.receipt.help)`（zh `:240`）。struct body **无 Button / onTapGesture / NavigationLink**，调用点是裸 `ToolbarItem`——chip 不可点、无展开 |

### 5.2 契约条款

1. **执行中不作无意义的不确定态**（`P1-9`）——破坏性操作进行中必须给出确定性进度，或至少给出已处理计数 + 剩余时间估计。禁止「空弧 + 一句话」，且 action bar 不得在该状态下完全无可点动作
2. **折叠态必须透出关键参数**（`P1-12`）——折叠标题不得借用其他模块文案；折叠摘要必须含当前去向
3. **估算与实测分流**（`P2-6`）——估算值不得与实测值在同一事实组内等权并排。**且估算值必须渲染在带稳定 `accessibilityIdentifier` 的独立分组容器内**——否则 `I-10` 无法被断言（XCUITest 看不到「组」这个概念，实测中四个 fact row 是平级兄弟）。**该标识属本契约的交付物，不是实现细节。**
4. **不自动选中**（`P2-10`）——不再预选第一个应用；或明确标注为示例
5. **计数口径一致**（`P2-11`）——两个数字若口径不同必须说明，否则只显示一个
6. **截断必须说明**（`P2-14`）——显示「还有 N 条」
7. **空态不得指向不存在的控件**（`P2-15`）——去掉「试试新的搜索词」，或让两个空态标题互斥渲染
8. **内部编号不给普通用户看**（`P2-16`）——`#331B` 对普通用户是纯认知噪音。从工具栏移除，仅保留在台账详情内；如保留则必须可点开解释
9. **About 首屏放版本号**（`P2-13`）
10. **过期恢复项不静默消失**（`P1-16`）——prune 前留墓碑，或 prune 后给出提示
11. **显式表达选择模型**（`P2-7`）——说明未勾选的文件留在原地

### 5.3 边界

- 不做「密度模式」「高级详情开关」一类渐进披露——**超出本规格范围**，属独立迭代（该建议出自 2026-03-08 UI Audit 的 P2-10，与本审计的 `P2-10` 无关，勿混）
- 不改任务中心的数据规模策略（147 条的存储/查询不在本次范围）

---

## 6. 契约六 —— 入口可达性

**覆盖**：`P1-7` `P1-18` `P2-9` `P2-12`

### 6.1 现状证据

**`P1-18`（最严重）**：设置**没有任何菜单入口或键盘路径**，⌘, 也不响应。

- `AtlasAppCommands.swift` 的 `CommandMenu` 只遍历 `AtlasRoute.sidebarRoutes`，设置不在其中
- `shortcutKey` 对 `.settings / .about` 直接 `preconditionFailure("Non-sidebar routes have no shortcut key")`
- 实测 ⌘, 无任何反应（无 Settings scene，也无该快捷键绑定）

> **与已交付 REQ 的关系**：`iterations/REQ-ui-ux-overhaul/requirement.md` 的 P1-3 把「⌘, 打开 Settings」列为**已完成**（该 REQ 整体 Status = DONE）。实际代码里不存在该绑定。**这是「标记 DONE 却未交付」，不是重复上报已完成项。**

**`P1-7`**：Smart Clean ② 复核页右侧面板只有「已选 N 项」+ 风险图例，**没有任何全选/取消全选控件**；而 File Organizer 同阶段有完整的「全选 / 取消全选」（`FileOrganizerStageViews.swift:174-187`）。且主按钮「执行已选 N 项」在 N=0 时置灰，用户要先经历一次「按钮点不动」才知道要勾选。

**`P2-12`**：Settings 的「排除项」区域**没有任何添加入口**。有数据时只做只读渲染（`ForEach(settings.excludedPaths)` → `AtlasDetailRow`），空态是 `AtlasEmptyState`。视图的写回调只有四个：`onSetLanguage` / `onSetTheme` / `onSetRecoveryRetention` / `onToggleNotifications`（`SettingsFeatureView.swift:11-14`）——**没有排除项的写回调**。

**`P2-9`**：「重复文件」徽章判据只是同名同大小——`Dictionary(grouping: entries, by: { FileNameBytesKey(name: $0.fileName, bytes: $0.bytes) })`（`FileOrganizerEvidenceBuilder.swift:286`），**不比对内容**。且徽章只在 footnote 追加两个字，无任何按重复筛选/批量操作的入口。

### 6.2 契约条款

1. **Settings 补菜单入口与 ⌘,**（`P1-18`）——需修改 `AtlasAppCommands.swift` 的 `preconditionFailure` 分支并触及 `AtlasRoute.sidebarRoutes` 的语义。**属 CONTRACT 变更**
2. **Smart Clean ② 补全选/取消全选**（`P1-7`），与 FO 对齐
3. **Settings 排除项补添加入口**（`P2-12`）——需新增写回调并接入 `AtlasAppModel`
4. **重复文件徽章**（`P2-9`）——**二选一**：
   - **（推荐）** 诚实改名（「同名同大小」）+ 提供筛选/聚合入口
   - 真·内容比对 → **会显著抬高扫描成本**，越界到性能，本规格不采纳

### 6.3 边界

- 不新增路由。Settings 已是 `AtlasRoute` 成员，本契约只解决它的**可达性**，不改变路由集合

---

## 7. 红线 —— 可测试不变量

每条不变量必须是**可判定**的，且**至少有一条回归守卫**。守卫形式只认仓库里**实际能执行**的三条通道：

| 通道 | 载体 | 执行入口 |
|---|---|---|
| 模型单测 | `AtlasAppModelTests` 等（`swift test`） | `swift test --package-path Packages` / `--package-path Apps` |
| UI 自动化 | `AtlasAppUITests`（XCUITest，已有 accessibility identifier） | `./scripts/atlas/run-ui-automation.sh`（`xcodebuild test -only-testing:AtlasAppUITests`） |
| AX 断言 | 委派 `macos-gui-acceptance` | 见该 agent 定义 |

> **为什么不用「视图测试」**：本仓库的 `*FeatureViewTests.swift` 只构造 view struct 断言初始属性（`testDefaultInitUsesFixtureData` 一类），**没有渲染断言能力**；5 个 SPM 根包的外部依赖数为 **0**，而 §0.2 禁止新增第三方依赖，故 ViewInspector / 快照测试这条路是堵死的。能对渲染结果下断言的只有 `AtlasAppUITests`。
>
> **执行边界（易踩）**：`swift test` **跑不到 XCUITest**——后者需 `xcodebuild test`。§9 的每波验证协议已相应补上该命令。

| # | 不变量 | 覆盖 | 守卫形式 |
|---|---|---|---|
| **I-1** | 失败结果不得写入非本 source 的槽位 | `P0-1` `NEW-1` | `AtlasAppModelTests`：触发台账恢复失败，断言台账 outcome 槽非空**且** Smart Clean 槽未被写入 |
| **I-2** | 无对应恢复项时，撤销控件不得处于可点状态 | `P0-2` | `AtlasAppUITests`：构造无恢复项的 receipt，断言撤销控件存在且 `isEnabled == false`，**同屏有理由文案** |
| **I-3** | 可恢复动作的回执在无可恢复项时**不得静默隐藏** | `P1-8` | `AtlasAppUITests`：断言该状态下撤销控件**仍在场**（`exists`）且 `isEnabled == false`，且同屏有理由文案——**隐藏即判失败** |
| **I-4** | 每个 `.destructive` 确认弹窗渲染 ①②③ 结构化字段；④ 当且仅当作用于可恢复项集合时必需 | `P0-3` `P0-4` `P0-5` | ①②③：**构造器非可选参数**（缺项编译不过）；④：**类型区分**（见 §7.1）+ 三条文案的 `AtlasAppUITests` 渲染断言 |
| **I-5** | 任何系统级授权请求前，app 内必须已有作用域说明 | `P1-3` | **已降级**（见 §7.1）：模型单测断言「发起扫描的调用路径必然先写入 preamble 状态」+ **人工验收项** |
| **I-6** | 任何 `isSnoozeable: false` 的横幅必须能一句话说明「现在不做会失去什么」 | `P1-1` | `OverviewRecommendation` 单测：断言不可忽略的 `BannerConfig` 后果字段非空 |
| **I-7** | 同一屏内，**两个不同动作**的可交互控件不得共用同一可见标签 | `P2-2` | `AtlasAppUITests`：枚举该屏容器内的**可交互**控件（Button / Link / DisclosureGroup）标签，断言无重复；**纯分类标签（`AtlasMetricCard` / `AtlasStatusChip` / 阶段条）不计入** |
| **I-8** | 同一计数在相邻两处不得给出相反结论 | `P1-4` | **拆两个载体**：**模型单测**断言两处渲染同源于一个值（口径是否一致是**模型层**事实，UI 层读不到）；`AtlasAppUITests` 只断言两个文案键在相邻两处**仍都渲染** |
| **I-9** | 被截断的列表必须同屏说明截断 | `P2-14` | `AtlasAppUITests`：`taskRuns.count > 5` 时断言存在「还有 N 条」 |
| **I-10** | 估算值与实测值不得在同一事实组内等权渲染 | `P2-6` | `AtlasAppUITests`：断言估算值渲染在**独立分组容器**内（该容器须投放稳定 `accessibilityIdentifier`，见契约五 §5.2 第 3 条）**且不属于实测事实组** |
| **I-11** | 每个路由至少两条可达路径（菜单/键盘 至少其一 + UI） | `P1-18` | **路由遍历单测**（落点见 §7.1）：`AtlasRoute.allCases` 每个 case 满足「在 `sidebarRoutes` 中 ∨ `shortcutKey` 非空」——**三个前置依赖见 §7.1，缺第一个编不过、缺第二个崩测试进程** |
| **I-12** | 任何渲染出的徽章/标签必须有对应动作，或明确说明其只是分类 | `P2-4` `P2-9` `P2-16` | `AtlasAppUITests` + strings 文案断言 |

> **I-11 是本规格最重要的一条。** `REQ-ui-ux-overhaul` P1-3 把「⌘, 打开 Settings」标为 DONE 却没交付——规格只写"应该怎样"就会重蹈覆辙，写成不变量才能挂守卫。仓库已有 `testPrimaryRoutesMatchFrozenMVP`、对比度门禁这类先例。

### 7.1 两条守卫的前置依赖与降级

**I-11 的三个前置依赖，缺一则守卫不可用：**

1. **访问级别（编不过）**：`shortcutKey` 声明在 `private extension AtlasRoute`（`AtlasAppCommands.swift:86`）内。Swift 中文件级 `private` 对 extension 成员等价于 `fileprivate`，而 `@testable import` **只放开 `internal`**——不先把它提到 `internal`，守卫**根本编不过**（`inaccessible due to 'fileprivate' protection level`）。
2. **崩溃点（不是断言失败）**：`shortcutKey` 现对 `.settings / .about` 走 `preconditionFailure("Non-sidebar routes have no shortcut key")`（`AtlasAppCommands.swift:101-102`）。直接遍历 `allCases` 调用它会**崩掉测试进程**——必须先改为返回 `KeyEquivalent?`。**这正是 §6.2(1) 已标为 CONTRACT 的那处改动**；守卫依赖它先落地，实现顺序不可颠倒。
3. **断言对象**：是 `AtlasRoute.sidebarRoutes`（`AtlasDomain.swift:132` 的静态属性），**不是 `CommandMenu`**——后者是 SwiftUI View body，不可枚举。菜单本体就是 `ForEach(AtlasRoute.sidebarRoutes)` 生成的（`AtlasAppCommands.swift:15`），故二者等价。

**守卫落点（不可写错）**：放在 `Apps/AtlasApp/Tests/AtlasAppTests/`（`@testable import AtlasApp`），**不是** `Packages/AtlasDomain/Tests/`。理由是它断言的是 **app 层**菜单/快捷键与路由的对应关系，而 `shortcutKey` 与 `CommandMenu` 都定义在 `Apps/AtlasApp/`。放错包会导致 §9 Wave 2 的验证命令**漏跑它**（覆盖该目标的只有 `swift test --package-path Apps`）。

**I-5 降级说明**：原守卫写作「断言 TCC 触发前已渲染前置说明」。TCC 对话框由**系统进程**弹出，单测观测不到「触发前」，XCUITest 也控制不了系统对话框时序——该断言在任何层级都不可执行。现拆为两半：

- **可自动化的那一半**：模型单测断言「凡是能发起扫描的调用路径，必然先写入 preamble 状态」。
- **不可自动化的那一半**：真实时序（系统弹窗出现时 app 内已渲染说明）列入 `macos-gui-acceptance` 的**人工验收项**，不冒充自动化覆盖。

**I-4 的 ④ 不是 optionality**：「当且仅当作用于可恢复项集合时必需」是条件性要求，`String?` 与 required init 都表达不了。需按动作类型分两个构造——`.recoverable(...)`（含 ④）与 `.plain(...)`（不含）——由**类型**而非评审来保证。

---

## 8. 逐条映射表

审计 **40 条**（39 条原始 + 1 条二次核验补报 `NEW-1`），全部有归属，无漏项。

| 契约 | 条目 | 数 |
|---|---|---|
| 一 · 操作结果 | `P0-1` `P0-2` `P1-8` `P1-11` `P1-14` `P1-17` + **`NEW-1`** | 7 |
| 二 · 破坏性确认四问 | `P0-3` `P0-4` `P0-5` `P1-10` | 4 |
| 三 · 权限分级索取 | `P1-1` `P1-2` `P1-3` `P1-5` `P1-6` `P2-8` | 6 |
| 四 · 术语体系 | `P1-4` `P1-13` `P1-15` `P2-1` `P2-2` `P2-3` `P2-4` `P2-5` | 8 |
| 五 · 状态可见性 | `P1-9` `P1-12` `P1-16` `P2-6` `P2-7` `P2-10` `P2-11` `P2-13` `P2-14` `P2-15` `P2-16` | 11 |
| 六 · 入口可达性 | `P1-7` `P1-18` `P2-9` `P2-12` | 4 |
| | **合计** | **40** |

**勾稽**：审计 P2 的 `P2-5`（`language.*` 零引用）归契约四；审计「已跟踪不重复报」的 `ATL-271`（Ledger 导出不遵循筛选芯片）与 `ATL-272`（6 条 `history.*` 孤儿键）**不在本规格覆盖范围**，保持 Backlog 跟踪。

---

## 9. 三波交付与依赖

| 波次 | 内容 | 前置 | 治理动作 |
|---|---|---|---|
| **Wave 0** | 契约四 术语基线**定稿**（决策，无代码）。**定稿范围 = 全规格涉及的全部新词与拆词**，不只 §4.1 现有 10 词的 zh 对照——还须含 `P1-15` 拆「已归档」所需的 `Expired` / `Archived`、「已结束（失败/取消）」、`P1-13` 的「可重试」、`P2-3` 的量词分离。**范围不足则 Wave 2 的 P1 改词无词可用，会逼实现者就地自造词——那就绕过了本契约的 CONTRACT 签字** | — | **产品负责人签字**（CONTRACT） |
| **Wave 1**（P0） | 契约四**实现**（P0 文案所需词汇）· 契约一全量 · 契约二全量 · 契约三的 (1)(2)(3) · **守卫基座**（见纪律 4：UI 状态注入、标识投放） | **Wave 0 阻塞此波** —— P0 三条弹窗文案要用定稿词汇 | `AtlasAppModel` 公开 API 变更，同步 `AppShellView` 调用点与测试 fixture。门禁的 `NOT RUN` 失败断言已于 2026-09-14 独立完成，**不在本波范围** |
| **Wave 2**（P1） | 契约三余项（`P1-5` `P1-6` `P2-8`）· 契约六的 `P1-7` `P1-18` · 契约四的 `P1-4` `P1-13` `P1-15` · 契约五的 `P1-9` `P1-12` `P1-16` | — | `P1-18` 触 `AtlasAppCommands`，属 CONTRACT，需签字 |
| **Wave 3**（P2） | 契约五余项（P2 层）· 契约六余项 · 契约四余项（P2 层改词 + 双语术语表回写 + **产品内术语入口**） | — | — |

**四条波次纪律**（四条都不得违反）：

1. **契约一与契约二各自作为原子变更整波交付，不按 P 级拆分。** 契约一的 P1 条目（`P1-8` `P1-11` `P1-14` `P1-17`）与它的 P0 条目共用同一次模型变更——拆开就要把 `AtlasActionOutcome` 做两遍。同理，契约二的四问约束是**组件 API 层面的非可选字段**，无法只对其中三条生效。
2. **Wave 0 只产出决策，不产出代码。** 契约四的实现分布在 Wave 1（P0 所需）与 Wave 3（P2 层）。
3. **契约五按 P 级拆分，且不构成原子变更。** 它的 P1 条目（`P1-9` `P1-12` `P1-16`）在 **Wave 2** 交付，P2 条目留 Wave 3——与契约一/二不同（那两者的 P1 条目必须与其 P0 条目同批，见第 1 条）。此拆分是刻意决定：`P1-9`（执行中无进度）属破坏性操作进行中的信息缺失，不得排至最后一波。
4. **每波交付物必须含该波不变量所需的「守卫基座」——缺则不构成覆盖。** 守卫基座指让守卫真能跑起来的基础设施：**UI 测试的状态注入能力**（经 `ATLAS_STATE_FILE` 预置快照，现仅冷启动空状态一种）、**Feature 包内的 `accessibilityIdentifier` 投放**（现全仓仅 30 处，`AtlasDesignSystem` 组件零投放）、**`AtlasAppUITests` 内的新用例**（现 4 个，无一对应 §7）。**基座缺失时，该不变量在本波记 `NOT RUN`，不得报 `Pass`**——不得用「守卫写了但跑不了」冒充覆盖。详见 §7 的三条通道表。

**关键路径风险**：Wave 0 是 CONTRACT 级且阻塞 Wave 1。Calm Ledger 先例的处理是在 `REQ` 里立 `## Contract Unfreeze Record` 显式记录解冻理由与批准。**这意味着规格通过后、Wave 1 开工前，产品负责人会被要求做一次正式签字。**

**验证**：每波收口跑

```bash
swift test --package-path Packages
swift test --package-path Apps
./scripts/atlas/run-ui-automation.sh     # XCUITest —— swift test 跑不到 UI 层守卫
```

契约一/二/五的 UI 断言与 I-1..I-12 逐步补齐；I-7 等 AX 层不变量委派 `macos-gui-acceptance`。

> **第三条命令不可省。** §7 里 7 条不变量（I-2 / I-3 / I-7 / I-8 / I-9 / I-10 / I-12）的守卫载体是 `AtlasAppUITests`，I-4 的渲染断言亦在其上——而前两条 `swift test` 命令按构造不执行 XCUITest。漏掉它，这些守卫会「写了但永不执行」，波次验证仍报绿。
>
> **⚠️ 但 `run-ui-automation.sh` 本身会「假绿」。** 它前置检查当前进程的 AX 授权（`ui-automation-preflight.sh`），**未授权时打印 `Skipping native UI automation` 并 `exit 0`**（`run-ui-automation.sh:8-11`）——即**跑零个测试也报成功**。在未授权的机器（新机默认态、多数 CI）上，上面 6 条守卫会全部静默跳过，而门禁照常放行。
>
> 故本规格规定：**`Skipped` 计为 `NOT RUN`，不计为 `Pass`；波次不得在 `NOT RUN` 状态下收口。**
>
> **且「判 `NOT RUN`」必须是一条会失败的断言，不能靠人读输出。** 现状是 `full-acceptance.sh:14` 把该脚本的 `exit 0` 当成功、其 `:18-33` 的失败分类逻辑永远到不了；而 `tee` 下来的 log 又在 `run-ui-automation.sh:26-27` 的 `trap … EXIT` 里被删，**事后无从查证**。因此：
>
> 1. **门禁默认行为 = 失败。** `full-acceptance.sh` 在 UI 自动化步骤之后**断言** log 中不含 `Skipping native UI automation`；含则 `exit 1`，报「UI 守卫未执行（`NOT RUN`）」，**不得计入通过**。
> 2. **豁免必须是显式 opt-in。** 本地开发机确知无 AX 授权时，用显式环境变量（如 `ATLAS_ALLOW_UI_SKIP=1`）跳过该断言。**默认值不是豁免**——静默跳过的路径必须消失。
> 3. 该改动属**守卫基座**（见 §9 波次纪律第 4 条）。**已于 2026-09-14 实现**——早于 Wave 1，作为门禁基础设施的独立修复。实现同时补上原缺口：失败时把 log 留存在 `${TMPDIR}/atlas-ui-automation-NOT-RUN.log`（原先 log 随 `trap … RETURN` 被删，**事后无从查证**）。**Wave 1 不再重复此项。**
>
> 需要权威结果时也可绕过 preflight 直连：
>
> ```bash
> xcodegen generate && xcodebuild test -project Atlas.xcodeproj -scheme AtlasApp \
>   -destination 'platform=macOS' -only-testing:AtlasAppUITests
> ```

---

## 附录 A —— 对上游审计的引用更正

对 `UX-Friction-Audit-2026-09-14.md` 做逐引用回源核验（抽验 44 处）。**审计质量高：4 处引用需更正，另 1 条漏报、1 处证据强度修正**：

| # | 条目 | 审计原文 | 实际 |
|---|---|---|---|
| 1 | `P1-15` | 两处 `return .archived` 在「**同一段 switch** 里」 | **不成立**——分属两个重载：`status(for run: TaskRun)` @ `LedgerTimelineView.swift:156`、`status(for item: RecoveryItem, now: Date)` @ `:167`。**问题实质仍成立**（「已归档」一词兼指两个状态），但措辞不可照抄 |
| 2 | `P1-12` | 渲染点 `FileOrganizerSupportViews.swift:227-238` | 实际块为 `:227-239`（闭括号在 239）。标题与 `defaultExpanded: false` 在 `:229-230`，相对位置一致 |
| 3 | `P2-11` | 「两个数字来自不同口径（`AtlasAppModel.swift:777,783`）」 | `:777`/`:783` 是**同一函数的两行**，只产出 `recordedLeftoverItems` 一个口径。另一口径实际在 `:1526` `refreshedLeftoverItems`。结论成立，**引用只能支撑一半** |
| 4 | `P2-13` | `:14-49` 首屏是「开发者卡与两张二维码卡」 | `:14-49` 内是开发者卡（`:14-40`）；二维码卡在 `SocialGrid()`（`:42` 调用，定义自 `:92`）。**部分证实** |

**漏报 1 条**：受限模式的非阻断软提示被渲染成 `AtlasErrorState` 的失败标题（详见 §1.1 `NEW-1`）。审计 `P1-3` 曾把这句文案当作「铺垫」正面引用。

**证据强度修正 1 处**：`P2-8` 以「FO 包内 `permission\|权限` 零命中」作证——对照组 SmartClean 包内**同样为 0**，故该 zero-hit 单独不构成证据。应改用接线对比（详见 §3.1）。

**状态**：上述 6 项（4 处引用更正 + 1 条漏报 + 1 处证据强度修正）已于 2026-09-14 回写 `UX-Friction-Audit-2026-09-14.md`——正文就地更正，并在该文档文末「二次核验」一节留痕。两份文档的引用现已一致。

---

## 附录 B —— 明确不做

- 全局 Toast 作为失败反馈载体（契约一 §1.3）
- 新增受限模式的领域概念（契约三 §3.3）
- 统一工作面与台账面的措辞风格（契约二 §2.3）
- 重复文件做真·内容比对（契约六 §6.2）
- 密度模式 / 高级详情开关等渐进披露（契约五 §5.3）
- 新增路由（契约六 §6.3）
- `ATL-271` / `ATL-272`（保持 Backlog 跟踪）
- 修改设计系统既有 token
- 引入第三方依赖
