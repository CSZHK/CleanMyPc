# UI Automation Blocker

## Status

Investigated and resolved locally after granting Accessibility trust to the calling process.

## Goal

Add native macOS UI automation for `AtlasApp` using Xcode/XCTest automation targets.

## What Was Tried

### Attempt 1: Main project native UI testing
- Added stable accessibility identifiers to the app UI for sidebar and primary controls.
- Tried a generated UI-testing bundle path from the main project.
- Tried a host-linked unit-test bundle path to probe `XCUIApplication` support.

### Result
- `bundle.unit-test` is not valid for `XCUIApplication`; XCTest rejects that path.
- The main-project UI-testing setup remained noisy and unsuitable as a stable repository default.

### Attempt 2: Independent minimal repro
- Built a standalone repro under `Testing/XCUITestRepro/` with:
  - one minimal SwiftUI app target
  - one UI test target
  - one test using `XCUIApplication`
- Generated the project with `xcodegen`
- Ran:

```bash
xcodebuild test \
  -project Testing/XCUITestRepro/XCUITestRepro.xcodeproj \
  -scheme XCUITestRepro \
  -destination 'platform=macOS'
```

### Result
- The minimal repro builds, signs, launches the UI test runner, and gets farther than the main-project experiment.
- It then fails with:
  - `Timed out while enabling automation mode.`

## Conclusion

- The dominant blocker is now identified as local macOS UI automation enablement, not Atlas business logic.
- Specifically, the current shell process is not trusted for Accessibility APIs, which is consistent with macOS UI automation bootstrap failure.
- After granting Accessibility trust to the terminal process, both the standalone repro and the Atlas main-project UI smoke tests succeed locally.

## Evidence

### Local permission check

```bash
swift -e 'import ApplicationServices; print(AXIsProcessTrusted())'
```

Initial result on this machine before granting Accessibility trust:

```text
false
```

Current result after granting Accessibility trust:

```text
true
```

### Minimal repro location

- `Testing/XCUITestRepro/project.yml`
- `Testing/XCUITestRepro/App/XCUITestReproApp.swift`
- `Testing/XCUITestRepro/UITests/XCUITestReproUITests.swift`

### Preflight helper

- `scripts/atlas/ui-automation-preflight.sh`

## Outcome

- `scripts/atlas/ui-automation-preflight.sh` now passes on this machine.
- `Testing/XCUITestRepro/` UI tests pass.
- Atlas main-project UI smoke tests pass through `scripts/atlas/run-ui-automation.sh`.

## Remaining Constraint

- Native UI automation still depends on Accessibility trust being granted for the process that runs `xcodebuild`. On a new machine, run the preflight first.

## 2026-03-08 Update

- The current machine can still hit `Timed out while enabling automation mode.` even when `AXIsProcessTrusted()` returns `true`.
- The standalone repro under `Testing/XCUITestRepro/` reproduced the same failure on 2026-03-08, which confirms the blocker is currently machine-level / environment-level rather than Atlas-product-specific.
- `scripts/atlas/run-ui-automation.sh` now retries after cleanup, and `scripts/atlas/full-acceptance.sh` now classifies the failure against the standalone repro before failing the product acceptance run.
