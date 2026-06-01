# PER: Review Follow-up — 4 CRITICAL Fixes

**Status:** COMPLETED
**Created:** 2026-06-01
**Scope:** AtlasAppUninstallEvidence.swift, MacAppsInventoryAdapter.swift, AtlasAppModel.swift, AtlasDomain.swift, AtlasScaffoldWorkerService.swift, test files
**Dimension:** P0+P1 — test gaps + correctness bugs

## Progress
- [x] Phase 1: 范围确认
- [x] Phase 2: 证据链核实
- [x] Phase 3: 实施修复
- [x] Phase 4: 回归验证
- [x] Phase 5: 收口总结

## Backlog
| # | Severity | Category | File:Line | Description | Status |
|---|----------|----------|-----------|-------------|--------|
| 1 | P1 | Test Gap | AtlasAppUninstallEvidenceSnapshotTests.swift | `analyzeSnapshot()` — 4 new integration tests | FIXED |
| 2 | P1 | Test Gap | MacAppsInventoryAdapterTests.swift | `computeEvidenceSummary()` — 2 new tests via public API | FIXED |
| 3 | P0 | Bug | AtlasAppModel.swift:516 | Legacy category mapping drops 4 categories → `recordedLeftoverItems` undercounts | FIXED |
| 4 | P0 | Bug | AtlasDomain.swift + AtlasScaffoldWorkerService.swift | Fingerprint divergence now persisted to recovery payload | FIXED |

## Decision Log
- #3 fix: Changed `recordedLeftoverItems` to prefer `uninstallSnapshot?.reviewOnlyItemCount` over legacy `uninstallEvidence.reviewOnlyItemCount`. Snapshot has all 10 categories; legacy drops 4 (savedState, containers, groupContainers, miscLeftovers).
- #4 fix: Added `evidenceDivergenceAtExecution: Bool` to `AtlasAppRecoveryPayload` (backward compatible — defaults false, only encoded when true). Worker sets it when fingerprint mismatch detected.
- #2 fix: Tested `computeEvidenceSummary` through public `collectInstalledApps()` API instead of changing visibility. Creates full sandbox app + 6 leftover category dirs.
- Test fix: `Library/Preferences/` parent dir must be created before writing plist file in sandbox.

## Surprises & Discoveries
- `appBundle` group in `analyzeSnapshot` only appears when bundle path exists on disk — not a phantom entry. Test assertions adjusted accordingly.
