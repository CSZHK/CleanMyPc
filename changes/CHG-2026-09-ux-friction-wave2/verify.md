# Verify — CHG-2026-09-ux-friction-wave2

**状态：进行中。** 本文件记录**首个切片**的实测结果。

## 三条门禁（首个切片后）

| # | 命令 | 结果 |
|---|------|------|
| 1 | `swift test --package-path Packages` | `606 / 0` — **PASS** |
| 2 | `swift test --package-path Apps` | `68 / 0` — **PASS**（Wave 1 收口时 66，本波 +2：`I-11` 守卫 + ⌘, 断言） |
| 1b | `swift test --package-path Packages`（第三个切片） | `609 / 0` — **PASS**（+3：`I-8` 的三条 `PermissionsSummaryMetrics` 断言） |
| 3 | `./scripts/atlas/run-ui-automation.sh` | **`9 tests / 0 failures` — EXIT 0**（HEAD 基线为 `4/2`） |

## 本切片交付

### `P1-18`（CONTRACT，已签字）
`Apps/AtlasApp/Sources/AtlasApp/AtlasAppCommands.swift`（+37/−7）：
- **`I-11` 前置 1**：`private extension AtlasRoute` → `extension`（`@testable import` 只放开 `internal`）
- **`I-11` 前置 2**：`shortcutKey` 由 `KeyEquivalent` + `preconditionFailure` → **`KeyEquivalent?`**
- **本体**：`.settings` 补 **⌘,**
- 导航菜单补 Settings 入口；sidebar 侧改可选绑定

### `I-11` 守卫（已挂且**经变异检验**）
- `AtlasAppModelTests.testEveryRouteHasAtLeastTwoReachablePaths` —— 遍历 `AtlasRoute.allCases`，断言「在 `sidebarRoutes` ∨ `shortcutKey` 非空 ∨ 在 `appMenuRoutes`」
- **变异检验已做**：把 `appMenuRoutes` 清空后，该用例**确实失败**（1 test / 1 failure）→ 守卫不是空转的
- 落点在 `Apps/AtlasApp/Tests/AtlasAppTests/`（规格 §7.1 要求的位置）

### `.about` 的裁定落地（产品负责人 2026-09-14）
新增 `AtlasRoute.appMenuRoutes: Set<AtlasRoute> = [.about]`（`AtlasDomain.swift:145`）—— 把「about 由 app 菜单承载」变成**可枚举事实**，因为 `I-11` 的断言对象只能取静态属性、不能取 `CommandMenu`（View body 不可枚举，评审 F3）。

## ⌘, 的定性结论（已解）

**结论：`⌘,` 不触发不是 App 缺陷，而是 XCUITest 无法合成标点键的菜单等价物。**

排查链（每步都是一次实测，不是推断）：

1. **菜单项确实建出来了** —— 「导航」菜单里「设置」项存在且 `enabled`
2. **导航本身没问题** —— 点该菜单项**能**抵达设置屏（`settings.*` 元素出现）
3. **⌘2 能用、⌘, 不能用** → 矛头指向逗号键
4. **改走 `CommandGroup(replacing: .appSettings)`**（SwiftUI 为 app 菜单 Settings 槽位指定的入口）→ 菜单项位置正确、点击仍可达，**但 ⌘, 仍不触发**
5. **对照实验（决定性）**：把 `.permissions` 临时绑到 **`⌘;`** —— 同为标点键但系统**未保留** —— 结果**同样不触发**；而 `⌘1`–`⌘7` 正常

⇒ **`typeKey` 对数字键可靠、对标点键不可靠。** 步骤 3–4 曾指向「macOS 保留了 ⌘, 槽位」，**该推断已被步骤 5 证伪**，特此更正（那是只在数字键上验证过的探针做出的外推）。

### 本切片对此的处置
- **`P1-18` 的菜单入口**：交付并经**点击**端到端验证 → `testSettingsMenuEntryOpensSettings` **通过**
- **`⌘,` 的键盘路径**：`shortcutKey` 映射正确、绑定声明在标准 Settings 槽位；**键盘行为记 `NOT RUN`**，列入 `macos-gui-acceptance` 人工验收项（不冒充覆盖）

## 顺带修复的 2 条既有红（HEAD 基线 → 全绿）

| 用例 | 原失败原因 | 修法 |
|---|---|---|
| `testKeyboardShortcutsNavigateAndOpenTaskCenter` | 期望 ⌘5=权限，实际映射 5=台账、6=权限（**陈旧期望**） | 改 ⌘6；并核实映射表 |
| `testSmartCleanAndSettingsPrimaryControlsExist` | ① 靠侧栏合成点击抵达设置（不可达）② `settings.language` / `settings.notifications` 等断言**写死 AX 角色** | ① 改走菜单入口；② 改按**标识**查（`.toggleStyle(.switch)` 的 Toggle 在 macOS 上不是 `switch` 角色）。这些断自设置不可达以来**从未被执行过**，是修复导航后才暴露的潜在错配 |

**UI 门禁：HEAD `4 tests / 2 failures` → 本切片 `8 tests / 0 failures`。**

## 第二个切片：契约四用词 + 契约三 §3.2(6) + 契约五 §5.2(2)

| finding | 改动 | 落点 |
|---|---|---|
| **`P1-15`** | 「已归档」拆词：新增 `AtlasLedgerEntryStatus.expired`（`.archived` 只留给任务失败/取消）；过期的恢复项改判 `.expired`；`ledger.filter.archive` 的**实际判据就是 `item.isExpired`**，文案随之改「已过期」 | `AtlasLedgerTimeline.swift` · `LedgerTimelineView.swift` · 两份 strings |
| **`P1-13`** | 冲突口径统一：`fileorganizer.conflict.exists` 补上「执行时会自动重命名，不会覆盖」（worker 实测行为）；`fileorganizer.receipt.failed.value` 删去「（可重试）」→「%d 项仍留在原位置」（回执上没有重试入口） | 两份 strings |
| **`P1-4`** | 权限计数口径：卡标题「暂不需要」→「可稍后授权」、值→「%d 个」；列表计数→「%d 个权限可稍后授权」；`next.ready.detail` →「%d/%d 个跟踪权限」。两处同源 `optionalMissingCount` | `PermissionsFeatureView.swift` · 两份 strings |
| **`P1-5`** | 去技术黑话：`Library`→「系统受保护的位置」、「系统级缓存」→「系统自动生成的缓存」。**四处都改**（含 R-6 裁定的 `infrastructure.*` 与 `fixture.*` 双落点） | 两份 strings（zh 侧已无残留） |
| **`P2-8`** | FO 补权限受限态：新增 `fileOrganizerRequiredPermissionsReady`（与 SmartClean **同判据**）；扫描前写 `.advisory`；**catch 里权限未就绪时保持 `.advisory`，不再渲染成 `fileorganizer.status.executionFailed`** | `AtlasAppModel.swift` |
| **`P1-12`** | `AtlasSectionDisclosure` 补可选 `summary`（折叠态透出关键参数、展开后隐藏）；FO 配置区改用**自己的**文案 + 摘要带去向 | `AtlasSectionDisclosure.swift` · `FileOrganizerSupportViews.swift` · 两份 strings |

### 本切片改写的「钉住旧行为」断言（3 条）
- `CalmLedgerComponentTests.testLedgerStatusBadgeMapping` — 断言 `.archived` 文案是「已归档」（旧词）；改为「已结束」并补 `.expired` 断言
- `LedgerModelTests.testEntryMappingRecoveryItemExpiredArchived` — 断言过期项映射为 `.archived`（缺陷本身）；改为 `.expired`
- （上一切片）`testKeyboardShortcutsNavigateAndOpenTaskCenter` 的陈旧 ⌘5 期望

## 第三个切片：剩余 4 条 finding + 2 个守卫 —— **本波完成**

| 项 | 改动 |
|---|---|
| **`P1-7`** | Smart Clean ② 补全选/取消全选（与 FO 同构）。全选作用于**当前可见**（筛选+搜索后）的条目 —— 不会偷偷选中被筛掉的行 |
| **`P1-9`** | 执行中不再作无意义的不确定态：`planExecutionStartedAt` + `TimelineView` 显示**已用时**（worker 只在完成时上报进度，故进度/计数/ETA 都无真实数据，已用时是唯一真实可得的量）；action bar 在该状态下给一个**真实动作**「查看台账」（新增 `.viewLedger` intent），不再 `intent: .none` |
| **`P1-6`** | 从系统设置返回且状态未变时给二次引导：记 `pendingAuthorizeKind`，`scenePhase == .active` 且该项仍未授予 ⇒ 渲染「你去过系统设置了，但这项权限还没生效」+ 两个常见原因 |
| **`P1-16`** | 过期恢复项被清理后不静默消失。**不给 worker 加墓碑**（§1.3 禁止改其恢复语义），改在 **app 层做会话间 id 差分**：消失的即为被 prune 的，记 `.ledger` 的 `.advisory`，台账横幅渲染提示 |
| **`I-7`** | `AtlasAppUITests.testReviewScreenHasNoConflictingInteractiveLabels`：枚举 ② 屏 `app.buttons`，同一 label 下出现**两个不同 identifier** ⇒ 判失败。阶段条按 `stageBar.` 标识前缀剔除（规格 §7 明文排除），为此给 `AtlasStageBar` 的 completed 段投放了稳定标识 |
| **`I-8`** | 抽 `PermissionsSummaryMetrics`（权限页计数的**单一来源**），两条渲染路径都走它；`packages` 侧 +3 条单测断言「同源」与「分母只数必需权限」 |

### 本波守卫小结
- 已挂且实测通过：`I-2` `I-3` `I-4`（主载体）`I-5`（降级）`I-6` `I-7` `I-8` `I-11`（经变异检验）
- **UI 门禁：HEAD 基线 `4 tests / 2 failures` → 本波收口 `9 tests / 0 failures`**

## 本波已无剩余 —— 待 Wave 3

Wave 3（P2 层 + 双语术语表回写 + 产品内术语入口；守卫 `I-9` `I-10` `I-12`）为下一波，**不跳波**。



契约三余项（`P1-5` `P1-6` `P2-8`）· 契约六 `P1-7` · 契约四 `P1-4` `P1-13` `P1-15` · 契约五 `P1-9` `P1-12` `P1-16`；守卫 `I-7` `I-8`。
