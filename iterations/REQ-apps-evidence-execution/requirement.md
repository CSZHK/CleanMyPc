# REQ-apps-evidence-execution

## Title
Apps Evidence Execution — Unified Evidence Model with Preview-Execute Integrity

## Change Class
MAJOR — Cross-cutting evidence model overhaul spanning Domain, Infrastructure, Protocol, CoreAdapters, FeaturesApps, FeaturesHistory, and DesignSystem packages

## Status
IMPLEMENTED — Code complete, review fixes applied, 368 tests passing

## Priority
P0 — Blocks EPIC-B and all future Apps feature work; addresses 7 critical evidence integrity gaps

## Truth Sources
- Domain models: `Packages/AtlasDomain/Sources/AtlasDomain/AtlasDomain.swift`
- Evidence analyzer: `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasAppUninstallEvidence.swift`
- Worker service: `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasScaffoldWorkerService.swift`
- Protocol: `Packages/AtlasProtocol/Sources/AtlasProtocol/AtlasProtocol.swift`
- Inventory adapter: `Packages/AtlasCoreAdapters/Sources/AtlasCoreAdapters/MacAppsInventoryAdapter.swift`
- Apps view: `Packages/AtlasFeaturesApps/Sources/AtlasFeaturesApps/AppsFeatureView.swift`
- History view: `Packages/AtlasFeaturesHistory/Sources/AtlasFeaturesHistory/HistoryFeatureView.swift`
- App model: `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`
- Localization: `Packages/AtlasDomain/Sources/AtlasDomain/Resources/{zh-Hans,en}.lproj/Localizable.strings`

## Description
Overhaul the Apps uninstall evidence pipeline to provide a single, frozen-at-capture evidence snapshot that flows identically through preview → completion → history rendering. The current implementation has 7 critical gaps:

1. **Dual capture** — `previewAppUninstall` and `executeAppUninstall` both independently call `AtlasAppUninstallEvidenceAnalyzer.analyze()`. If files change between preview and execute, the user sees one plan but a different reality is recorded. No `planID` ties preview to execution.
2. **Review-only never cleaned** — leftover items shown during preview but never physically moved. Purely informational.
3. **leftoverItems count diverges** — `MacAppsInventoryAdapter` checks 7 hardcoded paths; `AtlasAppUninstallEvidenceAnalyzer` checks 5 categories with different path sets. Counts shown in app list may not match preview groups.
4. **Ephemeral ActionPlan lost** — `ActionPlan` created in `makeAppUninstallPreview()` at preview is discarded at execution; `executeAppUninstall` rebuilds from scratch. No continuity in history.
5. **estimatedBytes incomplete** — `ActionPlan.estimatedBytes = uninstallEvidence.bundleBytes` only. Excludes all review-only bytes.
6. **Stale post-restore** — `AtlasAppPostRestoreRefreshStatus` records divergence but takes no action. No "Re-scan leftovers" action.
7. **No per-path evidence in AppFootprint** — only `leftoverItems: Int` count; no paths visible at listing time.

Solution: capture once at preview, persist snapshot keyed by `planID`, verify fingerprint at execution, render through shared component.

## Project Constraints
- Swift 6.0 strict concurrency (actor isolation for `AtlasScaffoldWorkerService`)
- macOS 14.0+
- All user-visible strings via `AtlasL10n` (zh-Hans default + en)
- Feature packages depend only on AtlasDesignSystem + AtlasDomain
- Design system tokens immutable; new components allowed
- Schema migration backward-compatible (`decodeIfPresent` for new optional fields, no forced re-encode)
- No third-party dependencies
- Protocol version bump from "0.3" → "0.3.2" (additive, no breaking change)

## Execution Rules
1. Phases in dependency order (see execution plan)
2. After each phase: `swift build --package-path Packages && swift build --package-path Apps`
3. Phase 1 is foundation — all others gated on it
4. `AtlasAppRecoveryPayload` schema migration test MUST pass before Phase 3
5. New category enum cases MUST have l10n keys in both languages
6. `ActionPlan` changes MUST NOT break SmartClean plan flow — add `estimatedReviewOnlyBytes` as optional field
7. Protocol changes MUST be additive (new optional fields / new response cases)

## Task Breakdown

### ATL-251: Fixture Baseline & Category Coverage
- Define 3 mainstream (Chrome, Slack, Spotify), 3 developer (Xcode CLI, Docker, Homebrew), 3 edge cases (sandboxed MAS app, symlinked app, weird-bundle-ID app)
- Each fixture specifies expected evidence categories (e.g., Chrome → supportFiles + caches + preferences + logs + launchItems + savedState)
- Fixtures work in unit tests (mock FS via protocol injection) and integration tests (real FS setup/teardown)
- **Files**: `AtlasDomain.swift` (AtlasScaffoldFixtures), `AtlasAppUninstallEvidence.swift` (analyzer), new `AtlasAppsEvidenceFixtureTests.swift`

### ATL-252: Unified Evidence Snapshot + Preview-Execute Integrity
**Domain layer (Phase 1)**:
- `AtlasAppEvidenceCategory` — 10-case enum replacing 5-case `AtlasFootprintEvidenceCategory`
- `AtlasEvidenceSafetyLevel` — safe / conditional / protected
- `AtlasAppEvidenceItem` — path, bytes, fileType, verified (Bool)
- `AtlasAppEvidenceGroup` — category, safetyLevel, items
- `AtlasAppUninstallEvidenceSnapshot` — bundlePath, bundleBytes, groups, fingerprintHash, planID, capturedAt
- `AtlasAppRecoveryPayload` v2: `uninstallSnapshot: AtlasAppUninstallEvidenceSnapshot` (optional, legacy decode synthesizes from old field)
- `ActionPlan`: add optional `evidencePlanID: UUID`, `estimatedReviewOnlyBytes: Int64`
- `AppFootprint`: add optional `evidenceSummary: [AtlasAppEvidenceCategory: Int]`

**Protocol layer (Phase 2)**:
- `AtlasCommand.previewAppUninstall` → response adds `.appEvidenceSnapshot` case or embed snapshot in `.preview`
- `AtlasCommand.executeAppUninstall(appID: UUID, planID: UUID?)` — carry optional planID so worker can look up snapshot
- Worker stores snapshots in transient `private var pendingAppUninstallSnapshots: [UUID: AtlasAppUninstallEvidenceSnapshot]` (non-persisted, acceptable for XPC worker process lifetime)

**Analyzer upgrade (Phase 2)**:
- Expand `AtlasAppUninstallEvidenceAnalyzer` to 10 categories: +savedState, +containers, +groupContainers, +miscLeftovers
- Compute `fingerprintHash` from sorted paths
- Return `AtlasAppUninstallEvidenceSnapshot` instead of `AtlasAppUninstallEvidence`

**Worker integrity (Phase 3)**:
- `previewAppUninstall`: run analyzer → store snapshot keyed by `planID` → return ActionPlan with `evidencePlanID`
- `executeAppUninstall(planID:)`: look up stored snapshot → verify fingerprint → proceed or warn divergence → create RecoveryItem with snapshot
- No more second analyzer call at execution time

**View consistency (Phase 5)**:
- `AtlasEvidenceGroupCard` shared component in AtlasDesignSystem with displayMode: preview / completion / history
- AppsFeatureView: preview and completion use same card
- HistoryFeatureView: renders v2 snapshots; v1 legacy shows "Legacy evidence" badge with synthesized empty groups

### ATL-253: Enhanced Restore Refresh + Divergence Detection
- `AtlasAppPostRestoreRefreshStatus` → add `evidenceDivergenceDetected: Bool`, `divergentCategories: [AtlasAppEvidenceCategory]`
- After restore, run lightweight evidence summary on restored app → compare group counts with stored snapshot
- UI: divergence warning card with "Re-scan leftovers" action triggers fresh preview
- Restore conflict: if bundle path already occupied → error with clear message
- **Files**: AtlasAppModel.swift, AppsFeatureView.swift, AtlasDomain.swift

### ATL-254: Acceptance Tests
- Full lifecycle: scan → preview → verify evidence → execute → verify bundle trashed → verify recovery item has snapshot → restore → verify refresh status
- Fixture baseline from ATL-251 exercised in tests
- Review-only items NOT moved during execution (verify on disk)
- Schema migration: load v1 JSON fixture → decode → verify synthesized snapshot → re-encode → round-trip

### ATL-255: CI Gate
- All ATL-251–254 criteria pass
- Zero regression in SmartClean / FileOrganizer / History flows
- Protocol version "0.3.1" backward-compatible with "0.3"

## Acceptance Criteria

### ATL-251
- **AC1**: Fixture defines ≥3 mainstream, ≥3 developer, ≥3 edge cases with expected category coverage per fixture
- **AC2**: Test asserts analyzer discovers expected categories per fixture
- **AC3**: Fixtures usable in both unit (mock FS) and integration tests

### ATL-252
- **AC1**: Preview, completion, history render from same `AtlasAppUninstallEvidenceSnapshot` type
- **AC2**: Fingerprint at preview matches fingerprint at execute when no files changed
- **AC3**: Files deleted between preview and execute → completion shows divergence warning with specific changed items
- **AC4**: `estimatedBytes` + `estimatedReviewOnlyBytes` both displayed in preview
- **AC5**: History renders v1 payloads with "Legacy evidence" badge

### ATL-253
- **AC1**: Restore triggers fresh inventory scan + evidence summary within the same refresh call
- **AC2**: Matching counts → .refreshed with no divergence
- **AC3**: Divergent counts → .refreshed with divergence warning + categories listed
- **AC4**: App not found in scan → .stale with error message
- **AC5**: Bundle path conflict → restoreConflict error

### ATL-254
- **AC1**: Full lifecycle test passes per fixture category
- **AC2**: Review-only items verified present on disk after execution
- **AC3**: Schema migration round-trip (v1 JSON → decode → re-encode → decode → match)

### ATL-255
- **AC1**: All ATL-251–254 ACs pass
- **AC2**: Existing SmartClean / FileOrganizer tests unchanged
- **AC3**: `swift build --package-path Packages && swift build --package-path Apps` green
