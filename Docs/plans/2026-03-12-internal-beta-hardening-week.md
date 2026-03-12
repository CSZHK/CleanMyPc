# Internal Beta Hardening Week Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the internal-beta candidate truthful for the 2026-03-16 hardening week by adding one new real Smart Clean execution path, tightening history/recovery claims, and capturing packaged-build QA evidence.

**Architecture:** Keep the existing real scan → worker execute → recovery-mapping model, but extend the Smart Clean execution allowlist for one high-value safe target class that the upstream Mole runtime already exports. Tighten worker summaries and History UI copy so Atlas only claims physical side effects when a real file move or restore mapping exists, then document packaged-build fresh-state verification in a dedicated execution note.

**Tech Stack:** Swift Package Manager, SwiftUI, XCTest, shell packaging scripts, Xcode build/package flow.

---

### Task 1: Add One New Safe Smart Clean Target Class

**Files:**
- Modify: `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift`
- Modify: `Packages/AtlasCoreAdapters/Sources/AtlasCoreAdapters/MoleSmartCleanAdapter.swift`
- Test: `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift`
- Test: `Packages/AtlasCoreAdapters/Tests/AtlasCoreAdaptersTests/MoleSmartCleanAdapterTests.swift`

**Step 1: Write the failing adapter and support tests**

Add tests for a `~/Library/pnpm/store/...` target so the repo proves:

- the detailed scan parser exposes a recognizable pnpm finding with structured `targetPaths`
- the worker allowlist treats `~/Library/pnpm/store/*` as a directly trashable safe target
- a file-backed `scan -> execute -> rescan` flow works for that target class

**Step 2: Run the focused tests to verify they fail**

Run:

```bash
swift test --package-path Packages --filter MoleSmartCleanAdapterTests
swift test --package-path Packages --filter AtlasInfrastructureTests
```

Expected:

- the pnpm target is not yet recognized or supported

**Step 3: Add the minimal implementation**

Implement:

- `~/Library/pnpm/store/*` in `AtlasSmartCleanExecutionSupport.isDirectlyTrashable`
- a readable title mapping such as `pnpm store` in `MoleSmartCleanAdapter.makeDetailedTitle`

**Step 4: Re-run the focused tests**

Run the same package tests and confirm the pnpm-target coverage passes.

**Step 5: Commit**

```bash
git add Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift Packages/AtlasCoreAdapters/Sources/AtlasCoreAdapters/MoleSmartCleanAdapter.swift Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift Packages/AtlasCoreAdapters/Tests/AtlasCoreAdaptersTests/MoleSmartCleanAdapterTests.swift
git commit -m "feat: support pnpm store smart clean execution"
```

### Task 2: Make History and Completion Claims Match Real Side Effects

**Files:**
- Modify: `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift`
- Modify: `Packages/AtlasFeaturesHistory/Sources/AtlasFeaturesHistory/HistoryFeatureView.swift`
- Modify: `Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings`
- Modify: `Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings`
- Test: `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift`

**Step 1: Write the failing truthfulness tests**

Add tests that prove:

- executing a supported plan whose file is already gone does not create a recovery item that implies Atlas moved it
- restore summaries distinguish physical restore from Atlas-state-only restore records

**Step 2: Run the focused infrastructure tests to verify failure**

Run:

```bash
swift test --package-path Packages --filter AtlasInfrastructureTests
```

Expected:

- current summaries and recovery bookkeeping still overclaim physical side effects

**Step 3: Implement the worker-side fix**

Update the scaffold worker so that:

- only findings with real `RecoveryPathMapping` entries create recovery items and count as “moved”
- missing-on-disk findings are cleared without being counted as physical execution
- restore summaries explicitly distinguish on-disk restore from Atlas-only state restoration

**Step 4: Implement the History UI copy split**

Update `HistoryFeatureView` and localization keys so recovery callouts and button hints reflect:

- supported file-backed restore paths
- Atlas-only restore records with no physical restore path

**Step 5: Re-run the focused tests**

Run the package tests again and confirm the truthfulness assertions pass.

**Step 6: Commit**

```bash
git add Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift Packages/AtlasFeaturesHistory/Sources/AtlasFeaturesHistory/HistoryFeatureView.swift Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift
git commit -m "fix: keep history claims aligned with real side effects"
```

### Task 3: Capture Hardening-Week QA and Packaged-Build Evidence

**Files:**
- Create: `Docs/Execution/Internal-Beta-Hardening-Week-2026-03-16.md`
- Modify: `Docs/Execution/Smart-Clean-Execution-Coverage-2026-03-09.md`
- Modify: `Docs/Execution/Smart-Clean-Manual-Verification-2026-03-09.md`
- Modify: `scripts/atlas/smart-clean-manual-fixtures.sh`

**Step 1: Update the manual fixture coverage**

Add the new safe target class to the fixture script and manual verification doc so QA can create disposable evidence for the new real execution path.

**Step 2: Build the latest packaged app**

Run:

```bash
./scripts/atlas/package-native.sh
```

Expected:

- latest `.app`, `.dmg`, and `.pkg` artifacts land in `dist/native`

**Step 3: Verify install and fresh-state launch**

Run:

```bash
KEEP_INSTALLED_APP=1 ./scripts/atlas/verify-dmg-install.sh
STATE_DIR="$PWD/.build/atlas-hardening-fresh-state" ./scripts/atlas/verify-app-launch.sh
```

Expected:

- packaged install succeeds
- packaged app launches against a brand-new workspace-state directory

**Step 4: Document bilingual QA and contract evidence**

Create `Docs/Execution/Internal-Beta-Hardening-Week-2026-03-16.md` with:

- clean-machine bilingual QA checklist/results for first launch, language switching, install path, Smart Clean, Apps, and History/Recovery
- fresh-state packaged-build verification notes and exact artifact paths
- test evidence for the new safe target class and `scan -> execute -> rescan`
- explicit copy constraints that prevent restore/execution overclaiming

**Step 5: Commit**

```bash
git add Docs/Execution/Internal-Beta-Hardening-Week-2026-03-16.md Docs/Execution/Smart-Clean-Execution-Coverage-2026-03-09.md Docs/Execution/Smart-Clean-Manual-Verification-2026-03-09.md scripts/atlas/smart-clean-manual-fixtures.sh dist/native
git commit -m "docs: capture internal beta hardening evidence"
```
