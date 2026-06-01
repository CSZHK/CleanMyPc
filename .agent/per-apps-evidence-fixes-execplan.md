# PER: Apps Evidence P0+P1 Fixes + Doc Sync

**Status:** COMPLETED
**Created:** 2026-06-01
**Scope:** 5 source files + 2 doc files
**Dimension:** P0+P1 bug fixes + documentation-代码一致性

## Progress
- [x] Phase 1: 范围确认
- [x] Phase 2: 证据链核实
- [ ] Phase 3: 实施修复
- [ ] Phase 4: 回归验证
- [ ] Phase 5: 收口总结

## Backlog
| # | Severity | Category | File:Line | Description | Status |
|---|----------|----------|-----------|-------------|--------|
| 1 | P1 | Bug | AtlasAppUninstallEvidence.swift:213 | Empty bundleIdentifier → hasSuffix("") always true → groupContainers matches ALL directories | FIXED |
| 2 | P1 | Bug | MacAppsInventoryAdapter.swift:119 | Same empty bundleIdentifier issue in adapter groupContainers scan | FIXED |
| 3 | P1 | Bug | AtlasAppUninstallEvidence.swift:93-126 | containers category double-counts bytes: containers = whole dir, supportFiles/caches/prefs/logs include sub-paths inside container | FIXED |
| 4 | P1 | Bug | AtlasScaffoldWorkerService.swift:1447 | removeAll() discards ALL pending snapshots, should only evict stale or let execution clean up | FIXED |
| 5 | P2 | Robustness | AtlasAppModel.swift:483 | planID from currentAppPreview?.id — nil when no preview, correct fallback. Not a real bug. | DEFERRED |
| 6 | DOC | Drift | requirement.md:17,19 | Wrong file paths (AtlasUninstallEvidence → AtlasAppUninstallEvidence, Infrastructure/AtlasScaffold → Infrastructure/AtlasScaffold) | FIXED |
| 7 | DOC | Drift | requirement.md:47 | Protocol version "0.3.1" — actual code uses "0.3.2" | FIXED |
| 8 | DOC | Drift | design doc:68 | fingerprintHash described as "SHA256" — actual implementation uses Hasher (non-crypto, non-portable) | FIXED |
| 9 | DOC | Drift | requirement.md:99 | References `RestoreRecommendedAction` type — does not exist in codebase | FIXED |

## Decision Log
- P0 #1/#2 downgraded to P1: bundleIdentifier has fallback in MacAppsInventoryAdapter ("unknown.{name}"), so empty string never reaches groupContainers in normal flow. Still needs defensive guard since analyzer is public struct.
- P1 #5 (wrong planID) downgraded to P2: nil planID triggers correct fallback path, not a real bug.
- Containers double-count fix approach: remove Container sub-paths from supportFiles/caches/preferences/logs since containers category covers entire dir.

## Surprises & Discoveries
- Design doc says SHA-256 but code uses Swift Hasher — non-crypto, non-cross-process-stable
- `leftoverItems` in AppFootprint changed from stored to computed via evidenceSummary — design doc was correct
