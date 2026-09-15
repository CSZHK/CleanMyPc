# REQ-copy-plain-language

## Title
白话文案整改（Atlas for Mac）—— 重开契约四 · 退役文书隐喻 · 建立文案门禁

## Change Class
**MAJOR** —— 触及 CONTRACT（术语体系）、设计语言（Calm Ledger v3 → v4）、两份 `Localizable.strings`（各 1166 键中的约 380 处文案值）、既有测试断言（2 处）、新增门禁脚本与上游接入点。

## Status
**DONE**（2026-09-15）—— 文案、门禁、文档、真机视觉验收全部完成并实测；CONTRACT 追认 **R-1..R-6 已签字**（见 `## Contract Unfreeze Record` → 签字记录 1）。

## Priority
**P1** —— 不阻断发版。但它是发版前「对普通用户可读」这一产品主张的前置条件。

## Truth Sources
- 设计规格: `Docs/design/2026-09-15-copy-plain-language.md`（**唯一实现权威**）
- 术语真相源: `iterations/REQ-copy-plain-language/terminology-baseline.md`（P-1..P-12 + R-1..R-6 裁定位）
- 判据锚点: `Docs/design/2026-09-14-ux-friction-remediation.md:16`（受众 = **非技术 Mac 用户**）
- 门禁判据: `scripts/atlas/copy_gate.py` 的 C1–C8（规则即判据，可执行）
- 被推翻对象: `iterations/REQ-ux-friction-remediation/terminology-baseline.md`（其 T-10 / T-12 / T-14 / §S-10）

## Description

既有中文文案在「术语精确」这一目标函数下退化为公文：屏幕副标题写成设计规格句、核心名词使用会计/法律/公文隐喻（台账 / 回执 / 足迹 / 证据 / 入账 / 作废）、说明性长句达 42 条。

本 REQ 退役整套文书隐喻，改用非技术 Mac 用户能直解的白话，并把「可读性」固化成两道防线：

1. **双语语气规范** —— `Docs/COPY_GUIDELINES.md` 补 zh 侧判据（原 Tone / Voice / Good Patterns **全部为 en 单语**，中文侧从无规范，这是漂移的结构性根因）
2. **机器门禁** —— `scripts/atlas/copy-gate.sh`，八条规则、可计数、有机器可读哨兵

## Contract Unfreeze Record

解冻项**须产品负责人逐项签字，不得由 agent 自主合入**（`iteration-governance` 的「升级给人」）。
本次为 **CONTRACT 二次解冻** —— 推翻 2026-09-14 已签字的那次。

| # | 项 | 本 REQ 采纳 | 产品负责人裁定 |
|---|---|---|---|
| **R-1** | `Ledger` → `History`（en 侧同步退役隐喻） | 同步退役 | **✅ 已签（2026-09-15）** |
| **R-2** | `№` → `#`（移除排版符号） | 移除 | **✅ 已签（2026-09-15）** |
| **R-3** | `Evidence` 拆为「未删除项」（apps/smartclean）/「分类依据」（fileorganizer） | 拆 | **✅ 已签（2026-09-15）** |
| **R-4** | `Review` / 复核 **保留不换**（78 处） | 保留 | **✅ 已签（2026-09-15）** |
| **R-5** | **`D-012` 反向撤销** —— 「台账」退回「历史记录」 | 撤销 | **✅ 已签（2026-09-15）** |
| **R-6** | Calm Ledger 出 **v4** 而非新建文档 | 出 v4 | **✅ 已签（2026-09-15）** |

### 签字记录 1 — 契约四二次解冻（2026-09-15）

- **产品负责人裁定**：**R-1..R-6 全部签字**，准予合入
- **对象**：`iterations/REQ-copy-plain-language/terminology-baseline.md` §1 / §5
- **R-5 属 `iteration-governance` §「升级给人」的人工确认点** —— 它撤销的是 2026-09-14 的一次已签字裁定（`D-012` 「台账保留、不重开」），**已由产品负责人显式确认撤销**。agent 未代答。

### 签字记录 2 — 范围外修复的追认（2026-09-15）

- **裁定**：**保留在本次 REQ**
- **对象**：`AtlasFormatters.relativeDate/shortDate` 的 locale 修复（`Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/AtlasDesignSystem.swift`）
- **性质**：真机视觉验收**顺带查出**的既有缺陷，不属术语基线的 P 系列。已按「保留」处理，并在 `trace.md` 与 CHG `verify.md` 显式标注为范围外顺带查出，附变异检验证据。

### 与 `REQ-ux-friction-remediation` 的关系

| 关系 | 内容 |
|---|---|
| **推翻** | 该 REQ 的 `terminology-baseline.md` §1 T-10（台账保留、D-012 不重开）、T-12（应用足迹）、T-14（证据）、§S-10（四个体系词「保留用词、补解释」） |
| **继承** | T-01..T-09 / T-11 / T-13 / T-15..T-19 的用词，以及 §2 的**全部拆词与量词规则**（S-1..S-9）不重开 |
| **不修改其正文** | 该 REQ 的历史记录原文保留；本 REQ 只在其 `trace.md` 的 `## Close Gate` 追加失效标注（沿用该 REQ 自己处理复审的既有先例） |
| **状态** | 该 REQ 当前为 `IN PROGRESS`（其 Close Gate 已因守卫空转被回退）。**本 REQ 不解除其阻塞**，两者并行、各自独立收口 |

## Blast Radius

**触及**
- `Packages/AtlasDomain/Sources/AtlasDomain/Resources/{zh-Hans,en}.lproj/Localizable.strings` —— 两份各约 175 行文案值
- `Packages/AtlasDomain/Tests/AtlasDomainTests/AtlasDomainTests.swift` —— 路由标题断言（其「Unfrozen row」注释需二次记录）
- `Packages/AtlasFeaturesHistory/Tests/AtlasFeaturesHistoryTests/LedgerModelTests.swift` —— 导出占位符断言
- `Docs/COPY_GUIDELINES.md` —— 语气规范双语化 + 术语表回写 + Containment Rules 重写
- `Docs/design/2026-06-10-frontend-redesign-calm-ledger.md` —— 出 v4
- 新增 `scripts/atlas/copy-gate.sh` / `copy_gate.py`

**不触碰**
- 任何 **键名**（沿用 S-1 先例：键名是内部标识，不对用户可见）
- `AtlasProtocol` / XPC / Helpers / Go / 设计系统 token / 恢复语义与 fail-closed 判定
- **孤儿键的删除** —— 见下方「不做项」

## 不做项（显式列出，防止被当作遗漏）

| # | 项 | 理由 |
|---|---|---|
| N-1 | **删除 310 个孤儿键** | 门禁把它作为**报告维**打印（C5），但**不纳入本 REQ 的阻断判据**。理由：(a) 删除死键属「死代码清理」，与本 REQ 的「文案质量」是**不同维度**；(b) 该工作**已由 `ATL-272` 单独跟踪**、署名为 `Docs Agent`（判据见 `iteration-governance` 的 `l10n-parity` 署名判例）。吸收进来会造成重复记账。**本 REQ 仍修复孤儿键中的禁用词**（否则门禁 C1 会红）——即「修内容、不删键」 |
| N-2 | `Review`/复核 换词 | 见 R-4。78 处改动面与收益不成比例 |
| N-3 | 长句的**硬上限**门禁 | C8 为报告维（阈值 96 显示宽度）。正文/说明类文案天然需要长度，硬卡会产生伪阳性 |
| N-4 | 英文文案的母语级润色 | 本 REQ 的 en 侧改动与 zh 侧同源同判据，但**未做母语者审校**。若需要，应作为独立事项排期 |

## Acceptance

1. `./scripts/atlas/copy-gate.sh` 退出码 **0**、哨兵 `ATLAS_COPY_GATE=PASS`（阻断维 C1–C4/C6/C7 全零）
2. `swift test --package-path Packages` 与 `--package-path Apps` **零失败**（不得低于各自基线）
3. L10n parity：两份 strings 键集合零差集、占位符零不对称（由 C6/C7 覆盖）
4. `Docs/COPY_GUIDELINES.md` 含 zh 侧语气判据；Calm Ledger 有 v4 且与实现对得上
5. 术语基线的 R-1..R-6 有产品负责人签字记录 —— **✅ 已满足（2026-09-15）**
6. **对抗式终审通过** —— 四路独立审查，推翻的 9 条声明全部修复；门禁从 6 维扩到 8 维，新增规则全部经变异检验（见 `trace.md` 的「终审」节）

## Docs Sync
见 `trace.md` 的同名节。
