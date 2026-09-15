# REQ-ux-friction-remediation Trace

## Validation Protocol
- 每波：`swift test --package-path Packages` + `swift test --package-path Apps` + `./scripts/atlas/run-ui-automation.sh`（**三条缺一不可**）
- **`Skipped` 计 `NOT RUN`，不计 `Pass`** —— 第三条命令在 AX 未授权时打印 `Skipping native UI automation` 并 `exit 0`。波次**不得在 `NOT RUN` 状态下收口**；本地确知无 AX 时用**显式** `ATLAS_ALLOW_UI_SKIP=1` 豁免并在回执写明接受覆盖缺口
- `swift test` **跑不到 XCUITest**（需 `xcodebuild test`）—— §7 里 I-2 / I-3 / I-7 / I-8 / I-9 / I-10 / I-12 的守卫载体全在 `AtlasAppUITests`，漏跑第三条 = 守卫「写了但永不执行」
- 需要权威结果时可绕过 preflight 直连：
  ```bash
  xcodegen generate && xcodebuild test -project Atlas.xcodeproj -scheme AtlasApp \
    -destination 'platform=macOS' -only-testing:AtlasAppUITests
  ```
- L10n 门禁：zh/en 键集合 parity + 占位符零不对称（Wave 3，委派 `l10n-parity`）
- AX 层人工验收项：I-5 的不可自动化那一半（委派 `macos-gui-acceptance`）

## Blast Radius
见 `requirement.md` 的同名节。要点：`AtlasAppModel` 公开 API 变更（触 `AppShellView` 调用点 + `AtlasAppModelTests` fixture）、`AtlasAppCommands`（CONTRACT）、两份 `Localizable.strings`、6 个 feature 包、`AtlasAppUITests` 新用例。
**不触碰**：`AtlasProtocol` / XPC / Helpers / Go / `AtlasScaffoldWorkerService` 的恢复语义与 fail-closed 判定 / 设计系统既有 token。

## Required Validation Modules
- `swift test --package-path Packages`
- `swift test --package-path Apps`
- `./scripts/atlas/run-ui-automation.sh`（XCUITest）
- 手工/委派：`macos-gui-acceptance`（I-5 人工验收项 + AX 层断言）

## Docs Sync
- `Docs/COPY_GUIDELINES.md` §Glossary —— **Wave 3** 回写双语术语表（本文 §0 的「不双写」约定）
- `AGENTS.md` —— 「UI 门禁（易踩）」已同步（2026-09-14）
- `Docs/Backlog.md` —— `P1-18` 与前身 REQ 的欠账关系已在审计正文留痕；`ATL-271` / `ATL-272` **保持 Backlog 跟踪，不在本 REQ 范围**
- `Iterations/REQ-ui-ux-overhaul` —— **不改**（其 Status = DONE 的历史判定不被本 REQ 追溯修改；`P1-18` 在审计里已注明「不是重复上报已完成项」）

## Planned Verification
| Phase | Verify Command | Status |
|-------|---------------|--------|
| Wave 0 | 术语基线逐条回源 + 维度闭合复算（脚本计数） | **PASS（2026-09-14，签字）** |
| Wave 1 | 三条门禁命令 + I-1..I-6/I-12(部分) 守卫 | **PASS** |
| Wave 2 | 三条门禁命令 + I-7/I-8/I-11 守卫 | **PASS** |
| Wave 3 | 三条门禁命令 + I-9/I-10/I-12 守卫 + L10n parity | **PASS** |

## Actual Verification
（执行时填写）

### Wave 1 / 2 / 3（2026-09-14 ~ 09-15）
- 逐波实测见 `changes/CHG-2026-09-ux-friction-wave{1,2,3}/verify.md`
- **UI 门禁的起点不干净**：HEAD 基线就是 `4 tests / 2 failures`（0 条新增失败即通过，增量门禁经产品负责人裁定）。本 REQ 收口时该套件为 `11 tests / 0 failures` —— 两条既有红一并修好（陈旧 ⌘5 期望 + 写死 AX 角色的断言）

### Wave 0（2026-09-14）
- 术语基线逐条回源：19 条核心术语的「现状 zh」列逐 key 对两份 strings 核对；S-1 的 `ds.ledger.status.archived` 双载体重载已回源 `LedgerTimelineView.swift:156` / `:167`；S-5 的冲突行为已回源 `AtlasScaffoldWorkerService.swift:777-795`（确认自动重命名、不覆盖）
- **回源核出一处规格与代码的落点差异**：见 `terminology-baseline.md` §4-B（`P1-5` 的「实机渲染原文」引的是 fixture key，运行时取数走 `infrastructure.permission.fullDiskAccess.needed`）。**按硬门禁要求只报告、不调和**，处理留给 Wave 2
- 维度闭合复算（脚本，非目测）：finding → 契约 40/40、finding → 波次 14+11+15=40、不变量 → 载体 12/12 —— 三维分别复算，**任一维不代言其他维**（该纪律来自 `REQ-calm-ledger-redesign` 的 S6 教训，已入 `iteration-governance` 的 Validation Gate）

## Actual Deliverables
（执行时填写）

### Wave 1 / 2 / 3（2026-09-14 ~ 09-15）
- 逐波实测见 `changes/CHG-2026-09-ux-friction-wave{1,2,3}/verify.md`
- **UI 门禁的起点不干净**：HEAD 基线就是 `4 tests / 2 failures`（0 条新增失败即通过，增量门禁经产品负责人裁定）。本 REQ 收口时该套件为 `11 tests / 0 failures` —— 两条既有红一并修好（陈旧 ⌘5 期望 + 写死 AX 角色的断言）

### Wave 0（2026-09-14）
- `iterations/REQ-ux-friction-remediation/terminology-baseline.md` —— T-01..T-19 / S-1..S-10 / N-1..N-10 / 4-A 对齐清单 8 条 / 开放项 R-1..R-6
- `iterations/REQ-ux-friction-remediation/{requirement.md,trace.md,tasks/wave0..wave3}`
- `changes/CHG-2026-09-ux-friction-wave0/{brief.md,verify.md}`

## Close Gate

> ⚠️ **本节结论于 2026-09-15 复审中被判定不可采信 —— 原文保留，仅追加失效范围。**
>
> 复审手段：**变异检验**（在 `/tmp` 导副本内改坏产品代码，确认守卫是否变红），非阅读判断。
>
> | 不变量 | 本节原声明 | 复审判定 | 根因 |
> |---|---|---|---|
> | `I-11` | 已挂且实测通过 | **守卫空转** | 析取式被 `inSidebar` 恒真短路；§7 表的载体定义本身弱于不变量 |
> | `I-8` | 已挂且实测通过 | **守卫自证** | 断言自己算 `n` 再造期望串，被测视图未读 |
> | `I-10` | 已挂且实测通过 | **守卫半段空转** | `measuredGroup.descendants` 恒为空集合 |
> | `I-5` | 按降级形式覆盖 | **守卫只证赋值存在** | 时序命题用存在性断言承载 |
>
> **仍成立**：`I-4` ②③④ 为唯一未覆盖项（平台限制）；**`I-9` 的 `NOT RUN` 记录属 `progress.md` 与 autopilot execplan 的陈旧值** —— `CHG-wave3/verify.md` 与本次实测均为「已挂且通过」。
>
> **修复与重验收**：`changes/CHG-2026-09-ux-friction-review-remediation/`。REQ 状态已回退 `IN PROGRESS`。

**Wave 0–3 全部 Planned Verification = PASS。**

- **finding**：40/40 实现落地；维度闭合复算（脚本）—— finding→契约 40/40、finding→波次 14+11+15=40、差集为空
- **三条门禁（Wave 3 收口实测）**：`swift test --package-path Packages` `612/0` · `swift test --package-path Apps` `68/0` · `run-ui-automation.sh` `11 tests, 0 failures, 0 skipped` **EXIT 0**（HEAD 基线 `4 tests / 2 failures`）
- **不变量**：12 条全部有载体且实测通过。**唯一未覆盖项**：
  - **`I-4` 的 ②③④ 渲染断言** —— macOS 把 `.confirmationDialog` 渲染成 AppKit 警报 sheet（标识被系统剥掉、正文只渲染首行），**平台限制**。产品负责人 2026-09-14 裁定「接受现状记账」；主载体（①②③ 构造器非可选 + ④ 类型区分）已完成并实测通过
- **`I-5`** 按降级形式（模型层断言 + `macos-gui-acceptance` 人工验收项）
- **AX 授权**：本机已授权，第 3 条门禁**真实执行**（不是 `Skipping native UI automation`）
- **术语表**：双语回写 `Docs/COPY_GUIDELINES.md` 完成 + 产品内入口（Settings「术语表」）—— 契约四 §0.2 的「只回写文档不算达标」两条都满足

### 遗留（供后续迭代，不阻塞本 REQ）
- 真实 ⌘, 按键行为 —— XCUITest 无法合成标点键的菜单等价物（对照实验已证），列入 `macos-gui-acceptance` 人工验收项
- `ATL-271` / `ATL-272` 按规格保持 Backlog 跟踪

---

### ⚠️ 二次失效标注（2026-09-15，`REQ-copy-plain-language`）

本 REQ 的 `terminology-baseline.md`（2026-09-14 签字版）被后续迭代**部分推翻**。原文保留，仅追加失效范围：

| 被推翻项 | 本 REQ 原结论 | 现结论 | 推翻者 |
|---|---|---|---|
| §1 **T-10** | `Ledger` /「台账」**保留**，`D-012 不重开` | 退役会计隐喻 →「历史记录」/ `History`；**`D-012` 反向撤销** | `REQ-copy-plain-language` 术语基线 P-1 + 裁定位 R-5 |
| §1 **T-12** | 对齐为「**应用足迹**」（R-2 裁定） | 退役 →「应用占用」/ `App Storage` | 同上 P-3（R-2 方向对、选词错） |
| §1 **T-14** | `Evidence` /「证据」保留，补解释 | 拆为「未删除项」/「分类依据」 | 同上 P-4 + P-5 + §2-A |
| §S-10 | 四个体系词「**保留用词、补解释**」 | 三词退役，术语表收缩到「残留 / 未删除项 / 恢复点」 | 同上 §3 |

**仍有效、未被推翻**：T-01..T-09 / T-11 / T-13 / T-15..T-19 的用词；§2 的**全部拆词与量词规则**（S-1..S-9）；§4-B 的回源核对记录。

**推翻理由（一句话）**：原基线的目标函数只有「消除歧义」，缺「用户第一次看到能不能懂」。为消歧引入的公文隐喻（台账 / 回执 / 入账 / 作废）使中文文案退化为法律文书。详见 `Docs/design/2026-09-15-copy-plain-language.md` §2。

**不修改本 REQ 的其余历史记录** —— 沿用本 REQ 自己处理 2026-09-15 复审时的既有先例（原文保留 + 追加失效范围，不改写）。
