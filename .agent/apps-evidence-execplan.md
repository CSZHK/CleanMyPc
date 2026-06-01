# Apps Evidence Execution — Execution Plan

## Summary
7-phase overhaul of the Apps uninstall evidence pipeline. 5 ATL tasks spanning 7 packages + app layer. Foundation is Phase 1 (Domain types) → Phase 2 (Analyzer + Protocol) → Phase 3 (Worker integrity) → Phases 4–6 (views + restore) → Phase 7 (tests).

## Iteration Reference
`iterations/REQ-apps-evidence-execution/`

## Dependency Graph
```
Phase 1 (Domain)
  ├── Phase 2 (Analyzer + Protocol)
  │     └── Phase 3 (Worker Integrity)
  │           ├── Phase 5 (View Consistency)
  │           └── Phase 6 (Restore Refresh)
  ├── Phase 4 (Inventory Adapter) ── can parallel Phase 2/3
  └── Phase 7 (Tests) ── gated on ALL above
```

## Protocol Changes (Critical — resolves reviewer gap)

### AtlasProtocol.swift changes
- `AtlasCommand.executeAppUninstall(appID:)` → `executeAppUninstall(appID:planID:)` — carry planID to look up stored snapshot
- `AtlasResponse` add optional `.appEvidenceSnapshot(AtlasAppUninstallEvidenceSnapshot)` if snapshot needs to flow back independently (otherwise embedded in `.preview`)
- Protocol version bump: `"0.3"` → `"0.3.1"` (additive, backward compatible)
- **Backward compat**: Old clients sending `executeAppUninstall(appID:)` without planID → worker re-runs analyzer (legacy path), no crash

### Worker transient storage
- `AtlasScaffoldWorkerService` (actor) adds:
  ```swift
  private var pendingAppUninstallSnapshots: [UUID: AtlasAppUninstallEvidenceSnapshot] = [:]
  ```
- Keyed by `ActionPlan.id` (the `planID`)
- Non-persisted: if XPC worker process restarts between preview and execute, snapshot is lost → fallback to re-running analyzer (same as current behavior)
- No schema impact on `AtlasWorkspaceState`

### Error handling for fingerprint mismatch
- Worker computes fresh fingerprint at execute time
- If mismatch → log divergence, create `RecoveryItem` with `divergenceWarning: [String]` listing changed paths
- **Never blocks execution** — mismatch is a warning, not a failure
- Divergence surfaces in UI via `AtlasAppPostRestoreRefreshStatus.divergenceWarning`

## Schema Migration Strategy

### AtlasAppRecoveryPayload v1 → v2
- v2 adds `uninstallSnapshot: AtlasAppUninstallEvidenceSnapshot?` (optional)
- v1 payloads decode via `decodeIfPresent` → `nil` snapshot → views show "Legacy evidence" badge
- **No `AtlasWorkspaceStateSchemaVersion` bump needed** — all new fields are optional with `decodeIfPresent` defaults
- `AppFootprint.evidenceSummary` is `[AtlasAppEvidenceCategory: Int]?` — optional, nil for old data
- `ActionPlan.evidencePlanID` is `UUID?` — nil for SmartClean plans
- `ActionPlan.estimatedReviewOnlyBytes` is `Int64?` — nil for SmartClean plans

## Phase Details

### Phase 1: Domain Types (ATL-252 partial)
**Objective**: Define all new types in AtlasDomain with full backward compatibility.

| New Type | Purpose |
|----------|---------|
| `AtlasAppEvidenceCategory` (10 cases) | Replaces 5-case `AtlasFootprintEvidenceCategory` |
| `AtlasEvidenceSafetyLevel` (3 cases) | safe / conditional / protected per category |
| `AtlasAppEvidenceItem` | path + bytes + fileType + verified flag |
| `AtlasAppEvidenceGroup` | category + safetyLevel + items |
| `AtlasAppUninstallEvidenceSnapshot` | Full snapshot: bundle + groups + fingerprintHash + planID + capturedAt |

**Modified types** (all additive, no breaking):
- `AppFootprint`: add `evidenceSummary: [AtlasAppEvidenceCategory: Int]?`
- `ActionPlan`: add `evidencePlanID: UUID?`, `estimatedReviewOnlyBytes: Int64?`
- `AtlasAppRecoveryPayload`: add `uninstallSnapshot: AtlasAppUninstallEvidenceSnapshot?`
- `AtlasAppPostRestoreRefreshStatus`: add `evidenceDivergenceDetected: Bool`, `divergentCategories: [AtlasAppEvidenceCategory]`

**Old types**: `AtlasFootprintEvidenceCategory` and `AtlasAppUninstallEvidence` kept as deprecated aliases for migration period.

**L10n keys** (both zh-Hans + en):
- 10 category names: `evidence.category.appBundle`, `.supportFiles`, `.caches`, `.preferences`, `.logs`, `.launchItems`, `.savedState`, `.containers`, `.groupContainers`, `.miscLeftovers`
- 3 safety levels: `evidence.safety.safe`, `.conditional`, `.protected`
- Divergence: `evidence.divergence.title`, `.divergence.detail`
- Legacy badge: `evidence.legacy.badge`

**Files**: `AtlasDomain.swift`, `Resources/{zh-Hans,en}.lproj/Localizable.strings`
**Checkpoint**: `swift build --package-path Packages`

### Phase 2: Analyzer + Protocol (ATL-251 + ATL-252)
**Objective**: Expand analyzer to 10 categories; wire protocol changes.

**Analyzer** (`AtlasAppUninstallEvidence.swift`):
- Add candidate URLs for 5 new categories:
  - `savedState`: `~/Library/Saved Application State/{bundleIdentifier}.savedState`
  - `containers`: `~/Library/Containers/{bundleIdentifier}`
  - `groupContainers`: `~/Library/Group Containers/*` (cross-ref check: only groups containing `bundleIdentifier` in any member app)
  - `miscLeftovers`: `~/Library/Cookies/{bundleIdentifier}.binarycookies`, `~/Library/WebKit/{bundleIdentifier}`, `~/Library/HTTPStorages/{bundleIdentifier}`, `~/Library/Profiles/{bundleIdentifier}`, `~/Library/ColorSync/{appName}`, `~/Library/Input Methods/{appName}.app`
  - **Group Containers cross-ref**: Only include if the group container's plist references this bundleIdentifier
  - **Concurrent access**: `analyze()` is already synchronous read-only (FileManager.fileExists) — no file mutation, safe under actor isolation

- Compute `fingerprintHash`: SHA256 of sorted paths → first 16 hex chars
- Return `AtlasAppUninstallSnapshot` with safetyLevel per group

**Protocol** (`AtlasProtocol.swift`):
- `executeAppUninstall(appID:planID:)` — planID is Optional, nil = legacy path
- Protocol version: "0.3.1"

**Fixture definitions** (AtlasScaffoldFixtures):
- 3 mainstream: Chrome, Slack, Spotify (with expected categories)
- 3 developer: Xcode CLI tools, Docker Desktop, Homebrew-installed app
- 3 edge: MAS sandboxed, symlinked bundle, dot-separated bundleID

**Files**: `AtlasAppUninstallEvidence.swift`, `AtlasProtocol.swift`, `AtlasDomain.swift`
**Checkpoint**: `swift build --package-path Packages`

### Phase 3: Worker Integrity (ATL-252 core)
**Objective**: Capture evidence once at preview; verify at execute.

**Worker changes** (`AtlasScaffoldWorkerService.swift`):
```swift
// New transient storage (actor-isolated, non-persisted)
private var pendingAppUninstallSnapshots: [UUID: AtlasAppUninstallEvidenceSnapshot] = [:]
```

**previewAppUninstall** (line ~461):
1. Run analyzer → create snapshot with planID = plan.id
2. Store: `pendingAppUninstallSnapshots[plan.id] = snapshot`
3. Set `ActionPlan.evidencePlanID = plan.id`, `.estimatedReviewOnlyBytes = snapshot.reviewOnlyBytes`
4. Return plan with snapshot

**executeAppUninstall** (line ~482):
1. Look up `pendingAppUninstallSnapshots[planID]`
2. If found → verify fingerprint; if mismatch → attach `divergenceWarning` to RecoveryItem
3. If NOT found (worker restarted) → re-run analyzer as fallback (current behavior)
4. Create RecoveryItem with v2 payload: `.uninstallSnapshot = snapshot`
5. Remove from pending map
6. **No re-run analyzer** in happy path

**Files**: `AtlasScaffoldWorkerService.swift`
**Checkpoint**: Schema migration test passes + `swift build --package-path Packages && swift build --package-path Apps`

### Phase 4: Inventory Adapter Parity (ATL-252 partial)
**Objective**: `leftoverItems` count matches evidence analyzer categories.

**MacAppsInventoryAdapter**:
- Replace 7 hardcoded path checks with lightweight category scan using same `AtlasAppEvidenceCategory` paths
- Path-existence only (no size computation) → populate `AppFootprint.evidenceSummary`
- `leftoverItems` becomes computed: `evidenceSummary?.values.reduce(0, +)`
- **Performance**: Same number of `FileManager.fileExists` calls, just organized by category

**Files**: `MacAppsInventoryAdapter.swift`
**Checkpoint**: Existing adapter tests pass

### Phase 5: View Consistency (ATL-252)
**Objective**: Shared rendering component for preview / completion / history.

**AtlasDesignSystem new component** (`AtlasEvidenceGroupCard.swift`):
- Accepts: `AtlasAppEvidenceGroup` + `displayMode` (.preview / .completion / .history)
- Preview: shows category + item count + total bytes + safety badge
- Completion: shows verified status per group + divergence warnings
- History: frozen snapshot with timestamp

**AppsFeatureView**:
- Preview section: render ActionPlan items using `AtlasEvidenceGroupCard(mode: .preview)`
- Completion: render RecoveryItem snapshot using `AtlasEvidenceGroupCard(mode: .completion)`
- Add `estimatedReviewOnlyBytes` display

**HistoryFeatureView**:
- Recovery detail: render v2 snapshot with `AtlasEvidenceGroupCard(mode: .history)`
- v1 payloads: show "Legacy evidence" badge + empty groups

**Files**: New `AtlasEvidenceGroupCard.swift`, `AppsFeatureView.swift`, `HistoryFeatureView.swift`
**Checkpoint**: Visual QA + `swift build`

### Phase 6: Restore Refresh (ATL-253)
**Objective**: Actionable divergence detection + UI after restore.

**AtlasAppModel**:
- `restoreRecoveryItem` → after restore, run `evidenceAnalyzer.analyze` on restored app
- Compare group counts with stored snapshot → compute divergence
- New status fields: `evidenceDivergenceDetected`, `divergentCategories`, `recommendedAction`
- Conflict: if `FileManager.fileExists(bundlePath)` before restore → `.restoreConflict`

**AppsFeatureView**:
- Divergence warning card: shows which categories diverged
- "Re-scan leftovers" button → triggers fresh preview flow
- Stale state: app not found after restore → show stale message

**Files**: `AtlasAppModel.swift`, `AppsFeatureView.swift`
**Checkpoint**: Restore test passes

### Phase 7: Acceptance Tests (ATL-251, ATL-254, ATL-255)
- `AtlasAppsEvidenceFixtureTests.swift`: per-fixture analyzer coverage
- `AtlasAppUninstallSnapshotTests.swift`: fingerprint stability + divergence simulation
- `AtlasAppsEvidenceLifecycleTests.swift`: full preview→execute→restore cycle
- `AtlasAppsSchemaMigrationTests.swift`: v1→v2 round-trip
- `MacAppsInventoryAdapterTests.swift`: evidenceSummary parity
- CI gate: all pass + zero regression

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Group Containers belong to multiple apps | Data loss | Cross-ref check: only include if plist references this bundleIdentifier |
| XPC worker restart loses pending snapshot | Fallback to current behavior | Re-run analyzer as fallback, same as today |
| Fingerprint false positives | Confusing warning | Only flag disappeared/changed items, not new items |
| Schema migration breaks existing users | App crash | All new fields optional, `decodeIfPresent`, round-trip test |
| Protocol version incompatibility | Old clients fail | Additive only, planID is optional |
| Analyzer performance on 500+ apps | Slow listing | Lightweight scan at listing (path-existence only), full scan at preview |
| Concurrent file changes during preview→execute | Divergence | Fingerprint verification + divergence warning (never block) |

## Checkpoint Protocol
After each phase:
1. `swift build --package-path Packages`
2. `swift build --package-path Apps`
3. Run affected test suite
4. Report to user → confirm → continue
