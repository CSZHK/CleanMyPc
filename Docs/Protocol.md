# Local Protocol

## Goals

- Provide a stable local contract between UI, worker, and helper components.
- Avoid parsing terminal-oriented text output.
- Support progress, execution, history, recovery, settings, and helper handoff.

## Protocol Version

- Current implementation version: `0.3.1`

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

## Current Implementation Note

- `health.snapshot` is backed by `lib/check/health_json.sh` through `MoleHealthAdapter`.
- `scan.start` is backed by `bin/clean.sh --dry-run` through `MoleSmartCleanAdapter` when the upstream workflow succeeds. If it cannot complete, the worker now rejects the request instead of silently fabricating scan results.
- `apps.list` is backed by `MacAppsInventoryAdapter`, which scans local app bundles and derives leftover counts.
- The worker persists a local JSON-backed workspace state containing the latest snapshot, current Smart Clean plan, and settings, including the persisted app-language preference.
- The repository and worker normalize recovery state by pruning expired `RecoveryItem`s and rejecting restore requests that arrive after the retention window has closed.
- Atlas localizes user-facing shell copy through a package-scoped resource bundle and uses the persisted language to keep summaries and settings text aligned.
- App uninstall can invoke the packaged or development helper executable through structured JSON actions.
- Structured Smart Clean findings can now carry executable target paths, and a safe subset of those targets can be moved to Trash and physically restored later.
- Structured Smart Clean action items now also carry `targetPaths`, and `plan.execute` prefers those plan-carried targets. Older cached plans can still fall back to finding-carried targets for backward compatibility.
- The app shell communicates with the worker over structured XPC `Data` payloads that encode Atlas request and result envelopes.

- `executePlan` is fail-closed for unsupported targets, but now supports a real Trash-based execution path for a safe structured subset of Smart Clean items.
- `recovery.restore` can physically restore items when `restoreMappings` are present; otherwise it falls back to model rehydration only.
- `recovery.restore` rejects expired recovery items with `restoreExpired` and rejects destination collisions with `restoreConflict`.
