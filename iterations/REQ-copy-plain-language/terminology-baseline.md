# 白话术语基线（P 系列）— 重开契约四

- **日期**：2026-09-15
- **状态**：**已签字通过（2026-09-15）** —— R-1..R-6 逐项裁定已记录，准予合入
- **上位**：`Docs/design/2026-09-15-copy-plain-language.md`
- **治理级别**：**CONTRACT**。本基线**推翻** `REQ-ux-friction-remediation` 的 `terminology-baseline.md`（2026-09-14 签字版）
- **被推翻的对象**：`iterations/REQ-ux-friction-remediation/terminology-baseline.md` §1 T-10（`Ledger` 台账「保留，D-012 不重开」）、T-12（`App Footprint` 应用足迹）、T-14（`Evidence` 证据）、§S-10（四个体系词「保留用词、补解释」）
- **不变的对象**：T-01..T-09、T-11、T-13、T-15..T-19 的用词与 §2 的全部拆词/量词规则（S-1..S-9）**继续有效**，本基线不重开

## 0. 本文的地位

本次推翻的**不是**「用词要精确」这条原则，而是它的**目标函数**：既有基线把「消除歧义」当成唯一判据，为消歧牺牲了可读性，导致中文文案退化为公文。本基线追加第二条判据：

> **非技术 Mac 用户第一次看到这个词，能不能懂？**

两条判据冲突时，**可读性优先**，歧义用「拆词」而不是「生僻词」解决。

**判据锚点**：`Docs/design/2026-09-14-ux-friction-remediation.md:16` 已把受众定义为**非技术 Mac 用户**（原 Wave 0 审计视角）。本基线沿用，不重新定义。

**不双写**：落地完成后 `Docs/COPY_GUIDELINES.md` §Glossary 是术语真相源，本文转为决策记录。

---

## 1. 替换对照表（P-1 .. P-12）

「现状」列 = 2026-09-15 从两份 `Localizable.strings` 逐 key 回源的实际渲染值。

| ID | 现状 zh | 现状 en | **定稿 zh** | **定稿 en** | 判据 |
|---|---|---|---|---|---|
| **P-1** | 台账 / 维护台账 / 台账流 / 台账条目 / 台账记录 | Ledger / Maintenance Ledger / Ledger Feed / Ledger entry | **历史记录** / **历史记录** / **最近记录** / **历史记录条目** / **历史记录** | **History** / **History** / **Recent activity** / **history entry** / **history** | 「台账」是会计/公文词，日常汉语不用。macOS 全系统（Finder、Safari、系统设置）用「历史记录」。en 侧 `Ledger` 同属会计词，一并改 `History` |
| **P-2** | 扫描回执 / 清理回执 / 整理回执 / 回执 | Scan Receipt / Cleanup Receipt / Organization receipt / Receipt | **扫描编号** / **清理编号** / **整理编号** / **编号** | **Scan ID** / **Cleanup ID** / **Organization ID** / **ID** | 「回执」是挂号信/公文语域词。该实体就是一个标识符（`#A1F3`），直接叫「编号」——**说它是什么，而不是它像什么** |
| **P-3** | 应用足迹 / 足迹 / 残留足迹 | App Footprint / Footprint | **应用占用** / **占用空间** / **残留占用** | **App storage** / **Storage used** / **Leftover storage** | 「足迹」是环保隐喻，用户要的信息是「占多少空间」。**推翻 T-12 的 R-2 裁定**（R-2 把三个 key 对齐成「应用足迹」，方向对、选词错） |
| **P-4** | 证据（apps/smartclean 语境：扫到但不移除的清单） | Evidence | **本次不删除**（状态/标题，实现里 13 处统一用它）/ **未删除项**（术语表与计数名词） | **Not removed**（状态/标题）/ **not-removed items**（计数） | 「证据」是法律词。此处语义 = 「Atlas 找到了，但这次不动它」，直说结果 |
| **P-5** | 证据（fileorganizer 语境：为何归入该分类） | evidence | **分类依据** | **classification reason** | 与 P-4 **拆词**：同形两义必须一词一义（沿用 S-1 拆词纪律）。FO 的证据面板渲染的是规则命中链，那是「依据」不是「未删除」 |
| **P-6** | 发现项 | finding(s) | **清理项** | **item(s)** | `finding` 的硬译。用户视角里它们是「可以清理的东西」 |
| **P-7** | № | № | **#** | **#** | `№` 是排版符号，非技术用户不识别。`#` 是通用符号 |
| **P-8** | 已作废 / 作废并重新扫描 | Superseded / Void & Rescan | **已失效** / **重新扫描** | **Superseded** / **Rescan** | 「作废」「void」是公文/法律词。`Void & Rescan` 还把动作说得比实际重 |
| **P-9** | 入账 / 已入账 | recorded | **已记录** | **Recorded** | 「入账」是会计词 |
| **P-10** | 主流程 | core workflows | **主要功能** | **main features** | 「主流程」是内部工程词（main flow 直译），不是用户语言 |
| **P-11** | 保留窗口 | retention window | **保留期** | **retention period** | 中文「窗口」首先被读作 UI window，歧义 |
| **P-12** | 仅限手动复核的证据 / 仅供复核 | review-only | **不自动删除** | **Not auto-removed** | 与 P-4 同源。`review-only` 描述的是 Atlas 的实现状态，不是用户看到的结果 |

### 1-B 保留不动（明确列出，防止下一轮又被当黑话重开）

| 词 | 保留理由 |
|---|---|
| **恢复点** / `Restore point` | 中文可直解（「建立一个可以恢复的点」），且已渲染成「执行前自动建立恢复点 · 保留 %d 天」这类自解释句式 |
| **复核** / `Review` | 标准汉语动词，非生僻词。78 处改动面与收益不成比例。S-3 的消歧（风险 chip 改「待复核」）已解决同屏撞名 |
| **受限模式** / `Limited mode` | 已有 `overview.callout.limited.*` 系列就地解释（「你仍然可以在受限模式下继续使用」） |
| **残留** / `Leftover files` | 「残留」是日常汉语（残留物、农药残留），且 `apps.metric.leftovers.detail` 有就地解释 |
| **清理计划 / 卸载计划 / 扫描 / 计划** | T-01..T-05，本就是白话 |
| **完全磁盘访问 / 辅助功能 / 通知** | macOS 系统权限名，不译（T-16..T-18） |

---

## 2. 词义拆分决定（拆词，不是改词）

沿用 S-1 纪律：**一个字形不得承载两个状态/语义**。本次拆两处：

### 2-A 「证据」拆两义（P-4 / P-5）

| 语义 | 出现语境 | **定稿 zh** | **定稿 en** |
|---|---|---|---|
| Atlas 扫到、本次不删除的文件清单 | Apps 卸载、Smart Clean 执行 | **不删除项** / **本次不删除** | **not-removed items** / **Not removed** |
| 某个文件为什么被归入该分类 | File Organizer 证据面板 | **分类依据** | **classification reason** |

判据：两者**载荷不同**（一个是「本次不动的文件集合」，一个是「规则命中链」），不是同一个东西的两种说法。

### 2-B 「台账」的两种角色不拆

原基线 §S-1 的注脚说明「归档」在**状态词**与**区域名词**两种角色下可以共存。同一逻辑本可用于「台账」，但本次**不沿用**——P-1 把所有角色统一替换为「历史记录」，理由是：拆词的前提是「该词本身要保留」，而 P-1 的裁定是**该词整个退役**，不存在「保留其区域名词角色」的问题。

---

## 3. 连带影响（v4 设计语言与规范）

| 对象 | 影响 | 落点 |
|---|---|---|
| `Docs/design/2026-06-10-frontend-redesign-calm-ledger.md` | **设计语言 v3 的「warm paper 文书语域」被废止** —— 隐喻承重墙（台账/回执/№/入账/作废）全部退役 | 出 **v4**，改写 §Concept 与 `Containment Rules` |
| `Docs/COPY_GUIDELINES.md` §Glossary | 19 条术语表中 6 条变更（Ledger / Scan Receipt / App Footprint / Evidence / Destination 保留 / 新增 Not-removed） | 回写双语表 |
| `Docs/COPY_GUIDELINES.md` §Containment Rules | 「文书语气限定在台账面」这条**失去指称对象**（台账面不复存在） | 替换为「全产品单一语域：白话直陈」 |
| 产品内术语表（Settings `glossary.*`） | 原 4 词（残留/足迹/台账/证据）中 3 词退役，**术语表收缩到仍需解释的词** | `glossary.*` key 组重构 |
| `Docs/design/2026-09-14-ux-friction-remediation.md` | 其 §4 契约四的既定结论被本 REQ 推翻 | **不修改原文**，在 `REQ-ux-friction-remediation/trace.md` 的 `## Close Gate` 追加失效标注（沿用该 REQ 自己的先例） |

---

## 4. 量词规则（沿用 S-2，不重开）

- **权限语境**：一律「**个**」+ 显式名词语素「权限」
- **文件 / 清理项 / 记录语境**：一律「**项**」+ 显式名词语素

`P-6` 的 `finding` → 「清理项」遵守本条：计数渲染为「%d 个清理项」而非「%d 个 finding」。

---

## 5. 逐词裁定位（**已签字**）

以下六项经产品负责人**逐项签字**（2026-09-15），**已构成合入承诺**。签字记录见
`requirement.md` 的 `## Contract Unfreeze Record` → 签字记录 1。

| # | 开放项 | 本基线采纳 | **产品负责人裁定** |
|---|---|---|---|
| **R-1** | `Ledger` → `History`（en 侧是否同步退役隐喻） | **同步退役** | ✅ 已签（2026-09-15） |
| **R-2** | `№` → `#`（移除排版符号） | **移除** | ✅ 已签（2026-09-15） |
| **R-3** | `Evidence` 拆为「不删除项」/「分类依据」两义 | **拆** | ✅ 已签（2026-09-15） |
| **R-4** | `Review` / 复核 保留不换（78 处） | **保留** | ✅ 已签（2026-09-15） |
| **R-5** | `D-012`（历史→台账）**反向撤销**，即回到「历史记录」 | **撤销** | ✅ 已签（2026-09-15） |
| **R-6** | Calm Ledger 设计语言出 v4 而非新建文档 | **出 v4** | ✅ 已签（2026-09-15） |

**R-5 是 §0.3 类的人工确认点**：它撤销的是 2026-09-14 已签字的一次裁定 —— **已由产品负责人于 2026-09-15 显式确认撤销**，agent 未代答。见 `requirement.md` 的 `## Contract Unfreeze Record` → 签字记录 1。

---

## 6. 回源核对记录

- 两份 `Localizable.strings` 键集合 parity：**1166 / 1166，零差集**（脚本核，2026-09-15）
- 含隐喻词的文案值：**132 个 key**，跨 20 个 key 前缀 · 全部 6 个 feature 包
- **额外发现（本基线范围外，已在门禁中固化为规则）**：
  - `route.history.title` / `route.history.subtitle`、`taskcenter.openHistory*`、`sidebar.history.dynamic` 是 **D-012 改名遗留的孤儿键**——`AtlasRoute` 只有 `case ledger`，无 `history` 用例，这几条永不渲染
  - `route.history.subtitle`（「跟踪任务、结果和恢复入口。」）与 `route.ledger.subtitle`（「记录每次任务的结果与恢复入口。」）是**近义重复**，前者为孤儿
