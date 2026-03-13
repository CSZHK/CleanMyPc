# Recovery Credibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Freeze Atlas recovery semantics against shipped behavior by adding missing restore coverage and publishing explicit acceptance evidence and a gate review for ATL-221 through ATL-225.

**Architecture:** The worker already supports restore mappings for file-backed recovery items and Atlas-only rehydration for older/state-only records. This slice should avoid widening restore scope; instead it should prove the current contract with focused automated tests, then freeze that contract in execution docs and a recovery gate review.

**Tech Stack:** Swift Package Manager, XCTest, Markdown docs

---

### Task 1: Add helper-backed app restore coverage

**Files:**
- Modify: `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift`
- Check: `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift`

**Step 1: Write the failing test**

Add a test that:
- creates a fake installed app under `~/Applications/AtlasExecutionTests/...`
- injects a stub `AtlasPrivilegedActionExecuting`
- executes app uninstall
- restores the resulting recovery item
- asserts the app bundle returns to its original path and the restore summary uses the disk-backed wording

**Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages --filter AtlasInfrastructureTests/testExecuteAppUninstallRestorePhysicallyRestoresAppBundle`
Expected: FAIL until the stub/helper-backed path is wired correctly in the test.

**Step 3: Write minimal implementation**

Implement only the test support needed:
- a stub helper executor that handles `.trashItems` and `.restoreItem`
- deterministic assertions for returned `restoreMappings`

**Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages --filter AtlasInfrastructureTests/testExecuteAppUninstallRestorePhysicallyRestoresAppBundle`
Expected: PASS

**Step 5: Commit**

```bash
git add Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift
git commit -m "test: cover helper-backed app restore"
```

### Task 2: Add mixed recovery summary coverage

**Files:**
- Modify: `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift`
- Check: `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift:1086`

**Step 1: Write the failing test**

Add a test that restores:
- one recovery item with `restoreMappings`
- one recovery item without `restoreMappings`

Assert the task summary contains both:
- disk restore wording
- Atlas-only restore wording

**Step 2: Run test to verify it fails**

Run: `swift test --package-path Packages --filter AtlasInfrastructureTests/testRestoreItemsMixedSummaryIncludesDiskAndStateOnlyClauses`
Expected: FAIL if the combined contract is not proven yet.

**Step 3: Write minimal implementation**

If needed, adjust only test fixtures or summary generation so mixed restores preserve both clauses without overstating physical restore.

**Step 4: Run test to verify it passes**

Run: `swift test --package-path Packages --filter AtlasInfrastructureTests/testRestoreItemsMixedSummaryIncludesDiskAndStateOnlyClauses`
Expected: PASS

**Step 5: Commit**

```bash
git add Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift
git commit -m "test: cover mixed recovery summaries"
```

### Task 3: Freeze recovery contract and evidence

**Files:**
- Create: `Docs/Execution/Recovery-Contract-2026-03-13.md`
- Create: `Docs/Execution/Recovery-Credibility-Gate-Review-2026-03-13.md`
- Modify: `Docs/README.md`
- Check: `Docs/Protocol.md`
- Check: `README.md`
- Check: `README.zh-CN.md`
- Check: `Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings`
- Check: `Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings`

**Step 1: Write the contract doc**

Document exactly what Atlas promises today:
- file-backed recovery physically restores only when `restoreMappings` exist
- Atlas-only recovery rehydrates workspace state without claiming on-disk return
- helper-backed restore is required for protected paths like app bundles
- restore fails closed when the trash source is gone, the destination already exists, or helper capability is unavailable

**Step 2: Write the evidence section**

Reference automated proof points:
- direct-trash cache restore test
- helper-backed app uninstall restore test
- mixed summary/state-only tests
- existing `scan -> execute -> rescan` coverage for supported targets

**Step 3: Write the gate review**

Mirror the existing execution gate format and record:
- scope reviewed (`ATL-221` to `ATL-225`)
- evidence reviewed
- automated validation summary
- remaining limits
- decision and follow-up conditions

**Step 4: Update docs index**

Add the new recovery contract and gate review docs to `Docs/README.md`.

**Step 5: Commit**

```bash
git add Docs/Execution/Recovery-Contract-2026-03-13.md Docs/Execution/Recovery-Credibility-Gate-Review-2026-03-13.md Docs/README.md
git commit -m "docs: freeze recovery contract and gate evidence"
```

### Task 4: Run focused validation

**Files:**
- Check: `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift`
- Check: `Docs/Execution/Recovery-Contract-2026-03-13.md`
- Check: `Docs/Execution/Recovery-Credibility-Gate-Review-2026-03-13.md`

**Step 1: Run targeted infrastructure tests**

Run: `swift test --package-path Packages --filter AtlasInfrastructureTests`
Expected: PASS

**Step 2: Run broader package tests**

Run: `swift test --package-path Packages`
Expected: PASS

**Step 3: Sanity-check docs claims**

Verify every new doc line matches one of:
- protocol contract
- localized UI copy
- automated test evidence

**Step 4: Summarize remaining limits**

Call out that:
- physical restore is still partial by design
- unsupported or older recovery items remain Atlas-state-only
- broader restore scope should not expand without new allowlist and QA evidence

**Step 5: Commit**

```bash
git add Docs/README.md Docs/Execution/Recovery-Contract-2026-03-13.md Docs/Execution/Recovery-Credibility-Gate-Review-2026-03-13.md Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift
git commit -m "chore: validate recovery credibility slice"
```
