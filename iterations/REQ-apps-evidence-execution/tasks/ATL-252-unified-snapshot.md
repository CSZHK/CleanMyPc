# ATL-252: Unified Evidence Snapshot + Preview-Execute Integrity

## Status
DONE

## Scope
- Domain types: `AtlasAppEvidenceCategory` (10 cases), `AtlasEvidenceSafetyLevel`, `AtlasAppEvidenceItem`, `AtlasAppEvidenceGroup`, `AtlasAppUninstallEvidenceSnapshot`
- Protocol: `executeAppUninstall(appID:planID:)`, version 0.3.1
- Analyzer: 10-category expansion + fingerprint computation
- Worker: transient snapshot storage + preview-execute integrity
- Views: `AtlasEvidenceGroupCard` shared component (preview/completion/history)

## Acceptance Criteria
- [x] AC1: Preview, completion, history render from same snapshot type
- [x] AC2: Fingerprint at preview matches fingerprint at execute when no files changed
- [x] AC3: Files changed between preview and execute → divergence warning logged
- [x] AC4: `estimatedBytes` + `estimatedReviewOnlyBytes` both displayed in preview
- [x] AC5: History renders v1 payloads with "Legacy evidence" badge

## Files Changed
- `AtlasDomain.swift`, `AtlasProtocol.swift`, `AtlasAppUninstallEvidence.swift`
- `AtlasScaffoldWorkerService.swift`, `AtlasEvidenceGroupCard.swift`
- `AppsFeatureView.swift`, `HistoryFeatureView.swift`

## Verification
- `swift build --package-path Packages && swift build --package-path Apps` ✅
- `swift test --package-path Packages` — 368 tests, 0 failures ✅
