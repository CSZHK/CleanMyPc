# AtlasCoreAdapters

## Responsibility

- Wrap reusable upstream and local system capabilities behind structured interfaces

## Current Adapters

- `MoleHealthAdapter` wraps `lib/check/health_json.sh` and returns structured overview health data.
- `MoleSmartCleanAdapter` wraps `bin/clean.sh --dry-run` behind a temporary state directory and parses reclaimable findings for Smart Clean.
- `MacAppsInventoryAdapter` scans local application bundles, estimates footprint size, and derives leftover counts for the `Apps` MVP workflow.
