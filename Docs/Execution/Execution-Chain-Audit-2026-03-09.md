# Execution Chain Audit — 2026-03-09

## Scope

This audit reviews the user-visible execution path for:

- `Smart Clean` scan
- `Smart Clean` execute
- `Apps` uninstall preview / execute
- `Recovery` restore
- worker selection and fallback behavior

## Summary

Atlas currently ships a mixed execution model:

- `Smart Clean` scan is backed by a real upstream dry-run adapter.
- `Apps` inventory is backed by a real local inventory adapter.
- `App uninstall` can invoke the packaged helper for the main app bundle path.
- `Smart Clean` execute now supports a real Trash-based execution path for a safe subset of structured user-owned cleanup targets, but broader execution coverage is still incomplete.
- `Restore` is currently state rehydration, not physical file restoration.
- Worker submission can silently fall back from XPC to the scaffold worker, which makes execution capability look stronger than it really is.

## End-to-End Chain

### 1. UI and App Model

- `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift:190` starts Smart Clean scan through `workspaceController.startScan()`.
- `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift:230` runs the current Smart Clean plan through `workspaceController.executePlan(planID:)`.
- `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift:245` immediately refreshes the plan after execution, so the UI shows the remaining plan rather than the just-executed plan.

### 2. Application Layer

- `Packages/AtlasApplication/Sources/AtlasApplication/AtlasApplication.swift:281` maps scan requests into structured worker requests.
- `Packages/AtlasApplication/Sources/AtlasApplication/AtlasApplication.swift:319` maps plan execution into a worker request and trusts the returned snapshot/events.
- The application layer does not distinguish between “state-only execution” and “real filesystem side effects”.

### 3. Worker Selection

- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasXPCTransport.swift:272` defines `AtlasPreferredWorkerService`.
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasXPCTransport.swift:288` submits to XPC first.
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasXPCTransport.swift:291` silently falls back to `AtlasScaffoldWorkerService` on any XPC error.

## Real vs Scaffold Classification

### Real or Mostly Real

#### Smart Clean scan

- `XPC/AtlasWorkerXPC/Sources/AtlasWorkerXPC/main.swift:5` wires `MoleSmartCleanAdapter` into the worker.
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:319` uses the configured `smartCleanScanProvider` when available.
- `Packages/AtlasCoreAdapters/Sources/AtlasCoreAdapters/MoleSmartCleanAdapter.swift:12` runs the upstream `bin/clean.sh --dry-run` flow and parses findings.

Result:
- The scan result can reflect the actual machine state.

#### Apps list

- `XPC/AtlasWorkerXPC/Sources/AtlasWorkerXPC/main.swift:8` wires `MacAppsInventoryAdapter` into the worker.
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:495` refreshes app inventory from the real adapter when available.

Result:
- App footprint listing is grounded in real local inventory.

#### App uninstall bundle removal

- `XPC/AtlasWorkerXPC/Sources/AtlasWorkerXPC/main.swift:9` wires the helper client into the worker.
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:533` checks whether the bundle path exists.
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:552` invokes the helper with `AtlasHelperAction(kind: .trashItems, targetPath: app.bundlePath)`.
- `Helpers/AtlasPrivilegedHelper/Sources/AtlasPrivilegedHelperCore/HelperActionExecutor.swift:35` supports `trashItems`.

Result:
- The main `.app` bundle path can be moved through the helper boundary.

### Mixed Real / Incomplete

#### Smart Clean execute

- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:383` begins Smart Clean plan execution.
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:414` removes selected findings from the in-memory snapshot.
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:416` recalculates reclaimable space from the remaining findings only.
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:417` rebuilds the current plan from the remaining findings.

What is now real:
- Structured scan findings can carry concrete `targetPaths`.
- Safe user-owned targets are moved to Trash during execution.
- `scan -> execute -> rescan` is now covered for a file-backed safe target path.

What is still missing:
- Broad execution coverage for all Smart Clean categories.
- A helper-backed strategy for protected or privileged Smart Clean targets.
- A physical restoration flow that mirrors the new real Trash-based execution path.

User-visible consequence:
- Safe structured targets can now disappear on the next real scan. Unsupported targets fail closed instead of pretending to be cleaned.

#### Restore

- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:445` restores items by re-inserting stored payloads into Atlas state.
- No physical restore operation is performed against the filesystem.

User-visible consequence:
- Recovery currently restores Atlas’s structured workspace model, not a verified on-disk artifact.

## Protocol and Domain Gaps

### Current protocol shape

- `Packages/AtlasProtocol/Sources/AtlasProtocol/AtlasProtocol.swift:92` only allows helper actions such as `trashItems` and `removeLaunchService`.
- `Packages/AtlasDomain/Sources/AtlasDomain/AtlasDomain.swift:109` defines `ActionItem.Kind` values such as `removeCache`, `removeApp`, `archiveFile`, and `inspectPermission`.

Gap:
- `ActionItem.Kind` communicates user intent, but it does not carry the executable path set or helper-ready structured target information required to make Smart Clean execution real.

## Risks

### R-011 Smart Clean Execution Trust Gap

- Severity: `High`
- Area: `Execution / UX / Trust`
- Risk: The UI presents Smart Clean execution as if it performs disk cleanup, but the current worker only mutates Atlas state for Smart Clean items.
- User impact: Users can believe cleanup succeeded even when the next scan rediscovers the same disk usage.
- Recommended action: Make execution capability explicit and block release-facing trust claims until Smart Clean execution is backed by real side effects.

### R-012 Silent Fallback Masks Capability Loss

- Severity: `High`
- Area: `System / Execution`
- Risk: Silent fallback from XPC to the scaffold worker can hide worker/XPC failures and blur the line between real execution and fallback behavior.
- User impact: Local execution may look successful even when the primary worker path is unavailable.
- Recommended action: Remove or narrow silent fallback in user-facing execution paths and surface a concrete error when real execution infrastructure is unavailable.

## Recommended Fix Order

1. Remove silent fallback for release-facing execution flows or gate it behind an explicit development-only mode.
2. Introduce executable structured targets for Smart Clean action items so the worker can perform real side effects.
3. Route Smart Clean destructive actions through the helper boundary where privilege or safety validation is required.
4. Add `scan -> execute -> rescan` contract coverage proving real disk impact.
5. Separate “logical recovery in Atlas state” from “physical file restoration” in both UI copy and implementation.

## Acceptance Criteria for the Follow-up Fix

- Running Smart Clean on real findings reduces those findings on a subsequent real scan.
- If the worker/helper cannot perform the action, the user sees a clear failure rather than a silent fallback success.
- History records only claim completion when the filesystem side effect actually happened.
- Recovery messaging distinguishes between physical restoration and model restoration until both are truly implemented.
