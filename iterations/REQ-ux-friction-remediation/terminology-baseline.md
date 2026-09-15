# Wave 0 — 契约四术语基线（已签字 2026-09-14）

- **日期**：2026-09-14
- **状态**：**已签字通过（2026-09-14）**，准予开 Wave 1。签字记录见 `requirement.md` 的 `## Contract Unfreeze Record` § 签字记录 1。**R-1–R-6 的逐项裁定亦已记录在该处**
- **上位**：`Docs/design/2026-09-14-ux-friction-remediation.md` §4（契约四）+ §9 Wave 0 行
- **定稿范围**（§9 Wave 0 原句）：**全规格涉及的全部新词与拆词** —— 不只 §4.1 现有 10 词的 zh 对照，还须含 `P1-15` 拆「已归档」所需的 `Expired` / `Archived`、「已结束（失败/取消）」、`P1-13` 的「可重试」、`P2-3` 的量词分离
- **治理级别**：**CONTRACT**。解冻记录落 `iterations/REQ-ux-friction-remediation/requirement.md` 的 `## Contract Unfreeze Record`

## 0. 本文的地位

本文是 **Wave 0 的决策产物**（决策，无代码）。落地分布：

| 波次 | 消费本文的哪部分 |
|---|---|
| Wave 1 | §3 全部（P0 三条弹窗 + 契约一/三的反馈措辞） |
| Wave 2 | §2 的 **S-1 / S-5 / S-6 / S-7 / S-8**（对应 §9 Wave 2 的 `P1-15` `P1-13` `P1-4` `P1-5`）+ **S-2 的量词规则**（S-6 的定稿措辞已按该规则书写，故 Wave 2 即须遵守） |
| Wave 3 | §2 的 **S-2 其余落点 / S-3 / S-4 / S-9 / S-10**（`P2-3` `P2-2` `P2-4` `P2-5` `P2-1` 均为 P2 层）+ §4 对齐清单 + 回写 `Docs/COPY_GUIDELINES.md` §Glossary |

> **波次归属以 §9 为准**：Wave 2 的契约四条只有 `P1-4` `P1-13` `P1-15` 三条；契约四的 P2 条目（`P2-1`..`P2-5`）全部在 Wave 3。S-2 是唯一跨波的——**规则**在 Wave 2 生效（因为 S-6 改的就是它管的那些计数），**其余落点**随 `P2-3` 在 Wave 3 收口。

**不双写**：Wave 3 回写完成后，`Docs/COPY_GUIDELINES.md` §Glossary 是术语真相源，本文转为 Wave 0 决策记录。Wave 0～2 期间以本文为准。

**本文只定词与措辞，不写实现**。每条结论都给了 `文件:行号` 或 strings key 作为落点。

---

## 1. 核心术语表（zh/en 双语）

现有 `Docs/COPY_GUIDELINES.md` §Glossary（`:35-48`）为 **en 单语**：12 条 bullet = 规格 §4.1 所称的 10 个单词术语 + 2 组复合术语（`Cleanup Plan / Uninstall Plan`、`Run Plan / Run Uninstall`）。本节扩为**双语 19 条**（上表 T-03 / T-05 即那两组复合术语），其中 4 个体系词（`残留` / `足迹` / `台账` / `证据`）**保留用词、补解释**（§4.2(2) 的裁定）。

「现状」列 = 当前产品内实际渲染值（已逐 key 回源）。

| ID | en | **zh（定稿）** | 现状 | 处理 |
|---|---|---|---|---|
| T-01 | Scan | 扫描 | 一致（`smartclean.stage.scan`） | 保留 |
| T-02 | Plan | 计划 | 一致（`smartclean.stage.plan.number` =「计划 №%d」） | 保留 |
| T-03 | Cleanup Plan / Uninstall Plan | 清理计划 / 卸载计划 | 一致 | 保留 |
| T-04 | Review | 复核 | 一致（`smartclean.stage.review`） | 保留；**不得被风险 chip 占用**（见 S-3） |
| T-05 | Run Plan / Run Uninstall | 执行清理计划 / 执行卸载 | 一致 | 保留 |
| T-06 | Reclaimable Space | 预计可释放空间 | 一致（`overview.metric.reclaimable.title`） | 保留；估算值须与实测分流（契约五） |
| T-07 | Recoverable | 可恢复 | 一致（`ledger.recovery.badge.available`） | 保留 |
| T-08 | Restore point | 恢复点 | 一致（`ledger.stamp.title`） | 保留 |
| T-09 | Retention window | 保留窗口 | 一致（渲染为「保留 %d 天」） | 保留 |
| T-10 | Ledger | **台账** | 一致（`route.ledger.title`） | **保留 —— D-012 不重开，见 §5** |
| T-11 | Scan Receipt | 扫描回执 | 一致（`smartclean.receipt.code.label`） | 保留 |
| T-12 | App Footprint | **应用足迹** | 「总应用占用」/「应用占用」/「残留足迹」**三值并存** | **R-2 已裁定：对齐**（§4-A-1，Wave 3 落地） |
| T-13 | Leftover Files | 残留文件 | 一致（`apps.metric.leftovers.title`） | 保留；体系词，补解释 |
| T-14 | Evidence | 证据 | 一致（`fileorganizer.evidence.open` =「查看证据」） | 保留；体系词，补解释 |
| T-15 | Limited Mode | 受限模式 | 一致（`permissions.callout.limited.title`） | 保留 |
| T-16 | Full Disk Access | 完全磁盘访问 | 一致 | 保留（macOS 系统名，不译） |
| T-17 | Accessibility | 辅助功能 | 一致 | 保留（macOS 系统名，不译） |
| T-18 | Notifications | 通知 | 一致 | 保留（macOS 系统名，不译） |
| T-19 | Destination | 目标位置 | 「目标位置」/「整理目标」并存 | 见注 |

> **T-19 注**：`fileorganizer.preview.row.to` =「目标位置」用于渲染**具体路径值**（P0-4 弹窗必须用它）；`fileorganizer.destination.title` =「整理目标」保留为**配置区标题**。两者语法角色不同，不算撞名。

---

## 2. 拆词与改词决定（S 系列）

### S-1 「已归档」拆词（`P1-15`）

**问题**：`ds.ledger.status.archived`（zh「已归档」/ en `Archived`）**一个词兼指两个状态**——`LedgerTimelineView.swift:162-163` 的 `.failed/.cancelled` 与 `:171-172` 的恢复项过期。用户读「已归档」＝「已安全保存」，实为**不可恢复的终态**。

**裁定**：拆为两条，一词一义。

| 语义 | **zh** | **en** | 落点 |
|---|---|---|---|
| 恢复项已过保留窗口，**不可恢复** | **已过期** | `Expired` | `ds.ledger.status.expired`（**新增**）；复用既有 `ledger.recovery.badge.expired` / `ledger.export.entry.status.expired` 的既有译法 |
| 任务运行失败/取消后的**终态** | **已结束** | `Archived` | `ds.ledger.status.archived`（**改值**；键名保留，内部标识不对用户可见） |

**连带改名**：`ledger.filter.archive`（zh「归档」/ en `Archive`）的判据是 `item.isExpired`（`LedgerFeatureView.swift:336`）——它筛的就是过期项。改为 **zh「已过期」/ en `Expired`**。

**保留不动**：`ledger.archive.section.older`（「更早归档」/ `Older Archive`）与 `ledger.archive.hint` 保留——「归档」在**区域/历史名词**角色下不与状态词冲突（拆词拆的是状态词）。

> ✅ **R-1 已裁定（2026-09-14）**：**照规格用 `Archived`**。en 侧 `Archived` ↔ zh「已结束」不是字面对译，已由产品负责人确认接受（§9 Wave 0 行把 `Expired` / `Archived` 列为所需 en 词）。

### S-2 量词分离（`P2-3`）

**问题**：权限语境与文件语境共用「项」（zh:646 / zh:1003），中文无单复数，字形完全相同。

**裁定（规则）**：
- **权限语境**：一律「**个**」+ 显式出现名词语素「**权限**」
- **文件/发现/记录语境**：一律「**项**」+ 显式出现名词语素

**落点**（已回源）：
- `permissions.optionalSection.count.one` / `.other`：「%d 项待处理」→ **「%d 个权限可稍后授权」**（措辞与 S-6 统一）
- `permissions.next.ready.detail`：「当前已具备 %d/%d 项跟踪权限」→ **「当前已具备 %d/%d 个跟踪权限」**
- 保持不变：`smartclean.summary.findingCount`（「%d 个发现项」，zh:421 → 文件语境用「项」）、`fileorganizer.selection.count`（「已选 %d / %d 项」）、`overview.capsule.recovery`（「可恢复 %d 项」）、`sidebar.ledger.dynamic`、`sidebar.smartclean.dynamic`

### S-3 同屏同名消歧（`P2-2`）

**问题**：Smart Clean ② 同屏渲染阶段条第二段「复核」（`smartclean.stage.review`，`SmartCleanSupportViews.swift:48`）与风险筛选 chip「复核」（`risk.review`，zh:25）。**en 侧同样撞名**（`smartclean.stage.review` = `"Review"`，`risk.review` = `"Review"`，en:24-26）——故 zh/en 都必须改，只改一侧不够。

**裁定**：改**风险 chip**，阶段条不动（`Review` = 复核 是术语表 T-04 的定义，阶段条是它的主场）。

| key | zh 现状 → 定稿 | en 现状 → 定稿 |
|---|---|---|
| `risk.review` | 复核 → **待复核** | `Review` → **`Needs Review`** |
| `smartclean.stage.review` | 复核（不动） | `Review`（不动） |

`risk.safe`（安全/`Safe`）、`risk.advanced`（高级/`Advanced`）不动。

> ✅ **R-3 已裁定（2026-09-14）**：采纳默认——**改风险 chip**，阶段条不动。

### S-4 译错修正（`P2-4`）

**问题**：`evidence.safety.conditional` en = `Conditional`（形容词，风险等级），zh 译成「需确认」（动作）。这不是设计选择，是译错。

**裁定**：zh **「需确认」→「有条件」**；en `Conditional` 不变。同族 `evidence.safety.safe`（安全）、`evidence.safety.protected`（受保护）不动。

### S-5 冲突口径统一（`P1-13`）

**问题**：同一件「冲突」在 FO 三个位置给出三种后果暗示。

**先定事实**（已回源 `AtlasScaffoldWorkerService.swift:777-795`）：worker 遇到目标位置同名文件时**自动重命名**（`name (1).ext`，循环避让），**不覆盖、不跳过**。`failedMoves` 只收真失败（源不存在 / 路径非法 / 目标在家目录外 / move 抛错），**与冲突无关**。

**裁定（唯一口径）**：

> **同名冲突 → 自动重命名，不覆盖；未勾选的文件留在原位置。**

| key | 现状 | 定稿 |
|---|---|---|
| `fileorganizer.conflict.exists` | 「目标位置已存在同名文件：%@」（听感＝会覆盖） | **「目标位置已有同名文件；执行时会自动重命名，不会覆盖：%@」** |
| `fileorganizer.conflict.callout.detail` | 「执行时将自动重命名冲突文件（如 filename (1).png）。取消选中可跳过这些文件。」 | **保留**（与判定一致） |
| `fileorganizer.receipt.failed.value` | 「%d 项失败（可重试）」（听感＝失败了且无处重试） | 见 S-7 |

en 对应：`conflict.exists` → `"A file with the same name is already at the destination; it will be renamed automatically — nothing is overwritten: %@"`

### S-6 权限计数口径统一（`P1-4`）

**问题**：概览卡标题「暂不需要」配缺失计数（`PermissionsFeatureView.swift:81-82`），同一批权限在下方列表叫「%d 项待处理」——两处**结论相反**。

**裁定**：两处收敛到**同一措辞**，且都用既有规范词 `permissions.status.optional` =「可稍后授权」。

| key | 现状 | 定稿 |
|---|---|---|
| `permissions.metric.later.title` | 「暂不需要」 | **「可稍后授权」**（值渲染为「%d 个」） |
| `permissions.optionalSection.count.one/.other` | 「%d 项待处理」 | **「%d 个权限可稍后授权」** |
| `permissions.metric.later.detail` | 「这些权限暂未授予也不会让 Atlas 进入受限模式…」 | 保留 |

两处必须同源于同一个 `optionalMissingCount`（I-8 的模型单测断言这一点）。

### S-7 「可重试」处置（`P1-13` 第三处）

§4.2(1) 规定：「可重试」**在回执上必须有对应入口，否则删去该措辞**。

**裁定（推荐）**：**删去**。`fileorganizer.receipt.failed.value`：「%d 项失败（可重试）」→ **「%d 项仍留在原位置」**；en → `"%d still in their original location"`。

理由：回执上没有重试入口（`fileorganizer.receipt.*` 无该控件）；补一个可达的重试入口是**新能力**，不在契约二/六的条款内（附录 B 精神）。

> ✅ **R-4 已裁定（2026-09-14）**：**删去「可重试」**，不补重试入口。

### S-8 去技术黑话（`P1-5`）

**问题**：权限行副标题直接暴露 `Library` 与「系统级缓存」。

**裁定**：`Library` → **「系统受保护的位置」**；「系统级缓存」→ **「系统自动生成的缓存」**。落点（两处都必须改，见 §4-A-3）：

- `infrastructure.permission.fullDiskAccess.needed`（运行时真实取数，`AtlasPermissionInspector.swift:95-99`）
- `fixture.permission.fullDiskAccess.rationale`（空状态脚手架路径，`AtlasApplication.swift:123` → `AtlasScaffoldFixtures`）
- `permissions.support.fullDiskAccess`（「下一步」卡片）
- `permissions.evidence.scope.fullDiskAccess`（三段式证据「影响范围」）

三段式证据结构（为什么/影响范围/如何授权）**保留**。

### S-9 语言名（`P2-5`）

非术语问题，但需一并定稿：`AtlasLanguage.displayName`（`AtlasLocalization.swift:24-31`）硬编码返回中文、绕过 `AtlasL10n`。**改走 `AtlasL10n`，启用两个零引用 key**（`language.zhHans` / `language.en`，zh:2-3 ｜ en:2-3）。两文件的值已存在且正确（en 文件里 `language.zhHans` = `"Simplified Chinese"`），**无需新词**。

### S-10 体系词解释（`P2-1`）

四个体系词**保留**，补产品内解释（Wave 3 建入口）。定稿解释如下——Wave 3 **不得就地自造**：

| 词 | zh 解释（定稿） | en | en 解释（定稿） |
|---|---|---|---|
| 残留 | 卸载或清理后仍留在磁盘上的配置文件、缓存和启动项。 | Leftover files | Support files, caches, and launch items left behind after an uninstall or cleanup. |
| 足迹 | 一个应用当前在磁盘上占用的全部空间。 | App footprint | All the disk space an app currently takes up. |
| 台账 | Atlas 自己保存的操作记录，也是恢复入口。 | Ledger | Atlas's own record of what ran, and the place you restore from. |
| 证据 | Atlas 扫到、但本次不会移除的清单。 | Evidence | What Atlas found. Listing it does not remove it. |

> S-10 的定义**只定稿文字**；「首次遇见解释 / 可查术语表」两个载体在 Wave 3 实现（§4.2(2)）。

---

## 3. 新词与定稿措辞（Wave 1 起各波消费）

以下均为**规格已在契约条款里要求、但产品内尚无对应词**的项。定稿在此，实现者不得自造。

| ID | 来源条款 | zh（定稿） | en（定稿） | 说明 |
|---|---|---|---|---|
| N-1 | 契约三 (1) `P1-1` | 按钮「**稍后再说**」；说明「**现在不做也能用。受限模式下扫描与清理照常运行，只是范围更小。**」 | `Not now` / "You can keep using Atlas without it. In limited mode, scans and cleanups still run — just over a smaller scope." | 复用既有 snooze 机制（`OverviewSnoozeStore`，7 天）；**不得**承诺受限模式能完成需要完全磁盘访问的工作（§3.3） |
| N-2 | 契约三 (3) `P1-3` | 「**下一步 macOS 会弹窗询问 Atlas 是否可以读取这个文件夹。这是系统的隐私保护，不是 Atlas 在索取额外权限；你现在可以选「不允许」，之后随时可以再授权。**」 | "macOS will now ask whether Atlas can read this folder. That's the system's privacy protection, not Atlas asking for extra access. You can choose “Don’t Allow” now and grant it later." | **必须在系统弹窗之前**已渲染（I-5 的可自动化那一半断言此路径） |
| N-3 | 契约一 §1.2(2) | 禁用理由「**本次没有可恢复的项目**」；动作类型不适用时的缺席说明「**这类操作不产生可恢复内容**」 | "Nothing from this run can be restored" / "This kind of action has nothing to restore" | 三态：`.available` / `.unavailable(reason)`（**默认态**）/ 不存在（**仅动作类型不适用**） |
| N-4 | 契约一 §1.2(3) | 「**本次未生成回执**」+「**已选 %d 项 · 处理结果无法确认**」⚠️**已修订，待追认** | "No receipt was created for this run" + "%d processed · %d not processed" | 禁止渲染点了不动的控件 |
| N-5 | 契约一 §1.2(4) | 磁盘还原「**已还原到原位置**」；仅状态还原「**已在 Atlas 中恢复 · 文件未被移动**」 | "Restored to the original location" / "Restored in Atlas · no files were moved" | 沿用台账侧既有对：`ledger.restore.action`「恢复」/ `ledger.restore.action.stateOnly`「在 Atlas 中恢复」；**必须映射到不同的 `kind` 或 `recovery` 载荷**，不能只换文案 |
| N-6 | 契约二 §2.2(1) 四问 | ①「**将移除 %@**」/「**将移动 %d 个文件**」②「**移动到：%@**」③「**可在 %d 天内从台账恢复到原位置**」④「**%d/%d 项可恢复**」 | "This removes %@" / "This moves %d files"; "Moves to: %@"; "Restorable from the Ledger for %d days"; "%d of %d items recoverable" | ④ 与既有 promise 行同形（实测 `22/23 项可恢复 · 保留 7 天 · 全程录入台账`）；④ 由**类型**（`.recoverable(...)` / `.plain(...)`）决定是否必需 |
| N-7 | 契约五 `P2-7` | 「**未勾选的文件留在原位置**」 | "Files you leave unchecked stay in place" | 显式表达选择模型 |
| N-8 | 契约五 `P2-14` | 「**还有 %d 条**」 | "%d more" | 截断说明 |
| N-9 | 契约六 `P2-9` | 「**同名同大小**」（替代「重复文件」） | `Same name & size`（替代 `Duplicate`） | 诚实改名（推荐案）；须同时提供筛选/聚合入口或明确标注为纯分类（I-12） |
| N-10 | 契约五 `P2-10` | 不预设选中；若保留示例选中，标注「**示例**」 | "Example" | 与列表副标题「选择一个应用」的承诺一致 |

---

## 4. 落点对齐清单

### 4-A 现存渲染需随本文对齐处

| # | key / 位置 | 现状 | 对齐为 | 波次 |
|---|---|---|---|---|
| A-1 | `apps.metric.footprint.title`、`apps.list.title`、`apps.detail.size` | 「总应用占用」/「已安装应用占用」/「应用占用」 | 与 T-12 一致：**「总应用足迹」/「已安装应用足迹」/「应用足迹」**（**R-2 已裁定**） | Wave 3 |
| A-2 | `ledger.filter.archive` | 「归档」/`Archive` | 「已过期」/`Expired`（S-1） | Wave 2 |
| A-3 | 见 S-8 四个 key | 含 `Library` /「系统级缓存」 | 见 S-8 | Wave 2 |
| A-4 | `permissions.metric.later.title`、`permissions.optionalSection.count.*`、`permissions.next.ready.detail` | 见 S-2 / S-6 | 见 S-2 / S-6 | Wave 2 |
| A-5 | `risk.review` | 「复核」/`Review` | 「待复核」/`Needs Review`（S-3，属 `P2-2`） | Wave 3 |
| A-6 | `evidence.safety.conditional` | 「需确认」 | 「有条件」（S-4） | Wave 3 |
| A-7 | `fileorganizer.conflict.exists`、`fileorganizer.receipt.failed.value` | 见 S-5 / S-7 | 见 S-5 / S-7 | Wave 2 |
| A-8 | `ds.ledger.status.archived`、新增 `ds.ledger.status.expired` | 「已归档」 | 见 S-1 | Wave 2 |

**所有落点均须同时改 `en.lproj` 与 `zh-Hans.lproj`**（AGENTS.md 约定）。

### 4-B 回源核对记录（Wave 0 期间发现，**留给 Wave 2 处理，此处只报告不调和**）

- **`P1-5` 的证据落点比规格写的多一处**。规格 §3.1 引 `fixture.permission.fullDiskAccess.rationale`（zh:80）为「实机渲染原文」。回源结果：`PermissionRowView.swift:28` 绑定 `subtitle: state.rationale`，而运行时 `state.rationale` 由 `AtlasPermissionInspector.swift:95-99` 产出，取自 `infrastructure.permission.fullDiskAccess.needed`（zh:122）。**两个 key 都含 `Library`，但只有 fixture key 含「系统级缓存」**。
  `fixture.*` 并非死键——空状态脚手架 `AtlasScaffoldWorkspace.state()`（`AtlasApplication.swift:123` → `AtlasScaffoldFixtures.permissions`）会渲染它，故两处都是真实落点、都要改（已列入 A-3）。
  **不擅自归并**：此处只记录「规格引的 key ≠ 运行时取数的 key」这一事实，由 `REQ` 的 `trace.md` 记录、实现时两处都改。

---

## 5. D-012 裁定（须产品负责人显式确认）

`D-012` 是「`历史` → `台账`」的改名决定，规格 §0.3 列为**可能被契约四重开**、**不得由 agent 自主合入**的项。

**本基线按 §4.2(2) 的明文裁定：`台账` 保留（T-10），D-012 不重开。** 契约四对台账面做的是**拆词与补解释**（S-1 / S-10），不是改名。

请产品负责人在签字时**显式确认此项**——这是 §0.3 要求的人工确认点，agent 不代答。

---

## 6. 开放项汇总（签字时逐项裁决）

| ID | 开放项 | 推荐 | **产品负责人裁定（2026-09-14）** |
|---|---|---|---|
| **R-1** | S-1 的 en 词：`Archived` ↔「已结束」不是字面对译 | 照规格用 `Archived` | **照规格用 `Archived`** ✅ |
| **R-2** | T-12 是否把「总应用占用」等一律对齐为「应用足迹」 | 对齐 | **对齐为「应用足迹」** ✅（Wave 3 落地） |
| **R-3** | S-3 消歧方向 | 改 chip | **改 chip** ✅（Wave 3 落地） |
| **R-4** | S-7 是否删去「可重试」 | 删去 | **删去** ✅（Wave 2 落地） |
| **R-5** | §5 D-012 确认 | 台账保留、不重开 | **台账保留、D-012 不重开** ✅（显式确认） |
| **R-6** | §4-B 的 `P1-5` 双落点核对 | 两处都改 | **两处都改** ✅（Wave 2 落地） |

---

## 6b. 签字后的修订（待追认）

| ID | 原定稿 | 实测修订 | 理由 |
|---|---|---|---|
| **N-4** | 「已处理 %d 项 · 未处理 %d 项」 | **「已选 %d 项 · 处理结果无法确认」**（en: `"%d selected · outcome could not be confirmed"`） | 规格 §1.2(3) 要求渲染已处理/未处理计数，但 §1.6 的 **fail-closed 红线**规定 worker 未返回就失败时不得编造处理计数。两处不能同时满足，取 fail-closed。**属对已签字基线的偏离，需产品负责人追认** |

依据：`changes/CHG-2026-09-ux-friction-wave1/verify.md` § 「一处规格与 fail-closed 红线的冲突」。

## 7. 签字

- ✅ **已签署（2026-09-14）**：`Wave 0 术语基线通过，准予开 Wave 1`
- 签字记录：`iterations/REQ-ux-friction-remediation/requirement.md` 的 `## Contract Unfreeze Record` → § 签字记录 1（含 R-1–R-6 逐项裁定与 D-012 显式确认）
- **效力**：签字后 P0 文案方可改动（`apps.confirm.uninstall.message` / `fileorganizer.confirm.execute.message` / `smartclean.confirm.execute.message`），Wave 1 开工
