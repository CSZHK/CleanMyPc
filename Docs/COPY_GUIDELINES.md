# Copy Guidelines

> **zh/en 双语。** 2026-09-15 由 `REQ-copy-plain-language` 补齐 zh 侧判据并重写语域规则。
>
> **为什么补 zh**：本文件此前 Tone / Product Voice / Good Patterns **全部为 en 单语**，中文侧从来没有语气规范。这不是排版疏忽 —— 它是 2026-09 那批中文文案退化成公文的**结构性根因**：写中文的人没有可依据的判据，只能向上游的设计规格要语言，于是规格句（「先解释为什么需要访问…」）被原样搬进了界面。
>
> **判据锚点**：受众 = **非技术 Mac 用户**（`Docs/design/2026-09-14-ux-friction-remediation.md:16`）。
> **执行判据**：`./scripts/atlas/copy-gate.sh`（可执行；本文件是**人读**的判据源，脚本是**机器读**的判据源，两者必须一致）。

---

## 1. 目标函数（两条，冲突时可读性优先）

1. **可读性** —— 非技术 Mac 用户第一次看到这个词/这句话，能懂吗？
2. **精确性** —— 它是否准确描述了实际会发生的事？

发生冲突时**可读性优先**；歧义用**拆词**解决（一词一义），**不要用生僻词解决**。

> 反例（2026-09 的实际退化路径）：为消除「已归档」的歧义，引入了「台账 / 回执 / 入账」一整套公文隐喻。歧义确实消除了，代价是用户一个词都不认识。

## 2. Tone / 语气（zh / en 双语）

| | zh | en |
|---|---|---|
| Calm 平静 | 陈述事实，不制造紧迫 | State facts; do not manufacture urgency |
| Direct 直白 | 说结果，不说实现状态 | Say what happened, not how it's implemented |
| Reassuring 让人安心 | 说明可逆性与边界，不打包票 | Explain reversibility and limits; never overpromise |
| Technical only when necessary 必要时才技术 | 系统名词（如「完全磁盘访问」）照用；**内部工程词不出现** | System names stay; internal engineering terms do not |

## 3. Product Voice / 产品口吻

- **先说发生了什么**（zh）/ Explain what happened first（en）
- **再说影响**（zh）/ Explain impact second（en）
- **每次都给下一步**（zh）/ Offer a next step every time（en）
- **不用恐吓式维护语言**（zh）/ Avoid fear-based maintenance language（en）

## 4. Good Patterns / 好句子（zh / en 对照）

| zh | en |
|---|---|
| 保留期是 7 天。 | The retention period is 7 days. |
| 不做也能用：受限模式下扫描与清理照常运行，只是范围更小。 | You can keep going without it — in limited mode, scans and cleanups still run, just over a smaller scope. |
| 大多数已选步骤都能恢复。 | Most selected steps are recoverable. |
| 本次不删除。 | Not removed. |

## 5. Avoid / 禁用

| 类别 | zh | en |
|---|---|---|
| 恐吓 | 「严重错误」「非法操作」「你的 Mac 有风险」 | `Critical error` / `Illegal operation` / `Your Mac is at risk` |
| 强制 | 「你必须允许」 | `You must allow this` |
| **文书隐喻**（2026-09 退役） | 「台账」「回执」「足迹」「入账」「作废」「№」 | `Ledger` / `Receipt` / `Footprint` / `№` |
| **法务词** | 「证据」（用于「扫到但不删除的清单」时） | `Evidence`（同义） |
| **内部工程词** | 「主流程」「发现项」 | `core workflows` / `finding(s)` |
| **规格句**（写给评审者的话） | 「而不是…」「在…前提下」「只突出…」「先解释…」 | — |
| **占位说明**（写给开发者的备注） | 「为未来版本预留的…」 | `Reserved … for a future scope decision` |

> 「文书隐喻」与「内部工程词」两行是**可机器检的硬约束**，见 §10 门禁。
>
> **en 侧大小写不敏感**：`ledger` / `receipt` / `app footprint` / `evidence` 与小写形态一并在禁。
> 唯一的逐字例外是 `No. %d`（小写 `no.` 在英文里是正常词）。

## 6. 句式与长度规则（可机器检）

| 规则 | 值 | 理由 |
|---|---|---|
| **屏幕副标题**（`route.*.subtitle` / `*.screen.subtitle`）显示宽度上限 | **≤ 48** | 显示宽度：CJK 记 2、其余记 1。实测值分布 p50=14 / p90=52，48 取在「常驻可见的一句」能读完的位置 |
| **屏幕副标题**禁用句式 | 见 §5「规格句」行 | 副标题是用户看得**最多**的一句；写设计意图的位置是设计文档，不是界面 |
| **说明性正文**宽度 | 报告维（> 96 告警，不阻断） | 权限理由、失败解释天然需要长度，硬卡会产生伪阳性 |
| **法定/诊断文案** | 豁免 | `settings.acknowledgement.*` / `settings.notices.body` / `xpc.error.*` |
| **编号字形** | **一律 `#`** | 不用 `№`；en 侧不得用 `No. %d` |

## 7. Glossary / 术语表（zh/en 双语）

> 2026-09-14 由 `REQ-ux-friction-remediation` 的 Wave 0 首次定稿；
> **2026-09-15 由 `REQ-copy-plain-language` 重开**（退役整套文书隐喻）。
> 逐项裁定见 `iterations/REQ-copy-plain-language/terminology-baseline.md`。
> 产品内可读入口见 Settings 的「术语表」。

| en | zh | 含义 |
|---|---|---|
| `Scan` | 扫描 | read-only analysis that collects findings; it never removes anything by itself. |
| `Plan` | 计划 | a numbered scan product (`#N`) carrying the reviewed set of steps Atlas proposes from the current findings; superseded plans are archived to History. Each rescan produces a new `#N` and voids the prior one. |
| `Cleanup Plan` / `Uninstall Plan` | 清理计划 / 卸载计划 | the actionable set of reviewed steps Atlas proposes from current findings. |
| `Review` | 复核 | the user checks the plan before it runs. Avoid using `preview` as the primary noun when the UI is really showing a plan. |
| `Run Plan` / `Run Uninstall` | 执行清理计划 / 执行卸载 | apply a reviewed plan. Use this for the action that changes the system. |
| `Reclaimable Space` | 预计可释放空间 | the estimated space the current plan can free. Make it explicit when the value recalculates after execution. |
| `Recoverable` | 可恢复 | Atlas can restore the result from History while the retention period is still open. |
| `Restore point` | 恢复点 | the stamp a run leaves behind when it creates recovery items. |
| `Retention period` | 保留期 | how long a recovery item stays restorable (rendered as 「保留 N 天」). Was `retention window` — 「窗口」读作 UI window，有歧义。 |
| **`History`** | **历史记录** | the record surface: numbered plans, restore points, and the archive of past runs. **2026-09-15 由 `Ledger`/「台账」改回**（退役会计隐喻）。 |
| **`Scan ID`** | **扫描编号** | per-scan identifier (e.g. `#A1F3`) stamped on a plan; links back into History. Was `Scan Receipt`/「扫描回执」. |
| **`App Storage`** | **应用占用** | the current disk space an app uses. Was `App Footprint`/「应用足迹」. |
| `Leftover Files` | 残留文件 | extra support files, caches, or launch items related to an app uninstall. |
| **`Not removed`** | **本次不删除**（状态/标题）· **未删除项**（名词/术语表） | files Atlas found but will not remove in this run. Was `Evidence`/「证据」. |
| **`classification reason`** | **分类依据** | why File Organizer put a file in a given category. **与上一行拆开**：同形两义必须一词一义。 |
| `Limited Mode` | 受限模式 | Atlas works with partial permissions and asks for more access only when a specific workflow needs it. |
| `Full Disk Access` / `Accessibility` / `Notifications` | 完全磁盘访问 / 辅助功能 / 通知 | macOS system permission names — do not translate. |
| `Destination` | 目标位置 | where File Organizer moves files (the path value; the settings section itself is 「整理目标」). |

### 拆词与量词规则（勿回退）

- **「回执」已拆**：作**阶段条/面板名**时 → **「结果」**（阶段条读作 扫描 / 复核 / 执行 / **结果**）；作**标识符**时 → **「编号」**（`扫描编号 #A1F3`）。
  > 教训：「回执」一词两义，机械统一成「编号」会让阶段条读出「扫描 / 复核 / 执行 / **编号**」。
- **「证据」已拆**：apps/smartclean 语境（扫到但不删除）→「未删除项」；fileorganizer 语境（为何归入该分类）→「分类依据」。
- **「已归档」已拆**（2026-09-14）：恢复项过期 → 已过期 / `Expired`（**不可恢复的终态**）；任务失败或取消 → 已结束 / `Archived`。两者不得再共用一个词。
- **量词分离**：权限语境一律「**个**」+ 显式名词语素「权限」；文件 / 清理项 / 记录语境一律「**项**」。
- **`Conditional`** 是形容词（风险等级），zh 用「有条件」，不得译成动作（如「需确认」）。
- **同名消歧**：阶段条的「复核」是术语表里的 `Review`；风险筛选 chip 用「待复核」/`Needs Review`。
- **`可重试`**：只有回执上真有重试入口时才可用这个措辞；否则删去。

### 体系词解释（zh 定稿）

原四词（残留 / 足迹 / 台账 / 证据）中三词已退役，**术语表随之收缩** —— 这本身就是「白话化达标」的证据：需要解释的词少了。

- **残留** — 卸载或清理后仍留在磁盘上的配置文件、缓存和启动项。
- **未删除项** — Atlas 扫到、但本次不会移除的文件。列出来不等于会移除。
- **恢复点** — 执行前自动建立的可恢复位置；保留期内可还原。

## 8. Consistency Rules

- Prefer `plan` over `preview` when referring to the actionable object the user can run.
- Use `review` for the decision step before execution, not for the execution step itself.
- If a button opens macOS settings, label it `Open System Settings` instead of implying Atlas grants access directly.
- Distinguish `current plan` from `remaining items after execution` whenever reclaimable-space values can change.
- Keep permission language calm and reversible: explain what access unlocks, whether it can wait, and what the next step is.
- **zh/en 必须同源同判据**：改一侧必改另一侧（`copy-gate.sh` 的 C4 检测成对术语，C6 检测占位符，C7 检测键集合）。

## 9. Containment Rules / 语域规则

> **2026-09-15 重写。** 原规则是「**文书语气仅限台账面**（warm paper）；工作面用直白动词」。
> 该规则**失去指称对象** —— 台账面这个语域不复存在（隐喻已退役）。
> 原文见 git 历史；它当时是**有意的双轨设计**，不是笔误。本次裁定：双轨合一。

- **全产品单一语域：白话直陈。** 不存在「记录面用文书语气」的例外。历史记录屏与工作屏说同一种话。
- **工作面的直白动词规则继续有效**：行动栏主按钮读 `执行清理计划` / `Run Cleanup Plan`，不得使用 签署 / sign / certify 一类法律关联动词。
- **恢复承诺是状态驱动的**，永不写意：只有当前计划**确实**建立了恢复点时，行动栏才打印恢复点承诺；否则显示普通状态。
- **内部标识不面向用户**：Swift 符号名（`ledgerFont()`）、键名（`ledger.*`）、包名（`AtlasFeaturesHistory`）、路由 case（`AtlasRoute.ledger`）、设计面内部代号（「台账面」）**都不是面向用户的词**，不受本文件约束。改这些属于键名重构。

## 10. 门禁

```bash
./scripts/atlas/copy-gate.sh          # 全量，退出码 0 = PASS
./scripts/atlas/copy-gate.sh -v       # 逐条明细
./scripts/atlas/copy-gate.sh --json   # 机器消费
./scripts/atlas/copy-gate.sh --only C1  # 单维复算
```

| 维 | 检查 | 阻断 |
|---|---|---|
| C1 | 术语禁用表（§5 的文书隐喻 / 法务词 / 内部工程词；en 大小写不敏感） | ✅ |
| **C1b** | **变形维** —— 同一概念的语序 / 名词化 / 搭配变体（正则）。字面表是穷举，必然追不上退化速度，故并设此维。**每发现一次漏网就补一条规则** | ✅ |
| C2 | 屏幕副标题宽度 ≤ 48 | ✅ |
| C3 | 屏幕副标题无规格句式 | ✅ |
| C4 | zh/en 术语成对（§8 最后一条） | ✅ |
| C5 | 孤儿键（零 Swift 引用） | ❌ 报告维，归 `ATL-272` |
| C6 | 占位符对称 | ✅ |
| C7 | 键集合 parity | ✅ |
| C8 | 长句 > 96 宽度 | ❌ 报告维 |
| **C9** | **Swift 字符串字面量**中的禁用词 / 字形。**范围只到生产源（跳过 `Tests/`）** —— 测试断言消息与夹具不是面向用户的载体 | ✅ |
| **C10** | **解析完整性** —— 每一行都真的被 `LINE_RE` 解析了。防的是「写成 `"k" = "v" ;` 或带行尾注释即可绕过全部规则、且键计数不变」这类**静默空转** | ✅ |

**新增文案的流程**：改完 → 跑 `copy-gate.sh` → 绿了才算改完。它不是建议，是判据。

**新增/修改规则后**：必须做**变异检验**（改坏被检对象，确认该维真会变红，再恢复）。
本仓库曾查出 4 条「改坏产品代码仍不失败」的空转守卫；不检验的规则等于没有。

**跨载体提醒**：面向用户的文案**不只住在 `.strings` 里**。`№` 就曾硬编码在 5 处 Swift 字面量中，
而 C1–C8 只扫两份 `.strings` ⇒ 门禁报 PASS 而 `№` 仍在渲染。这正是 C9 存在的理由 ——
**门禁的输入面必须覆盖被检事实的全部载体**。
