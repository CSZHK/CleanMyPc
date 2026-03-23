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
| `Smart Clean` competitive readiness | Supported high-confidence safe cleanup classes are explicit, disk-backed where claimed, and unsupported paths fail closed visibly | focused `AtlasInfrastructureTests`, `AtlasAppTests`, `scan -> execute -> rescan` tests | Validate one supported and one unsupported scenario against current comparison targets | partial |
| `Apps` | User can refresh apps, preview uninstall, and execute uninstall through worker flow | `AtlasApplicationTests`, `AtlasInfrastructureTests`, `AtlasAppTests`, `MacAppsInventoryAdapterTests` | Launch app, preview uninstall, execute uninstall, confirm history updates | covered |
| `Apps` competitive readiness | Uninstall preview explains supported footprint categories, concrete leftover evidence paths, and recoverability/audit implications clearly enough to stand against open-source uninstall specialists | `AtlasApplicationTests`, `AtlasInfrastructureTests`, `AtlasAppTests` plus fixture validation | Preview uninstall for fixture apps, confirm category clarity, observed paths, and completion/history evidence | partial |
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

### Scenario 2b: App uninstall trust verification
1. Open `Apps`.
2. Preview uninstall for a fixture app.
3. Confirm the preview distinguishes supported footprint categories rather than only showing a generic leftover count.
4. Confirm at least one review-only evidence group shows concrete observed paths.
5. Execute uninstall.
6. Confirm completion and history/recovery surfaces describe what Atlas actually removed and recorded.
7. Confirm recovery detail distinguishes the recoverable bundle from review-only leftover evidence.

### Scenario 3: DMG install verification
1. Build distribution artifacts.
2. Open `Atlas-for-Mac.dmg`.
3. Copy `Atlas for Mac.app` to `Applications`.
4. Launch the installed app.

### Scenario 4: Smart Clean supported vs unsupported verification
1. Run a `Smart Clean` scan with one supported high-confidence target class.
2. Execute and rescan.
3. Confirm on-disk effect is visible and history reflects a real side effect.
4. Run a scenario with an unsupported or unstructured finding.
5. Confirm Atlas blocks or rejects execution clearly instead of implying success.

## Selective Parity Validating Fixtures

- `Smart Clean` supported fixture: app-container cache or temp data under `~/Library/Containers/<bundle-id>/Data/Library/Caches` or `~/Library/Containers/<bundle-id>/Data/tmp`, validated with `scan -> execute -> rescan`.
- `Smart Clean` fail-closed fixture: launch-agent, service-adjacent, or otherwise unsupported target such as `~/Library/LaunchAgents/<bundle-id>.plist`, validated as review-only or rejected.
- `Apps` mainstream GUI fixture: one large GUI app with visible support files and caches, such as `Final Cut Pro`.
- `Apps` developer-heavy fixture: one developer-oriented app with larger support/caches footprint, such as `Xcode`.
- `Apps` launch-item or service-adjacent fixture: one app with launch-agent evidence, such as `Docker`.
- `Apps` sparse-leftover fixture: one app that produces only a small preference or saved-state trail, validated so Atlas does not overstate removal scope.

## Current Blocking Item

- Signed/notarized public distribution remains blocked by missing Apple Developer release credentials.
