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

- `Scan` — read-only analysis that collects findings; it never removes anything by itself.
- `Plan` — a numbered scan product (`№N`) carrying the reviewed set of steps Atlas proposes from the current findings; superseded plans are archived to the Ledger. Each rescan produces a new № and voids the prior one.
- `Cleanup Plan` / `Uninstall Plan` — the actionable set of reviewed steps Atlas proposes from current findings.
- `Review` — the user checks the plan before it runs. Avoid using `preview` as the primary noun when the UI is really showing a plan.
- `Run Plan` / `Run Uninstall` — apply a reviewed plan. Use this for the action that changes the system.
- `Reclaimable Space` — the estimated space the current plan can free. Make it explicit when the value recalculates after execution.
- `Recoverable` — Atlas can restore the result from the Ledger while the retention window is still open.
- `Ledger` (was `History`; zh 台账) — the warm-paper record surface: numbered plans, restore points, and the archive of past runs.
- `Scan Receipt` — per-scan identifier (e.g. #A1F3) stamped on a plan; links back into the Ledger.
- `App Footprint` — the current disk space an app uses.
- `Leftover Files` — extra support files, caches, or launch items related to an app uninstall.
- `Limited Mode` — Atlas works with partial permissions and asks for more access only when a specific workflow needs it.

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
