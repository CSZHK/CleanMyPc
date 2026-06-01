# ATL-254: Acceptance Tests

## Status
DONE

## Scope
- Domain model tests: `AtlasEvidenceModelTests` (8 tests)
- Snapshot/analyzer tests: `AtlasAppUninstallEvidenceSnapshotTests` (10 tests)
- Schema migration: v1→v2 round-trip (included in domain tests)
- Fingerprint stability + divergence simulation

## Acceptance Criteria
- [x] AC1: Domain model tests cover all new types + Codable round-trip
- [x] AC2: Fingerprint identical for identical groups, different for changed paths
- [x] AC3: Schema migration v1→v2 round-trip (v1 JSON → decode → snapshot nil)
- [x] AC4: Review-only groups exclude appBundle
- [x] AC5: reviewOnlyBytes / totalBytes / reviewOnlyItemCount computed correctly

## Files
- `Packages/AtlasDomain/Tests/AtlasDomainTests/AtlasEvidenceModelTests.swift` (new)
- `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasAppUninstallEvidenceSnapshotTests.swift` (new)

## Verification
- `swift test --package-path Packages` — 368 tests, 0 failures ✅
