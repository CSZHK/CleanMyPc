---
name: iteration-governance
description: Atlas 仓库的迭代治理流程——REQ/CHG 追溯包结构、Contract/Sync/Validation 三道 Gate、子代理委派模板与子代理治理（准入标准、命名避撞、工具集最小化、写边界、退役、经验回流台账）、.agent 工作草稿与 findings/investigation 分工、UC/INV/CONTRACT/infra 升级规则。非 trivial 任务开始前、新建或更新 REQ/CHG 时、委派子代理前、新增或修改 .claude/agents/*.md 时使用。
---

# 迭代治理

## 实现状态（读之前先看这条）

**`bin/ato-iter` 与 `.harness/*` 结构化镜像尚未实现** —— 2026-06-10 产品负责人会话已确认接受缺失。治理流程当前以 `changes/CHG-*/{brief,verify}.md` + 手工执行验证命令等价替代。

下文凡引用 `bin/ato-iter` 子命令处均为**目标设计**，落地前**不作为发版阻塞门**；不应将其缺失误报为治理缺口，也不要为了"补齐"去实现它——那是产品负责人的决策，不是 agent 的。

## 真相存放地

| 内容 | 位置 | 权威性 |
|------|------|--------|
| 长期产品真相 | `Docs/product/*`、`Docs/design/*` | 规范真相源 |
| 需求级长期追溯 | `iterations/REQ-*` | 规范真相源 |
| 单次执行 | `changes/CHG-*` | 规范真相源 |
| 工作草稿 | `.agent/<task>-*.md` | 临时，须回写上游 |
| `.harness/*` | — | **仅**结构化镜像与执行证据，不得作为规范真相源，不得取代 `Docs/` 或 `changes/` |

根目录 `task_plan.md`、`findings.md`、`progress.md`、`investigation.md`、`live-map.md`、`requirements.md` 不得充当项目级权威计划；若存在只能作临时草稿，必须回写到 `.agent/*` 或 `iterations/*`。

## 三道 Gate

对 Codex / Claude Code 这类 coding agent：

1. **Contract Gate**（非 trivial 任务开始前）：装载 `CLAUDE.md`、ExecPlan、相关 `REQ` / `CHG`。
2. **Sync Gate**（编辑前、委派前、重大决策前、最终答复前各过一次）：确认手上的事实与上游真相一致。
3. **Validation Gate**（收尾）：`doctor + verify + 真实验证` 全通过才算过。两条门禁卫生规则：
   - **覆盖性逐维独立核验** —— 一份规格/变更的完整性有多个维度（finding→契约、→不变量、→波次、→验证协议…）。**任一维 100% 覆盖不构成其他维也覆盖的证据**：各维表格往往各自自洽，而彼此之间从没有人核过。收尾时对**每一维**分别做闭合复算（总数 / 零重复 / 零遗漏），并用脚本计数而非目测。
   - **门禁命令必须区分「跳过」与「通过」** —— 脚本在前置条件不满足时 `exit 0` 会让门禁**假绿**（跑零个测试也报成功）。把任何脚本写进门禁之前，先确认它在「前置不满足」时的退出码语义；`Skipped` 一律计 `NOT RUN`，不得计 `Pass`。

## 工作草稿约定

- 非 trivial 工作默认使用 `.agent/<task>-execplan.md`。
- 研究密集或跨会话任务同时维护 `.agent/<task>-findings.md` 与 `.agent/<task>-progress.md`。
- 复杂 bug / 协议 / 状态链路排查额外维护 `.agent/<task>-investigation.md`；若主体是当前代码地图，可命名为 `.agent/<task>-live-map.md`。**当前零实例** —— 这两类为条件触发，零实例只说明近期没有触发条件的任务，不是治理缺口。
- **恢复顺序固定**：`execplan → findings → investigation/live-map(如有) → progress → 工作树`。
- `execplan.md` 含 `## Surprises & Discoveries` 节，用于承载本次运行的意外发现（也是子代理回流 L1 的落点，见「子代理治理」D9）。**该节是回流机制的前提** —— 缺了它，L1 落点悬空。
- `findings.md` **只做摘要索引**，不承载长篇调查正文；详细链路、root cause、不变量提取进入 `investigation` / `live-map`。
  **越界判据看结构，不看行数**：出现 `## Current State Analysis` / `## Competitive Analysis` / `## Risk Assessment` 一类**论述性二级节**，或出现**逐文件证据表格**，即为越界。
  **行数不是判据** —— 链接式索引天然会随条目增长（`.agent/calm-ledger-round21-findings.md` 38 行仍是合规索引）。用行数当阈值会误报合规文件。
- Local-Only `investigation/live-map` 中沉淀出的长期约束、稳定链路或共享排障入口，必须升级回受版本控制的规则、架构或追溯文档。这条是**无条件**的；「子代理治理」D9 的 T1–T4 是**子代理运行经验**的额外通道，两者不冲突：D9 管「agent 自己的教训」，本条管「排查出的技术约束」。

## REQ 最小协议

每个新 REQ 包至少包含 `requirement.md`、`tasks/`、`trace.md`。

新建或显著更新 `REQ` 时优先补齐：

- `requirement.md` — `Change Class`、`Truth Sources`、真实 `Acceptance`
- `trace.md` — `Validation Protocol`、`Blast Radius`、`Required Validation Modules`、`Docs Sync`、`Planned/Actual Verification`、`Actual Deliverables`

如存在 `Close Gate` 字段，完成态优先以该字段为准。

## CHG 约定

- 单次执行入口只落在 `changes/CHG-*`。
- `brief.md` 是 canonical change root，`verify.md` 是该 change 的验收协议源。

## 子代理委派模板

委派至少写明六项：

- `Objective`
- `Read Scope`
- `Write Scope`
- `Acceptance Slice`
- `Stop Condition`
- `Handback Format`

## 子代理治理

`.claude/agents/*.md` 是项目级 subagent 定义。**新增、修改、退役都受本节约束。**

### D1 两类 agent 的区分（先读这条）

仓库里有两个都叫「agent」的东西，不要混用：

| | Persona Agent | Executable Subagent |
|---|---|---|
| 是什么 | 角色，人对职责的署名 | 进程，Claude Code 可委派的运行时单元 |
| 定义在哪 | `Docs/README.md` 的 Ownership 节 | `.claude/agents/<name>.md` |
| 有无工具集 | 无 | 有（frontmatter `tools:`） |
| 命名形态 | `Product Agent` / `QA Agent` | `gate-runner` / `release-prep` |

Persona 名册（9 个）是 `Docs/Backlog.md` 里 issue 的 `Owner Agent` 署名来源。
**新增 executable subagent 必须声明它服务哪个 persona**，否则仓库里会出现两套互不相识的 agent 命名世界。

当前映射：

| Subagent | 服务的 Persona |
|---|---|
| `gate-runner` | `QA Agent` |
| `macos-gui-acceptance` | `QA Agent` |
| `l10n-parity` | `Docs Agent` |
| `release-prep` | `Release Agent` |

> `l10n-parity` 归 `Docs Agent` 而非 `UX Agent`：判据是**同类工作在 `Docs/Backlog.md` 里已由谁署名**。孤儿键清理（`ATL-272`）署的是 `Docs Agent`，同一 agent 的职责面不该跨两处漂移。有 Backlog 判例时**以判例为准**，不要凭 persona 描述自由裁量。

### D2 准入标准

三条**全中**才可新增：

1. **已复发，或按 roadmap / 迭代计划会复发** —— 不是「将来可能有用」。
2. **输入输出边界稳定** —— 不是一次性探索。
3. **需要上下文隔离、受限工具集，或固定模型档位** —— 三者至少中一。

**否定判据**：只是「这个活比较独立」而不满足 ①② 的，不建 agent，用 `.agent/<task>-execplan.md` 在主循环做。

### D3 命名与避撞

- 文件名 kebab-case，与 frontmatter `name:` 一致。
- **禁止与 persona 名撞** —— 不能叫 `qa-agent.md`，那会与 persona 层混淆。
- 新增前先查一遍 `.claude/agents/` 与 `Docs/README.md` 的 Ownership 节。

### D4 工具集最小化

从**实际动作**反推工具，不从「可能需要」反推。

- 只读 + 回填表格 → 不需要写入工具。
- 需要写文件 → **`Write` 与 `Edit` 都算写入工具**，任一出现即触发下一条。
- 有写入工具 → **必须在正文写明写入白名单目录**（例：`macos-gui-acceptance` 的 `.claude/bugs/<name>/`、`gate-runner` 的 `changes/CHG-*/verify.md` 表格行）。

### D5 写边界

两层防线，缺一不可：

- `## 委派协议` 的 `Write Scope` 项 —— 被委派时由控制器给定。
- 正文的 `## 红线` 节 —— agent 的自我约束。

**`## 红线` 是四份 agent 共用的固定节名**，不得改名（曾出现 `硬约束` / `安全红线` / `绝对禁止` 三种别名，导致本节指称失效）。新增 agent 一律用 `## 红线`。

**`.claude/agents/**` 永久在所有 subagent 的 Write Scope 之外**（理由见 D9 自修改边界）。此处「所有 subagent」**不含**控制器与人工 —— 合入与退役动作恰由他们执行。

### D6 模型档位

默认**不写** `model:`（继承会话模型）。仅当该 agent 需要与控制器不同档位时才显式写，并在 `description` 说明理由。

当前 4 个 agent 均未写 `model:` —— **暂无实例**，此条为前瞻条款。

### D7 委派协议

见上文「子代理委派模板」六项。此处不复制。

### D8 升级给人

沿用 `UC / INV / CONTRACT / infra`。**治理专属**追加三项：

- 任何**改变约束**的 retro 提案 —— 加或减工具、扩或收 Write Scope、增或删 Stop Condition、改 `model:`。
  **「收窄」与「放宽」同等对待**：收紧同样是改契约，不能由控制器自行合入（曾漏掉「收」导致收窄 Write Scope 可绕过人审）。
- 新 agent 准入（D2）
- agent 退役（D10）

### D9 回流与进化

**证据分级放，不要都往一处堆。**

| 层 | 位置 | 生命周期 |
|---|---|---|
| L1 运行事实 | `.agent/<task>-execplan.md` 的 `## Surprises & Discoveries` | 随任务死 |
| L2 跨 agent 教训 | 本文档的「Agent 教训台账」 | 长期 |
| L3 agent 定义进化 | `.claude/agents/<name>.md` 的 `## 反模式（实测）` | 随 agent 退役 |

**触发条件**（不是每次都回流 —— 那会让台账变成没人读的流水账）：

| # | 触发 | 判定 |
|---|---|---|
| T1 | 被控制器打回 | 六项缺项退回，或交付不合格需重做 |
| T2 | Stop Condition 被触发 | agent 在 `## 停止条件` 列出的任一情形上停下 |
| T3 | 同类失败第二次出现 | 见下方「T3 怎么判」 |
| T4 | 既有约束被证明不够 | 实测发现必须扩/收 Write Scope 或改工具集才能完成 Objective |

**T3 怎么判。** T3 需要计数器，而计数器就是 L2 自己 —— 所以：

- **T1 / T2 命中时必须写 L2**，这是唯一的记账动作，不是可选项。此时若还没有可点击的去向，`去向` 列写 `待提升` —— **这是台账里唯一允许的非路径值**。
- 控制器合入时先比对 L2 是否有**同类**条目。有 → 命中 T3，把该条从 L2 提升进 L3（agent 的 `## 反模式（实测）`），`去向` 改成实际路径。
- **「同类」= 同 agent + 同根因。** 跨 agent 的相似问题不算同类，但控制器合入时应把它们抽象成一条 —— 这是控制器作为跨 agent 视角的主要价值。

**T3 是这套机制的核心**：单次教训不该改 agent 定义（噪声），重复教训必须改（否则就是写死）。

**排除规则**：纯环境性阻塞（服务端过载、权限未就绪、无 bundle 环境崩溃）**只进 L1，不进 L2**。环境阻塞要如实报告并停止，不构成方法论教训。

**自修改边界**：agent **不得**写 `.claude/agents/**`，包括它自己的定义文件。
`tools:` 是 Claude Code 运行时读取的权限清单 —— 能自改就能给自己加 `Write`、编辑掉白名单、删掉停止条件。其中**改 Stop Condition 最危险**，它承载着人工确认点。

agent 只能产出 **Retro 提案**（见各 agent 的「回传形态」），由控制器合入。

**控制器是谁**：指**委派该 agent 的主循环会话**，不是某个 agent 定义文件。仓库里**没有也不需要** `controller` agent 定义 —— 它是会话角色。

**合入时机与责任**：每次 `changes/CHG-*` 收口前，控制器检查本 CHG 期间产生的全部 Retro 提案，逐条按上述规则合入；命中 D8 的转人工。**没有这一步，台账与 carry-forward 断链是同一个病** —— 所以它是收口动作的一部分，不是「有空再说」。

### D10 退役

触发任一：

1. 连续两个 REQ / CHG 周期未被委派。
2. 职责已被 skill 或脚本吸收。
3. 约束与现行约定冲突且无法收敛。

动作：从 `.claude/agents/` 移除文件 + 在台账记一条 `去向 = 退役（理由）`。**不静默删除。**

### D11 与 `Docs/Templates/AGENT_HANDOFF_TEMPLATE.md` 的关系

该模板是**指针**，不是委派协议的副本 —— 权威定义只有上文六项。模板内含一张「六项 ↔ 旧五节」映射表供老读者迁移。

## Agent 教训台账

跨 agent 的流程教训。**`去向` 列必须指向可点击的既有路径，不得写「待办」** —— 这是防止教训「记录了但不会做」的唯一机制（对照：`.agent/calm-ledger-round21-execplan.md` 的 C1/C2 曾只落到 `iterations/REQ-calm-ledger-redesign/trace.md` 这条只增时间线，无 owner、不被排期）。

| 日期 | Agent | 触发 | 教训 | 去向 |
|------|-------|------|------|------|

当前无条目 —— 首条在下次命中 T1–T4 时登记。

- `日期` 填**事件发生日**（由 agent 在 Retro 提案里给出），**不是合入日**。批量合入会让时间序塌缩，T3 的「第二次」就判不出来。
- `Agent` 填 subagent 名；控制器自身的教训填 `控制器`。
- 产品类遗留项**不进本表**，走 `Docs/Backlog.md` 的 `## Process & Governance Backlog`。

## 升级给人（不允许默认自主变更）

命中 `UC / INV / CONTRACT / infra` 时必须升级给人。

## 目标设计：`bin/ato-iter` 命令面（未实现）

保留设计意图，便于将来落地；当前**不要**假设这些命令可用。

```
bin/ato-iter new --title "<title>"
bin/ato-iter chg new --req-id <REQ-ID> --task-id <TASK-ID> --title "<title>"
bin/ato-iter chg verify --chg-id <CHG-ID>
bin/ato-iter acceptance sync --chg-id <CHG-ID>
bin/ato-iter baseline run --chg-id <CHG-ID>
bin/ato-iter state get --chg-id <CHG-ID>
bin/ato-iter state set --chg-id <CHG-ID> --status <status>
bin/ato-iter eval record --chg-id <CHG-ID> --verdict PASS|FAIL|BLOCKED
bin/ato-iter doctor
bin/ato-iter verify --req-id <REQ-ID>
bin/ato-iter delegation-template --req-id <REQ-ID> --task-id <TASK-ID>
bin/ato-iter close-check --req-id <REQ-ID>
bin/ato-iter stale-review --days 14
bin/ato-iter sync-index
bin/ato-iter handoff --req-id <REQ-ID>
```

已定下的语义约束（落地时不得违反）：

- `close-check` 只服务 DVP-1 / normalized REQ，且 `Planned Verification` 至少要有一条非 `doctor/verify/close-check/sync-index` 的真实验证命令；旧 REQ 若仍使用复杂 shell/here-doc 验证计划，必须先规范化，再用该命令收口。
- `repair-minimums` 不能通过合成 `Close Gate: NOT_RUN` 去重开历史已完成 REQ。
- `stale-review` 的最近活动必须来自持久化信号，不允许依赖 checkout-time 文件 `mtime`。

## 分层边界

- `AGENTS.md`（仓库根）= 工具无关层：构建命令、环境变量、本地化/XcodeGen/Landing 约定、Attribution。Claude Code 通过 `CLAUDE.md` 的 `@AGENTS.md` 导入。
- `CLAUDE.md` = Claude 专属层：本 skill 的指针、gstack 浏览约束、治理速查。
- 本 skill = 治理的完整流程（按需加载）。

同一条约定不得在 `AGENTS.md` 与 `CLAUDE.md` 双写：工具无关内容只落 `AGENTS.md`，Claude 专属内容只落 `CLAUDE.md`。若治理约定将来下沉到 `AGENTS.md` 的治理节，须从其原位置移除，不得两处并存。
