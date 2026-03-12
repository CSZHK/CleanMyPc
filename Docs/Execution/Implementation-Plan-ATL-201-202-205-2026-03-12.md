# ATL-201 / ATL-202 / ATL-205 Implementation Plan

> **For Codex:** Execute this plan task-by-task. Keep changes small, verify each layer narrowly first, and commit frequently.

**Goal:** Remove release-facing silent scaffold fallback, expose explicit execution-unavailable failures in the app UI, and narrow bilingual execution/recovery copy so Atlas only claims behavior it can actually prove today.

**Architecture:** Keep the worker fallback capability available only as an explicit development override, but make the default app path fail closed. Surface worker rejection reasons through the application layer as user-facing localized errors, then render those errors in `Smart Clean` as a danger-state callout instead of a quiet summary string. Tighten copy in the app and release-facing docs so “recoverable” and “restore” only describe the currently shipped behavior.

**Tech Stack:** Swift 6, SwiftUI, Swift Package Manager tests, package-scoped localization resources, Markdown docs.

---

### Task 1: Lock Release-Facing Worker Fallback Behind Explicit Development Mode

**Files:**
- Modify: `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`
- Modify: `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasXPCTransport.swift`
- Test: `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasXPCTransportTests.swift`
- Test: `Apps/AtlasApp/Tests/AtlasAppTests/AtlasAppModelTests.swift`

**Step 1: Write the failing transport tests**

Add tests in `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasXPCTransportTests.swift` that cover:

- release/default mode does **not** fall back when XPC rejects `executionUnavailable`
- explicit development mode still can fall back when `allowFallback == true`

Use the existing rejected-result fixture style:

```swift
let rejected = AtlasWorkerCommandResult(
    request: request,
    response: AtlasResponseEnvelope(
        requestID: request.id,
        response: .rejected(code: .executionUnavailable, reason: "simulated packaged worker failure")
    ),
    events: [],
    snapshot: AtlasScaffoldWorkspace.snapshot(),
    previewPlan: nil
)
```

**Step 2: Run the transport tests to verify the current fallback behavior**

Run:

```bash
swift test --package-path Packages --filter AtlasXPCTransportTests
```

Expected:

- one new test fails because the current app-facing setup still allows fallback when XPC rejects `executionUnavailable`

**Step 3: Make fallback opt-in for development only**

In `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasXPCTransport.swift` and `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`:

- keep `AtlasPreferredWorkerService` capable of fallback for explicit dev usage
- stop hardcoding `allowFallback: true` in `AtlasAppModel`
- derive fallback permission from an explicit development-only env path, for example:

```swift
let allowScaffoldFallback = ProcessInfo.processInfo.environment["ATLAS_ALLOW_SCAFFOLD_FALLBACK"] == "1"
```

- pass that value into `AtlasPreferredWorkerService(...)`

The key result is:

- installed/release-facing app path fails closed by default
- developers can still opt in locally with an env var

**Step 4: Add an app-model test for the default worker policy**

In `Apps/AtlasApp/Tests/AtlasAppTests/AtlasAppModelTests.swift`, add a focused test around a worker rejection path using an injected fake worker or a small helper constructor so the app model no longer assumes fallback-enabled behavior in default/release configuration.

Target behavior:

```swift
XCTAssertFalse(model.canExecuteCurrentSmartCleanPlan)
XCTAssertTrue(model.latestScanSummary.contains("unavailable"))
```

**Step 5: Run tests and verify**

Run:

```bash
swift test --package-path Packages --filter AtlasXPCTransportTests
swift test --package-path Apps --filter AtlasAppModelTests
```

Expected:

- transport tests pass
- app-model tests still pass with the new fail-closed default

**Step 6: Commit**

```bash
git add Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasXPCTransport.swift Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasXPCTransportTests.swift Apps/AtlasApp/Tests/AtlasAppTests/AtlasAppModelTests.swift
git commit -m "fix: gate scaffold fallback behind dev mode"
```

### Task 2: Surface Explicit Execution-Unavailable Failure States in Smart Clean

**Files:**
- Modify: `Packages/AtlasApplication/Sources/AtlasApplication/AtlasApplication.swift`
- Modify: `Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings`
- Modify: `Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`
- Modify: `Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift`
- Modify: `Packages/AtlasFeaturesSmartClean/Sources/AtlasFeaturesSmartClean/SmartCleanFeatureView.swift`
- Test: `Packages/AtlasApplication/Tests/AtlasApplicationTests/AtlasApplicationTests.swift`
- Test: `Apps/AtlasApp/Tests/AtlasAppTests/AtlasAppModelTests.swift`

**Step 1: Write the failing application-layer tests**

Add tests in `Packages/AtlasApplication/Tests/AtlasApplicationTests/AtlasApplicationTests.swift` for:

- `executionUnavailable` rejection maps to a user-facing localized error
- `helperUnavailable` rejection maps to a user-facing localized error

Use the existing `FakeWorker` and a rejected response:

```swift
let result = AtlasWorkerCommandResult(
    request: request,
    response: AtlasResponseEnvelope(
        requestID: request.id,
        response: .rejected(code: .executionUnavailable, reason: "XPC worker offline")
    ),
    events: [],
    snapshot: AtlasScaffoldWorkspace.snapshot(),
    previewPlan: nil
)
```

Assert on `error.localizedDescription`.

**Step 2: Run the application tests to verify they fail**

Run:

```bash
swift test --package-path Packages --filter AtlasApplicationTests
```

Expected:

- new rejection-mapping tests fail because `AtlasWorkspaceControllerError` still uses the generic `application.error.workerRejected`

**Step 3: Add code-specific user-facing error strings**

In `Packages/AtlasApplication/Sources/AtlasApplication/AtlasApplication.swift`, replace the one-size-fits-all rejection mapping with explicit cases:

```swift
case let .rejected(code, reason):
    switch code {
    case .executionUnavailable:
        return AtlasL10n.string("application.error.executionUnavailable", reason)
    case .helperUnavailable:
        return AtlasL10n.string("application.error.helperUnavailable", reason)
    default:
        return AtlasL10n.string("application.error.workerRejected", code.rawValue, reason)
    }
```

Add matching bilingual keys in both `.strings` files.

**Step 4: Write the failing app-model/UI-state tests**

In `Apps/AtlasApp/Tests/AtlasAppTests/AtlasAppModelTests.swift`, add tests that verify:

- executing a plan with `executionUnavailable` leaves the plan non-busy
- the model stores an explicit Smart Clean execution issue
- the summary and/or issue text is specific, not a silent generic fallback success

Introduce a small fake worker actor in the test file if needed:

```swift
private actor RejectingWorker: AtlasWorkerServing {
    func submit(_ request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult { ... }
}
```

**Step 5: Implement explicit Smart Clean failure state**

In `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`:

- add a dedicated published property such as:

```swift
@Published private(set) var smartCleanExecutionIssue: String?
```

- clear it before a new scan / preview / execute attempt
- set it when `executeCurrentPlan()` catches `executionUnavailable` or `helperUnavailable`

In `Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift`, pass the new issue through to `SmartCleanFeatureView`.

In `Packages/AtlasFeaturesSmartClean/Sources/AtlasFeaturesSmartClean/SmartCleanFeatureView.swift`:

- add an optional `executionIssue: String?`
- render a danger-tone callout or status state when this value exists
- prefer this explicit issue over a normal “ready” or cached-plan state

The UI target is:

- a failed real execution attempt is visually obvious
- the user sees “unavailable” or “helper unavailable”, not just a stale summary string

**Step 6: Run tests and verify**

Run:

```bash
swift test --package-path Packages --filter AtlasApplicationTests
swift test --package-path Apps --filter AtlasAppModelTests
```

Expected:

- rejection mapping tests pass
- app-model tests show explicit failure-state behavior

**Step 7: Commit**

```bash
git add Packages/AtlasApplication/Sources/AtlasApplication/AtlasApplication.swift Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift Packages/AtlasFeaturesSmartClean/Sources/AtlasFeaturesSmartClean/SmartCleanFeatureView.swift Packages/AtlasApplication/Tests/AtlasApplicationTests/AtlasApplicationTests.swift Apps/AtlasApp/Tests/AtlasAppTests/AtlasAppModelTests.swift
git commit -m "fix: expose explicit smart clean execution failures"
```

### Task 3: Narrow Bilingual Execution and Recovery Copy to Shipped Behavior

**Files:**
- Modify: `Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings`
- Modify: `Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `Docs/HELP_CENTER_OUTLINE.md`
- Modify: `Docs/Execution/Current-Status-2026-03-07.md`
- Modify: `Docs/Execution/Beta-Gate-Review.md`
- Modify: `Docs/Execution/Smart-Clean-Execution-Coverage-2026-03-09.md`

**Step 1: Write the copy audit checklist directly into the diff**

Before editing text, create a short checklist in your working notes and verify every claim against current behavior:

- does this line claim physical restore for all recoverable items?
- does this line imply History/Recovery always means on-disk restore?
- does this line distinguish “supported restore path” from “model-only restore”?
- does this line imply direct execution for unsupported Smart Clean items?

**Step 2: Tighten in-app copy first**

Update the localized strings most likely to overclaim current behavior:

- `smartclean.execution.coverage.full.detail`
- `smartclean.preview.callout.safe.detail`
- `application.recovery.completed`
- `infrastructure.restore.summary.one`
- `infrastructure.restore.summary.other`
- `history.callout.recovery.detail`
- `history.detail.recovery.callout.available.detail`
- `history.restore.hint`

The wording rule is:

- say “when supported” or “when a restore path is available” where true
- avoid implying every recoverable item restores physically
- avoid implying every Smart Clean item is directly executable

**Step 3: Tighten release-facing docs**

Update:

- `README.md`
- `README.zh-CN.md`
- `Docs/HELP_CENTER_OUTLINE.md`
- `Docs/Execution/Current-Status-2026-03-07.md`
- `Docs/Execution/Beta-Gate-Review.md`
- `Docs/Execution/Smart-Clean-Execution-Coverage-2026-03-09.md`

Specific goals:

- README should keep “recovery-first” as a principle without implying universal physical restore
- `Current-Status` and `Beta-Gate-Review` must match the current subset reality
- help content should explicitly include the case where restore cannot return a file physically

**Step 4: Run the narrowest verification**

Run:

```bash
swift test --package-path Packages --filter AtlasApplicationTests
swift test --package-path Apps --filter AtlasAppModelTests
```

Then manually verify:

- Smart Clean empty/ready/error copy still reads correctly in both Chinese and English
- History / Recovery copy still makes sense after narrowing restore claims

Expected:

- tests stay green
- docs and UI no longer overclaim physical restore or execution breadth

**Step 5: Commit**

```bash
git add Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings README.md README.zh-CN.md Docs/HELP_CENTER_OUTLINE.md Docs/Execution/Current-Status-2026-03-07.md Docs/Execution/Beta-Gate-Review.md Docs/Execution/Smart-Clean-Execution-Coverage-2026-03-09.md
git commit -m "docs: narrow execution and recovery claims"
```

### Task 4: Final Verification and Handoff

**Files:**
- Review only: `Docs/Execution/Beta-Acceptance-Checklist.md`
- Review only: `Docs/Execution/Execution-Chain-Audit-2026-03-09.md`
- Review only: `Docs/ROADMAP.md`
- Review only: `Docs/Backlog.md`

**Step 1: Run focused regression commands**

Run:

```bash
swift test --package-path Packages --filter AtlasXPCTransportTests
swift test --package-path Packages --filter AtlasApplicationTests
swift test --package-path Apps --filter AtlasAppModelTests
```

Expected:

- all targeted tests pass

**Step 2: Run broader package and app tests if the focused tests are green**

Run:

```bash
swift test --package-path Packages
swift test --package-path Apps
```

Expected:

- no regressions in package or app test suites

**Step 3: Manual product verification**

Verify on the latest local packaged or debug build:

1. Force an execution-unavailable path and confirm Smart Clean shows a visible danger-state failure.
2. Confirm no silent fallback success path is visible in normal app mode.
3. Confirm Smart Clean still executes supported safe targets.
4. Confirm Recovery/History wording no longer implies guaranteed physical restore for every item.

**Step 4: Handoff notes**

Record:

- what was changed
- which files changed
- which tests passed
- whether physical restore remains partial after copy hardening
- whether signed-release work is still blocked by missing credentials
