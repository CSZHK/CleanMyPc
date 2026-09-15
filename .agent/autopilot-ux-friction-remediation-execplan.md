# Autopilot: UX 摩擦修复（REQ-ux-friction-remediation）剩余波次

## Meta
- **Status**: IN_PROGRESS
- **Created**: 2026-09-14
- **Task Slug**: ux-friction-remediation
- **Estimated Phases**: 6
- **Mechanisms**: execplan / direct / 并行子代理（gate-runner · l10n-parity · macos-gui-acceptance）/ AskUserQuestion
- **Cross-Session**: yes
- **规模/类型**: L / migrate（判据见 Decision Log D1）

> **单一恢复入口**：本文件。`.agent/ux-friction-impl-execplan.md` 已降级为**支撑笔记**（保留 S1–S6 的实测教训），不再是恢复指针。

## Task Summary
自驱推进 `REQ-ux-friction-remediation` 的剩余波次（Wave 1 收口 → Wave 2 → Wave 3），按已定的逐波硬门禁交付并用三条门禁收口。

## 不可违反的硬门禁（来自 REQ + 用户指令）

1. 波次顺序 Wave 1 → 2 → 3，**不跳波、不合并**
2. 命中 CONTRACT 的改动（契约四术语体系、`P1-18` 触 `AtlasAppCommands`、`D-012`）**必须产品负责人签字**
3. 每波收口跑三条，缺一不可：
   `swift test --package-path Packages` / `swift test --package-path Apps` / `./scripts/atlas/run-ui-automation.sh`
4. `Skipped` 计 `NOT RUN`；**守卫基座缺失时该不变量记 `NOT RUN`，不得报 `Pass`**
5. **增量门禁**（已裁定）：第 3 条以 HEAD 基线取差集，不新增失败即可收口
6. 不新增第三方依赖；不改设计系统既有 token；不写 `.claude/agents/**`；不改 `AtlasScaffoldWorkerService` 的恢复语义与 fail-closed 判定；附录 B 逐条不碰；不在 main 上直接提交

## Phases

### Phase 1: Wave 1 收口 —— 守卫基座 + `I-2`/`I-3`/`I-4`
- **Mechanism**: direct
- **Input**: Wave 1 实现已落地（14 finding），三条门禁零新增失败；`I-2`/`I-3`/`I-4` 因缺守卫基座记 `NOT RUN`
- **Action**:
  1. 在 `AtlasAppModel` 加**启动环境变量驱动的测试接缝**（`#if DEBUG`），提供两个 fixture：
     - `receipt-no-recovery` —— 执行回执存在 + 恢复项为空（`hasRestorePoint == false`）
     - `review-executable` —— ② 复核页有可执行的新鲜计划（用于打开破坏性弹窗）
  2. 在 `Apps/AtlasAppUITests` 补用例：
     - `I-2`：FO 回执 → 撤销控件 `exists == true` ∧ `isEnabled == false` ∧ 同屏有理由文案
     - `I-3`：Smart Clean 回执 → 同上（**隐藏即判失败**）
     - `I-4`：`confirm.destructive.{object,destination,recovery,recoverableCount}` 四项渲染断言
  3. 跑三条门禁 + HEAD 基线差集
  4. 关闭 `CHG-2026-09-ux-friction-wave1`
- **Checkpoint**: 三条命令有输出；第 3 条零新增失败；`I-2`/`I-3`/`I-4` 由 `NOT RUN` 变为**已挂且实测通过**（或如实记 NOT RUN 并说明）
- **Output**: `changes/CHG-2026-09-ux-friction-wave1/verify.md` 收口
- **Status**: ✅ **COMPLETED** —— 守卫基座建成；`I-2`/`I-3` 已挂且实测通过；`I-4` 主载体（构造器非可选 + 类型区分）已完成、渲染断言按平台限制如实降级记账；三条门禁零新增失败

### Phase 2: 三项人工裁决
- **Mechanism**: AskUserQuestion
- **Input**: Phase 1 完成
- **Action**: ① `P1-18` 的 **CONTRACT 签字**；② Wave 1 CHG 关闭确认；③ **`I-4` 的 ②③④ 渲染断言**：接受现状记账，还是把三条弹窗从 `.confirmationDialog` 换成自绘 sheet（后者能让四问全进可访问性树，属 UI 形态变更）
- **Checkpoint**: 签字落 `requirement.md` 的 `## Contract Unfreeze Record`
- **Output**: 签字记录
- **Status**: ✅ COMPLETED（三项裁定均已落 `requirement.md`）

### Phase 3: Wave 2 实现
- **Status**: ✅ COMPLETED（11/11 finding 关闭；`I-7`/`I-8` 已挂且全绿）
- **Mechanism**: direct（+ 定点子代理）
- **Input**: Phase 2 签字
- **Action**: 契约三余项（`P1-5` `P1-6` `P2-8`）· 契约六 `P1-7` `P1-18` · 契约四 `P1-4` `P1-13` `P1-15` · 契约五 `P1-9` `P1-12` `P1-16`；守卫 `I-7` `I-8` `I-11`
  - `I-11` 的三个前置**顺序不可颠倒**：访问级别提权 → `shortcutKey` 返回 `KeyEquivalent?`（**CONTRACT，已签字**）→ 断言 `AtlasRoute.sidebarRoutes`；守卫落 **`Apps/AtlasApp/Tests/AtlasAppTests/`**
- **Checkpoint**: 三条门禁 + 零新增失败
- **Output**: `changes/CHG-2026-09-ux-friction-wave2/`

### Phase 4: Wave 2 收口
- **Mechanism**: direct 判定（三条门禁实测）
- **Status**: ✅ COMPLETED —— `609/0` · `68/0` · UI `9 tests / 0 failures` EXIT 0（HEAD 基线 `4/2`）

### Phase 5: Wave 3 实现
- **Status**: ✅ COMPLETED（15/15 finding 关闭；`I-10`/`I-12` 已挂且全绿）
  - **更正（2026-09-15 复审）**：原记「`I-9` 显式 `NOT RUN`」**已过时**。`taskcenter-many-runs` fixture 改走
    **读取侧**（`AtlasAppModel.taskCenterTaskRuns`）后，`I-9` 守卫已挂且实测通过 —— 见 `changes/CHG-2026-09-ux-friction-wave3/verify.md`
    与本次复审实测（`11 tests, 0 failures`，其中 `testTaskCenterStatesTruncation` passed，且它是**无条件**断言、非空转）。
- **Mechanism**: direct（+ 子代理 `l10n-parity`）
- **Input**: Phase 4
- **Action**: 契约五 P2 层 · 契约六 `P2-9` `P2-12` · 契约四 P2 层改词 + **双语术语表回写 `Docs/COPY_GUIDELINES.md` §Glossary** + **产品内术语入口**；守卫 `I-9` `I-10` `I-12`

### Phase 6: Wave 3 收口 + REQ Close Gate
- **Status**: ✅ COMPLETED（收口结论本身于 2026-09-15 复审被判定不可采信 —— 见下方「复审裁定」）
- **Mechanism**: direct + 子代理
- **Action**: 三条门禁 + L10n parity + 全量维度闭合复算 + REQ `Close Gate`

## 复审裁定（2026-09-15）—— 本计划的完成态**不再是** REQ 的收口依据

本计划各 Phase 已全部 `COMPLETED`，但复审以**变异检验**证明其中至少 4 条不变量的守卫
「改坏产品代码仍不失败」（`I-11` 被 `inSidebar` 短路 / `I-8` 自证 / `I-10` 空集合判真 / `I-5` 只证赋值存在）。

- **REQ 状态**：已回退 `IN PROGRESS`；`trace.md` 的 `## Close Gate` 已追加失效范围标注。
- **修复与重验收**：`changes/CHG-2026-09-ux-friction-review-remediation/`。
- **本计划**：保持 `IN_PROGRESS` 的 Meta 状态不变，等待补丁单收口后再判定是否置 `COMPLETED`。
  **恢复时不要再从本文件重跑 Wave 2/3** —— 那两波已完成，重跑会覆盖已有产物。

## Recovery Protocol
恢复时按以下顺序读取：
1. 本文件（检查每个 Phase 的 Status）
2. `.agent/autopilot-ux-friction-remediation-progress.md`
3. `iterations/REQ-ux-friction-remediation/trace.md`（Actual Verification / Deliverables）
4. `changes/CHG-2026-09-ux-friction-wave*/verify.md`
5. `git status && git diff --stat`
6. 找到第一个非 COMPLETED 的 Phase，从那里继续

## Progress
- [x] 2026-09-14 Phase 0/1/2/3：分析 + 机制选择 + 计划确认（产品负责人）
- [x] 2026-09-14 N-4 偏离**已追认**（fail-closed 版）
- [x] 2026-09-14 Phase 1（大部分）：守卫基座建成（`ATLAS_UI_TEST_FIXTURE` 接缝 + `receipt-no-recovery` fixture + 3 条新用例）
      → **`I-2` ✅ / `I-3` ✅ 实测通过**；`I-4` ⚠️ 未过
- [x] 2026-09-14 Phase 1 收尾：修 `review-executable` fixture（两个真坑已修并固化自检）→ 3 条 UI 守卫全绿 → 三条门禁零新增失败 → **CHG-2026-09-ux-friction-wave1 已收口**
- [x] 2026-09-14 Phase 2：三项裁定全落（`P1-18` 签字 / Wave 1 CHG 关闭 / `I-4` 接受现状记账）
- [x] 2026-09-14/15 Phase 3+4：**Wave 2 完成** —— 11/11 finding 关闭，`I-7`/`I-8` 已挂，三条门禁全绿
- [x] 2026-09-15 Phase 5+6：**Wave 3 完成并收口**（15/15；三条门禁 `612/0` · `68/0` · UI `11 tests, 1 skipped, 0 failures` EXIT 0）
- [x] `P2-1` 产品内术语表入口 + 双语术语表回写 `Docs/COPY_GUIDELINES.md` 均已完成
- [ ] ~~Phase 5 Wave 3 实现~~：契约五 P2 层（`P2-6` `P2-7` `P2-10` `P2-11` `P2-13` `P2-14` `P2-15` `P2-16`）· 契约六 `P2-9` `P2-12` · 契约四 P2 层（`P2-1`..`P2-5`）+ **双语术语表回写 `Docs/COPY_GUIDELINES.md` + 产品内术语入口** · 守卫 `I-9` `I-10` `I-12`

## Decision Log

- **D1（类型判定）**：归 `migrate` 而非 `deliver`。理由：无 design→implement→review→qa 金路径，是按**已签字规格 + 既有 REQ/CHG** 逐波落地；且用户已给定逐波硬门禁。entry-map 规定 feature 型走 `auto`，本判定有边界性，已在 Phase 3 前向用户明示「可推翻」。
- **D2（不建 Agent Teams）**：改动强耦合于 `AtlasAppModel` / 组件 / 两份 strings，并行 teammate 会互踩；状态真相在 REQ/CHG 而非多角色协调。取「并行子代理」档。
- **D3（N-4 追认）**：产品负责人 2026-09-14 追认 fail-closed 版（「已选 %d 项 · 处理结果无法确认」）。
- **D4（单一恢复入口）**：`.agent/ux-friction-impl-execplan.md` 降级为支撑笔记，避免两套恢复指针。
