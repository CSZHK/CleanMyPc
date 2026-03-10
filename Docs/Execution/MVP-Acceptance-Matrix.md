# MVP Acceptance Matrix

## Goal

Track the frozen Atlas for Mac MVP against user-visible acceptance criteria, automated coverage, and manual verification needs.

## Scope

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Recovery`
- `Permissions`
- `Settings`

## Matrix

| Module | Acceptance Criterion | Automated Coverage | Manual Verification | Status |
|--------|----------------------|--------------------|---------------------|--------|
| `Overview` | Shows health snapshot, reclaimable space, permissions summary, and recent activity | `swift test --package-path Packages`, `AtlasApplicationTests`, native build | Launch app and confirm overview renders without crash | covered |
| `Smart Clean` | User can scan, preview, and execute a recovery-first cleanup plan | `AtlasApplicationTests`, `AtlasInfrastructureTests`, `AtlasAppTests` | Launch app, run scan, review lanes, execute preview | covered |
| `Apps` | User can refresh apps, preview uninstall, and execute uninstall through worker flow | `AtlasApplicationTests`, `AtlasInfrastructureTests`, `AtlasAppTests`, `MacAppsInventoryAdapterTests` | Launch app, preview uninstall, execute uninstall, confirm history updates | covered |
| `History` | User can inspect runs and restore recovery items | `AtlasInfrastructureTests`, `AtlasAppTests` | Launch app, restore an item, verify it disappears from recovery list | covered |
| `Recovery` | Destructive flows create structured recovery items with expiry | `AtlasInfrastructureTests` | Inspect history/recovery entries after execute or uninstall | covered |
| `Permissions` | User can refresh best-effort macOS permission states | package tests + app build | Launch app, refresh permissions, inspect cards | partial-manual |
| `Settings` | User can update recovery retention and notifications and persist them | `AtlasApplicationTests`, `AtlasAppTests` | Relaunch app and verify settings remain persisted | covered |
| Packaging | App produces `.zip`, `.dmg`, `.pkg` | `scripts/atlas/package-native.sh` | Inspect output artifacts | covered |
| Installation | User can install from DMG into Applications | `scripts/atlas/verify-dmg-install.sh` | Open DMG and drag app to Applications | covered |
| Signed Distribution | Installer is signed and notarized | `scripts/atlas/signing-preflight.sh` + packaging with credentials | Verify Gatekeeper-friendly install on a clean machine | blocked-by-credentials |
| UI smoke | Sidebar and primary controls are automatable through native UI tests | `scripts/atlas/run-ui-automation.sh` | Run on a trusted local machine or CI agent with automation enabled | covered |

## Required Manual Scenarios

### Scenario 1: Smart Clean end-to-end
1. Launch the app.
2. Open `Smart Clean`.
3. Run scan.
4. Refresh preview.
5. Execute preview.
6. Confirm `History` and `Recovery` update.

### Scenario 2: App uninstall end-to-end
1. Open `Apps`.
2. Refresh app footprints.
3. Preview uninstall for one app.
4. Execute uninstall.
5. Confirm the item appears in `History` / `Recovery`.

### Scenario 3: DMG install verification
1. Build distribution artifacts.
2. Open `Atlas-for-Mac.dmg`.
3. Copy `Atlas for Mac.app` to `Applications`.
4. Launch the installed app.

## Current Blocking Item

- Signed/notarized public distribution remains blocked by missing Apple Developer release credentials.
