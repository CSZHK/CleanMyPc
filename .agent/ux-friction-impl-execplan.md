# ux-friction-impl — ExecPlan（实现阶段）

> ⚠️ **本文件已降级为「支撑笔记」**（2026-09-14）。**唯一可恢复入口**是
> `.agent/autopilot-ux-friction-remediation-execplan.md`（铁律：一个任务只有一个可恢复计划）。
> 本文件保留的是 Wave 0–1 的实测教训（S1–S6）与材料索引，不再作为恢复指针。

## Objective

在 Atlas 仓库实现 `Docs/design/2026-09-14-ux-friction-remediation.md`（**唯一实现权威**），范围 Wave 1–3。交付形态：Wave 0 术语基线签字 → 逐波 REQ/CHG 追溯包 + 三条门禁收口。

## Status

**Wave 0 已签字。Wave 1 已落地契约一/二/三 + `I-1`/`I-5`/`I-6` 守卫，三条门禁零新增失败；但守卫基座（UI 状态注入）未建，`I-2`/`I-3`/`I-4` 记 `NOT RUN` → 未达收口条件。** 另有一处对 N-4 的偏离待追认。

分支 `iter/ux-friction-remediation`（未 push；**禁止直接在 main 上提交**）。

## 材料与权威顺序

1. `Docs/design/2026-09-14-ux-friction-remediation.md` —— 实现规格（6 契约 / §7 12 不变量 / §8 40 条映射 / §9 三波交付 / 附录 B 不做项）
2. `Docs/Execution/UX-Friction-Remediation-Design-Gate-Review-2026-09-14.md` —— 评审记录与 Remaining Limits
3. `Docs/Execution/UX-Friction-Audit-2026-09-14.md` —— 上游诊断（40 条 finding 原始描述）
4. `iterations/REQ-ux-friction-remediation/` —— 本 REQ 追溯包
5. `AGENTS.md` / `.claude/skills/iteration-governance/SKILL.md`

**规格与代码不符时：停在那一处并报告，不自行调和。**

## 硬门禁（不可违反）

1. **Wave 0 先做**：产出契约四术语基线 → **停下交产品负责人签字** → 未签字前**不得改任何 P0 文案**
2. 波次顺序 Wave 1 → 2 → 3，不跳波、不合并
3. 命中 CONTRACT 的改动（契约四术语体系、`P1-18` 触 `AtlasAppCommands`、`D-012`）必须产品负责人签字，不得自主合入
4. `Skipped` 计 `NOT RUN`，不计 `Pass`；该波不得在 `NOT RUN` 下收口（除非显式 `ATLAS_ALLOW_UI_SKIP=1` 并在回执写明）
5. 守卫基座属该波交付物；基座缺失时不变量记 `NOT RUN`

## 进度

| 波次 | 状态 | 产出 |
|---|---|---|
| Wave 0 | **产出完成，待签字** | `terminology-baseline.md`（T-19 / S-10 / N-10 / 4-A×8 / R-6）+ REQ/CHG 包 |
| Wave 1（P0） | **进行中（未收口）** | 契约一模型层 + `P0-1`/`NEW-1` + 三态控件 + `I-1` 守卫已落地并绿；契约二/三、守卫基座、收口待续 |
| Wave 2（P1） | 未开始 | — |
| Wave 3（P2） | 未开始 | — |

## 三条门禁（每波缺一不可）

```bash
swift test --package-path Packages
swift test --package-path Apps
./scripts/atlas/run-ui-automation.sh
```

## Surprises & Discoveries

### S1. `P1-5` 的证据落点比规格写的多一处（已在 Wave 0 报告，未调和）

规格 §3.1 引 `fixture.permission.fullDiskAccess.rationale`（zh:80）为「实机渲染原文」。回源：

- `PermissionRowView.swift:28` 绑定 `subtitle: state.rationale`
- 运行时 `state.rationale` 由 `AtlasPermissionInspector.swift:95-99` 产出 → 取自 `infrastructure.permission.fullDiskAccess.needed`（zh:122）
- **两个 key 都含 `Library`，但只有 fixture key 含「系统级缓存」**
- `fixture.*` 不是死键：空状态脚手架 `AtlasScaffoldWorkspace.state()`（`AtlasApplication.swift:123`）会渲染它

**处置**：按硬门禁「不自行调和」，只在 `terminology-baseline.md` §4-B 记录事实并把两处都列入对齐清单（A-3）。**Wave 2 实现时两处都要改。**

### S2. `OverviewRecommendationTests.swift:56` 有一条会被 `P1-1` 推翻的断言

该测试现断言「permission banner is never snoozeable」。`P1-1` 要求补「稍后」出口 → 该断言必须同步更新。**Wave 1 若只改实现不改测试，会红。**

### S3. AX 已授权 —— 第三条门禁真实可跑（Wave 1 实测）

`ui-automation-preflight.sh` → `Accessibility trusted for current process: true`，exit 0。
故 `run-ui-automation.sh` **真实执行**（不是 `Skipping native UI automation`），本机可承载 UI 层不变量。
这解除了 Wave 0 设计评审 `Remaining Limits` 里的最大未覆盖项在**本机**的适用性。

### S4. **既有 4 条 XCUITest 在 HEAD 上就红 2 条**（本波未引入）

Wave 1 跑第三条门禁得到 `Executed 4 tests, with 2 failures`（exit 1）。为定性，在 `HEAD`（`94a0722`）的独立 worktree 跑同一条命令作基线：**同 2 条、同行号**。

- `testSmartCleanAndSettingsPrimaryControlsExist` @ `:56` —— Settings 屏不可达（根因 = `P1-18`，Wave 2）
- `testKeyboardShortcutsNavigateAndOpenTaskCenter` @ `:75` —— ⌘5 期望 Permissions，实际 ⌘5 = `.ledger`

**教训：`run-ui-automation.sh` 的「假绿」有两种，之前只防住了一种。**
先前只认「未授权 → Skipped → exit 0」这一种假绿（已由 `full-acceptance.sh` 的 `NOT RUN` 断言兜住）。但**已授权环境里还有第二种：套件长期红着没人看** —— 因为未授权环境把它整体跳过了，红从未被任何人观察到。**要判断「本波有没有引入失败」，必须先有 HEAD 基线**，不能只看当前 exit code。

**规避方式**（已用于本波）：任何涉及 UI 门禁的波次，收口前先在 `git worktree add --detach <tmp> HEAD` 里跑同一条命令拿基线，用**差集**判定，而不是用绝对绿。

**已裁定（2026-09-14）**：采用**增量门禁** —— 以 HEAD 基线为准，不新增失败即可收口；2 条红挂账 Wave 2。

### S5. 规格 §1.2(3) 与 fail-closed 红线冲突（`P1-11`/`P1-14`）

规格要求失败态渲染「已处理 / 未处理计数」；但 worker 未返回就失败时这些数**无从确认**，而 §1.6 的 fail-closed 纪律禁止编造。取 fail-closed，把 N-4 的措辞改为「已选 %d 项 · 处理结果无法确认」，**登记为对已签字基线的偏离待追认**。

### S6. 「回执存在但无恢复项」这一态**无法冷启动注入** —— 守卫基座的真实难点

`I-2` / `I-3` 要断言的态需要「执行回执存在 + 恢复项为空」。但执行回执（`smartCleanExecutionReceipt`）是**内存态、不落盘**，`ATLAS_STATE_FILE` 的冷启动快照造不出来；而走到该态需要执行一次真实清理（破坏性）。

**结论**：这正是规格 §9 纪律 4 把「UI 测试的状态注入能力」列为**守卫基座**的原因 —— 不加一条按启动环境变量驱动的 app 内测试接缝，这两条不变量永远只能 `NOT RUN`。**下轮的第一件事。**

## 下一步

1. ~~Wave 0 签字~~ —— **已完成（2026-09-14）**，R-1–R-6 已逐项裁定
2. **Wave 1 续做**（按 `tasks/wave1-p0.md`）：契约二的四问组件 + 三条弹窗 → 契约三 (1)(2)(3) → 守卫基座（`AtlasAppUITests` 新用例）→ 收口
3. **待裁定**：Wave 1 收口判据（既有 UI 红算阻塞 vs 增量门禁）—— 见 S4 与 `verify.md`
4. Wave 2 开工前另需 `P1-18` 的 CONTRACT 签字（解冻记录第 2 项）

## 禁止

- 不新增第三方依赖；不改设计系统既有 token；不写 `.claude/agents/**`
- 不改 `AtlasScaffoldWorkerService` 的恢复语义与 fail-closed 判定（规格 §1.3）
- 附录 B「明确不做」逐条不碰；直接在 main 上提交
