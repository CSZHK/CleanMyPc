# Verify — CHG-2026-09-ux-friction-wave1

**状态：✅ 已收口（2026-09-14）。** 三条门禁零新增失败；`I-2`/`I-3` 已挂且实测通过；`I-4` 按「编译期为主载体 + 平台限制」如实记账。

## 三条门禁的实测输出

| # | 命令 | 结果 |
|---|------|------|
| 1 | `swift test --package-path Packages` | `Executed 606 tests, with 0 failures` — **PASS** |
| 2 | `swift test --package-path Apps` | `Executed 64 tests, with 0 failures` — **PASS**（基线 62；本波 +2：`I-1` 与 `I-5` 守卫） |
| 3 | `./scripts/atlas/run-ui-automation.sh` | `Executed 7 tests, with 2 failures` — **exit 1**（新增 3 条守卫用例 **3 条全绿**；2 条失败 = HEAD 基线同 2 条） |

### 第 3 条的增量门禁判定（产品负责人 2026-09-14 裁定）

| 用例 | HEAD 基线 | 本波 | 差集 |
|---|---|---|---|
| `testDefaultLanguageIsChineseAndCanSwitchToEnglish` | passed | passed | — |
| `testSidebarShowsFrozenMVPRoutes` | passed | passed | — |
| `testKeyboardShortcutsNavigateAndOpenTaskCenter` | **failed** `:75` | **failed** `:75` | 无变化（既有） |
| `testSmartCleanAndSettingsPrimaryControlsExist` | **failed** `:56` | **failed** `:56` | 无变化（既有） |
| `testSmartCleanReceiptUndoIsPresentButDisabledWithoutRestorePoint`（新增，`I-3`） | — | **passed** | 新增通过 |
| `testFileOrganizerReceiptUndoIsPresentButDisabledWithoutRecoveryItem`（新增，`I-2`） | — | **passed** | 新增通过 |
| `testDestructiveConfirmationOpensAndRendersScopeQuestion`（新增，`I-4`） | — | **passed** | 新增通过 |

**既有 2 条红的差集为空；新增 3 条用例全绿。** 第 3 条命令的 `exit 1` 完全来自基线那 2 条红（根因 `P1-18` / `shortcutKey` 期望值，均属 Wave 2）。 两条红挂账 Wave 2（根因分别为 `P1-18` 与 `shortcutKey` 期望值）。
基线取法：`git worktree add --detach <tmp> HEAD` 内跑同一条命令（本波已执行并清理）。

## 关闭的 finding（Wave 1 范围内）

| finding | 关闭依据 | 守卫 |
|---|---|---|
| `P0-1` | 台账恢复结果写进 `.ledger` 槽；`LedgerFeatureView` 新增 `restoreOutcomeBanner` 就地呈现。`AtlasAppModelTests` 中原先**钉住缺陷本身**的断言已改写 | `I-1` ✅ |
| `P0-2` | FO 回执「撤销」由无门控渲染 → `AtlasUndoAvailability` 三态（禁用 + 理由） | `I-2` ✅ |
| `P1-8` | Smart Clean 回执「撤销」由静默隐藏 → 三态（禁用 + 理由） | `I-3` ✅ |
| `P1-11` | ③ 错误态 `hasReceipt == false` 不再渲染死按钮；改为真实出口 + 「本次未生成回执」+ 最少可用信息。原断言钉住缺陷，已改写 | 动作栏单测 ✅ |
| `P1-14` | 与 `P1-11` 同构（FO） | 动作栏单测 ✅ |
| `P1-17` | 模型按 `restoreMappings` 判据产出 `recovery.scope`；台账屏按 scope 渲染两种不同表述 | 模型层 ✅ |
| `NEW-1` | `.advisory` / `.failed` 分流；受限模式软提示走 `AtlasCallout(.warning)` | 渲染断言 ⛔ NOT RUN（随 `I-4` 的同一接缝待补） |
| `P0-3` | Apps 卸载确认改 `AtlasDestructiveConfirmation`（① ② ③ 非可选 + ④ 类型区分） | `I-4` ✅ 主载体 + ⚠️ 渲染断言 NOT RUN |
| `P0-4` | FO 执行确认同上；② 把 `~/Organized` 带进弹窗 | `I-4` ✅ 主载体 + ⚠️ 同上 |
| `P0-5` | Smart Clean 执行确认同上；④ 把 promise 行的 `N/M` 带进弹窗 | `I-4` ✅ 主载体 + ⚠️ 同上 |
| `P1-10` | 空态按钮在有计划号时改「作废并重新扫描」，标签描述**对话框的后果** | `I-7`（Wave 2） |
| `P1-1` | 权限横幅 `isSnoozeable: false` → `true`，新增 `.snooze` 出口与「稍后再说」；文案说明「现在不做也能用」+ 受限范围。原断言「never snoozeable」已推翻 | `I-6` ✅ |
| `P1-2` | 首屏顺序改为「下一步」优先于问候语；接上零引用的 `overview.callout.limited.*` | — |
| `P1-3` | FO ① 首扫前渲染 `fileorganizer.scan.preamble.*`（作用域说明） | `I-5` ✅（降级形式） |

## 不变量守卫状态

| # | 载体 | 状态 |
|---|---|---|
| `I-1` | `AtlasAppModelTests.testLedgerRestoreFailureNeverWritesAnotherSourceSlot` | ✅ **已挂且实测通过** |
| `I-6` | `OverviewRecommendationTests.testRow1PermissionMissingBeatsEverything` 内新增断言 | ✅ **已挂且实测通过** |
| `I-5` | 模型单测 `testFileOrganizerScanWritesPreambleState` | ✅ 已挂且通过（**降级形式**：只覆盖可自动化的那一半；真实时序仍是 `macos-gui-acceptance` 人工验收项，**不冒充自动化覆盖**） |
| `I-2` | `AtlasAppUITests.testFileOrganizerReceiptUndoIsPresentButDisabledWithoutRecoveryItem` | ✅ **已挂且实测通过** |
| `I-3` | `AtlasAppUITests.testSmartCleanReceiptUndoIsPresentButDisabledWithoutRestorePoint` | ✅ **已挂且实测通过** |
| `I-4` | ①②③ 构造器非可选 + ④ 类型区分（**编译期，已完成**）／弹窗渲染断言 | ✅ 主载体已达成；渲染断言**降级为可断言的部分**（弹窗打开 + ① 渲染，实测通过），②③④ 记 `NOT RUN`（平台限制，见下） |

## 守卫基座：已建成大半（I-2 / I-3 已绿；I-4 渲染断言未过）

### 已建成
- **状态注入能力**：`AtlasAppModel` 新增 `#if DEBUG` 的启动环境变量接缝（`ATLAS_UI_TEST_FIXTURE`），当前两个 fixture：
  - `receipt-no-recovery` —— Smart Clean ④ / FO ⑤ 同时落在「回执存在、**无**恢复项」的终态（这是 `ATLAS_STATE_FILE` 冷启动**造不出来**的态：执行回执是内存态、不落盘）
  - `review-executable` —— ② 复核页可执行的新鲜计划（**尚未达到目的**，见下）
- `accessibilityIdentifier` 投放：`smartclean.receipt.undo.reason` / `fileorganizer.receipt.undo.reason` / `smartclean.executeSelection` / `confirm.destructive.*` / `ledger.restoreOutcome.*` / `overview.callout.limited` / `fileorganizer.scan.preamble` 等
- **`I-2` / `I-3` 已挂且实测通过**（上表两条新增用例）

### `I-4` 的最终记账：编译期为主载体 + 平台限制

**已达成（主载体，规格 §7 原文）**：①②③ 是 `AtlasDestructiveConfirmation` 的**非可选构造参数**（缺项编译不过）；④ 由 `case .recoverable / .plain` 的**类型**区分。三条破坏性弹窗已全部改用它。

**平台限制（实测发现，非实现缺陷）**：规格还要求「三条文案的 `AtlasAppUITests` 渲染断言」。本波实测证明这在 `.confirmationDialog` 下**不可达成** —— macOS 把它渲染成 AppKit 警报 `Sheet`：

```
Sheet (label: '警告')
  StaticText  value: 执行这份清理计划？
  StaticText  value: 将清理已选的 4 项      ← 只有 ①
  Button '取消'   Button '执行计划'
```

- SwiftUI 的 `accessibilityIdentifier` **被系统替换**（树里是 `_NS:58` 一类），按标识查询取不到
- 正文**只渲染第一行**，②③④ 不进可访问性树

**本波的处置**：用例降级为断言**可断言的部分**（弹窗确实打开 + ① 按文本前缀渲染），改名 `testDestructiveConfirmationOpensAndRendersScopeQuestion`；②③④ 的渲染断言记 **`NOT RUN`**，**不冒充覆盖**。

> 这是**第二处**「规格要求与本仓库现状冲突」——与 `I-5`、`F1`（视图测试无渲染断言能力）同族：都是把守卫写在平台做不到的能力上。**需产品负责人裁定**：接受现状记账，还是把三条弹窗从 `.confirmationDialog` 换成自绘 sheet（能让四问全部进可访问性树，但属 UI 形态变更）。

### 修 fixture 时踩到的两个真坑（已修，留档）

1. **启动后的 snapshot reload 会冲掉内存态注入**：`AppShellView.task`（`:100-103`）调 `refreshHealthSnapshotIfNeeded()` / `refreshPermissionsIfNeeded()`，两者都 `snapshot = output.snapshot`。只改内存的 fixture 在首帧之后即失效 ⇒ **注入必须落到真相源（repository）**。
2. **不能自造 finding**：全新状态文件下 app 落到**脚手架工作区**，reload 带回的是那 4 条脚手架 findings；自造 finding 的 id 不在其中 ⇒ `selectedFindingIDs` 求交集后归零 ⇒ 按钮显示「执行已选 **0** 项」并置灰。**改为从真实 findings 派生**计划与选中集。

两条都已固化：单测 `testReviewExecutableFixtureProducesExecutablePlan`（7 项断言）+ `testReviewExecutableFixtureSurvivesSnapshotReload`（reload 后仍可执行）。

## ⚠️ 一处规格与 fail-closed 红线的冲突（报告，未自行调和）

规格 §1.2(3) 要求失败态渲染「本次未生成回执」+ **最少可用信息（已处理 / 未处理计数）**；
而 §1.6 的 fail-closed 纪律（本 REQ 的 `禁止` 项之一）规定：worker 未返回就失败时，**本次到底动了几项无从确认，不得编造**。

两处不能同时满足。**本波的处理**：结构按 §1.2(3) 实现（不再渲染死控件、给真实出口、渲染「本次未生成回执」），计数字段按 fail-closed 降级为诚实版 ——
`action.receipt.missing.counts` 由 Wave 0 定稿的「已处理 %d 项 · 未处理 %d 项」改为 **「已选 %d 项 · 处理结果无法确认」**（en: `"%d selected · outcome could not be confirmed"`）。

**这是对已签字术语基线 N-4 的偏离，需产品负责人裁定。**

## 收口判定：**✅ 收口**

三条门禁：
1. `swift test --package-path Packages` → `606 / 0` — PASS
2. `swift test --package-path Apps` → `66 / 0` — PASS（基线 62，本波 +4：`I-1` `I-5` + 2 条 fixture 自检）
3. `./scripts/atlas/run-ui-automation.sh` → `7 tests / 2 failures`，**失败集与 HEAD 基线逐条相同**（`:75` `:56`）

按**增量门禁**裁定：**零新增失败 → 通过**。

**已知缺口（不冒充覆盖）**：`I-4` 的 ②③④ 渲染断言 = `NOT RUN`（平台限制，见上）；`I-5` 的真实时序 = `macos-gui-acceptance` 人工验收项。
