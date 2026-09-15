# Copy Guidelines

## Tone

- Calm
- Direct
- Reassuring
- Technical only when necessary

## Product Voice

- Explain what happened first.
- Explain impact second.
- Offer a next step every time.
- Avoid fear-based maintenance language.

## Good Patterns

- `Results may be incomplete without Full Disk Access.`
- `You can keep using limited mode and grant access later.`
- `Most selected actions are recoverable.`

## Avoid

- `Critical error`
- `Illegal operation`
- `You must allow this`
- `Your Mac is at risk`

## CTA Style

- Use clear verbs: `Retry`, `Open System Settings`, `Review Plan`, `Restore`
- Avoid generic CTA labels such as `OK` and `Continue`

## Glossary

> **zh/en 双语**，2026-09-14 由 `REQ-ux-friction-remediation` 的 Wave 0 定稿、Wave 3 回写。
> 定稿与逐项裁定见 `iterations/REQ-ux-friction-remediation/terminology-baseline.md`；
> 产品内可读入口见 Settings 的「术语表」（`P2-1`）。

| en | zh | 含义 |
|---|---|---|
| `Scan` | 扫描 | read-only analysis that collects findings; it never removes anything by itself. |
| `Plan` | 计划 | a numbered scan product (`№N`) carrying the reviewed set of steps Atlas proposes from the current findings; superseded plans are archived to the Ledger. Each rescan produces a new № and voids the prior one. |
| `Cleanup Plan` / `Uninstall Plan` | 清理计划 / 卸载计划 | the actionable set of reviewed steps Atlas proposes from current findings. |
| `Review` | 复核 | the user checks the plan before it runs. Avoid using `preview` as the primary noun when the UI is really showing a plan. |
| `Run Plan` / `Run Uninstall` | 执行清理计划 / 执行卸载 | apply a reviewed plan. Use this for the action that changes the system. |
| `Reclaimable Space` | 预计可释放空间 | the estimated space the current plan can free. Make it explicit when the value recalculates after execution. |
| `Recoverable` | 可恢复 | Atlas can restore the result from the Ledger while the retention window is still open. |
| `Restore point` | 恢复点 | the stamp a run leaves behind when it creates recovery items. |
| `Retention window` | 保留窗口 | how long a recovery item stays restorable (rendered as 「保留 N 天」). |
| `Ledger` (was `History`) | 台账 | the warm-paper record surface: numbered plans, restore points, and the archive of past runs. **D-012 保留，不重开。** |
| `Scan Receipt` | 扫描回执 | per-scan identifier (e.g. #A1F3) stamped on a plan; links back into the Ledger. |
| `App Footprint` | 应用足迹 | the current disk space an app uses. |
| `Leftover Files` | 残留文件 | extra support files, caches, or launch items related to an app uninstall. |
| `Evidence` | 证据 | what Atlas found. Listing it does not remove it. |
| `Limited Mode` | 受限模式 | Atlas works with partial permissions and asks for more access only when a specific workflow needs it. |
| `Full Disk Access` / `Accessibility` / `Notifications` | 完全磁盘访问 / 辅助功能 / 通知 | macOS system permission names — do not translate. |
| `Destination` | 目标位置 | where File Organizer moves files (the path value; the settings section itself is 「整理目标」). |

### 拆词与量词规则（Wave 0 而定，勿回退）

- **「已归档」已拆**：恢复项过期 → 已过期 / `Expired`（**不可恢复的终态**）；任务失败或取消 → 已结束 / `Archived`。两者不得再共用一个词。
- **量词分离**：权限语境一律「**个**」+ 显式名词语素「权限」；文件 / 发现语境一律「**项**」。
- **`Conditional`** 是形容词（风险等级），zh 用「有条件」，不得译成动作（如「需确认」）。
- **同名消歧**：阶段条的「复核」是术语表里的 `Review`；风险筛选 chip 用「待复核」/`Needs Review`。
- **`可重试`**：只有回执上真有重试入口时才可用这个措辞；否则删去。

### 体系词解释（zh 定稿）

- **残留** — 卸载或清理后仍留在磁盘上的配置文件、缓存和启动项。
- **足迹** — 一个应用当前在磁盘上占用的全部空间。
- **台账** — Atlas 自己保存的操作记录，也是恢复入口。
- **证据** — Atlas 扫到、但本次不会移除的清单。列出来不等于会移除。

## Consistency Rules

- Prefer `plan` over `preview` when referring to the actionable object the user can run.
- Use `review` for the decision step before execution, not for the execution step itself.
- If a button opens macOS settings, label it `Open System Settings` instead of implying Atlas grants access directly.
- Distinguish `current plan` from `remaining items after execution` whenever reclaimable-space values can change.
- Keep permission language calm and reversible: explain what access unlocks, whether it can wait, and what the next step is.

## Calm Ledger zh / en Copy Reference (spec §5.4)

| zh-Hans | en | Notes |
|---|---|---|
| 计划 №42 | Plan №42 | Visual glyph `№` shared; a11y label expands to 计划编号 42 / Plan number 42 |
| 扫描回执 #A1F3 | Scan Receipt #A1F3 | Receipt identifier per scan/plan |
| 台账 | Ledger | Empty state appends one sentence positioning the module |
| 恢复点已建立 · X GB · 保留 7 天 | Restore point created · X GB · kept for 7 days | Restore-point stamp |
| 已验证 ✓ | Verified ✓ | Evidence verification mark |
| 已作废（重扫后旧计划） | Superseded | Old plan after a rescan |

### Containment Rules

- **Documentary tone is confined to the Ledger surface (warm paper).** The numbered `№`, restore-point stamps, and "已入账 №N · 撤销" toast all live there or in the per-plan receipt view (work-module stage ④).
- **Work surfaces use plain, direct verbs.** Action-bar primary buttons read `执行清理计划` / `Run Cleanup Plan`, not signing-style language. Do not use legal-association verbs like 签署 / sign / certify on work surfaces.
- **Recovery promises are state-driven**, never aspirational: the action bar only prints a restore-point promise when a restore point has actually been established for the current plan; otherwise it shows the plain status.
