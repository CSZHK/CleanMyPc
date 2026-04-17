# Manual Test SOP

## Goal

Provide a repeatable manual test procedure for Atlas for Mac beta validation on a real macOS machine.

## Intended Tester

- Internal QA
- Product owner
- Developer performing release candidate validation

## Test Environment Preparation

### Machine Requirements
- macOS 14 or newer
- Ability to grant Accessibility permission to the terminal and Xcode when UI automation is used
- Access to `dist/native` artifacts from the current candidate build

### Clean Start Checklist
- Quit all running Atlas for Mac instances
- Remove old local install if testing a clean DMG install:
  - `~/Applications/Atlas for Mac.app`
- Clear temporary validation folders if needed:
  - `.build/atlas-native/`
  - `.build/atlas-dmg-verify/`
- Ensure the build under test is freshly produced

## Preflight Commands

Run these before starting manual validation:

```bash
swift test --package-path Packages
swift test --package-path Apps
./scripts/atlas/package-native.sh
./scripts/atlas/verify-bundle-contents.sh
KEEP_INSTALLED_APP=1 ./scripts/atlas/verify-dmg-install.sh
./scripts/atlas/verify-app-launch.sh
./scripts/atlas/ui-automation-preflight.sh || true
./scripts/atlas/run-ui-automation.sh || true
```

## Manual Test Logging Rules

For every issue found, record:

- build timestamp
- artifact used (`.app`, `.dmg`, `.pkg`)
- screen name
- exact steps
- expected result
- actual result
- screenshot or screen recording if possible
- whether it blocks the beta exit criteria

## Scenario SOP

### SOP-01 Launch and Navigation
1. Open `Atlas for Mac.app`.
2. Confirm the main window appears.
3. Confirm sidebar routes are visible:
   - `Overview`
   - `Smart Clean`
   - `Apps`
   - `History`
   - `Permissions`
   - `Settings`
4. Switch through all routes once.
5. Confirm no crash or blank screen occurs.

**Pass condition**
- All routes render and navigation remains responsive.

### SOP-02 Smart Clean Workflow
Reference: `Docs/Execution/Smart-Clean-Manual-Verification-2026-03-09.md` for disposable local fixtures and rescan/restore verification.

1. Open `Smart Clean`.
2. Click `Run Scan`.
3. Wait for summary and progress to update.
4. Click `Refresh Preview`.
5. Review `Safe`, `Review`, and `Advanced` sections.
6. Click `Execute Preview`.
7. Open `History`.
8. Confirm a new execution record exists.
9. Confirm `Recovery` shows new entries.

**Pass condition**
- Scan, preview, and execute complete without crash and leave history/recovery evidence.

### SOP-03 Apps Workflow
Reference: `Docs/Execution/Apps-Evidence-Fixture-Baseline-2026-03-24.md`

1. Open `Apps`.
2. Click `Refresh App Footprints`.
3. Choose a validating fixture app from the frozen fixture matrix.
4. Click `Preview`.
5. Confirm the preview shows the recoverable bundle action.
6. Confirm the preview groups review-only evidence by category rather than only showing a leftover total.
7. Confirm at least one review-only group shows concrete observed paths.
8. Click `Uninstall` for the selected app.
6. Open `History`.
9. Confirm an uninstall task run exists.
10. Confirm `Recovery` includes the app recovery entry.
11. Confirm recovery detail distinguishes the recoverable bundle from review-only leftover evidence.

**Pass condition**
- Preview and uninstall flow complete through worker-backed behavior.

### SOP-04 Recovery Restore Workflow
1. Open `History`.
2. In `Recovery`, choose one item.
3. Click `Restore`.
4. Confirm the item disappears from the recovery list.
5. Return to the relevant screen (`Smart Clean` or `Apps`) and confirm state reflects the restore.
6. If the restored item is an app payload, confirm `Apps` shows either:
   - a refreshed post-restore evidence state, or
   - an explicit stale-evidence state
7. Confirm Atlas does not silently reuse pre-uninstall leftover counts without one of those states.

**Pass condition**
- Recovery restore succeeds and updates visible state.

### SOP-05 Permissions Workflow
1. Open `Permissions`.
2. Click `Refresh Permission Status`.
3. Confirm cards render for:
   - `Full Disk Access`
   - `Accessibility`
   - `Notifications`
4. If you enable `Full Disk Access`, fully quit and reopen Atlas, then confirm `Refresh Permission Status` can reflect the new state.
5. Confirm the page does not hang or crash if some permissions are missing.

**Pass condition**
- Best-effort permission inspection returns a stable UI state, and Full Disk Access guidance matches the real macOS relaunch requirement.

### SOP-06 Settings Workflow
1. Open `Settings`.
2. Change recovery retention.
3. Toggle notifications.
4. Quit the app.
5. Relaunch the app.
6. Return to `Settings`.
7. Confirm both values persisted.
8. Confirm acknowledgement and third-party notices text are visible.

**Pass condition**
- Settings persist across relaunch and trust content is visible.

### SOP-07 DMG Install Path
1. Double-click `dist/native/Atlas-for-Mac.dmg`.
2. Drag `Atlas for Mac.app` into `Applications`.
3. Launch the installed app from `Applications`.
4. Confirm the main window appears.

**Pass condition**
- DMG install path behaves like a normal user install.

### SOP-08 PKG Verification Path
1. Run `pkgutil --expand dist/native/Atlas-for-Mac.pkg dist/native/pkg-expand-manual`.
2. Confirm the package expands without error.
3. Run `pkgutil --check-signature dist/native/Atlas-for-Mac.pkg`.
4. Record whether the current build is `Developer ID signed`, `ad hoc signed`, or `unsigned`.

**Pass condition**
- PKG structure is valid and signing state is explicitly recorded.

### SOP-09 Native UI Smoke
1. Run `./scripts/atlas/ui-automation-preflight.sh`.
2. If the machine is trusted for Accessibility, run `./scripts/atlas/run-ui-automation.sh`.
3. Confirm the UI smoke test suite passes.

**Pass condition**
- Native UI smoke passes on a machine with proper macOS automation permissions.

## Failure Classification

### P0
- App does not launch
- Primary workflow crashes
- Smart Clean or Apps core flow cannot complete
- Recovery restore fails consistently

### P1
- Non-blocking but severe UX issue
- Persistent visual corruption on a core screen
- Packaging/install issue with a documented workaround

### P2
- Minor UI issue
- Copy inconsistency
- Non-core polish regression

## Final Tester Output

At the end of a run, summarize:

- build under test
- artifact path used
- scenarios executed
- pass/fail for each scenario
- P0 / P1 / P2 issues found
- recommendation:
  - `Pass`
  - `Pass with Conditions`
  - `Fail`
