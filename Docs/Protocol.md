# Local Protocol

## Goals

- Provide a stable local contract between UI, worker, and helper components.
- Avoid parsing terminal-oriented text output.
- Support progress, execution, history, recovery, settings, and helper handoff.

## Protocol Version

- Current implementation version: `0.3.2`

## UI ↔ Worker Commands

- `health.snapshot`
- `permissions.inspect`
- `scan.start`
- `plan.preview`
- `plan.execute`
- `recovery.restore`
- `apps.list`
- `apps.uninstall.preview`
- `apps.uninstall.execute`
- `settings.get`
- `settings.set`

## Worker ↔ Helper Models

### `AtlasHelperAction`

- `id`
- `kind`
- `targetPath`
- `destinationPath` (required for restore-style actions)

### `AtlasHelperActionResult`

- `action`
- `success`
- `message`
- `resolvedPath`

## Response Payloads

- `accepted(task)`
- `health(snapshot)`
- `permissions(permissionStates)`
- `apps(appFootprints)`
- `preview(actionPlan)`
- `settings(settings)`
- `rejected(code, reason)`

### Error Codes in Current Use

- `unsupportedCommand`
- `permissionRequired`
- `helperUnavailable`
- `executionUnavailable`
- `restoreExpired`
- `restoreConflict`
- `invalidSelection`

## Event Payloads

- `taskProgress(taskID, completed, total)`
- `taskFinished(taskRun)`
- `permissionUpdated(permissionState)`

## Core Schemas

### Finding

- `id`
- `category`
- `title`
- `detail`
- `bytes`
- `risk`
- `targetPaths` (optional structured execution targets derived from the scan adapter)

### ActionPlan

- `id`
- `title`
- `items`
- `estimatedBytes`

### ActionItem

- `id`
- `title`
- `detail`
- `kind`
- `recoverable`
- `targetPaths` (optional structured execution targets carried by the current plan)
- `evidencePaths` (optional structured review-only evidence paths carried by the current plan; not executable intent)

### TaskRun

- `id`
- `kind`
- `status`
- `summary`
- `startedAt`
- `finishedAt`

### AppFootprint

- `id`
- `name`
- `bundleIdentifier`
- `bundlePath`
- `bytes`
- `leftoverItems`

### RecoveryItem

- `id`
- `title`
- `detail`
- `originalPath`
- `bytes`
- `deletedAt`
- `expiresAt`
- `payload`
- `restoreMappings` (optional original-path ↔ trashed-path records for physical restoration)

### AppRecoveryPayload

- `schemaVersion`
- `app`
- `uninstallEvidence`

App uninstall evidence rules:

- `uninstallEvidence.bundlePath` and `uninstallEvidence.bundleBytes` are the recoverable bundle evidence reused by preview, completion, and history.
- `uninstallEvidence.reviewOnlyGroups` are structured review-only leftover evidence groups that remain informational and auditable.

## Workspace State Persistence

Atlas persists local workspace state in a versioned JSON envelope:

- `schemaVersion`
- `savedAt`
- `snapshot`
- `currentPlan`
- `settings`

Compatibility rules:

- legacy top-level `AtlasWorkspaceState` files must still decode on load
- after a successful legacy decode, Atlas may rewrite the file into the current versioned envelope
- legacy app recovery payloads that stored a raw `AppFootprint` must still decode into the current `AppRecoveryPayload` shape

### AtlasSettings

- `recoveryRetentionDays`
- `notificationsEnabled`
- `excludedPaths`
- `language`
- `acknowledgementText`
- `thirdPartyNoticesText`

## Protocol Rules

- Progress must be monotonic.
- Rejected requests return a stable code plus a user-facing reason.
- Destructive flows must end in a history record.
- Recoverable flows must produce structured recovery items.
- Helper actions must remain allowlisted structured actions, never arbitrary command strings.
- Fresh Smart Clean preview plans should carry `ActionItem.targetPaths` for executable items so execution does not have to reconstruct destructive intent from UI state.
- Review-only uninstall evidence may carry `ActionItem.evidencePaths`, which are informational only and must not be treated as execution targets.
- App restore flows must refresh app inventory before `Apps` reuses leftover counts. If refresh cannot confirm current evidence, `Apps` must show an explicit stale-evidence state.

## Current Implementation Note

- `health.snapshot` is backed by `lib/check/health_json.sh` through `MoleHealthAdapter`.
- `scan.start` is backed by `bin/clean.sh --dry-run` through `MoleSmartCleanAdapter` when the upstream workflow succeeds. If it cannot complete, the worker now rejects the request instead of silently fabricating scan results.
- `apps.list` is backed by `MacAppsInventoryAdapter`, which scans local app bundles and derives lightweight leftover counts suitable for interactive refresh.
- The worker persists a versioned local JSON workspace state containing the latest snapshot, current Smart Clean plan, and settings, including the persisted app-language preference.
- Legacy top-level workspace-state files are migrated on load into the current versioned envelope when possible.
- The repository and worker normalize recovery state by pruning expired `RecoveryItem`s and rejecting restore requests that arrive after the retention window has closed.
- Atlas localizes user-facing shell copy through a package-scoped resource bundle and uses the persisted language to keep summaries and settings text aligned.
- App uninstall can invoke the packaged or development helper executable through structured JSON actions.
- Structured Smart Clean findings can now carry executable target paths, and a safe subset of those targets can be moved to Trash and physically restored later.
- Structured Smart Clean action items now also carry `targetPaths`, and `plan.execute` prefers those plan-carried targets. Older cached plans can still fall back to finding-carried targets for backward compatibility.
- App uninstall preview items may also carry `evidencePaths` for review-only leftover evidence. These are visible in UI detail but must never be executed as destructive targets.
- The app shell communicates with the worker over structured XPC `Data` payloads that encode Atlas request and result envelopes.

- `executePlan` is fail-closed for unsupported targets, but now supports a real Trash-based execution path for a safe structured subset of Smart Clean items.
- `recovery.restore` can physically restore items when `restoreMappings` are present; otherwise it falls back to model rehydration only.
- `recovery.restore` rejects expired recovery items with `restoreExpired` and rejects destination collisions with `restoreConflict`.
- App payload restores now surface post-restore evidence refresh state in `Apps`. Atlas either shows refreshed current evidence or an explicit stale-evidence state after the app-inventory refresh attempt.
