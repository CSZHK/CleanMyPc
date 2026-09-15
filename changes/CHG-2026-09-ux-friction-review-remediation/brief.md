# CHG-2026-09-ux-friction-review-remediation

- REQ: REQ-ux-friction-remediation
- Task: review-remediation（复审发现修复轮）
- Scope: 修复 2026-09-15 分支复审出的 24 条发现（门禁 infra 3 · 不变量守卫 5 · 契约语义 4 · 术语 CONTRACT 1 · 测试确定性 4 · 记录/注释 7）
- Canonical Plan: 本文件（canonical change root）；验收协议见同目录 `verify.md`
- 上游证据: `.agent/ui-friction-remediation-execplan.md` + 2026-09-15 复审会话（完整性快照 `sha256:266c42b1…`，verify clean）

## 状态：✅ 已收口（2026-09-15）—— 三条门禁全绿，变异矩阵 6/6

- 门禁：`612/0` · `72/0`（+3 新守卫）· UI `11 tests, 0 failures` `TEST SUCCEEDED` `EXIT 0`
- 详见 `verify.md`（含 §7 残余风险与 §8 事后复核清单）

## 1. 为什么开这个 CHG

2026-09-15 对分支 `iter/ux-friction-remediation` 做了一次 advisory 复审（5 个 specialist + controller 回源抽验）。
复审结论：**REQ 的 Close Gate 结论不可采信**——至少 4 条不变量的守卫经变异检验证明「改坏产品代码仍不失败」，
且 4 份治理记录互相矛盾（详见 §3）。

本 CHG 承接该复审的修复与重验收。**不改写 REQ 的历史收口记录**（`trace.md`/`CHG-wave*/verify.md` 原文保留），
只在其上追加失效范围标注。

## 2. 授权记录（必读）

按 `CLAUDE.md`「命中 `UC / INV / CONTRACT / infra` 时，必须升级给人，不允许默认自主变更」，
本次全部改动**已逐类升级并经产品负责人裁定**：

| 类别 | 涉及项 | 裁定 |
|---|---|---|
| INV（不变量守卫） | F-04 / F-05 / F-09 / TS-03 / TS-04 | ✅ 一次性预授权全量修复（2026-09-15） |
| infra（门禁脚本） | F-01 / F-02 / F-06 | ✅ 同上 |
| CONTRACT（契约四术语） | F-10 | ✅ 同上 |
| 契约语义 | F-07 / F-08 / TS-01 / CT-04..07 | ✅ 同上 |
| REQ 状态处置 | Close Gate 失效 | ✅ 新建本 CHG 补丁单 + REQ 回 `IN PROGRESS` |

> **留痕要求**：上述类别在 `verify.md` 中须逐项列出「改前 → 改后」与变异检验证据，供事后复核。
> 预授权不等同于免检——事后复核是这次授权的一部分。

## 3. 发现清单（24 条）

### 3.1 门禁 infra（Slice A）

| ID | 严重度 | 内容 | 落点 |
|---|---|---|---|
| F-01 | P1 | `full-acceptance.sh` 的「atlas 与 repro 双 timeout」路径 `return 0`——零 UI 覆盖判为通过，绕过本文件刚建立的 `ATLAS_ALLOW_UI_SKIP` 显式豁免 | `scripts/atlas/full-acceptance.sh:51-54` |
| F-02 | P2 | 跳过协议 = 对生产者人类可读散文做 grep；改文案即静默回到假绿，两端无守卫钉住 | `full-acceptance.sh:20` ↔ `run-ui-automation.sh:9` |
| F-06 | P1 | UI 门禁在「执行 0 个测试」时 `xcodebuild` 返回 0 并打印 `** TEST SUCCEEDED **` → 判通过 | `run-ui-automation.sh:31`、`full-acceptance.sh:37` |

### 3.2 不变量守卫空转（Slice B）

> 判定手段一律为**变异检验**（在 `/tmp` 导副本内改坏产品代码，确认守卫变红；不改共享工作树）。

| ID | 不变量 | 变异实证 | 根因 |
|---|---|---|---|
| F-04 | `I-11` | `.permissions` 的 `shortcutKey` 置 `nil` → 守卫 **passed** | 析取式 `inSidebar ∨ hasShortcut ∨ inAppMenu` 被 `inSidebar` 恒真短路；**规格 §7 表里的载体定义本身弱于它要守的不变量**（不变量是「菜单/键盘 至少其一 **+** UI」） |
| F-05 | `I-8` | 列表侧计数改独立口径 → 守卫 **passed** | 断言自己算 `n` 再造期望串，被测视图一行未读 |
| F-09 | `I-10` | 估算行移入实测组内部 → 守卫 **passed** | `measuredGroup.descendants` 恒为空集合（探针实测 `labels = []`） |
| TS-03 | `I-5` | 赋值语句移到 TCC 调用之后 → 守卫 **passed** | 断言赋值存在性，不涉时序 |
| TS-04 | `I-10` | 同 F-09 | 同 F-09 |

### 3.3 契约语义与测试确定性（Slice C）

| ID | 严重度 | 内容 |
|---|---|---|
| F-03 | **P0** | `testRestoredItemIsNotReportedAsPruned` 的绿取决于仓库外持久 OS 态（`com.apple.dt.xctest.tool` 域）。注入污染 → 必红；清空 → 连跑 5 次全绿。测试在模型构造**之后**才写种子，且从不清理 |
| F-07 | P1 | `.apps` outcome 槽只写不读（`AtlasAppModel.swift:1131` 唯一写点，全仓零读取点）——原本可见的摘要变为不可见 |
| F-08 | P1 | 台账过期清理 advisory 无出清路径（`clearPlan(.ledger)`/`clearExecution(.ledger)` 全仓零命中）→ 粘性横幅 |
| TS-01 | P1 | `restoreRecoveryItemCore` 成功路径无条件 `clearExecution(.smartClean)`——跨 source 清除，`I-1` 只钉了写入方向 |
| CT-04 | P2 | `.unavailable(reason:)` 零生产、`unavailableReason` 零消费 |
| CT-05 | P2 | `AtlasActionRecovery.itemCount` 生产后零消费，且硬编码为 `1` |
| CT-06 | P2 | `.plain(...)` 零生产（与规格 §2.2(1) 的字段约束意图不符） |
| CT-07 | P2 | `.permissions` source 零生产且零读取 |

### 3.3b 修复过程中新发现（追加）

| ID | 严重度 | 内容 |
|---|---|---|
| **F-11** | **P0** | **Release 构建编不过** —— `AtlasAppModel.swift` 的 `#if DEBUG`（守卫基座 fixture 接缝）与下一个 `#endif` 之间**吞掉了 P1-16 整段**（`seenRecoveryItemIDsKey` / `forgetSeenRecoveryItem` / `surfaceExpiredRecoveryPruneIfNeeded`）。而 `init` 与 `restoreRecoveryItemCore` 在 **release 可达路径**上调用它们 → `error: cannot find 'forgetSeenRecoveryItem' in scope`。**长期隐身的原因**：`swift test` / `xcodebuild test` / `xcodebuild build-for-testing` **全是 Debug 配置**，REQ 的「两套语言模式都要能编过」只约束了 SPM 5.10 ↔ Xcode 6.0，**没有约束 Debug ↔ Release**。 |
| **F-12** | P2 | `AGENTS.md` 的「UI 门禁（易踩）」节在本 CHG 改完哨兵协议后失准（仍写「断言 log 不含该跳过标记」），且未记载「零测试不可豁免」与 CI 影响。 |

**F-11 的处置**：先闭合 fixture 接缝的 `#if DEBUG`（`:260`），在 `applyUITestFixture` 前重新开启（`:310`），使 P1-16 段落回 release；并在该段留下醒目的边界警示注释。**同时暴露一条流程缺口**：`build-for-testing` 不能替代 release 编译验证 —— 已加入本 CHG 的验收协议（见 `verify.md` §1b）。

### 3.4 术语 CONTRACT（Slice D）

| ID | 严重度 | 内容 |
|---|---|---|
| F-10 | P1 | 契约四拆词只做了 zh 半侧：`zh ds.ledger.status.archived` = 「已结束」，en 仍 `"Archived"`；`.failed/.cancelled` 都映射到该状态，英文用户读作「已妥善归档」 |

### 3.5 测试与注释（Slice B/C/D）

| ID | 内容 |
|---|---|
| UI-02 | 新增 XCUITest 把中文文案硬编码进断言，套件未钉语言 → 换 en 即假红 |
| UI-03 | `I-4` ① 用 `.exists` 无等待（同屏已用 `waitForExistence`），动画期竞态 |
| SC-01 | `reapplyUITestFixtureOverlay` 被两处注释引用，**实现不存在**（误导后续审查者按错误模型推断） |

### 3.6 治理记录互斥（Slice E）

| ID | 内容 | 正确的一侧 |
|---|---|---|
| R-01 | autopilot execplan **Phase 3/5/6 各有两条 `Status:` 行**（`✅ COMPLETED` 与 `PENDING` 并存），而 Recovery Protocol 明写「找到第一个非 COMPLETED 的 Phase 继续」→ 会重跑 Wave 2/3 | execplan 的 `✅ COMPLETED` |
| R-02 | `requirement.md:10` 写「Wave 2 开工中」，其自身 `trace.md` Close Gate 写 Wave 0–3 全 PASS | `trace.md` |
| R-03 | execplan Phase 5 + progress 记 `I-9 显式 NOT RUN`；`CHG-wave3/verify.md` 与**实测**均为已挂且通过 | `CHG-wave3/verify.md` |
| R-04 | progress 记 UI 门禁 `11 tests, 1 skipped`；全仓 `XCTSkip` 零命中，实测 `0 skipped` | `trace.md` |
| R-05 | 三处记 Apps 门禁 `68/0`；实测 `69 tests`（`grep -c "func test"` 亦为 69） | 实测 |

## 4. 硬门禁（本 CHG 不可违反）

1. 三条门禁每轮收口缺一不可：`swift test --package-path Packages` / `swift test --package-path Apps` / `./scripts/atlas/run-ui-automation.sh`
2. **`Skipped` 计 `NOT RUN`，不计 `Pass`**
3. 每条守卫修复**必须附变异检验证据**（改坏产品代码 → 守卫变红），无变异证据的守卫修复不予收口
4. 不改写 REQ 历史收口记录；只追加失效范围标注
5. 不新增第三方依赖；不改设计系统既有 token；不改 `AtlasScaffoldWorkerService` 的恢复语义与 fail-closed 判定
6. 两条语言模式（SPM `5.10` / Xcode `SWIFT_VERSION 6.0`）都要能编过
7. `docs` 与 `strings` 改动须双语同步

## 5. Write Scope

```
scripts/atlas/{full-acceptance.sh,run-ui-automation.sh}
Apps/AtlasApp/Sources/AtlasApp/{AtlasAppModel.swift,AppShellView.swift,AtlasAppCommands.swift}
Apps/AtlasApp/Tests/AtlasAppTests/AtlasAppModelTests.swift
Apps/AtlasAppUITests/AtlasAppUITests.swift
Packages/AtlasDomain/Sources/AtlasDomain/{AtlasActionOutcome.swift,AtlasDomain.swift}
Packages/AtlasDomain/Sources/AtlasDomain/Resources/{en,zh-Hans}.lproj/Localizable.strings
Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/Components/AtlasDestructiveConfirmation.swift
Packages/AtlasFeatures{SmartClean,Permissions,Apps,FileOrganizer,History}/**（按发现需要）
.agent/autopilot-ux-friction-remediation-{execplan,progress}.md
iterations/REQ-ux-friction-remediation/{requirement.md,trace.md}
```

**复核轮追加**（产品负责人 §8 走查后裁定，见 `verify.md` §9b）：

```
.github/workflows/atlas-acceptance.yml     ← CI 豁免裁定
AGENTS.md                                  ← 「UI 门禁（易踩）」节同步
changes/CHG-2026-09-ux-friction-review-remediation/{brief,verify}.md  ← 本包自身
```

## 6. 不在本 CHG 范围

- 附录 B「明确不做」逐条
- 真实 ⌘, 按键行为（XCUITest 合成标点键不可靠，留 `macos-gui-acceptance` 人工验收项）
- `I-4` 的 ②③④ 渲染断言（macOS AppKit 警报平台限制，产品负责人 2026-09-14 已裁定接受现状记账）
- `ATL-271` / `ATL-272`（保持 Backlog 跟踪）
