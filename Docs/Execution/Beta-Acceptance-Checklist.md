# Beta Acceptance Checklist

## Goal

Provide a release-facing checklist for deciding whether Atlas for Mac is ready to enter or exit the beta phase.

## Scope

This checklist applies to the frozen MVP modules:

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Recovery`
- `Permissions`
- `Settings`

## Entry Criteria

Before starting beta acceptance, confirm all of the following:

- [ ] `swift test --package-path Packages` passes
- [ ] `swift test --package-path Apps` passes
- [ ] `./scripts/atlas/full-acceptance.sh` passes
- [ ] `dist/native/Atlas for Mac.app` is freshly built
- [ ] `dist/native/Atlas-for-Mac.dmg` is freshly built
- [ ] `dist/native/Atlas-for-Mac.pkg` is freshly built
- [ ] `Docs/Execution/MVP-Acceptance-Matrix.md` is up to date
- [ ] Known blockers are documented in `Docs/RISKS.md`

## Build & Artifact Checks

- [ ] App bundle opens from `dist/native/Atlas for Mac.app`
- [ ] DMG mounts successfully
- [ ] DMG contains `Atlas for Mac.app`
- [ ] DMG contains `Applications` shortcut
- [ ] PKG expands with `pkgutil --expand`
- [ ] SHA256 file exists and matches current artifacts
- [ ] Embedded helper exists at `Contents/Helpers/AtlasPrivilegedHelper`
- [ ] Embedded XPC service exists at `Contents/XPCServices/AtlasWorkerXPC.xpc`
- [ ] `./scripts/atlas/verify-bundle-contents.sh` passes

## Functional Beta Checks

### Overview
- [ ] App launches to a visible primary window
- [ ] Sidebar navigation shows all frozen MVP routes
- [ ] Overview displays health summary cards
- [ ] Overview displays reclaimable space summary
- [ ] Overview displays recent activity without crash

### Smart Clean
- [ ] User can open `Smart Clean`
- [ ] User can run scan
- [ ] User can refresh preview
- [ ] User can execute preview
- [ ] Execution updates `History`
- [ ] Execution creates `Recovery` entries for recoverable items
- [ ] Supported cleanup classes are explicit
- [ ] Unsupported or review-only cleanup paths fail closed visibly
- [ ] `scan -> execute -> rescan` proof exists for the validating supported fixture
- [ ] The validating supported fixture is an app-container cache or temp target under `~/Library/Containers/...`
- [ ] The validating unsupported fixture is a launch-agent, service-adjacent, or otherwise review-only target

### Apps
- [ ] User can open `Apps`
- [ ] User can refresh app footprints
- [ ] User can preview uninstall
- [ ] User can execute uninstall
- [ ] Uninstall updates `History`
- [ ] Uninstall creates `Recovery` entry
- [ ] Uninstall preview explains supported footprint categories, not only totals
- [ ] Review-only evidence displays concrete observed paths for at least one validating fixture
- [ ] Completion state explains what Atlas actually removed and what was recorded for recovery/history
- [ ] History / Recovery detail distinguishes the recoverable bundle from review-only leftover evidence
- [ ] Fixture coverage includes one mainstream GUI app, one developer-heavy app, one launch-item/service-adjacent app, and one sparse-leftover app

### History / Recovery
- [ ] History shows recent task runs
- [ ] Recovery shows recoverable items after destructive flows
- [ ] User can restore a recovery item
- [ ] Restored item disappears from recovery list

### Permissions
- [ ] Permissions screen opens without crash
- [ ] User can refresh permission status
- [ ] Permission cards render all expected states

### Settings
- [ ] Settings screen opens without crash
- [ ] User can change recovery retention
- [ ] User can toggle notifications
- [ ] Settings persist after relaunch
- [ ] Acknowledgement copy is visible
- [ ] Third-party notices copy is visible

## Install Checks

### DMG Path
- [ ] DMG install validation passes with `KEEP_INSTALLED_APP=1 ./scripts/atlas/verify-dmg-install.sh`
- [ ] Installed app exists at `~/Applications/Atlas for Mac.app`
- [ ] Installed app launches successfully

### PKG Path
- [ ] PKG builds successfully
- [ ] PKG expands successfully
- [ ] PKG signing status is known (`Developer ID signed`, `ad hoc signed`, or `unsigned`)

## Native UI Automation Checks

- [ ] `./scripts/atlas/ui-automation-preflight.sh` passes on the validating machine
- [ ] `./scripts/atlas/run-ui-automation.sh` passes
- [ ] UI smoke confirms sidebar routes and primary Smart Clean / Settings controls

## Beta Exit Criteria

Mark beta candidate as ready only if all are true:

- [ ] No P0 functional blocker remains open
- [ ] No P0 crash-on-launch or crash-on-primary-workflow remains open
- [ ] All frozen MVP workflows complete end to end
- [ ] Install path has been validated on the current candidate build
- [ ] Known unsupported areas are explicitly documented
- [ ] Release-signing status is explicit
- [ ] `Smart Clean` and `Apps` do not overclaim parity with broader cleaner tools

## Sign-off

| Role | Name | Status | Notes |
|------|------|--------|-------|
| `QA Agent` |  | Pending |  |
| `Mac App Agent` |  | Pending |  |
| `System Agent` |  | Pending |  |
| `Release Agent` |  | Pending |  |
| `Product Agent` |  | Pending |  |
