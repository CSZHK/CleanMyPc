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
- `Cleanup Plan` / `Uninstall Plan` — the actionable set of reviewed steps Atlas proposes from current findings.
- `Review` — the user checks the plan before it runs. Avoid using `preview` as the primary noun when the UI is really showing a plan.
- `Run Plan` / `Run Uninstall` — apply a reviewed plan. Use this for the action that changes the system.
- `Reclaimable Space` — the estimated space the current plan can free. Make it explicit when the value recalculates after execution.
- `Recoverable` — Atlas can restore the result from History while the retention window is still open.
- `App Footprint` — the current disk space an app uses.
- `Leftover Files` — extra support files, caches, or launch items related to an app uninstall.
- `Limited Mode` — Atlas works with partial permissions and asks for more access only when a specific workflow needs it.

## Consistency Rules

- Prefer `plan` over `preview` when referring to the actionable object the user can run.
- Use `review` for the decision step before execution, not for the execution step itself.
- If a button opens macOS settings, label it `Open System Settings` instead of implying Atlas grants access directly.
- Distinguish `current plan` from `remaining items after execution` whenever reclaimable-space values can change.
- Keep permission language calm and reversible: explain what access unlocks, whether it can wait, and what the next step is.
