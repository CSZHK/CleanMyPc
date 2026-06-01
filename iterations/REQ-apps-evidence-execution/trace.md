# REQ-apps-evidence-execution — Trace

## Validation Protocol
- Phase gate: `swift build --package-path Packages && swift build --package-path Apps`
- After each phase: report progress and await confirmation before proceeding
- Phase 7 gated on all implementation phases (1–6) completing
- Schema migration round-trip test MUST pass before Phase 3 begins
- Protocol backward compat: old client (no planID) still works
- Final gate: all ATL-251 through ATL-255 acceptance criteria pass in CI

## Blast Radius
| Package | Impact | Risk |
|---------|--------|------|
| AtlasDomain | New types (6) + modified types (4, all additive) + l10n keys (~20) | Medium — schema migration |
| AtlasProtocol | `executeAppUninstall` adds optional `planID`; version 0.3→0.3.1 | Low — additive |
| AtlasInfrastructure | Worker transient storage + preview/execute refactor | High — core logic change |
| AtlasCoreAdapters | Inventory adapter lightweight evidence summary | Low — additive |
| AtlasDesignSystem | New `AtlasEvidenceGroupCard` component | Low — new file |
| AtlasFeaturesApps | View changes for preview/completion rendering | Medium — UI refactor |
| AtlasFeaturesHistory | History renders v2 snapshots + legacy badge | Medium — backward compat |
| Apps/AtlasApp | AtlasAppModel restore refresh enhancement | Medium — restore logic |
| Recovery payloads on disk | v1 → v2 forward-compatible migration | High — must not break existing users |

## Required Validation Modules
1. `swift build --package-path Packages` — compilation
2. `swift build --package-path Apps` — app compilation
3. Domain model unit tests (new types + Codable round-trip)
4. Evidence analyzer tests (10 categories × fixture apps)
5. Fingerprint stability test (stable input → same hash)
6. Fingerprint divergence test (changed input → different hash + warning)
7. Schema migration round-trip (v1 JSON → decode → re-encode → decode → match)
8. Worker integration test (preview→execute with snapshot lookup)
9. View rendering tests (preview/completion/history consistency)
10. Restore refresh divergence test
11. Regression: SmartClean flow unchanged
12. Regression: FileOrganizer flow unchanged
13. Full lifecycle acceptance script (scan → preview → execute → verify → restore → verify refresh)

## Docs Sync
- [x] `docs/design/apps-evidence-model.md` — Full design document
- [x] `.agent/apps-evidence-execplan.md` — Execution plan
- [x] `.agent/apps-evidence-findings.md` — Findings summary
- [x] `iterations/REQ-apps-evidence-execution/requirement.md` — REQ
- [x] `iterations/REQ-apps-evidence-execution/trace.md` — This file
- [ ] `docs/PRD.md` — Update after EPIC-A complete
- [ ] `docs/ROADMAP.md` — Update milestone status after EPIC-A complete
- [ ] `docs/Backlog.md` — Mark EPIC-A ATL items complete

## Planned Verification
| Phase | Verify Command | Status |
|-------|---------------|--------|
| Phase 1: Domain Types | `swift build` + schema migration test | ✅ PASS |
| Phase 2: Analyzer + Protocol | `swift build` + fixture category tests | ✅ PASS |
| Phase 3: Worker Integrity | `swift build` + fingerprint tests | ✅ PASS |
| Phase 4: Inventory Adapter | `swift build` + leftoverItems parity test | ✅ PASS |
| Phase 5: View Consistency | `swift build` + visual verification | ✅ PASS |
| Phase 6: Restore Refresh | `swift build` + divergence detection test | ✅ PASS |
| Phase 7: Acceptance Tests | Full test suite + acceptance script | ✅ PASS (368 tests, 0 failures) |

## Actual Verification

### Build Gates
- `swift build --package-path Packages` ✅
- `swift build --package-path Apps` ✅
- `swift test --package-path Packages` ✅ 368 tests, 0 failures

### Review Rounds
1. **Review 1** — Found 6 bugs (P0×4, P1×1, P2×2) → all fixed
2. **Review 2** — 0 P2+ bugs, 3 P3 observations (non-blocking)
3. **Review 3 (pre-merge)** — Found 4 P1 + 9 P2 issues via multi-source review (structured + testing specialist + maintainability specialist + adversarial). All P1 and actionable P2 fixes applied:
   - P1: Removed savedState path from supportFiles (cross-category duplication)
   - P1: Added miscLeftovers candidate URLs (WebKit, Cookies, HTTPStorages)
   - P1: Fixed groupContainers to use directory scan with suffix/component matching
   - P1: Removed dead `divergenceWarnings` parameter from `makeRecoveryItem`
   - P2: Eliminated double snapshot creation in `analyzeSnapshot`
   - P2: Added `computeFingerprint(for:)` static method + documented Hasher session scope
   - P2: Clear `pendingRestoreSnapshotCategoryCounts` on error path
   - P2: Tightened groupContainers substring match in adapter

### Schema Migration
- v1 → v2 round-trip test passes (`testRecoveryPayload_v1_migration`, `testAppRecoveryPayload_schemaMigration_v1_to_v2`)
- All new fields optional with `decodeIfPresent` defaults
- No `AtlasWorkspaceStateSchemaVersion` bump needed

### Protocol Backward Compat
- `executeAppUninstall(appID:planID:)` — planID is optional, nil = legacy path
- Protocol version "0.3.1" additive, no breaking change

## Actual Deliverables

### Code Changes (14 files modified + 3 new)
| File | Changes |
|------|---------|
| `AtlasDomain.swift` | +165 lines — 6 new types + 4 modified types |
| `AtlasAppUninstallEvidence.swift` | +144 lines — 10-category analyzer + snapshot + groupContainers scan |
| `AtlasScaffoldWorkerService.swift` | +99 lines — transient snapshot storage + preview-execute integrity |
| `AtlasProtocol.swift` | Protocol 0.3→0.3.1, `executeAppUninstall(appID:planID:)` |
| `MacAppsInventoryAdapter.swift` | +80 lines — 10-category evidence summary |
| `AppsFeatureView.swift` | +55 lines — preview/completion evidence cards + divergence callout |
| `HistoryFeatureView.swift` | +13 lines — v2 snapshot rendering + legacy badge |
| `AtlasAppModel.swift` | +72 lines — restore refresh + divergence detection |
| `AtlasEvidenceGroupCard.swift` | **New** — shared design system component (3 display modes) |
| `AtlasEvidenceModelTests.swift` | **New** — 8 domain model tests |
| `AtlasAppUninstallEvidenceSnapshotTests.swift` | **New** — 10 snapshot/analyzer tests |
| `Localizable.strings` (both) | +32 keys each — 10 categories, 3 safety levels, divergence/legacy strings |

### Governance Docs
| Doc | Path |
|-----|------|
| Requirement | `iterations/REQ-apps-evidence-execution/requirement.md` |
| Trace | `iterations/REQ-apps-evidence-execution/trace.md` |
| Design | `docs/design/apps-evidence-model.md` |
| Execution Plan | `.agent/apps-evidence-execplan.md` |
| Findings | `.agent/apps-evidence-findings.md` |

## Close Gate
All ATL-251 through ATL-255 acceptance criteria pass + 0 test regressions + schema migration verified + protocol backward compat verified = PASS
