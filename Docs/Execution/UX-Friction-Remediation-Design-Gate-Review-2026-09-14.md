# UX Friction Remediation — Design Gate Review

## Gate

- 主题门：`UX Friction Remediation` / **设计评审**（对象是实现规格，非 slice 落地、非对外承诺核查）

> **形态说明**：`Docs/Templates/GATE_REVIEW_TEMPLATE.md` 定义了「Slice 门」与「Credibility 门」两形态，**设计评审不匹配任何一个**。本文件取**必需核心 5 节**，并借用形态 B 的 `Conditions` / `Remaining Limits` / `Blockers`（因 `Decision` = `Pass with Conditions`）。**形态归属待产品负责人确认**——若认可，本文件可作为模板增设「设计评审门」形态的判例。

## Review Date

- `2026-09-14`

## Scope Reviewed

- `Docs/design/2026-09-14-ux-friction-remediation.md` —— 6 契约 + 12 不变量 + 40 条映射 + 三波交付（评审时 478 行）
- 上游：`Docs/Execution/UX-Friction-Audit-2026-09-14.md`（40 条 finding = 39 原始 + 1 条补报 `NEW-1`）

## Readiness Checklist

- [x] 规格落盘且自检通过（占位符 0；40 条 finding 覆盖完整）
- [x] 上游引用已完成一轮回源核验（审计侧 4 处更正 + 1 条漏报 + 1 处证据强度修正，已回写审计正文）
- [x] 治理定位已声明（CONTRACT 升级项已列出，含 `D-012` 需人工签字）
- [x] 下一阶段入口明确（开 `REQ` + `## Contract Unfreeze Record`）
- [x] 评审条件 F1–F4 已落地（落地情况见「Follow-up Actions」）

## Evidence Reviewed

- 规格正文与附录 A / B（全文逐节阅读，非抽样）
- **代码回源**：`LedgerTimelineView.swift`、`FileOrganizerSupportViews.swift`、`AtlasAppModel.swift`、`AboutFeatureView.swift`、`SmartCleanStageViews.swift`、`AtlasAppCommands.swift`、`AtlasDomain.swift`、`AtlasBrand.swift`
- **测试与工具链**：`Packages/*/Tests/*FeatureViewTests.swift`、`Apps/AtlasAppUITests/AtlasAppUITests.swift`、`scripts/atlas/run-ui-automation.sh`、`scripts/atlas/ui-automation-preflight.sh`、`scripts/test.sh`、5 个 `Package.swift`
- **先例**：`Packages/AtlasDomain/Tests/AtlasDomainTests/AtlasDomainTests.swift:10`（`testPrimaryRoutesMatchFrozenMVP`）

## Automated Validation Summary

- **不适用** —— 评审对象是实现规格，本次**无代码改动**，`swift test` 无增量可验。以下为可脚本化的静态校验：
- **覆盖性闭合复算**：40/40 落点、0 重复、0 遗漏（脚本执行，非目测）
- **计数交叉验证**：审计正文 P0=5 / P1=18 / P2=16 = 39，+ 补报 `NEW-1` = 40；规格 §8 映射表合计 7+4+6+8+11+4 = 40
- **共享引用比对**：审计与规格共有的 6 处行号逐条回源一致（`:167` / `:227-239` / `:1526` / `:414` / `:387-390` / `:45-49`）

## Design Review Assessment

### F1 守卫机制不可执行（**阻塞级**）

- §7 为 12 条不变量中的 7 条指定「视图测试」为守卫形式，**该能力在本仓库不存在**：`*FeatureViewTests.swift` 只构造 view struct 断言初始属性（`testDefaultInitUsesFixtureData` 一类），无渲染断言；5 个 SPM 根包外部依赖数为 **0**，而 §0.2 禁止新增第三方依赖——ViewInspector / 快照测试路线被规格自身堵死。
- 唯一能对渲染结果下断言的是 `Apps/AtlasAppUITests`（已接线：`project.yml:125-135`；执行入口：`scripts/atlas/run-ui-automation.sh`）——但 §9 的收口协议只跑 `swift test`，**按构造执行不到它**。
- 后果：守卫「写了但永不执行」，而波次验证仍报绿——与 §0.3 所记 `P1-18`「标记 DONE 却未交付」同形。
- **处置**：§7 重写守卫列为三条可执行通道（模型单测 / `AtlasAppUITests` / AX 断言）并附执行边界说明；§9 验证协议补 XCUITest 命令。**已落地。**

### F2 I-4 的 ④ 无法用编译期保证

- 「④ 当且仅当作用于可恢复项集合时必需」是**条件性**要求，optionality 表达不了。§0.2 只写 ①②③（正确），§7 I-4 却把 ④ 并入同一守卫描述——两处口径不一。
- **处置**：§7.1 明确 ④ 由**类型区分**（`.recoverable(...)` / `.plain(...)`）保证；§0.2 同步。**已落地。**

### F3 I-11 守卫与不变量不等价，且会崩测试进程

- 不变量要求「≥2 条可达路径（菜单/键盘至少其一 + UI）」，守卫只断言其一，「+ UI」那半未覆盖。
- 断言对象 `CommandMenu` 是 SwiftUI View body，**不可枚举**。
- `shortcutKey` 对 `.settings / .about` 走 `preconditionFailure`（`AtlasAppCommands.swift:101-102`）——遍历 `allCases` 调用它会**崩掉测试进程**，而非断言失败。
- **处置**：断言对象改为 `AtlasRoute.sidebarRoutes`（`AtlasDomain.swift:132`）；§7.1 写明两个前置依赖，并标注该守卫**依赖已标 CONTRACT 的 `shortcutKey` 改动先落地**，实现顺序不可颠倒。**已落地。**

### F4 I-5 在任何层级都不可测

- TCC 对话框由**系统进程**弹出：单测观测不到「触发前」，XCUITest 也控制不了系统对话框时序。
- **处置**：拆为「模型层静态断言（可自动化）」+「`macos-gui-acceptance` 人工验收项（不冒充自动化覆盖）」；§0.2 为其开**唯一例外**。**已落地。**

### F5–F10（次要 / 口径 / 落点）

| # | 问题 | 处置 |
|---|---|---|
| F5 | §4.1 残留 `:168`，与附录 A 及代码冲突 | 改 `:167`。**已落地** |
| F6 | 「审计 39 条 + 新增 1 条」口径在审计回写后失真（审计现含 `NEW-1`，已是 40 条） | 四处统一为 40，交叉验证闭合。**已落地** |
| F7 | §4.2(2) 的「产品内术语入口」未进 §0.2 成功标准，也未进任何波次 | §0.2 + Wave 3 补归属。**已落地** |
| F8 | `run-ui-automation.sh` 在 AX 未授权时 `exit 0`——**跳过了却报成功**。**修 F1 时回源才发现**；否则 F1 的修法会把失败模式从「没有守卫」换成「静默跳过且门禁放行」，后者更坏 | 规格规定 `Skipped = NOT RUN ≠ Pass`；同一约束写入 `AGENTS.md`。**已落地** |
| F9 | 契约四的三条 P1 条目（`P1-4` `P1-13` `P1-15`）不在任何波次 | 移入 Wave 2。**已落地** |
| F10 | 契约五的 P1 条目（`P1-9` `P1-12` `P1-16`）被排在标着 P2 的 Wave 3 | 拆契约五，P1 移入 Wave 2；立 §9 纪律第 3 条显式记录该拆分。**已落地** |

### 第二轮：独立复核（2026-09-14）

第一轮评审与全部处置均由控制器第一手完成，其 `Remaining Limits` 自记「无第二方复核」。为闭合该项，另派**两个只读子代理**独立复核：一个对抗性事实核验（要求每个缺席性断言附实际执行的命令与条数），一个设计健全性评审。**二者均未接触第一轮的推理过程。**

控制器对两份报告逐条抽验回源，**否掉 3 条**（含被复核者列为「已确认缺口 #1」的一条）。

#### L1 §7.1 漏第三个前置：I-11 的守卫**编不过** —— 已修

- `shortcutKey` 声明在 `private extension AtlasRoute`（`AtlasAppCommands.swift:86`）。`@testable import` **只放开 `internal`**，够不到 `private`。
- §7.1 原列两个前置，**漏了访问级别提权**；且**未写守卫落点**。
- **处置**：§7.1 改为三个前置，并写明落点必须在 `Apps/AtlasApp/Tests/AtlasAppTests/`（放错包会让 §9 Wave 2 的验证命令**漏跑它**）。**已落地。**

#### L2 F8 不是风险，是**已存在的管道** —— 已裁

- `.github/workflows/atlas-acceptance.yml:18-23`（`runs-on: macos-latest`）→ `./scripts/atlas/full-acceptance.sh`
- `full-acceptance.sh:14`：`if ./scripts/atlas/run-ui-automation.sh 2>&1 | tee "$atlas_log"; then` —— 脚本未授权时 `exit 0`，**直接走成功分支**，其 `:18-33` 的「环境阻塞 vs 应用缺陷」分类逻辑**永远到不了**。
- 即 F8 的严重度被定低了：本文件原把它记为「脚本会假绿」的风险描述，实际是一条**已在 CI 上生效的管道**。
- **取证边界**：机制已由代码行号确认；「该 runner 上确实从未执行过」需一次实际 CI 运行才能坐实。
- **裁定（产品负责人）**：**让 `NOT RUN` 成为一条会失败的断言**，不靠人读输出。
- **处置**：§9 写入三条——① 门禁默认失败（`full-acceptance.sh` 断言 log 不含 `Skipping native UI automation`，含则 `exit 1`）；② 豁免必须显式 opt-in（`ATLAS_ALLOW_UI_SKIP=1`），**默认不豁免**；③ 该改动属**守卫基座**。
- **实现（2026-09-14，早于 Wave 1）**：`full-acceptance.sh` 已加断言与豁免分支，并在失败时把 log 留存在 `${TMPDIR}/atlas-ui-automation-NOT-RUN.log` —— **补上原先 log 随 `trap … RETURN` 被删、事后无从查证的缺口**。四分支行为已测（跳过→`1` / 跳过+豁免→`0` / 正常通过→`0` / 正常失败→`1`），跳过标记与生产者**逐字一致**。`AGENTS.md` 同步。
- **未验证**：`shellcheck` 本机未安装（`scripts/test.sh` 会在有它的环境跑）；**未经真实 CI 运行**——「该 runner 上此前确实从未执行过 UI 断言」仍属代码推断，需一次 CI 运行坐实。

#### L3 I-2 / I-3 的三态映射**未定义** —— 已裁

- `I-2`（`P0-2`，FO）与 `I-3`（`P1-8`，Smart Clean）覆盖的是**同一个条件**（无恢复点），却要求不同渲染：前者「控件存在 ∧ `isEnabled == false`」，后者「被隐藏 + 缺席理由」。
- §1.2(2) 的三态模型（`.available` / `.unavailable(reason)` / 不存在）**没有给出条件 → 态的判定规则**。这是**欠定义**，不是矛盾。
- **裁定**：统一到 **`.unavailable(reason)`**——「条件不满足 ≠ 控件不适用」。凡「动作可恢复但本次无可恢复项」**一律禁用 + 理由，不得隐藏**；「不存在」态仅保留给动作类型根本不适用者。依据是审计 `P1-8` 自己的表述（「在不满足条件时是**不存在**，不是置灰」）——它要求的正是置灰。
- **处置**：§1.2(2) 补入判定规则表 + 一段显式规则；`I-3` 重写为「**不得静默隐藏**」。**已落地。**
- ⚠️ **此项改变用户可见形态（置灰 vs 隐藏），属产品取舍——可推翻。**

#### 复核中**被否掉**的 3 条（记录以免将来重报）

| 复核者报的 | 抽验结果 |
|---|---|
| 「**已确认缺口 #1**：I-11 的前置排在 Wave 2，而 I-11 是 **Wave 1** 的红线」 | **前提编造**。全文档中 `I-11` 只出现于 §7 表格与 §7.1，**没有任何一处给它指派波次**。冲突不成立（残留的「守卫无落点」已并入 L1） |
| 「纪律 3 的论据瑕疵：`P1-9` 是纯渲染谓词，非破坏性操作中缺失」 | **不成立**。复核者把证据标签【代码】误当作主题内容。`P1-9` 即 Smart Clean 执行中无进度 |
| 「全仓 `accessibilityIdentifier` 仅 14 处」 | **数字不准**，实测 **30 处** |

> **方法论产出**：复核者的**定量断言**同样必须抽验，不限于缺席性断言——第 3 条即为此类。

#### 裁定 5 条设计层主张（复核提出，控制器裁定）

| # | 复核主张 | 裁定与处置 |
|---|---|---|
| 1 | **`I-7`**（同屏同名）交给 AX dump 不可判定——排除不了**合法同名**；AX 容器语义在 SwiftUI 下不保真；「一屏」无定义 | **收窄不变量**：改为「**两个不同动作**的可交互控件不得共用同一可见标签」，纯分类标签（`AtlasMetricCard` / `AtlasStatusChip` / 阶段条）**排除**；载体**从 AX dump 换到 `AtlasAppUITests`**（可枚举 Button / Link / DisclosureGroup 标签）。**已落地** |
| 2 | **`I-10`**（估算/实测不同组）无锚点——fact row 是平级兄弟，无 group 元素或标识 | **契约补交付物**：§5.2 第 3 条要求估算值渲染在**带稳定 `accessibilityIdentifier` 的独立分组容器**内（同时利好 VoiceOver）→ 守卫变为可断言。**已落地** |
| 3 | **`I-8` 载体错配**——口径是模型层事实，UI 只能读到渲染串 | **拆载体**：模型单测断言两处同源；`AtlasAppUITests` 只断言两个文案键仍渲染。**已落地** |
| 4 | **契约四 P1 条目要用的词不在 Wave 0 定稿范围** | **扩 Wave 0 范围**：定稿 = **全规格涉及的全部新词与拆词**（含 `Expired` / `Archived` /「已结束（失败/取消）」/「可重试」/ 量词分离）。否则 Wave 2 无词可用而就地自造，**绕过 CONTRACT 签字**。**已落地** |
| 5 | **§9 无「守卫基座」交付物** | **立 §9 纪律第 4 条**：每波交付物必须含该波不变量所需的守卫基座（状态注入 / 标识投放 / 新用例）；**基座缺失时该不变量记 `NOT RUN`，不得报 `Pass`**。**已落地** |

> 第 4 项与 L3 同属**产品可见取舍**（前者是术语范围，后者是控件形态），可推翻。其余三项是技术性修正。

## Remaining Limits

- **AX 授权未决（本门最大的未覆盖）**：F8 只修到「不静默通过」。规格要求 `Skipped` 计 `NOT RUN`，但**不解决「在未授权环境里根本跑不了」**。若开发机 / CI 未授予 AX 权限，七条 UI 守卫将长期处于 `NOT RUN`——门禁诚实了，**覆盖仍然缺位**。需产品负责人决定是否把 AX 授权列为开发 / CI 环境的前置要求。
- **独立复核已完成，其设计层主张亦已裁**：第二轮由两个只读子代理独立完成（见上），第一轮的「无第二方复核」限制**就此闭合**；复核提出的 5 条设计层主张**已全部裁定并落地**。**本轮无遗留未裁项**——除 L2 外。
- **未评审「规格能否落地」**：本次只审**内部一致性与可执行性**，不验证实现难度、工作量估计与 Wave 划分的现实性——那属 `REQ` 阶段的职责。
- **F1–F10 的发现顺序本身是根因证据**：F1–F5 由**阅读**得出，F8 / F9 / F10 在**动手改**时才撞出，且同属「交付物有名字但没落点」。根因是覆盖性只核了 finding→契约 **一维**，不变量 / 波次 / 验证协议三维从未被核。已补全量复算，并回流至 `iteration-governance` 的 Validation Gate。

## Conditions

`Decision` = `Pass with Conditions`。

**已达成的条件**：F1–F4、第二轮 **L1**（§7.1 第三前置 + 守卫落点）、**L3**（三态判定规则 + `I-3` 重写）、**5 条设计层主张**（`I-7` / `I-10` / `I-8` 载体、Wave 0 范围、守卫基座纪律），以及 **L2** 的裁定（`NOT RUN` 须落成会失败的断言）——**除 L2 的脚本实现外，均已落地**。

**放行的剩余前提**：

1. 产品负责人**终审 §1.2(2) / §7 / §9**——本块经三轮改动（首轮评审 → 裁示 → 独立复核裁定），是最需要人过目的部分
2. ~~**实现 L2**~~ —— **已完成（2026-09-14）**：`full-acceptance.sh` 加 `NOT RUN` 失败断言 + `ATLAS_ALLOW_UI_SKIP` 显式豁免 + 失败时 log 留存。四分支行为已测（跳过→1 / 跳过+豁免→0 / 正常通过→0 / 正常失败→1）
3. 开 `REQ` 时立 `## Contract Unfreeze Record`，覆盖契约四术语体系与 `P1-18` 的 `AtlasAppCommands` 改动；**`D-012` 须人工签字，不得由 agent 自主合入**

## Blockers

- **本门无阻塞。**
- 分开记一条**属其他轨道的欠账**：`iterations/REQ-ui-ux-overhaul` 的 P1-3 把「⌘, 打开 Settings」标为已完成（该 REQ 整体 Status = DONE）却未交付绑定——由本规格的 `I-11` 守卫兜住，**不构成本规格的放行阻塞**。

## Decision

- **`Pass with Conditions`**

## Follow-up Actions

1. 产品负责人终审 §1.2(2) / §7 / §9 → 通过后解除剩余条件
2. **实现 L2**：`full-acceptance.sh` 加 `NOT RUN` 失败断言 + `ATLAS_ALLOW_UI_SKIP` 显式豁免（守卫基座，Wave 1）
3. 决定 **CI runner 是否授予 AX** —— L2 落地后，未授权将**直接失败**而非静默通过；若 CI 确实无法授权，须显式设 `ATLAS_ALLOW_UI_SKIP=1` 并在 `REQ` 里记明「UI 层不变量在该环境为 `NOT RUN`」这一已知覆盖缺口
4. 开 `iterations/REQ-*`（含 `## Contract Unfreeze Record`）+ Wave 0 术语基线签字
5. 确认本文件的**形态归属**：是否据此为 `GATE_REVIEW_TEMPLATE.md` 增设第三种形态（设计评审门）
