# Calm Ledger 重设计 — M0 治理 + M1 Token 层 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 Calm Ledger 重设计的治理工件（D-012、EPIC-E、REQ/CHG/.agent），并落地设计系统 v3 的 Token 层（色彩 xcassets 化 + 三声部字型 + 动效 + 对比度门禁脚本 + 中文宋体/№ 字形实测），分支内构建与测试全绿。

**Architecture:** 单一 JSON Token 清单（`scripts/design/calm-ledger-tokens.json`）作为 hex 唯一真相源，驱动两个 Node 脚本：对比度门禁（WCAG AA 校验）与 colorset 生成器（写入 `AtlasColors.xcassets`）。Swift 侧 `AtlasBrand.swift` 全量改为 colorset 引用（移除 `@MainActor` 运行时外观查询），字型改三声部（SF Pro / SF Mono / New York+宋体 cascade）。旧 API 名最大化保留（`success/warning` 等仅换值），仅 `heroMetric/cardMetric` 改名（共 ~8 个调用点）。

**Tech Stack:** Swift 6 / SwiftUI（macOS 14+）、SPM、XCTest、Node.js ≥18（脚本，无第三方依赖）

**规格真相源:** `Docs/design/2026-06-10-frontend-redesign-calm-ledger.md`（v1.1）。本计划为 5 份计划序列之一（M0+M1）；M2（组件层）、M3（屏幕迁移）、M4（收尾）计划在各自里程碑边界编写。

**约定:** 所有命令在仓库根 `/Users/zhukang/CleanMyPc` 执行。每个任务结尾提交一次。

---

## Task 1: 创建分支并将 Docs/product 入库（M0 起点）

**Files:**
- 无代码改动；git 操作 + 既有 untracked 目录入库

- [ ] **Step 1: 创建长分支**

```bash
git checkout -b redesign/calm-ledger
```
Expected: `Switched to a new branch 'redesign/calm-ledger'`

- [ ] **Step 2: 将产品目标文档入库（规格 §0.4：长期真相必须受版本控制）**

```bash
git add Docs/product/
git commit -m "docs(product): track next-stage product goals (governance: durable truth must be version-controlled)"
```
Expected: 2 files changed（`next-stage-product-goals-2026-06.md`、`next-stage-goals-review-2026-06.md`）

## Task 2: D-012 决策入档

**Files:**
- Modify: `Docs/DECISIONS.md`（在 `### D-011 …` 小节之后、`## Update Rule` 之前插入）

- [ ] **Step 1: 插入以下完整小节**

```markdown
### D-012 Calm Ledger Frontend Redesign

- The design truth source moves from `Docs/DESIGN_SPEC.md` (v2 "Calm Authority") to `Docs/design/2026-06-10-frontend-redesign-calm-ledger.md` (v1.1 "Calm Ledger") once the redesign branch merges
- The `History` module is renamed to `台账` (zh-Hans) / `Ledger` (en); route identifier `AtlasRoute.history` becomes `AtlasRoute.ledger`; the SPM package name `AtlasFeaturesHistory` is retained
- The frozen-MVP route-name contract test (`testPrimaryRoutesMatchFrozenMVP`) is explicitly unfrozen for this rename; the unfreeze is recorded in `iterations/REQ-calm-ledger-redesign/requirement.md`
- Default window size becomes 1180×740 (minimum 980×640); existing users keep their autosaved frame — the evidence-drawer tier is the accepted baseline for them
- `File Organizer` is retroactively recognized as an in-scope production module (it shipped in v1.0.8 without a decision entry)
- The redesign is **not** a mainline epic: it runs inside the EPIC-D external-blockage window under the interrupt protocol defined in the design spec §0.3 (pause at milestone boundary when signing credentials arrive; EPIC-D resumes with full priority; redesign branch rebases main per milestone)
- The Startup module sidebar slot remains **contingent on a separate D-010 update** and must not ship before that approval
```

- [ ] **Step 2: Commit**

```bash
git add Docs/DECISIONS.md
git commit -m "docs(decisions): add D-012 Calm Ledger redesign (rename, truth source, window size, governance position)"
```

## Task 3: Backlog 增补 EPIC-E

**Files:**
- Modify: `Docs/Backlog.md`

- [ ] **Step 1: 在 `- \`EPIC-D\` Release Readiness` 行之后追加一行**

```markdown
- `EPIC-E` Calm Ledger Frontend Redesign (non-mainline; runs in EPIC-D blockage window per D-012; UI-automation baseline ATL-267 must land AFTER this merges)
```

- [ ] **Step 2: 在 `### Now` 小节末尾追加（不删除既有行）**

```markdown
- `EPIC-E` Calm Ledger Redesign — M0 governance + M1 token layer in progress on `redesign/calm-ledger` (interrupt protocol: design spec §0.3)
```

- [ ] **Step 3: Commit**

```bash
git add Docs/Backlog.md
git commit -m "docs(backlog): add EPIC-E Calm Ledger redesign with EPIC-D interrupt ordering"
```

## Task 4: 建立 REQ 包（requirement / trace / tasks）

**Files:**
- Create: `iterations/REQ-calm-ledger-redesign/requirement.md`
- Create: `iterations/REQ-calm-ledger-redesign/trace.md`
- Create: `iterations/REQ-calm-ledger-redesign/tasks/m0-governance.md` … `tasks/m4-closeout.md`（5 个占位任务卡）

- [ ] **Step 1: 写 `requirement.md`**

```markdown
# REQ-calm-ledger-redesign

## Title
Calm Ledger 前端全面重设计（一次到位）

## Change Class
MAJOR — 全部 8 屏 + 壳层 + 设计系统 v3 + IA 改名，长分支整体交付

## Status
OPEN

## Priority
P0（EPIC-E；非 mainline，受 EPIC-D 中断协议约束）

## Truth Sources
- 设计规格: Docs/design/2026-06-10-frontend-redesign-calm-ledger.md (v1.1)
- 决策: Docs/DECISIONS.md (D-009 / D-010 / D-012)
- IA: Docs/IA.md（M4 同步）
- 文案: Docs/COPY_GUIDELINES.md（M4 同步）
- 实施计划序列: Docs/plans/2026-06-10-calm-ledger-m0-m1.md（M2/M3/M4 计划在里程碑边界补充）

## Description
按规格 v1.1 执行「Calm Ledger · 平静台账」重设计：三声部字型、双气质表面色彩、阶段条 + 证据面板 + 行动栏骨架、历史→台账改名、概览三段式。纯前端：Worker / XPC / 协议零改动。

## Contract Unfreeze Record
- `AtlasDomainTests.testPrimaryRoutesMatchFrozenMVP` 冻结路由名包含「历史」；本 REQ 依据 D-012 与产品负责人 2026-06-10 会话确认将其解冻为「台账」。

## Project Constraints
- Swift 6 strict concurrency；macOS 14.0+；不引入第三方依赖
- 全部用户可见字符串过 AtlasL10n（zh-Hans 默认 + en）
- Feature 包只依赖 AtlasDesignSystem + AtlasDomain
- 协议层（AtlasCommand/Response/Event）与 Worker 行为不变（回归红线）
- 每视图文件 ≤ 350 行；可达性红线见规格 §6

## Acceptance（取自规格 §0.2 / §7）
- 8 屏 + 壳层表面全部迁移，无双轨并存
- 对比度脚本（scripts/design/contrast-check.mjs）全部 PASS
- 既有测试（Packages 377 + Apps 29 + Helpers 16）经更新后全绿；新组件有单测
- 双语言 × 双外观 × 两档内容宽手动矩阵通过；zh/en 台账声部截图对比专项通过
- 截图基线重导出（atlas-history.png → atlas-ledger.png 含 README 引用）
```

- [ ] **Step 2: 写 `trace.md`**

```markdown
# REQ-calm-ledger-redesign Trace

## Validation Protocol
- 每任务: 计划文档内的 verify 命令（含期望输出）
- 每里程碑: swift build --package-path Apps + swift test --package-path Packages + node scripts/design/contrast-check.mjs
- M3 起每屏: 手动矩阵抽查（双语言 × 双外观 × 两档内容宽）
- 最终: 规格 §7 全量验收 + 人工 UI 审查

## Blast Radius
- Packages/AtlasDesignSystem: token 全量重铸 + 9 新组件 + AtlasScreen 插槽
- Packages/AtlasFeatures*: 全部 6 个 feature 包视图重写/拆分
- Apps/AtlasApp: 壳层（侧栏/工具栏/任务中心/菜单/窗口尺寸）+ AtlasAppModel ViewState
- Packages/AtlasDomain: AtlasRoute 改名 + L10n 键迁移（~120 键 × 2 语言）
- 不触碰: AtlasProtocol / AtlasInfrastructure / XPC / Helpers / Go

## Required Validation Modules
- swift build --package-path Apps
- swift test --package-path Packages / Apps / Helpers
- node scripts/design/contrast-check.mjs（M1 起为合并门禁）
- 人工: 手动矩阵 + zh/en 台账声部对比 + VoiceOver 抽查

## Docs Sync（规格 §0.4 全表）
DECISIONS(D-012) / Backlog(EPIC-E) / IA / COPY_GUIDELINES / DESIGN_SPEC(头注) / PRD / ROADMAP / HELP_CENTER_OUTLINE / WORKSPACE_LAYOUT / README 截图 / Docs/product 入库

## Planned Verification
| Phase | Verify Command | Status |
|-------|---------------|--------|
| M0 | git log 检查 5 个治理 commit；ls iterations/REQ-calm-ledger-redesign | PENDING |
| M1 | node scripts/design/contrast-check.mjs && swift test --package-path Packages && swift build --package-path Apps | PENDING |
| M2 | swift test --package-path Packages（新组件单测全绿） | PENDING |
| M3 | swift test --package-path Packages && swift test --package-path Apps + 每屏手动矩阵 | PENDING |
| M4 | ./scripts/test.sh + 截图重导 + 双语言键集合 diff 脚本 0 缺失 | PENDING |

## Actual Verification
（执行时填写）

## Actual Deliverables
（执行时填写）

## Close Gate
M0–M4 全部 Planned Verification = PASS + 手动矩阵 + 人工 UI 审查通过
```

- [ ] **Step 3: 写 5 个任务卡（每个 3–5 行，指向对应计划文档）**

`tasks/m0-governance.md`:
```markdown
# M0 治理工件
状态: IN_PROGRESS
计划: Docs/plans/2026-06-10-calm-ledger-m0-m1.md Task 1–6
产出: 分支 / D-012 / EPIC-E / REQ 包 / CHG 包 / .agent 三件套
```

`tasks/m1-tokens.md`:
```markdown
# M1 Token 层
状态: PENDING
计划: Docs/plans/2026-06-10-calm-ledger-m0-m1.md Task 7–14
产出: token 清单 + 对比度门禁 + colorsets + AtlasColor/Typography/Motion/Layout v3 + 宋体/№ 实测
```

`tasks/m2-components.md`:
```markdown
# M2 组件层
状态: PENDING
计划: Docs/plans/2026-06-XX-calm-ledger-m2.md（M1 收口后编写）
产出: 9 新组件 + AtlasScreen 插槽 + 修改/吸收/扩展清单（规格 §4.2/§4.3）
```

`tasks/m3-screens.md`:
```markdown
# M3 屏幕迁移
状态: PENDING
计划: Docs/plans/2026-06-XX-calm-ledger-m3.md（M2 收口后编写）
产出: 智能清理样板间（含阶段状态机）→ 台账 → 概览 → 应用 → 文件整理 → 权限 → 设置/关于 + 壳层表面
```

`tasks/m4-closeout.md`:
```markdown
# M4 收尾
状态: PENDING
计划: Docs/plans/2026-06-XX-calm-ledger-m4.md（M3 收口后编写）
产出: 路由/L10n 脚本迁移 + 文档同步（规格 §0.4）+ 可达性全检 + 截图基线 + 手动矩阵
```

- [ ] **Step 4: Commit**

```bash
git add iterations/REQ-calm-ledger-redesign/
git commit -m "chore(governance): scaffold REQ-calm-ledger-redesign (requirement, trace, milestone tasks)"
```

## Task 5: 建立 CHG 包与 .agent 三件套

**Files:**
- Create: `changes/CHG-2026-06-calm-ledger-m0m1/brief.md`
- Create: `changes/CHG-2026-06-calm-ledger-m0m1/verify.md`
- Create: `.agent/calm-ledger-redesign-execplan.md`
- Create: `.agent/calm-ledger-redesign-findings.md`
- Create: `.agent/calm-ledger-redesign-progress.md`

- [ ] **Step 1: 写 `changes/CHG-2026-06-calm-ledger-m0m1/brief.md`**

```markdown
# CHG-2026-06-calm-ledger-m0m1

- REQ: REQ-calm-ledger-redesign
- Task: m0-governance + m1-tokens
- Scope: 治理工件 + 设计系统 v3 Token 层（不含组件/屏幕）
- Canonical Plan: Docs/plans/2026-06-10-calm-ledger-m0-m1.md
- Note: `bin/ato-iter` 在本仓库缺失；按 CLAUDE.md 治理采用手工等价流程（本 brief/verify 即等价物），已升级产品负责人确认（2026-06-10 会话）。
```

- [ ] **Step 2: 写 `changes/CHG-2026-06-calm-ledger-m0m1/verify.md`**

```markdown
# Verify — CHG-2026-06-calm-ledger-m0m1

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | 治理工件齐备 | ls iterations/REQ-calm-ledger-redesign changes/CHG-2026-06-calm-ledger-m0m1 .agent | 3 处均存在对应文件 |
| 2 | 对比度门禁 | node scripts/design/contrast-check.mjs | `ALL PASS`，exit 0 |
| 3 | colorset 生成幂等 | node scripts/design/generate-colorsets.mjs && git status --porcelain Packages | 第二次运行无 diff |
| 4 | 包测试 | swift test --package-path Packages | 全绿（377 + M1 新增） |
| 5 | App 构建 | swift build --package-path Apps | Build complete! |
| 6 | 宋体 cascade | swift test --package-path Packages --filter AtlasDesignSystemTests.testLedgerFontCascade | PASS（FAIL 即触发规格 §1.3 降级决策点，升级人审） |
```

- [ ] **Step 3: 写 `.agent/calm-ledger-redesign-execplan.md`**

```markdown
# Calm Ledger Redesign — ExecPlan（指针文件，不复制内容，避免双真相）

- 规格: Docs/design/2026-06-10-frontend-redesign-calm-ledger.md (v1.1)
- 当前计划: Docs/plans/2026-06-10-calm-ledger-m0-m1.md
- REQ: iterations/REQ-calm-ledger-redesign/
- 当前 CHG: changes/CHG-2026-06-calm-ledger-m0m1/
- 里程碑: M0 ▶ M1 ▷ M2 ▷ M3 ▷ M4（计划按边界续写）
- 中断协议: 规格 §0.3（签名凭据到位 → 当前里程碑边界暂停，EPIC-D 恢复）
```

- [ ] **Step 4: 写 `.agent/calm-ledger-redesign-findings.md`**

```markdown
# Findings 索引
- 4 agent 评审结论已合入规格 v1.1（commit 26c6776）；原始评审全文见会话记录，关键结论：路由无持久化（改名为编译期清单）、zh serif 需显式 Songti cascade、语义色对比度定稿值已重算、EPIC-D 中断协议落入 §0.3。
- M1 实测待办: 宋体 cascade 观感（降级决策点）、№ U+2116 在 New York 的字形覆盖。
```

- [ ] **Step 5: 写 `.agent/calm-ledger-redesign-progress.md`**

```markdown
# Progress
- [x] 设计规格 v1.1 提交（26c6776）
- [ ] M0 治理工件（本计划 Task 1–6）
- [ ] M1 Token 层（本计划 Task 7–14）
- [ ] M2 / M3 / M4（计划待编写）
```

- [ ] **Step 6: Commit**

```bash
git add changes/ .agent/calm-ledger-redesign-execplan.md .agent/calm-ledger-redesign-findings.md .agent/calm-ledger-redesign-progress.md
git commit -m "chore(governance): add CHG-m0m1 brief/verify and .agent execplan/findings/progress"
```

## Task 6: M0 验收

- [ ] **Step 1: 核验治理工件**

```bash
ls iterations/REQ-calm-ledger-redesign/ changes/CHG-2026-06-calm-ledger-m0m1/ && git log --oneline -6
```
Expected: requirement.md/trace.md/tasks 存在；brief/verify 存在；6 个 commit（分支起点 + 5 个治理提交）

- [ ] **Step 2: 更新 `.agent/calm-ledger-redesign-progress.md` 勾掉 M0 行，commit**

```bash
git add .agent/calm-ledger-redesign-progress.md && git commit -m "chore(governance): M0 complete"
```

---

## Task 7: Token 清单（hex 唯一真相源）

**Files:**
- Create: `scripts/design/calm-ledger-tokens.json`

- [ ] **Step 1: 写入完整清单（值全部来自规格 §1.2，禁止改动）**

```json
{
  "$comment": "Calm Ledger v1.1 token manifest — single source of truth for hex values. Consumed by contrast-check.mjs and generate-colorsets.mjs. Spec: Docs/design/2026-06-10-frontend-redesign-calm-ledger.md §1.2",
  "colors": {
    "AtlasBrand":          { "light": "#0F766E", "dark": "#1FB5A3" },
    "AtlasBrandHover":     { "light": "#149F8C", "dark": "#2BC4B1" },
    "AtlasAccent":         { "light": "#34D399", "dark": "#52E2B5" },
    "AtlasInk":            { "light": "#10302C", "dark": "#E9F1ED" },
    "AtlasInkData":        { "light": "#0F3C36", "dark": "#E9F1ED" },
    "AtlasTextBody":       { "light": "#2C403B", "dark": "#D7E3DE" },
    "AtlasTextSecondary":  { "light": "#5D736D", "dark": "#9FB3AC" },
    "AtlasTextTertiary":   { "light": "#637672", "dark": "#7E938C" },
    "AtlasCanvasTop":      { "light": "#EEF7F4", "dark": "#0F1413" },
    "AtlasCanvasBottom":   { "light": "#F8FBFA", "dark": "#141A18" },
    "AtlasSurface":        { "light": "#FFFFFF", "dark": "#1A211F" },
    "AtlasSurfaceSubdued": { "light": "#F8FBFA", "dark": "#202926" },
    "AtlasSurfaceInput":   { "light": "#F4F8F6", "dark": "#161D1B" },
    "AtlasSurfaceBorder":  { "light": "#E4EEEA", "dark": "#2B3633" },
    "AtlasLedgerPaper":    { "light": "#FDFCF8", "dark": "#221F19" },
    "AtlasLedgerInk":      { "light": "#2A2620", "dark": "#CFC8B8" },
    "AtlasLedgerSecondary":{ "light": "#7A7160", "dark": "#9C9482" },
    "AtlasLedgerBorder":   { "light": "#E8E0CF", "dark": "#3C3830" },
    "AtlasLedgerRule":     { "light": "#D8CFBA", "dark": "#4A4338" },
    "AtlasSafe":           { "light": "#0F766E", "dark": "#4ADE9E" },
    "AtlasSafeFill":       { "light": "#E7F6EF", "dark": "#18342B" },
    "AtlasReview":         { "light": "#8F5E0B", "dark": "#E8A33D" },
    "AtlasReviewFill":     { "light": "#FDF3E3", "dark": "#3A2E18" },
    "AtlasDanger":         { "light": "#B93330", "dark": "#F07B72" },
    "AtlasDangerFill":     { "light": "#FDECEA", "dark": "#3A211F" },
    "AtlasInfo":           { "light": "#2B66AE", "dark": "#6FA8E8" },
    "AtlasInfoFill":       { "light": "#EAF2FB", "dark": "#1C2C40" },
    "AtlasActionBarBg":    { "light": "#10302C", "dark": "#0C2421" },
    "AtlasActionBarText":  { "light": "#9FD4C9", "dark": "#9FD4C9" },
    "AtlasActionBarData":  { "light": "#52E2B5", "dark": "#52E2B5" },
    "AtlasCardRaised":     { "light": "#FFFFFFA6", "dark": "#FFFFFF0F" },
    "AtlasHeroSurface":    { "light": "#00000005", "dark": "#FFFFFF0A" }
  },
  "contrastPairs": [
    { "fg": "AtlasTextBody",       "bg": "AtlasSurface",        "min": 4.5 },
    { "fg": "AtlasTextSecondary",  "bg": "AtlasSurface",        "min": 4.5 },
    { "fg": "AtlasTextTertiary",   "bg": "AtlasSurface",        "min": 4.5 },
    { "fg": "AtlasInk",            "bg": "AtlasSurface",        "min": 4.5 },
    { "fg": "AtlasInkData",        "bg": "AtlasSurface",        "min": 3.0 },
    { "fg": "AtlasLedgerInk",      "bg": "AtlasLedgerPaper",    "min": 4.5 },
    { "fg": "AtlasLedgerSecondary","bg": "AtlasLedgerPaper",    "min": 4.5 },
    { "fg": "AtlasSafe",           "bg": "AtlasSafeFill",       "min": 4.5 },
    { "fg": "AtlasReview",         "bg": "AtlasReviewFill",     "min": 4.5 },
    { "fg": "AtlasDanger",         "bg": "AtlasDangerFill",     "min": 4.5 },
    { "fg": "AtlasInfo",           "bg": "AtlasInfoFill",       "min": 4.5 },
    { "fg": "AtlasActionBarText",  "bg": "AtlasActionBarBg",    "min": 4.5 },
    { "fg": "AtlasActionBarData",  "bg": "AtlasActionBarBg",    "min": 3.0 },
    { "fg": "AtlasTextSecondary",  "bg": "AtlasSurfaceSubdued", "min": 4.5 },
    { "fg": "AtlasBrand",          "bg": "AtlasSurface",        "min": 4.5 }
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add scripts/design/calm-ledger-tokens.json
git commit -m "feat(design): add Calm Ledger token manifest (single hex source of truth)"
```

## Task 8: 对比度门禁脚本（先于取色实现——这是 M1 的「失败测试」）

**Files:**
- Create: `scripts/design/contrast-check.mjs`

- [ ] **Step 1: 写脚本（完整代码）**

```javascript
#!/usr/bin/env node
// WCAG AA contrast gate for Calm Ledger tokens.
// Usage: node scripts/design/contrast-check.mjs   (exit 1 on any failure)
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)));
const manifest = JSON.parse(readFileSync(join(root, "calm-ledger-tokens.json"), "utf8"));

function srgb(hex) {
  const h = hex.replace("#", "");
  const v = (i) => parseInt(h.slice(i, i + 2), 16) / 255;
  return [v(0), v(2), v(4)]; // alpha (if present) ignored: gate checks opaque pairs only
}
function luminance(hex) {
  const lin = srgb(hex).map((c) => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2];
}
function ratio(fg, bg) {
  const [l1, l2] = [luminance(fg), luminance(bg)].sort((a, b) => b - a);
  return (l1 + 0.05) / (l2 + 0.05);
}

let failures = 0;
for (const pair of manifest.contrastPairs) {
  for (const mode of ["light", "dark"]) {
    const fg = manifest.colors[pair.fg]?.[mode];
    const bg = manifest.colors[pair.bg]?.[mode];
    if (!fg || !bg) { console.error(`MISSING token: ${pair.fg} or ${pair.bg} (${mode})`); failures++; continue; }
    const r = ratio(fg, bg);
    const ok = r >= pair.min;
    if (!ok) failures++;
    console.log(`${ok ? "PASS" : "FAIL"}  [${mode}] ${pair.fg} on ${pair.bg}  ${r.toFixed(2)}:1  (min ${pair.min})`);
  }
}
if (failures > 0) { console.error(`\n${failures} failure(s)`); process.exit(1); }
console.log("\nALL PASS");
```

- [ ] **Step 2: 运行验证（值已在规格评审中逐对计算过，应全过）**

```bash
node scripts/design/contrast-check.mjs
```
Expected: 30 行 `PASS …`，末行 `ALL PASS`，exit 0。若任何 FAIL：**停下**，对照规格 §1.2 修清单值（规格是真相源），不得调低 min。

- [ ] **Step 3: Commit**

```bash
git add scripts/design/contrast-check.mjs
git commit -m "feat(design): add WCAG AA contrast gate script (M1+ merge gate)"
```

## Task 9: colorset 生成器 + 生成 32 个 colorset

**Files:**
- Create: `scripts/design/generate-colorsets.mjs`
- Generate: `Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/Resources/AtlasColors.xcassets/<Name>.colorset/Contents.json` × 32（覆盖既有 AtlasBrand/AtlasAccent）

- [ ] **Step 1: 写生成器（完整代码；输出格式镜像既有 AtlasBrand.colorset）**

```javascript
#!/usr/bin/env node
// Generates .colorset bundles from calm-ledger-tokens.json. Idempotent.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const manifest = JSON.parse(readFileSync(join(here, "calm-ledger-tokens.json"), "utf8"));
const xcassets = join(here, "../../Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/Resources/AtlasColors.xcassets");

function components(hex) {
  const h = hex.replace("#", "");
  const c = (i) => (parseInt(h.slice(i, i + 2), 16) / 255).toFixed(10);
  const alpha = h.length === 8 ? (parseInt(h.slice(6, 8), 16) / 255).toFixed(10) : "1.0000000000";
  return { red: c(0), green: c(2), blue: c(4), alpha };
}
function entry(appearanceValue, hex) {
  return {
    idiom: "universal",
    appearances: [{ appearance: "luminosity", value: appearanceValue }],
    color: { "color-space": "srgb", components: components(hex) },
  };
}
for (const [name, modes] of Object.entries(manifest.colors)) {
  const dir = join(xcassets, `${name}.colorset`);
  mkdirSync(dir, { recursive: true });
  const json = {
    colors: [entry("light", modes.light), entry("dark", modes.dark)],
    info: { author: "xcode", version: 1 },
  };
  writeFileSync(join(dir, "Contents.json"), JSON.stringify(json, null, 2) + "\n");
  console.log(`wrote ${name}.colorset`);
}
console.log(`\n${Object.keys(manifest.colors).length} colorsets generated`);
```

- [ ] **Step 2: 运行并核验幂等**

```bash
node scripts/design/generate-colorsets.mjs && node scripts/design/generate-colorsets.mjs && git status --porcelain | head
```
Expected: 两次输出 `32 colorsets generated`；`git status` 显示新增/修改的 colorset 文件（第二次运行不再追加 diff）

- [ ] **Step 3: Commit**

```bash
git add scripts/design/generate-colorsets.mjs "Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/Resources/AtlasColors.xcassets"
git commit -m "feat(design-system): generate Calm Ledger colorsets from token manifest (32 colorsets)"
```

## Task 10: 失败测试 — Token v3 存在性与三声部

**Files:**
- Modify: `Packages/AtlasDesignSystem/Tests/AtlasDesignSystemTests/AtlasDesignSystemTests.swift`（文件末尾 `}` 之前追加）

- [ ] **Step 1: 追加以下测试（此时不编译/失败 = 红）**

```swift
    // MARK: - Calm Ledger v3 Tokens

    func testCalmLedgerColorTokensExist() {
        let _ = AtlasColor.ink
        let _ = AtlasColor.inkData
        let _ = AtlasColor.surface
        let _ = AtlasColor.surfaceSubdued
        let _ = AtlasColor.surfaceInput
        let _ = AtlasColor.ledgerPaper
        let _ = AtlasColor.ledgerInk
        let _ = AtlasColor.ledgerSecondary
        let _ = AtlasColor.ledgerBorder
        let _ = AtlasColor.ledgerRule
        let _ = AtlasColor.successFill
        let _ = AtlasColor.warningFill
        let _ = AtlasColor.dangerFill
        let _ = AtlasColor.infoFill
        let _ = AtlasColor.actionBarBg
        let _ = AtlasColor.actionBarText
        let _ = AtlasColor.actionBarData
        let _ = AtlasColor.brandHover
        let _ = AtlasColor.cardRaised   // v3: no longer @MainActor — plain static let
        let _ = AtlasColor.heroSurface  // v3: no longer @MainActor — plain static let
    }

    func testThreeVoiceTypographyExists() {
        let _ = AtlasTypography.dataHero
        let _ = AtlasTypography.dataMetric
        let _ = AtlasTypography.dataBody
        let _ = AtlasTypography.dataCaption
        let _ = AtlasTypography.ledgerTitle
        let _ = AtlasTypography.ledgerNumber
    }

    func testMotionStageTokensExist() {
        let _ = AtlasMotion.stageTransition
        let _ = AtlasMotion.stampIn
    }

    func testLayoutBreakpoints() {
        XCTAssertEqual(AtlasLayout.evidencePanelMinWidth, 300)
        XCTAssertEqual(AtlasLayout.evidencePanelBreakpoint, 880)
        XCTAssertEqual(AtlasLayout.actionBarCompactBreakpoint, 740)
    }

    func testLedgerFontCascadeResolvesSongtiForChinese() {
        // 规格 §1.3: zh 台账声部必须显式解析到 Songti SC，不依赖系统回退。
        // FAIL ⇒ 触发规格降级决策点（serif 仅限拉丁工件），升级人审，不得静默跳过。
        let nsFont = AtlasTypography.ledgerNSFont(size: 19, weight: .bold)
        let sample = "台账" as CFString
        let resolved = CTFontCreateForString(nsFont as CTFont, sample, CFRange(location: 0, length: 2))
        let family = CTFontCopyFamilyName(resolved) as String
        XCTAssertTrue(family.contains("Songti"), "zh ledger voice resolved to '\(family)', expected Songti SC")
    }

    func testNumeroGlyphAvailableInLedgerFont() {
        // 规格 §1.3: № (U+2116) 需在台账声部可用；缺失则 en 回退 "No."（M2 组件层处理）。
        let nsFont = AtlasTypography.ledgerNSFont(size: 13, weight: .bold)
        let resolved = CTFontCreateForString(nsFont as CTFont, "№" as CFString, CFRange(location: 0, length: 1))
        var chars: [UniChar] = [0x2116]
        var glyphs: [CGGlyph] = [0]
        let ok = CTFontGetGlyphsForCharacters(resolved, &chars, &glyphs, 1)
        XCTAssertTrue(ok && glyphs[0] != 0, "№ glyph unavailable — record fallback decision in findings")
    }
```

- [ ] **Step 2: 运行确认编译失败（红）**

```bash
swift test --package-path Packages --filter AtlasDesignSystemTests 2>&1 | tail -5
```
Expected: 编译错误 `has no member 'ink'` 等 —— 失败确认

## Task 11: 实现 AtlasColor v3 + Typography 三声部 + Motion/Layout（绿）

**Files:**
- Modify: `Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/AtlasBrand.swift`

- [ ] **Step 1: 用以下内容替换 `AtlasColor` 整个 enum（行 24–102）**

```swift
// MARK: - Color Tokens

/// Calm Ledger palette — every value lives in AtlasColors.xcassets (light+dark),
/// generated from scripts/design/calm-ledger-tokens.json. Do not hardcode hex here.
public enum AtlasColor {

    // ── Brand ──────────────────────────────────────────
    public static let brand = Color("AtlasBrand", bundle: .module)
    /// Hover/pressed fill variant — fills and borders only, never text (spec §1.2).
    public static let brandHover = Color("AtlasBrandHover", bundle: .module)
    /// Mint accent — non-text uses only (progress, badges, decoration).
    public static let accent = Color("AtlasAccent", bundle: .module)

    // ── Semantic (spec: safe/review/danger/info — API keeps legacy names) ──
    public static let success = Color("AtlasSafe", bundle: .module)
    public static let warning = Color("AtlasReview", bundle: .module)
    public static let danger  = Color("AtlasDanger", bundle: .module)
    public static let info    = Color("AtlasInfo", bundle: .module)
    public static let successFill = Color("AtlasSafeFill", bundle: .module)
    public static let warningFill = Color("AtlasReviewFill", bundle: .module)
    public static let dangerFill  = Color("AtlasDangerFill", bundle: .module)
    public static let infoFill    = Color("AtlasInfoFill", bundle: .module)

    // ── Surfaces ───────────────────────────────────────
    public static let canvasTop = Color("AtlasCanvasTop", bundle: .module)
    public static let canvasBottom = Color("AtlasCanvasBottom", bundle: .module)
    public static let surface = Color("AtlasSurface", bundle: .module)
    public static let surfaceSubdued = Color("AtlasSurfaceSubdued", bundle: .module)
    public static let surfaceInput = Color("AtlasSurfaceInput", bundle: .module)
    /// Legacy alias — migrate consumers to `surface` during M3, then remove.
    public static var card: Color { surface }
    public static let cardRaised = Color("AtlasCardRaised", bundle: .module)
    public static let heroSurface = Color("AtlasHeroSurface", bundle: .module)

    // ── Ledger paper (warm trust surface, spec §1.2 边界) ──
    public static let ledgerPaper = Color("AtlasLedgerPaper", bundle: .module)
    public static let ledgerInk = Color("AtlasLedgerInk", bundle: .module)
    public static let ledgerSecondary = Color("AtlasLedgerSecondary", bundle: .module)
    public static let ledgerBorder = Color("AtlasLedgerBorder", bundle: .module)
    public static let ledgerRule = Color("AtlasLedgerRule", bundle: .module)

    // ── Text ───────────────────────────────────────────
    public static let ink = Color("AtlasInk", bundle: .module)
    public static let inkData = Color("AtlasInkData", bundle: .module)
    public static let textPrimary = Color("AtlasTextBody", bundle: .module)
    public static let textSecondary = Color("AtlasTextSecondary", bundle: .module)
    public static let textTertiary = Color("AtlasTextTertiary", bundle: .module)

    // ── Border ─────────────────────────────────────────
    public static let border = Color("AtlasSurfaceBorder", bundle: .module)
    public static let borderEmphasis = Color.primary.opacity(0.14)

    // ── Action bar (ink-dark pinned bar) ───────────────
    public static let actionBarBg = Color("AtlasActionBarBg", bundle: .module)
    public static let actionBarText = Color("AtlasActionBarText", bundle: .module)
    public static let actionBarData = Color("AtlasActionBarData", bundle: .module)

    // ── Gradients ──────────────────────────────────────
    /// Legacy hero gradient (brand → accent). M3 migrates hero uses; keep for compatibility.
    public static var brandGradient: LinearGradient {
        LinearGradient(colors: [brand, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// Next-action banner gradient (spec §3: brand → brandHover, 135°).
    public static var bannerGradient: LinearGradient {
        LinearGradient(colors: [brand, brandHover], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
```

- [ ] **Step 2: 用以下内容替换 `AtlasTypography` 整个 enum（原行 104–145）**

```swift
// MARK: - Typography Tokens (three voices, spec §1.3)

/// ① UI voice: SF Pro (default design — rounded removed in v3)
/// ② Data voice: SF Mono — every number, size, path, timestamp
/// ③ Ledger voice: New York + Songti SC explicit cascade — ledger artifacts ONLY
public enum AtlasTypography {

    // ── ① UI voice ─────────────────────────────────────
    public static let screenTitle = Font.system(size: 28, weight: .bold)
    public static let sectionTitle = Font.system(size: 17, weight: .semibold)
    public static let label      = Font.subheadline.weight(.semibold)
    public static let rowTitle   = Font.system(size: 13, weight: .semibold)
    public static let body       = Font.system(size: 13)
    public static let bodySmall  = Font.system(size: 11)
    public static let caption    = Font.system(size: 11, weight: .semibold)
    public static let captionSmall = Font.system(size: 10)

    // ── ② Data voice (SF Mono) ─────────────────────────
    public static let dataHero   = Font.system(size: 42, weight: .semibold, design: .monospaced)
    public static let dataMetric = Font.system(size: 26, weight: .semibold, design: .monospaced)
    public static let dataBody   = Font.system(size: 12, design: .monospaced)
    public static let dataCaption = Font.system(size: 10.5, design: .monospaced)

    // ── ③ Ledger voice (serif + zh Songti cascade) ─────
    public static let ledgerTitle = ledgerFont(size: 19, weight: .bold)
    public static let ledgerNumber = ledgerFont(size: 13, weight: .bold)

    /// Serif with explicit Songti SC cascade so zh-Hans renders 宋体, not PingFang
    /// (system serif fallback for CJK is undefined across OS versions — spec §1.3).
    public static func ledgerFont(size: CGFloat, weight: Font.Weight) -> Font {
        Font(ledgerNSFont(size: size, weight: weight.nsWeight))
    }

    /// NSFont variant exposed for CoreText feasibility tests.
    public static func ledgerNSFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        var descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        let songti = NSFontDescriptor(fontAttributes: [.family: "Songti SC"])
        descriptor = descriptor.addingAttributes([.cascadeList: [songti]])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}

private extension Font.Weight {
    var nsWeight: NSFont.Weight {
        switch self {
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        default: return .regular
        }
    }
}
```

并为 `testLedgerFontCascade*` 的重载提供桥接：`ledgerNSFont(size:weight:)` 已按 `NSFont.Weight` 暴露——测试中 `.bold` 直接可用。

- [ ] **Step 3: `AtlasMotion` 末尾（`spring` 之后）追加两个 token**

```swift
    /// Stage-bar content transition — 12pt slide + fade (spec §1.5).
    public static let stageTransition = Animation.snappy(duration: 0.30)
    /// Stamp-in spring for completion / recovery-point moments (spec §1.5).
    public static let stampIn = Animation.spring(response: 0.45, dampingFraction: 0.62)
    // countUp is NOT an Animation: implemented as contentTransition(.numericText()) in M2 components.
```

- [ ] **Step 4: `AtlasLayout` 中 `browserSplitThreshold` 声明处替换为**

```swift
    /// DEPRECATED (Calm Ledger M3 removes): superseded by evidencePanelBreakpoint.
    /// Still consumed by AppsFeatureView / HistoryFeatureView until their M3 migration.
    public static let browserSplitThreshold: CGFloat = 860
    /// Evidence panel minimum width (spec §4.1).
    public static let evidencePanelMinWidth: CGFloat = 300
    /// Below this content width the evidence panel becomes a slide-over drawer (spec §2.4).
    public static let evidencePanelBreakpoint: CGFloat = 880
    /// Below this content width the action bar collapses to primary + shield badge (spec §2.4).
    public static let actionBarCompactBreakpoint: CGFloat = 740
```

- [ ] **Step 5: 高程调淡（规格 §1.4：阴影 −30%，去内发光）— `AtlasElevation` 中两处值替换**

```swift
    public var shadowOpacity: Double {
        switch self {
        case .flat:      return 0
        case .raised:    return 0.035
        case .prominent: return 0.063
        }
    }
```

并删除 `atlasCardBackground` 中 `// Prominent cards get a subtle top-left inner glow` 起的整个 `if elevation == .prominent { … }` 块。

- [ ] **Step 6: 文件头注释（行 1–18）更新为 Calm Ledger 叙述**

```swift
// MARK: - Atlas Brand Identity & Design Tokens
//
// Brand Concept: "Calm Ledger / 平静台账" (spec: Docs/design/2026-06-10-frontend-redesign-calm-ledger.md)
//   Calm shell × precise mono data × ledger trust artifacts.
//
// Visual Language:
//   - Cool work surfaces (white cards on mint-white canvas) vs warm ledger paper
//   - Three type voices: SF Pro (UI) / SF Mono (data) / New York+Songti (ledger artifacts only)
//   - Three elevation tiers, shadows softened 30% vs v2; no glassmorphism
//   - Continuous corners; motion snappy, never bouncy; reduce-motion respected
//
// Tokens are colorset-backed (AtlasColors.xcassets), generated from
// scripts/design/calm-ledger-tokens.json. Run scripts/design/contrast-check.mjs
// before changing any value.
```

- [ ] **Step 7: 编译（仍会因 heroMetric/cardMetric 消费者而红）**

```bash
swift build --package-path Packages 2>&1 | grep -E "error|warning: .*deprecated" | head -20
```
Expected: `has no member 'heroMetric'` / `'cardMetric'` 类错误（消费者待迁移——Task 12 处理）

## Task 12: 迁移 heroMetric/cardMetric 调用点（约 8 处）

**Files:**
- Modify: `grep` 命中的 feature view 文件（预期含 AtlasFeaturesOverview / Permissions / SmartClean 等 + AtlasHeroCard）

- [ ] **Step 1: 定位全部调用点**

```bash
grep -rn "AtlasTypography.heroMetric\|AtlasTypography.cardMetric" Packages Apps --include="*.swift"
```
Expected: 约 8 处（评审实测各 ~4 处）

- [ ] **Step 2: 机械替换**

- `AtlasTypography.heroMetric` → `AtlasTypography.dataHero`
- `AtlasTypography.cardMetric` → `AtlasTypography.dataMetric`

（语义不变：这两个位置只承载数字，正是数据声部。）

- [ ] **Step 3: 同步清理 `AtlasCircularProgress.swift` 内 2 处 `.rounded`**

```bash
grep -n "rounded" Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/Components/AtlasCircularProgress.swift
```
将命中行的 `design: .rounded` 改为 `design: .monospaced`（环内是百分比数字 → 数据声部）。

- [ ] **Step 4: 构建至绿**

```bash
swift build --package-path Packages && swift build --package-path Apps
```
Expected: 两个 `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add -A Packages Apps
git commit -m "feat(design-system): Calm Ledger token layer v3 — colorset palette, three-voice typography, motion/layout tokens, elevation softening"
```

## Task 13: 测试全绿 + 宋体/№ 实测决策点

- [ ] **Step 1: 跑设计系统测试**

```bash
swift test --package-path Packages --filter AtlasDesignSystemTests 2>&1 | tail -10
```
Expected: 全 PASS（含 Task 10 新增 6 个）。

**决策点（规格 §8 M1）**: 若 `testLedgerFontCascadeResolvesSongtiForChinese` 或 `testNumeroGlyphAvailableInLedgerFont` FAIL —— 不得删测/跳过：在 `.agent/calm-ledger-redesign-findings.md` 记录实测结果，按规格 §1.3 降级方案（zh 台账声部改界面声部加字重差异 / en № 回退 "No."）修订规格后再继续，并升级人审。

- [ ] **Step 2: 跑全量 Packages 测试（确认零回归）**

```bash
swift test --package-path Packages 2>&1 | tail -3
```
Expected: `Test Suite 'All tests' passed`，总数 = 377 + 6 新增 = 383（若存量中有依赖旧色值的失败，逐个核对——预期为 0：评审确认存量断言均为存在性/单调性检查）

- [ ] **Step 3: Commit（如有测试侧微调）**

```bash
git add -A Packages
git commit -m "test(design-system): Calm Ledger v3 token tests green incl. Songti cascade and numero glyph probes"
```

## Task 14: M1 验收 + CHG 收口

- [ ] **Step 1: 跑 CHG verify 全表**

```bash
node scripts/design/contrast-check.mjs && \
node scripts/design/generate-colorsets.mjs && git status --porcelain Packages | wc -l && \
swift test --package-path Packages 2>&1 | tail -2 && \
swift build --package-path Apps 2>&1 | tail -1
```
Expected: `ALL PASS` ；幂等行数 `0`；测试 passed；`Build complete!`

- [ ] **Step 2: 回填治理工件**

- `iterations/REQ-calm-ledger-redesign/trace.md`: M0、M1 行 Status → `PASS`，`Actual Verification` 粘贴 Step 1 输出摘要
- `iterations/REQ-calm-ledger-redesign/tasks/m0-governance.md` / `m1-tokens.md`: 状态 → DONE
- `.agent/calm-ledger-redesign-progress.md`: 勾掉 M1 行
- `changes/CHG-2026-06-calm-ledger-m0m1/verify.md`: 表格追加 `Result` 列填 PASS

- [ ] **Step 3: Commit**

```bash
git add iterations changes .agent
git commit -m "chore(governance): M1 verified — token layer green, contrast gate passing, CHG-m0m1 closed"
```

- [ ] **Step 4: 汇报暂停点**

向产品负责人汇报：M0+M1 完成、宋体/№ 实测结论、是否触发降级决策；获确认后编写 M2 计划（`Docs/plans/` 下一份，按规格 §4.2/§4.3 九组件逐个 TDD）。

---

## 计划自审记录（writing-plans Self-Review）

1. **Spec coverage（M0+M1 范围）**: 规格 §0.3 治理（Task 1–6 ✓）、§0.4 部分同步（D-012/Backlog/Docs-product ✓，其余属 M4）、§1.2 色彩（Task 7–9, 11 ✓ 含 30 colorset 与对比度门禁）、§1.3 三声部（Task 11 ✓ 宋体 cascade + 实测 Task 10/13 ✓ 钳制上限值此层不实现——macOS 无全局 Dynamic Type，验收口径为 §7 放大档实测，记录于 REQ）、§1.4 高程（Task 11 Step 5 ✓）、§1.5 动效（Task 11 Step 3 ✓，countUp 显式移交 M2）、§4.1 layout（Task 11 Step 4 ✓）。组件/屏幕/改名/L10n 均为 M2–M4 范围，已在 REQ tasks/ 卡片中登记。
2. **Placeholder scan**: 无 TBD/TODO；所有代码块完整可粘贴；唯一的「按 grep 结果替换」（Task 12）给出了精确命令、替换规则与预期数量。
3. **Type consistency**: `AtlasColor.successFill/warningFill`（代码名）↔ 规格 `safeFill/reviewFill`（spec 名）映射已在 Task 11 Step 1 注释声明；`ledgerNSFont(size:weight:)` 测试（Task 10）与实现（Task 11 Step 2）签名一致（`NSFont.Weight`）；`evidencePanelBreakpoint/actionBarCompactBreakpoint` 测试与实现同名同值；colorset 名（manifest）与 `Color("…")` 字符串逐一核对一致（30/30）。
