# Internal Beta Hardening Week — 2026-03-16

## Context

This document now serves two purposes:

- the **week plan** for the internal-beta hardening window
- the **execution record** for the hardening work completed on **2026-03-12** before the week formally opens

The path `Docs/Execution/Internal-Beta-Hardening-Week-2026-03-16.md` did not exist at the start of the hardening pass. One side of the rebase introduced the week plan, while the other introduced the initial execution record, so this merged version keeps both.

## Planned Window

- `2026-03-16` to `2026-03-20`

## Goal

Convert the current internal-beta candidate into a more truthful and defensible build by completing clean-machine validation, tightening first-run confidence, and strengthening the real `Smart Clean` execution evidence for the most valuable safe targets.

## Scope

Keep work inside the frozen MVP modules:

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Recovery`
- `Permissions`
- `Settings`

Do not expand into:

- `Storage treemap`
- `Menu Bar`
- `Automation`
- signed public beta work

## Must Deliver

- Clean-machine bilingual QA for first launch, language switching, install path, `Smart Clean`, `Apps`, and `History/Recovery`
- Fresh-state verification using a new workspace-state file and the latest packaged build
- One concrete increment in real `Smart Clean` execute coverage for high-value safe targets
- Stronger `scan -> execute -> rescan` verification for supported `Smart Clean` paths
- A current recovery-boundary note that distinguishes physical restore from model-only restore

## Backlog Mapping

- `ATL-203` Run bilingual manual QA on a clean machine
- `ATL-204` Validate fresh-state first launch from packaged artifacts
- `ATL-211` Expand real `Smart Clean` execute coverage for top safe target classes
- `ATL-213` Add stronger `scan -> execute -> rescan` contract coverage
- `ATL-214` Make history and completion states reflect real side effects only

## Day Plan

- `Day 1` Repackage the current build, run clean-machine bilingual QA, and log all trust or first-run defects
- `Day 2` Validate fresh-state behavior end to end, then close any launch, language, or stale-state regressions found on Day 1
- `Day 3` Implement the next safe-target execution increment for `Smart Clean`
- `Day 4` Add or tighten `scan -> execute -> rescan` coverage and verify history/completion summaries only claim real side effects
- `Day 5` Re-run focused verification, update execution docs, and hold an internal hardening gate review

## Owner Tasks

- `Product Agent`
  - keep execution hardening inside frozen MVP scope
  - decide whether any newly discovered recovery wording needs to narrow further before the next build
- `UX Agent`
  - review first-run, failure, and restore-adjacent wording on the validating build
  - flag any UI text that still implies universal physical restore or universal direct execution
- `Mac App Agent`
  - close first-run and state-presentation issues from clean-machine QA
  - keep `Smart Clean` failure and completion surfaces aligned with real worker outcomes
- `System Agent`
  - extend real `Smart Clean` execution support for the selected safe target classes
  - preserve fail-closed behavior for unsupported targets
- `Core Agent`
  - help carry executable structured targets and result summaries through the worker/application path
- `QA Agent`
  - run clean-machine validation and maintain the issue list
  - add and rerun `scan -> execute -> rescan` verification
- `Docs Agent`
  - update execution notes and recovery-boundary wording when evidence changes

## Validation Plan

### Manual

- Install the latest packaged build on a clean machine
- Verify default app language and switching to `English`
- Verify fresh-state launch with a new workspace-state file
- Run `Smart Clean` scan, preview, execute, and rescan for the supported safe-path fixture
- Verify `History` / `Recovery` wording still matches actual restore behavior

### Automated

- `swift test --package-path Packages`
- `swift test --package-path Apps`
- focused `scan -> execute -> rescan` coverage for the newly supported safe targets
- `./scripts/atlas/full-acceptance.sh` after implementation work lands

## Exit Criteria

- Clean-machine QA is complete and documented
- Fresh-state launch behavior is verified on the latest packaged build
- At least one new high-value safe target class has real `Smart Clean` execution support
- `scan -> execute -> rescan` evidence exists for the newly supported path
- No user-facing copy in the validating build overclaims physical restore or direct execution
- Week-end gate can either pass or fail with a short explicit blocker list

## Known Blockers

- Public release work remains blocked by missing Apple signing and notarization credentials
- Recovery still requires explicit wording discipline wherever physical restore is not yet guaranteed

## Outcome Snapshot

### Landed in this pass

- Added one new real Smart Clean execute target class for `~/Library/pnpm/store/*`.
- Added stronger worker-side truthfulness so Atlas only records recovery/history side effects when a real file move happened.
- Hardened recovery restore semantics so batched restore requests preflight all selected items before mutating Atlas state.
- Mapped helper-backed restore destination conflicts back to the restore-specific rejection path instead of the generic execution-unavailable path.
- Split History recovery messaging between:
  - file-backed restore entries with `restoreMappings`
  - Atlas-only recovery entries with no supported on-disk restore path
- Rebuilt the latest native artifacts and verified packaged install plus fresh-state launch.

### Current blocker

- Local UI automation is no longer a hard blocker on this Mac.
- `./scripts/atlas/full-acceptance.sh` passed on **2026-03-13** for the latest recovery-fix candidate build.

The remaining gap is narrower:

- a dedicated clean-machine bilingual manual walkthrough is still outstanding
- current packaged-build evidence is still machine-local, not evidence from a second physical clean Mac

## Packaged-Build Evidence

### Latest artifacts built on 2026-03-13

- App: `dist/native/Atlas for Mac.app`
- DMG: `dist/native/Atlas-for-Mac.dmg`
- PKG: `dist/native/Atlas-for-Mac.pkg`
- ZIP: `dist/native/Atlas-for-Mac.zip`
- Checksums: `dist/native/Atlas-for-Mac.sha256`

### Checksum record

```text
2d5988ac5f03d06b5f8ec2c94869752ad5c67de0f7eeb7b59aeb9e463f6cdee9  Atlas-for-Mac.zip
2b5d1a1b6636edcf180b5639bcf62734d25e05adcb405419f7a234ade3870c1e  Atlas-for-Mac.dmg
e89f50a77d9148d18ca78d8a0fd005394fc5848e6ae6a5231700e1b180135495  Atlas-for-Mac.pkg
```

### Verified commands

- `./scripts/atlas/full-acceptance.sh` — **pass** on 2026-03-13
- `./scripts/atlas/package-native.sh` — **pass** on 2026-03-13
- `./scripts/atlas/verify-bundle-contents.sh` — **pass** on 2026-03-13
- `KEEP_INSTALLED_APP=1 ./scripts/atlas/verify-dmg-install.sh` — **pass** on 2026-03-13
- `./scripts/atlas/verify-app-launch.sh` — **pass** on 2026-03-13
- `./scripts/atlas/run-ui-automation.sh` — **pass** on 2026-03-13 for the latest recovery-fix candidate build

### Fresh-state file evidence

- State directory: `.build/atlas-hardening-fresh-state-2026-03-12`
- New state file: `.build/atlas-hardening-fresh-state-2026-03-12/workspace-state.json`
- First-launch persisted language in that brand-new state file: `zh-Hans`

This is a machine-local fresh-state packaged-build verification, not a claim of having used a second physical clean Mac.

## Must-Deliver Status

### 1. Clean-machine bilingual QA

**Status:** `Partially complete / manual clean-machine pass still pending`

Completed evidence:

- Packaged install path verified to `~/Applications/Atlas for Mac.app`
- Fresh-state packaged launch verified with a brand-new workspace-state directory
- Default first-launch language persisted as `zh-Hans`
- Language-switch persistence covered by app-model test evidence and local UI automation
- Smart Clean, Apps, and Recovery trust paths covered by package and app tests listed below

Remaining blocker:

- A dedicated clean-machine bilingual manual walkthrough is still not recorded for this candidate build

### 2. Fresh-state verification with latest packaged build

**Status:** `Complete`

- Latest packaged build created in `dist/native`
- DMG install verification passed
- Fresh-state launch verification passed against `.build/atlas-hardening-fresh-state-2026-03-12`

### 3. One concrete increment in real Smart Clean execute coverage

**Status:** `Complete`

New safe direct-trash target class added:

- `~/Library/pnpm/store/*`

Code path:

- Allowlist: `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift`
- Parser/title recognition: `Packages/AtlasCoreAdapters/Sources/AtlasCoreAdapters/MoleSmartCleanAdapter.swift`

### 4. Stronger `scan -> execute -> rescan` contract evidence

**Status:** `Complete`

New and existing contract evidence now covers:

- existing cache-backed real path
- new pnpm-store real path
- stale-target handling where Atlas must not claim a physical move

### 5. History/completion surfaces only claim real side effects

**Status:** `Complete`

Behavior tightened so that:

- no recovery entry is created when the selected Smart Clean target is already absent on disk
- restore summaries distinguish file-backed restore from Atlas-only state restoration
- History callouts and restore button hints distinguish on-disk restore from Atlas-only restore

## Test Evidence

### Adapter + infrastructure

- `swift test --package-path Packages --filter MoleSmartCleanAdapterTests` — **pass** on 2026-03-12
- `swift test --package-path Packages --filter AtlasInfrastructureTests` — **pass** on 2026-03-12
- `swift test --package-path Packages` — **pass** on 2026-03-13 after the recovery restore atomicity and helper-conflict fix

Key tests:

- `testParseDetailedFindingsBuildsExecutableTargets`
- `testPnpmStoreTargetIsSupportedExecutionTarget`
- `testScanExecuteRescanRemovesExecutedPnpmStoreTargetFromRealResults`
- `testExecutePlanDoesNotCreateRecoveryEntryWhenTargetIsAlreadyGone`
- `testRestoreItemsStateOnlySummaryDoesNotClaimOnDiskRestore`
- `testRestoreRecoveryItemPhysicallyRestoresRealTargets`

### App-model coverage

- `swift test --package-path Apps --filter AtlasAppModelTests` — **pass** on 2026-03-12
- `swift test --package-path Apps` — **pass** on 2026-03-13 after the recovery restore atomicity and helper-conflict fix

Key tests:

- `testSetLanguagePersistsThroughWorkerAndUpdatesLocalization`
- `testPreferredXPCWorkerPathFailsClosedWhenScanIsRejected`
- `testExecuteCurrentPlanExposesExplicitExecutionIssueWhenWorkerRejectsExecution`
- `testExecuteCurrentPlanOnlyRecordsRecoveryForRealSideEffects`
- `testRestoreExpiredRecoveryItemReloadsPersistedState`
- `testRestoreRecoveryItemReturnsFindingToWorkspace`

## QA Matrix

| Area | Evidence | Status |
| --- | --- | --- |
| First launch | packaged app launch smoke with new state dir | Pass |
| Install path | DMG install validation to `~/Applications` | Pass |
| Default language | fresh packaged state file persisted `zh-Hans` | Pass |
| Language switching | app-model persistence test plus local UI automation pass on 2026-03-13; clean-machine manual pass still pending | Partial |
| Smart Clean execute | package tests + real file-backed contract tests | Pass |
| Apps | app-model and infrastructure uninstall/recovery tests | Pass |
| History / Recovery | file-backed vs Atlas-only summary/copy split + restore tests | Pass |

## Copy Guardrails After This Pass

Do keep saying:

- `Smart Clean only claims real cleanup for supported targets it actually moved.`
- `History distinguishes on-disk restore from Atlas-only restoration.`
- `Recovery can only claim physical return when a supported restore mapping exists.`

Do not say:

- `Every recoverable item returns to disk.`
- `Smart Clean moved an item` when the file was already absent.
- `Restore succeeded on disk` for Atlas-only recovery records.

## Files Changed for Hardening

- `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`
- `Packages/AtlasApplication/Sources/AtlasApplication/AtlasApplication.swift`
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift`
- `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift`
- `Packages/AtlasCoreAdapters/Sources/AtlasCoreAdapters/MoleSmartCleanAdapter.swift`
- `Packages/AtlasCoreAdapters/Tests/AtlasCoreAdaptersTests/MoleSmartCleanAdapterTests.swift`
- `Packages/AtlasFeaturesHistory/Sources/AtlasFeaturesHistory/HistoryFeatureView.swift`
- `Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings`
- `Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings`
- `Apps/AtlasApp/Tests/AtlasAppTests/AtlasAppModelTests.swift`
- `scripts/atlas/smart-clean-manual-fixtures.sh`
- `Docs/Execution/Smart-Clean-Execution-Coverage-2026-03-09.md`
- `Docs/Execution/Smart-Clean-Manual-Verification-2026-03-09.md`
