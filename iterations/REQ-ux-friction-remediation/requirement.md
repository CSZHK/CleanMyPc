# REQ-ux-friction-remediation

## Title
UX 摩擦修复（Atlas for Mac）—— 6 契约 · 12 不变量 · 三波交付

## Change Class
MAJOR — 触及模型层公开 API（`AtlasAppModel`）、菜单/路由可达性（`AtlasAppCommands`）+ `AtlasRoute.sidebarRoutes` 语义、术语体系（CONTRACT），跨 6 个 feature 包 + app 壳层 + 两份 `Localizable.strings`。Wave 0 为 CONTRACT 级决策，阻塞 Wave 1。

## Status
**IN PROGRESS** — Wave 0–3 均已收口（2026-09-14 ~ 09-15），但**收口结论于 2026-09-15 复审中被判定不可采信**，回退为进行中。

- **复审发现**：至少 4 条不变量的守卫经变异检验证明「改坏产品代码仍不失败」（`I-11` / `I-8` / `I-10` / `I-5`），
  其覆盖声明不成立；另有 5 处治理记录互相矛盾。
- **处置**：修复与重验收移出本 REQ，改由补丁单承载 → `changes/CHG-2026-09-ux-friction-review-remediation/`。
- **本 REQ 的历史收口记录（`trace.md` / `changes/CHG-2026-09-ux-friction-wave*/verify.md`）原文保留、不改写**，
  仅在 `trace.md` 的 `## Close Gate` 追加失效范围标注。
- **复审证据**：完整性快照 `sha256:266c42b1a63136b7c7da9b15a46e7cbb6df926568c85ba673f45e35d4a194799`，
  审查窗口内 `review-integrity verify = clean`（无越权改动）。

## Priority
P0（阻断：Wave 0 未签字前不得改任何 P0 文案）

## Truth Sources
- 实现规格: `Docs/design/2026-09-14-ux-friction-remediation.md`（**唯一实现权威**，6 契约 / §7 12 不变量 / §8 40 条映射 / §9 三波交付 / 附录 B 不做项）
- 诊断真相源: `Docs/Execution/UX-Friction-Audit-2026-09-14.md`（40 条 = 39 原始 + 补报 `NEW-1`）
- 设计评审: `Docs/Execution/UX-Friction-Remediation-Design-Gate-Review-2026-09-14.md`（F1–F10 + L1–L3 + 5 条设计层主张已裁，`Decision = Pass`）
- 术语真相源: `iterations/REQ-ux-friction-remediation/terminology-baseline.md`（Wave 0 定稿；Wave 3 后移交 `Docs/COPY_GUIDELINES.md` §Glossary）
- 文案纪律: `Docs/COPY_GUIDELINES.md`（§Containment Rules：工作面直白动词、台账面文书语气）
- 设计语言: `Docs/design/2026-06-10-frontend-redesign-calm-ledger.md`（v3，**本 REQ 不动设计语言**）

## Description
按规格实现 40 条 finding 的修复。6 个契约：操作结果契约（结构化 `AtlasActionOutcome`）、破坏性确认四问、权限分级索取、术语体系、状态可见性、入口可达性。交付按严重度分三波，Wave 0 先定术语基线。

## Contract Unfreeze Record

解冻项（§0.3 + §9），**三项均须产品负责人签字，不得由 agent 自主合入**：

| # | 项 | 内容 | 推进状态 |
|---|---|---|---|
| 1 | **契约四 术语体系** | 重建 zh/en 术语表，可能触及路由名与 `COPY_GUIDELINES.md` | **已签字（2026-09-14）** —— `terminology-baseline.md` 通过，准予开 Wave 1。见下方签字记录 |
| 2 | **契约六 `P1-18`** | Settings 补菜单入口与 ⌘, —— 需改 `AtlasAppCommands.swift` 的 `preconditionFailure("Non-sidebar routes have no shortcut key")`（`:101-103`）并触及 `AtlasRoute.sidebarRoutes`（`AtlasDomain.swift:132`）的语义 | **已签字（2026-09-14）** —— 准予开 Wave 2，见签字记录 2 |
| 3 | **`D-012`**（`历史`→`台账`） | 契约四可能重开 | **Wave 0 一并裁决**：`terminology-baseline.md` §5 裁定「台账保留、D-012 不重开」，须显式确认 |

先例：`iterations/REQ-calm-ledger-redesign/requirement.md`。

### 签字记录 1 — 契约四术语体系（2026-09-14）

- **产品负责人裁定**：`Wave 0 术语基线通过，准予开 Wave 1`
- **对象**：`iterations/REQ-ux-friction-remediation/terminology-baseline.md`
- **一并裁决（逐项）**：

| 项 | 裁定 |
|---|---|
| **D-012** | **台账保留、D-012 不重开**（§0.3 要求的人工确认点，已显式确认） |
| R-1 | 照规格用 **`Archived`**（zh「已结束」↔ en `Archived`，非字面对译） |
| R-2 | **对齐为「应用足迹」**（`apps.metric.footprint.title` / `apps.list.title` / `apps.detail.size` 三个 key 随 Wave 3 对齐） |
| R-3 | 采纳默认：**改风险 chip**（不动阶段条），`risk.review` → 「待复核」/`Needs Review`；Wave 3 落地 |
| R-4 | **删去「可重试」** → `fileorganizer.receipt.failed.value` 改「%d 项仍留在原位置」；Wave 2 落地 |
| R-6 | 采纳默认：`P1-5` 的 `infrastructure.*` 与 `fixture.*` **两处都改**；Wave 2 落地 |

- **效力**：签字后 P0 文案方可改动，Wave 1 开工。

### 签字记录 2 — 契约六 `P1-18`（2026-09-14）

- **产品负责人裁定**：`签字，准予开 Wave 2`
- **解冻对象**：`AtlasAppCommands.swift` 的 `private extension AtlasRoute.shortcutKey`（`:86-104`）
  - 现对 `.settings / .about` 走 `preconditionFailure("Non-sidebar routes have no shortcut key")`（`:101-103`）
  - 改为返回 `KeyEquivalent?`（非 sidebar 路由返回 `nil`）
- **触及**：`AtlasRoute.sidebarRoutes`（`AtlasDomain.swift:132`）的语义 —— `I-11` 的断言对象
- **连带义务**：`I-11` 的**三个前置顺序不可颠倒**（访问级别提权 → 返回 `KeyEquivalent?` → 断言 `sidebarRoutes`）；
  守卫落点固定在 `Apps/AtlasApp/Tests/AtlasAppTests/`（放错包会让 Wave 2 的验证命令漏跑它）
- **效力**：Wave 2 开工。

### 签字记录 3 — `I-4` 的渲染断言降级（2026-09-14）

- **产品负责人裁定**：**接受现状记账**
- **对象**：`I-4` 的 ②③④ 渲染断言。实测证明在 `.confirmationDialog` 下不可达成 —— macOS 渲染成 AppKit 警报 `Sheet`，SwiftUI 的 `accessibilityIdentifier` 被系统替换（树里是 `_NS:*`），且正文只渲染第一行。
- **处置**：`I-4` 主载体按规格原文保留（**①②③ 构造器非可选** + **④ 由类型区分**，均已完成）；UI 断言降级为「弹窗打开 + ① 按文本前缀渲染」（已实测通过）；**②③④ 记 `NOT RUN`，不冒充覆盖**。
- **同族先例**：`I-5` 的真实时序降级为 `macos-gui-acceptance` 人工验收项。

> **对本 REQ 前身欠账的说明**：`iterations/REQ-ui-ux-overhaul/requirement.md` 的 P1-3 把「⌘, 打开 Settings」标为已完成（该 REQ 整体 Status = DONE）而代码中无该绑定。本 REQ 的 `I-11` 守卫兜住它，`P1-18` 为其修复切片。

## Project Constraints
- **不新增第三方依赖**（5 个 SPM 根包外部依赖数为 0，刻意约束）
- **不修改设计系统既有 token**（`AtlasColor` / `AtlasTypography` / `AtlasSpacing` / `AtlasRadius` / `AtlasElevation` / `AtlasMotion`）
- **不改 `AtlasScaffoldWorkerService` 的恢复语义与 fail-closed 判定**（规格 §1.3）
- 附录 B「明确不做」逐条不碰
- 双语言：新增文案须**同时**改 `en.lproj` 与 `zh-Hans.lproj`（`Packages/AtlasDomain/Sources/AtlasDomain/Resources/`），经 `AtlasL10n` 访问
- 改 `project.yml` 后必须重跑 `xcodegen generate`
- 两套语言模式（SPM `5.10` / Xcode `SWIFT_VERSION 6.0`）**都要能编过**

## Acceptance（取自规格 §0.2，可判定）
- 40 条 finding 全部有归属契约，无漏项（§8）
- §7 的 12 条不变量全部可判定，且**每条至少一条回归守卫**；**I-5 是唯一例外**（真实时序不可自动观测 → 模型层静态断言 + `macos-gui-acceptance` 人工验收项）
- 契约四 zh/en 术语表定稿并回写 `Docs/COPY_GUIDELINES.md`；**且产品内存在可读入口**（首次遇见解释 + 可查术语表）——只回写文档不算达标
- 破坏性确认弹窗的 ①②③ 字段**在组件 API 层面不可缺省**（缺项编译不过）；④ 由类型区分（`.recoverable(...)` / `.plain(...)`），不走 optionality
- 不新增第三方依赖；不修改设计系统既有 token

## Blast Radius
- `Apps/AtlasApp`：`AtlasAppModel`（公开 API 变更）、`AppShellView`（调用点）、`AtlasAppCommands`（CONTRACT）、`TaskCenterView`、新增 UI 测试用例
- `Packages/AtlasDomain`：L10n 键（两份 strings）、`AtlasRoute` 相关只读引用、`AtlasLocalization`
- `Packages/AtlasFeatures{Overview,SmartClean,FileOrganizer,Apps,History,Permissions,Settings,About}`：涉及 finding 的视图与模型
- `Packages/AtlasDesignSystem`：**只投放 `accessibilityIdentifier`，不动 token**
- `Apps/AtlasAppUITests`：新增守卫用例（现仅 4 个，无一对应 §7）
- 不触碰：`AtlasProtocol` / XPC / Helpers / Go / `AtlasScaffoldWorkerService` 的恢复语义与 fail-closed 判定
