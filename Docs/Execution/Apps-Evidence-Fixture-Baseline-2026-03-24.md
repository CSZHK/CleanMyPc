# Apps Evidence Fixture Baseline — 2026-03-24

## Goal

Freeze the validating fixture set for `EPIC-A: Apps Evidence Execution` so uninstall preview, completion, history, and post-restore refresh behavior are tested against the same comparison pressure every time.

## Scope

This baseline applies only to the frozen MVP `Apps`, `History`, and `Recovery` surfaces.

## Fixture Matrix

| Fixture Class | Recommended App | Acceptable Equivalent | Why It Matters | Expected Evidence Pattern |
|---------------|-----------------|-----------------------|----------------|---------------------------|
| Mainstream GUI | `Final Cut Pro` | another large GUI app with visible support files and caches | Validates the everyday “large app plus obvious leftovers” uninstall story | bundle + support files + caches |
| Developer-heavy | `Xcode` | another developer tool with heavy support/cache footprint | Validates Atlas against developer cleanup expectations | bundle + support files + caches + logs |
| Launch-item / service-adjacent | `Docker` | another app that leaves launch-agent or service-adjacent traces | Validates that Atlas records service-adjacent evidence honestly without overclaiming removal | bundle + launch-item evidence + other review-only groups |
| Sparse leftover | lightweight utility with small prefs/saved-state trail | any app that leaves only a small preference or saved-state record | Validates that Atlas does not inflate shallow evidence into a scary uninstall story | bundle + minimal review-only evidence, or bundle-only |

## Selection Rules

- Prefer the named apps when available so comparisons stay stable across runs.
- If a named app is unavailable, substitute only with an app that matches the same evidence pattern.
- Do not add fixtures that require new MVP surfaces or unsupported cleanup classes.
- Record the actual app used in the test log whenever a substitute is chosen.

## Benchmark Rubric

### Preview Evidence

- Atlas must show the recoverable bundle action explicitly.
- Atlas must group leftover evidence by supported categories instead of collapsing everything into a single leftover count.
- At least one review-only group for the validating fixture must expose concrete observed paths.

### Completion Evidence

- The uninstall completion summary must describe what Atlas actually removed.
- If review-only evidence exists, the completion summary must also state that Atlas recorded it rather than removed it.
- The summary must not imply launch-item or service removal unless Atlas actually performed it.

### History / Recovery Evidence

- Recovery detail must distinguish the recoverable bundle from review-only leftover evidence.
- Recovery detail must preserve the uninstall evidence taxonomy captured at uninstall time.
- History must remain compatible with older app recovery payloads that did not record the richer evidence shape.

### Post-Restore Evidence Refresh

- After app restore, Atlas must refresh the current app inventory before it reuses leftover counts in `Apps`.
- If refresh succeeds, `Apps` must surface a fresh post-restore evidence state.
- If refresh cannot confirm current evidence, `Apps` must surface an explicit stale-evidence state instead of silently reusing old counts.

## Pass Threshold

- All four fixture classes have a named validating app or approved substitute.
- Each fixture class maps to at least one expected evidence pattern above.
- The same fixture set can be reused in preview, uninstall, history, restore, and post-restore refresh checks without redefining the benchmark.

## Non-Goals

- Expanding beyond the frozen MVP modules.
- Treating fixture breadth as a proxy for release readiness.
- Claiming full parity with broader uninstall tools.
