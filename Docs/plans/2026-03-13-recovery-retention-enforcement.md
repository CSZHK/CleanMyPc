# Recovery Retention Enforcement Plan

## Goal

Align shipped recovery behavior with the existing Atlas retention contract so expired recovery items are no longer restorable, no longer linger as active recovery entries, and return stable restore-specific protocol errors.

## Problem

The current worker restores any `RecoveryItem` still present in state, even when `expiresAt` is already in the past. The app also keeps the restore action available as long as the item remains selected. This breaks the retention-window claim already present in the protocol, task-state, and recovery docs.

## Options

### Option A: Narrow docs to match current code

- Remove the retention-window restore claim from docs and gate reviews.
- Keep restore behavior unchanged.

Why not:

- It weakens an existing product promise instead of fixing the trust gap.
- It leaves expired recovery items actionable in UI and worker flows.

### Option B: Enforce expiry only inside `restoreItems`

- Reject restore requests when any selected `RecoveryItem.expiresAt` is in the past.
- Leave repository state unchanged.

Why not:

- Expired entries would still linger in active recovery state across launches.
- The app could still display stale recovery items until the user attempts restore.

### Option C: Enforce expiry centrally and prune expired recovery items

- Normalize persisted workspace state so expired recovery items are removed on load/save.
- Recheck expiry in the worker restore path to fail closed for items that expire while the app is open.
- Return stable restore-specific error codes for expiry and restore conflicts.
- Disable restore UI when the selected entry is already expired.

## Decision

Choose Option C.

## Implementation Outline

1. Extend `AtlasProtocolErrorCode` with restore-specific cases used by this flow.
2. Normalize workspace state in `AtlasWorkspaceRepository` by pruning expired `RecoveryItem`s.
3. Recheck expiry in `AtlasScaffoldWorkerService.restoreItems` before side effects.
4. Map restore conflicts such as an already-existing destination to a stable restore-specific rejection.
5. Disable restore actions for expired entries in History UI.
6. Add tests for:
   - expired recovery rejection
   - repository pruning of expired recovery items
   - restore conflict rejection
   - controller localization for restore-specific rejections
7. Update protocol, architecture, task-state, recovery contract, and gate review docs to match the shipped behavior.

## Validation

- `swift test --package-path Packages --filter AtlasInfrastructureTests`
- `swift test --package-path Packages --filter AtlasApplicationTests`
- `swift test --package-path Packages`
