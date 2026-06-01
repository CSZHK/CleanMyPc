# ATL-253: Enhanced Restore Refresh + Divergence Detection

## Status
DONE

## Scope
- `AtlasAppPostRestoreRefreshStatus` → `evidenceDivergenceDetected`, `divergentCategories`
- After restore: compare snapshot category counts vs fresh evidence summary
- UI: divergence warning card + "Re-scan leftovers" action
- `rescanLeftovers(appID:)` method on AtlasAppModel

## Acceptance Criteria
- [x] AC1: Restore triggers fresh inventory scan + evidence summary
- [x] AC2: Matching counts → .refreshed with no divergence
- [x] AC3: Divergent counts → .refreshed with divergence warning + categories listed
- [x] AC4: App not found in scan → .stale with error message
- [x] AC5: Re-scan leftovers clears divergence state

## Files Changed
- `AtlasAppModel.swift`, `AppsFeatureView.swift`, `AtlasDomain.swift`

## Verification
- `swift test --package-path Packages` — 368 tests, 0 failures ✅
