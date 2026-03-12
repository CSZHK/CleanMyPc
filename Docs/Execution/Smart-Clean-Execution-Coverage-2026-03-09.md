# Smart Clean Execution Coverage — 2026-03-09

## Goal

Explain, in user-facing and release-facing terms, what `Smart Clean` can execute for real today, what still fails closed, and how recovery behaves for executed items.

This document is intentionally simpler than `Docs/Execution/Execution-Chain-Audit-2026-03-09.md`. It is meant to support product, UX, QA, and release communication.

## Current Position

`Smart Clean` no longer presents a misleading “success” when only scaffold/state-based execution is available.

The current behavior is now:

- real scan when the upstream clean workflow succeeds
- real execution for a safe structured subset of targets
- physical restoration for executed items when recovery mappings are present
- explicit failure for unsupported or unstructured targets
- the UI now distinguishes cached plans from current-session verified plans and blocks execution until a plan is refreshed in the current session

## What Runs for Real Today

`Smart Clean` can physically move supported targets to Trash when the scan adapter returns structured execution targets.

### Supported direct Trash targets

These user-owned targets can be moved to Trash directly by the worker when they are returned as structured `targetPaths`:

- `~/Library/Caches/*`
- `~/Library/Logs/*`
- `~/Library/Suggestions/*`
- `~/Library/Messages/Caches/*`
- `~/Library/Developer/Xcode/DerivedData/*`
- `~/.npm/*`
- `~/.npm_cache/*`
- `~/.oh-my-zsh/cache/*`
- paths containing:
  - `__pycache__`
  - `.next/cache`
  - `component_crx_cache`
  - `GoogleUpdater`
  - `CoreSimulator.log`
- `.pyc` files under the current user home directory

### Supported helper-backed targets

Targets under these allowlisted roots can run through the helper boundary:

- `/Applications/*`
- `~/Applications/*`
- `~/Library/LaunchAgents/*`
- `/Library/LaunchAgents/*`
- `/Library/LaunchDaemons/*`

## What Does Not Run Yet

The following categories remain incomplete unless they resolve to the supported structured targets above:

- broader `System` cleanup paths
- partially aggregated dry-run results that do not yet carry executable sub-paths
- categories that only expose a summary concept rather than concrete target paths
- any Smart Clean item that requires a more privileged or more specific restore model than the current Trash-backed flow supports

For these items, Atlas should fail closed rather than claim completion.

## User-Facing Meaning

### Cached vs current plan

Atlas can persist the last generated Smart Clean plan across launches. That cached plan is useful for orientation, but it is not treated as directly executable until the current session successfully runs a fresh scan or plan update.

The UI now makes this explicit by:

- marking cached plans as previous results
- disabling `Run Plan` until the plan is revalidated
- showing which plan steps can run directly and which remain review-only


### When execution succeeds

It means:

- Atlas had concrete target paths for the selected plan items
- those targets were actually moved to Trash
- recovery records were created with enough information to support physical restoration for those targets

It does **not** mean:

- every Smart Clean category is fully implemented
- every reviewed item is physically restorable in every environment
- privileged or protected targets are universally supported yet

### When execution is rejected

It means Atlas is protecting trust by refusing to report a cleanup it cannot prove.

Typical reasons:

- the scan adapter did not produce executable targets for the item
- the current path falls outside the supported execution allowlist
- the required worker/helper capability is unavailable

## Recovery Model

### Physical restore available

When a recovery item contains structured `restoreMappings`, Atlas can move the trashed item back to its original path.

This is currently the most trustworthy recovery path because it corresponds to a real on-disk side effect.

### Model-only restore still possible

Older or unstructured recovery records may only restore Atlas’s internal workspace model.

That means:

- the item can reappear in Atlas UI state
- the underlying file may not be physically restored on disk

## Product Messaging Guidance

Use these statements consistently in user-facing communication:

- `Smart Clean runs real cleanup only for supported items in the current plan.`
- `Unsupported items stay review-only until Atlas can execute them safely.`
- `Recoverable items can be restored when a recovery path is available.`
- `Some recoverable items restore on disk, while older or unstructured records restore Atlas state only.`
- `If Atlas cannot prove the cleanup step, it should fail instead of claiming success.`

Avoid saying:

- `Smart Clean cleans everything it scans`
- `All recoverable items can always be restored physically`
- `Execution succeeded` when the action only changed in-app state

## Release Gate Recommendation

Do not describe `Smart Clean` as fully disk-backed until all major frozen-MVP Smart Clean categories support:

- structured execution targets
- real filesystem side effects
- physical recovery where promised
- `scan -> execute -> rescan` verification
