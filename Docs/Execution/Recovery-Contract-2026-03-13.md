# Recovery Contract — 2026-03-13

## Goal

Freeze Atlas recovery semantics against the behavior that is actually shipped today.

## Scope

- `ATL-221` physical restore for file-backed recoverable actions where safe
- `ATL-222` restore validation on real file-backed test cases
- `ATL-223` README, in-app, and release-facing recovery claim audit
- `ATL-224` recovery contract and acceptance evidence freeze

## Canonical Contract

### 1. What a recovery item means

- Every recoverable destructive flow must produce a structured `RecoveryItem`.
- A `RecoveryItem` may carry `restoreMappings` that pair the original path with the actual path returned from Trash.
- `restoreMappings` are the only shipped proof that Atlas can claim an on-disk return path for that item.

### 2. When Atlas can claim physical restore

Atlas can claim physical on-disk restore only when all of the following are true:

- the recovery item still exists in active Atlas recovery state
- its retention window is still open
- the recovery item contains at least one `restoreMappings` entry
- the trashed source still exists on disk
- the original destination path does not already exist
- the required execution capability is available:
  - direct move for supported user-trashable targets such as `~/Library/Caches/*` and `~/Library/pnpm/store/*`
  - helper-backed restore for protected targets such as app bundles under `/Applications` or `~/Applications`

### 3. When Atlas restores state only

If a recovery item has no `restoreMappings`, Atlas may still restore Atlas workspace state by rehydrating the saved `Finding` or `AppFootprint` payload.

State-only restore means:

- the item reappears in Atlas UI state
- the action remains auditable in History
- Atlas does not claim the underlying file or bundle returned on disk

### 4. Failure behavior

Restore remains fail-closed. Atlas rejects the restore request instead of claiming success when:

- the recovery item has expired and is no longer active in recovery state (`restoreExpired`)
- the trash source no longer exists
- the original destination already exists (`restoreConflict`)
- the target falls outside the supported direct/helper allowlist
- a required helper capability is unavailable (`helperUnavailable`)
- another restore precondition fails after validation (`executionUnavailable`)

### 5. History and completion wording

- Disk-backed restores must use the disk-specific completion summary.
- State-only restores must use the Atlas-only completion summary.
- Mixed restore batches must report both clauses instead of collapsing everything into a physical-restore claim.

## Accepted Physical Restore Surface

### Direct restore paths

The currently proven direct restore surface is the same safe structured subset used by Smart Clean execution:

- `~/Library/Caches/*`
- `~/Library/pnpm/store/*`
- other targets explicitly allowed by `AtlasSmartCleanExecutionSupport.isDirectlyTrashable`

### Helper-backed restore paths

The currently proven helper-backed restore surface includes app bundles that require the privileged helper path:

- `/Applications/*.app`
- `~/Applications/*.app`

## Claim Audit

The following surfaces now match the frozen contract and must stay aligned:

- `README.md`
- `README.zh-CN.md`
- `Docs/Protocol.md`
- `Docs/Execution/Smart-Clean-Execution-Coverage-2026-03-09.md`
- `Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings`
- `Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings`

No additional README or in-app narrowing is required in this slice because the shipped wording already distinguishes:

- supported on-disk restore
- Atlas-only state restoration
- fail-closed behavior for unsupported or unprovable actions

## Release-Note-Safe Wording

Future release notes must stay within these statements unless the restore surface expands and new evidence is added:

- `Recoverable items can be restored when a supported recovery path is available.`
- `Some recoverable items restore on disk, while older or unstructured records restore Atlas state only.`
- `Atlas only claims physical return when it recorded a supported restore path for that item.`
- `Unsupported or unavailable restore paths fail closed instead of being reported as restored.`

Avoid saying:

- `All recoverable items restore physically.`
- `History always returns deleted files to disk.`
- `Restore succeeded` when Atlas only rehydrated workspace state.

## Acceptance Evidence

### Automated proof points

- `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift`
  - `testRepositorySaveStatePrunesExpiredRecoveryItems`
  - `testRestoreRecoveryItemPhysicallyRestoresRealTargets`
  - `testExecuteAppUninstallRestorePhysicallyRestoresAppBundle`
  - `testRestoreItemsStateOnlySummaryDoesNotClaimOnDiskRestore`
  - `testRestoreItemsMixedSummaryIncludesDiskAndStateOnlyClauses`
  - `testRestoreItemsRejectsExpiredRecoveryItemsAndPrunesThem`
  - `testRestoreItemsRejectsWhenDestinationAlreadyExists`
  - `testScanExecuteRescanRemovesExecutedTargetFromRealResults`
  - `testScanExecuteRescanRemovesExecutedPnpmStoreTargetFromRealResults`
- `Packages/AtlasApplication/Tests/AtlasApplicationTests/AtlasApplicationTests.swift`
  - `testRestoreItemsMapsRestoreExpiredToLocalizedError`
  - `testRestoreItemsMapsRestoreConflictToLocalizedError`
- `Docs/Execution/Smart-Clean-Manual-Verification-2026-03-09.md`
- `Docs/Execution/Smart-Clean-QA-Checklist-2026-03-09.md`

### What the evidence proves

- direct-trash file-backed recovery physically returns a real file to its original path
- helper-backed app uninstall recovery physically returns a real app bundle to its original path
- Atlas-only recovery records do not overclaim on-disk restore
- mixed restore batches preserve truthful summaries when disk-backed and Atlas-only items are restored together
- expired recovery items are pruned from active recovery state and fail closed if a restore arrives after expiry
- destination collisions return a stable restore-specific rejection instead of claiming completion
- supported file-backed targets still satisfy `scan -> execute -> rescan` credibility checks

## Remaining Limits

- Physical restore is intentionally partial, not universal.
- Older or unstructured recovery entries remain Atlas-state-only unless they carry `restoreMappings`.
- Broader restore scope must not ship without new allowlist review, automated coverage, and matching copy updates.
