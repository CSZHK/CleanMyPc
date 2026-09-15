# Verify — CHG-2026-09-ux-friction-review-remediation

**状态：✅ 已收口（2026-09-15）** —— 三条门禁全绿，变异矩阵 6/6 通过。

> **证据来源标注**：`[亲验]` = 控制器本人跑过并核对原始输出；`[报证]` = 子代理执行并附命令与输出原文，控制器已抽验其关键结论。

## 1. 三条门禁（最终冻结态，2026-09-15 12:31–12:32）`[亲验]`

| # | 命令 | 基线（复审时实测） | **最终结果** |
|---|------|-------------------|-------------|
| 1 | `swift test --package-path Packages` | `612 / 0` | **`612 / 0 failures` — PASS** |
| 2 | `swift test --package-path Apps` | `69 / 0` | **`72 / 0 failures` — PASS**（+3 条新守卫） |
| 3 | `./scripts/atlas/run-ui-automation.sh` | `11 tests, 0 failures, 0 skipped` | **`11 tests, 0 failures` · `** TEST SUCCEEDED **` · `EXIT 0`** |

零失败用例（全文 grep `error:` / `TEST FAILED` 均为空）。第 3 条**真实执行**：日志无 `ATLAS_UI_GATE=NOT_RUN`、无 `Skipping native UI automation`。

`func test` 计数（脚本） = **72**，与门禁 2 的实测一致。

## 1b. Release 编译验证（本轮**新增**的门禁，因 F-11 而加）

> **为什么加**：REQ 的「两套语言模式都要能编过」只约束了 SPM 5.10 ↔ Xcode 6.0，**没有约束 Debug ↔ Release**。
> 而全部既有验证路径（`swift test`、`xcodebuild test`、`xcodebuild build-for-testing`）**都是 Debug 配置** ——
> 于是一个只影响 Release 的编译阻断可以长期隐身（F-11 就是这样躲过整轮 REQ 的）。

| 命令 | 结果 |
|------|------|
| `swift build --package-path Apps -c release` | **`Build complete!` EXIT 0** ✅ |
| `swift build --package-path Packages -c release` | **`Build complete!` EXIT 0** ✅ |
| `xcodebuild -project Atlas.xcodeproj -scheme AtlasApp -configuration Release -destination 'platform=macOS' build` | **`** BUILD SUCCEEDED **`** ✅ |

> 排查备注：用 `xcodebuild -target AtlasApp`（而非 `-scheme`）会因 SPM 依赖未被构建而报
> `Unable to find module dependency` / `lstat(...bundle)` —— 那是**调用方式**的问题，不是仓库缺陷。
> 验证 Release 请一律走 `-scheme`。

### F-11 的修复与归因

`AtlasAppModel.swift` 的 `#if DEBUG`（守卫基座 fixture 接缝，`:236`）与下一个 `#endif` 之间**吞掉了 P1-16 整段**
（`seenRecoveryItemIDsKey` / `forgetSeenRecoveryItem` / `surfaceExpiredRecoveryPruneIfNeeded`），
而它们在 **release 可达路径**上被调用（`init` 与 `restoreRecoveryItemCore`）
→ `error: cannot find 'forgetSeenRecoveryItem' in scope`。

**修复**：fixture 接缝在 `:260` 闭合、在 `applyUITestFixture` 前于 `:310` 重新开启，P1-16 段落回 release；
并在该段留下边界警示注释。修后 release 三路全绿（上表）。

**归因**：本分支**未提交工作树**引入（`git show HEAD:...AtlasAppModel.swift` 无任何 `#if DEBUG`），非本 CHG 引入。

## 2. 变异检验矩阵（守卫有效性的唯一证据）

> 方法：在 `/tmp` 的 `git archive` 导副本内改坏**产品代码**，确认守卫**变红**。共享工作树零改动。

| # | 守卫 | 变异动作 | 修复前 | **修复后** | 来源 |
|---|------|---------|--------|-----------|------|
| M-1 | `I-11` `testEveryRouteHasAtLeastTwoReachablePaths` | `.permissions.shortcutKey → nil` | passed（空转） | **failed**：`I-11(菜单/键盘半支): permissions 既没有快捷键、也不在 appMenuRoutes` | `[亲验]` |
| M-2 | `I-8` `testBothSurfacesShareOneSourceValue` | 卡片侧改用另一口径 | passed（自证） | **failed**：`卡片「3 个」 vs 列表「2 个权限可稍后授权」` | `[报证]` |
| M-3 | `I-10` `testReceiptEstimateSitsInItsOwnGroup` | 估算行移入实测组容器 | passed（空集合判真） | **failed**：`实测组实际内容：[...fact.items, ...fact.completed, ...fact.code, ...fact.estimated]` | `[报证]`，探针输出已附 |
| M-4 | `I-5` `testFileOrganizerScanWritesPreambleState` | 赋值挪到扫描调用之后 | passed（只证存在） | **failed**：`preamble 必须先于扫描调用被发起而置位` | `[报证]` |
| M-5 | `I-1`（清除方向，`TS-01`） | restore 分支重新插回无条件 `clearExecution(.smartClean)` | 无守卫 | **failed** | `[报证]` |
| M-6 | `F-03` 测试确定性 | `self.userDefaults = .standard` | n/a | **failed**：`1 条过期记录已被清理…` | `[报证]` |

**M-3 附带的根因发现**：仅加 `accessibilityIdentifier` 不够 —— 容器标识会**传播覆盖**子元素，实测组子树只剩一个元素。须同时加 `.accessibilityElement(children: .contain)`。加后探针：

```
I-10 PROBE measuredIDs=["smartclean.receipt.fact.items", "smartclean.receipt.fact.completed", "smartclean.receipt.fact.code"]
```

## 3. 门禁脚本分支实测（Slice A）

复用复审方法：**提取真实函数体配桩**（不重写函数）。

**消费者侧（`full-acceptance.sh`，8/8 通过）** `[亲验]`

| 分支 | 期望 | 结果 |
|------|------|------|
| preflight 跳过，无豁免 | `1` | ✅ RC=1 |
| preflight 跳过 + `ATLAS_ALLOW_UI_SKIP=1` | `0` | ✅ RC=0 |
| atlas 与 repro **双 timeout**，无豁免 | `1`（**修复前 `0`** = F-01） | ✅ RC=1 |
| 双 timeout + 豁免 | `0` | ✅ RC=0 |
| 执行 **0 个测试**，无豁免 | `1`（**修复前 `0`** = F-06） | ✅ RC=1 |
| 执行 0 个测试 + 豁免 | `1`（**配置缺陷不可豁免**） | ✅ RC=1 |
| 正常通过 | `0` | ✅ RC=0 |
| 正常失败（非环境类） | `1` | ✅ RC=1 |

**生产者侧（`run-ui-automation.sh`，3/3 通过）** `[亲验]`：收集 0 用例 → `EXIT=1` + 发出 `ATLAS_UI_GATE=ZERO_TESTS`；正常通过 → `EXIT=0`；正常失败 → `EXIT=1`。

**F-02**：生产者以常量 `NOT_RUN_SENTINEL` 为唯一来源，消费者只匹配哨兵（不再匹配人类可读英文句子）。零测试用**独立**哨兵，与豁免闸分离。`bash -n` 两脚本均通过。

## 4. 测试确定性（F-03）`[亲验 + 报证]`

`surfaceExpiredRecoveryPruneIfNeeded()` 每次从全局 `UserDefaults.standard` 读写基线，而 SPM 测试进程的 `.standard` 解析到机器级持久域 `com.apple.dt.xctest.tool`。修法：默认存储**在测试进程下自动改用每进程独立 suite**，生产仍 `.standard`；测试在**构造模型之前**写种子。

| 步骤 | 结果 |
|------|------|
| 注入污染 id → 隔离跑 | 5/5 `0 failures`（**修复前必红**） |
| 清空该域 → 隔离跑 | 5/5 `0 failures` |
| 全量 Apps 套件跑完 → 查该域 | `does not exist`（无残留） |
| 变异：改回 `.standard` | 守卫**变红** |

## 5. L10n parity `[亲验]`

```
en=1167  zh=1167
en∖zh: 空      zh∖en: 空      占位符不对称键: 空
```

## 6. 维度闭合复算（脚本计数，非目测）`[亲验]`

> 纪律来源：`iteration-governance` 的 Validation Gate——**任一维 100% 覆盖不构成其他维也覆盖的证据**，各维分别复算。

| 维度 | 方法 | 结果 |
|------|------|------|
| finding → 契约/波次 | 规格唯一 finding 集 vs 各 wave 任务文件并集 | **40 / 40，双向差集为空** |
| 不变量 → **载体** | `I-1..I-12` 各自向后映射到具名测试方法 | **12 / 12 均有载体** |
| 不变量 → **守卫有效性** | §2 变异矩阵 | **6 条经变异检验；另有 6 条未做**（见 §7） |
| 测试方法数 vs 门禁实测 | `func test` 计数 vs `Executed N tests` | **72 = 72** |
| L10n 键集合 | 双向差集 + 逐键占位符 | **零差异** |

## 7. 未覆盖与残余风险（明写不藏）

1. **6 条不变量的守卫未做变异检验**：`I-1`（写入方向）、`I-2`、`I-3`、`I-4`、`I-6`、`I-7`、`I-9`、`I-12` 中，除 `I-1` 的清除方向（M-5）外均**未**验证「改坏产品代码是否会红」。本次只修了经实证空转的 4 条（`I-11`/`I-8`/`I-10`/`I-5`）。**其余守卫可能同样空转** —— 这是本 CHG 最大的残余风险，建议后续单独开一轮全量变异审计。
2. **`I-4` 的 ②③④ 渲染断言**：平台限制（macOS AppKit 警报），产品负责人 2026-09-14 已裁定接受现状记账。**仍记 `NOT RUN`**。
3. **真实 ⌘, 按键行为**：XCUITest 无法合成标点键的菜单等价物，留 `macos-gui-acceptance` 人工验收项。
4. **`.accessibilityElement(children: .contain)` 改动了两个事实组容器的 AX 形态**：第三条门禁 11/11 通过表明无回归，但**未做 VoiceOver 实机走查**。
5. **release 构建的严格并发模式**：`xcodebuild build-for-testing` 通过（Swift 6 严格并发），但**未跑 release 配置**。
6. **相邻面未修（有意不扩面）**：`refreshPlanPreview()` 首行的 `clearExecution(.smartClean)` 是 **HEAD 既有语义**（非本 CHG 引入），意味着任何 `.finding` 载荷的恢复都会清掉 `.smartClean` 槽 —— 属同一 `TS-01` 家族，但规格未覆盖且会触及既有契约，**已记账待裁定**。
7. **`scripts/test.sh`（shell/bats/Go）未跑**；`XPC` / `Helpers` / `Testing` 三包未审、未跑。

## 8. 事后复核清单（预授权的一部分）

产品负责人 2026-09-15 一次性预授权全部 INV/CONTRACT/infra 类改动。以下为**需逐项复核**的承重决策：

| # | 决策 | 位置 | 影响面 |
|---|------|------|--------|
| 1 | UI 门禁新增「零测试 → 失败」且**不可豁免** | `run-ui-automation.sh` / `full-acceptance.sh` | 用例被改名会让门禁红 —— 这是**有意**的（配置缺陷应当红） |
| 2 | 双 timeout 路径改走 `ATLAS_ALLOW_UI_SKIP` 豁免闸 | `full-acceptance.sh` | 从此环境级阻断默认**不放行**（原来是硬编码放行） |
| 3 | `AtlasAppModel` 新增可注入 `userDefaults`，测试进程下默认改用独立 suite。**审查后已收紧两处**：① 整段 `#if DEBUG`（release 里根本不参与编译，不再靠运行期判据）；② 改 `static let` **一次性求值**（原先每次访问都 `removePersistentDomain`，即每次模型构造都清域 —— 对将来「需在两次构造间保留基线」的用例是静默陷阱） | `AtlasAppModel.swift:137-156` | 生产行为不变（release 走 `#else` 分支直接 `return .standard`） |
| 4 | `.apps` outcome 接回渲染（**跳过 `.succeeded`**，只渲染 failed/advisory） | `AppsFeatureView.swift` / `AppShellView.swift` | 新增 2 个文案键 |
| 5 | 台账 prune advisory 的出清 **= 用户显式点击关闭控件**（审查后**已改**：原为视图 `onAppear` 自动清） | `LedgerFeatureView.swift`（`restoreOutcomeBanner` 内新增 `ledger.prune.notice.dismiss` 按钮；`onAppear` 不再触发） | **原方案有缺陷**：「`onAppear` 清除」是「**显示**即清」而非「**已读**才清」—— 用户快速划过台账屏（或将来把台账设为默认落地页）时会在**从未被读到**的情况下消失，恰好回到 `P1-16` 要修的「静默消失」。改后与 `AtlasNextActionBanner`/`AtlasUndoBanner` 的显式关闭约定一致。新增双语键 `ledger.prune.notice.dismiss`（知道了 / Got it） |
| 6 | `TS-01`：**整条删除** restore 分支的 `clearExecution(.smartClean)`（而非收窄条件） | `AtlasAppModel.swift` | 见代码注释里排除的两个错误版本 |
| 7 | `CT-04/CT-07` 接上生产/消费（原本零生产/零消费）；`CT-06` **有意保留** `.plain` 不造调用点 | 多处 | `CT-06` 依据规格 §7.1：删掉会让 `I-4` 的 ④ 载体消失 |
| 8 | 门禁脚本新增哨兵协议（生产者→消费者） | 两个脚本 | 协议变更，未来改文案不再影响判定 |

## 9b. 复核轮（2026-09-15 §8 走查）新增的改动

产品负责人过 `§8` 复核清单后裁定「改」，据此做了三件事：

| # | 动作 | 触发 |
|---|------|------|
| 1 | `defaultUserDefaults` 收紧：整段 `#if DEBUG` + `static let` 一次性求值 | §8-3 走查发现（见上表第 3 行） |
| 2 | 台账 prune advisory 出清改显式关闭控件 | §8-5 走查发现（见上表第 5 行） |
| 3 | **修 `F-11` Release 编译阻断** + 新增 release 编译门禁 | 由 #1 的 `#if DEBUG` 改动**牵出**：为验证 #1 而首次尝试 release 构建，暴露出 P1-16 段被 DEBUG 块吞掉的既有阻断 |

**#3 的连带价值**：本轮之前**没有任何验证路径碰过 Release**。REQ 的「两套语言模式都要能编过」
只覆盖 SPM 5.10 ↔ Xcode 6.0，未覆盖 Debug ↔ Release —— 这是本次新增 §1b 的原因。

| 4 | `.github/workflows/atlas-acceptance.yml` 的 acceptance 步骤加 `env: ATLAS_ALLOW_UI_SKIP: "1"` | CI 决策：GitHub runner 无 AX 授权 ⇒ 不设则第 [9/11] 步必红（自 `c7a7a2c` 起已如此） |

**#4 的语义边界（关键，勿误读）**：该变量**只**豁免两条**环境限制**路径（AX 未授权 / 双 timeout）。
它**不**豁免 `ATLAS_UI_GATE=ZERO_TESTS` —— 配置缺陷在 CI 里照样红。
实测（真实函数体 + 桩，`ATLAS_ALLOW_UI_SKIP="1"`）：`notrun → RC=0` · **`zero → RC=1`** · `ok → RC=0`。
即：**CI 接受「这台 runner 没有 AX」，不接受「UI 用例根本没跑起来」**。
YAML 经 ruby `YAML.load_file` 校验，step 级 env 解析为 `{"ATLAS_ALLOW_UI_SKIP"=>"1"}`。

**文档同步**：`AGENTS.md` 的「UI 门禁（易踩）」节已按哨兵协议重写，补上 CI 裁定与「零测试不可豁免」；
原「断言 log 不含该跳过标记」的措辞已失准（改为哨兵判定）。

**复核轮后的最终三门禁**（冻结态 `13:04–13:06`）：
`612 / 0` · `72 / 0` · UI `11 tests, 0 failures` `** TEST SUCCEEDED **` `EXIT 0`，另加 §1b 的 release 三路全绿。

## 9c. 仍未自动化守卫的一处（诚实记账）

`F-08` 的**视图侧出清触发**（点击 `ledger.prune.notice.dismiss`）**无自动化守卫**：
仓库的 `*FeatureViewTests` 无渲染断言能力（只能断言 view 的初始属性），
XCUITest 覆盖它需要新增一个 `prune-notice` fixture 与用例。**模型侧**的清槽有守卫
（`testLedgerPruneAdvisoryIsWrittenAndThenClearedOnAcknowledge`）。
本项记 `NOT RUN`，不冒充覆盖。

## 9. 复审自身的更正（诚实留痕）

**F-10 / UI-1 不成立。** 复审曾判「en 侧 `ds.ledger.status.archived` 未随 zh 拆词」为 P1 缺陷。
回源术语真相源后证伪：

- `Docs/COPY_GUIDELINES.md:63`：「任务失败或取消 → **已结束 / `Archived`**」
- `iterations/REQ-ux-friction-remediation/terminology-baseline.md:76` / `:244` R-1：
  **「照规格用 `Archived`。en 侧 `Archived` ↔ zh「已结束」不是字面对译，已由产品负责人确认接受」**

**复审失误的性质**：只核了「en 侧未改」这个**机制**，未核「en 该是什么」这个**义务** ——
抽样回源必须回到**义务的真相源**，而不是只回到现象。**F-10 无需改动，strings 未动。**
本项由子代理按 Stop Condition 停住上报、未自造 en 词，处理正确。
