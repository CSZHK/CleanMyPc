# ATL-211 / ATL-214 / ATL-226-230 Implementation Plan

> **For Codex:** Use this as the first coding-slice plan for the selective-parity strategy. Keep scope inside frozen MVP. Verify behavior with narrow tests and fixture-driven checks before broader UI validation.

## Goal

Make Atlas more defensible against `Mole`, `Tencent Lemon Cleaner`, and `Pearcleaner` without expanding beyond MVP:

- increase `Smart Clean` competitive credibility on the most visible safe cleanup classes
- deepen the `Apps` module so uninstall preview and completion evidence feel trustworthy and specific

## Product Rules

- Do not add new top-level product surfaces.
- Do not imply parity with broader tools when Atlas still supports only a narrower subset.
- Prefer explicit supported-vs-review-only states over speculative or partial execution.
- Prefer categories Atlas can prove and recover over categories that merely look complete in the UI.

## Target Outcomes

### Smart Clean

- Atlas can execute more of the high-confidence safe cleanup classes users naturally compare to `Mole` and `Lemon`.
- Completion and history copy only describe real disk-backed side effects.
- Unsupported paths remain explicit and fail closed.

### Apps

- Atlas explains what an uninstall preview actually contains.
- Users can understand bundle footprint, leftovers, launch-item/service implications, and recoverability before confirming.
- The uninstall flow leaves stronger audit and completion evidence than the current baseline.

## Competitive Pressure Matrix

### Smart Clean comparison pressure

Top overlap with `Mole` and `Lemon`:

- user cache roots
- logs and temp data
- developer artifact roots
- high-confidence app-specific junk paths already represented structurally in Atlas

Non-goals for this slice:

- duplicate file cleanup
- similar photos
- privacy-cleaning as a standalone surface
- treemap storage analysis

### Apps comparison pressure

Top overlap with `Pearcleaner` and `Lemon`:

- uninstall leftovers clarity
- launch-item / service-adjacent footprint awareness
- better explanation of what Atlas will remove, what it will not remove, and what is recoverable

Non-goals for this slice:

- Homebrew manager as a new standalone module
- PKG manager as a new standalone module
- plugin manager as a new standalone module
- auto-cleaning daemon behavior

## Task 1: Freeze Fixture and Benchmark Set

### Goal

Define the exact scenarios the coding slice must satisfy before implementation starts drifting.

### Deliverables

- a `Smart Clean` target-class list used for parity work
- an `Apps` fixture list covering:
  - mainstream GUI app
  - developer-heavy app
  - app with launch item or service artifact
  - app with sparse leftovers

### Proposed file touch map

- `Docs/Execution/MVP-Acceptance-Matrix.md`
- `Docs/Execution/Beta-Acceptance-Checklist.md`
- future test fixtures under `Testing/` or package test directories as implementation chooses

### Acceptance

- each benchmark scenario is tied to a real competitor comparison pressure
- each benchmark scenario is tied to a current MVP surface

## Task 2: Smart Clean Selective Parity Increment

### Goal

Land one implementation slice that widens competitive coverage without weakening trust.

### Likely code areas

- `Packages/AtlasCoreAdapters/Sources/AtlasCoreAdapters/MoleSmartCleanAdapter.swift`
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift`
- `Packages/AtlasApplication/Sources/AtlasApplication/AtlasApplication.swift`
- `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`
- `Packages/AtlasFeaturesSmartClean/Sources/AtlasFeaturesSmartClean/SmartCleanFeatureView.swift`

### Work shape

- extend safe allowlisted target support only where Atlas already has structured evidence
- tighten plan/execution/result summaries so history reflects actual side effects only
- expose unsupported findings as review-only rather than ambiguous ready-to-run items

### Tests

- package-level contract tests for `scan -> execute -> rescan`
- app-model tests for explicit unsupported or unavailable states

### Acceptance

- at least one new high-confidence safe target class is supported end to end
- unsupported target classes remain visibly unsupported
- no history or completion surface overclaims what happened on disk

## Task 3: Apps Preview Taxonomy and Evidence

### Goal

Make uninstall preview feel materially stronger against `Pearcleaner` and `Lemon`.

### Likely code areas

- `Packages/AtlasApplication/Sources/AtlasApplication/AtlasApplication.swift`
- `Packages/AtlasInfrastructure/Sources/AtlasInfrastructure/AtlasInfrastructure.swift`
- `Packages/AtlasProtocol/`
- `Packages/AtlasFeaturesApps/Sources/AtlasFeaturesApps/AppsFeatureView.swift`
- `Apps/AtlasApp/Sources/AtlasApp/AtlasAppModel.swift`

### Work shape

- expand preview categories so the UI can group footprint evidence more explicitly
- distinguish:
  - application bundle
  - support files
  - caches
  - preferences
  - logs
  - launch/service-adjacent items where Atlas can safely classify them
- keep unclear or unsupported items explicitly separate instead of silently mixing them into a generic leftover count

### Tests

- application-layer tests for preview taxonomy
- infrastructure tests for structured footprint generation
- UI snapshot or app-model assertions for preview grouping if feasible

### Acceptance

- uninstall preview provides more than a count and byte total
- supported footprint categories are explicit and user-comprehensible
- ambiguous items are clearly labeled rather than overstated

## Task 4: Apps Trust Cues and Completion Evidence

### Goal

Turn `Apps` from a functional uninstall screen into a trust-differentiated uninstall workflow.

### Likely code areas

- `Packages/AtlasFeaturesApps/Sources/AtlasFeaturesApps/AppsFeatureView.swift`
- `Apps/AtlasApp/Sources/AtlasApp/AppShellView.swift`
- localization resources in `Packages/AtlasDomain`

### Work shape

- add supported-vs-review-only messaging where relevant
- show recoverability and audit implications before destructive confirmation
- tighten completion summaries so they state what Atlas actually removed and what was recorded for recovery/history

### Tests

- app-model tests for completion summaries and history-driven state
- focused UI verification for uninstall preview -> execute -> history/recovery path

### Acceptance

- the flow answers, before confirm:
  - what will be removed
  - what evidence Atlas has
  - what is recoverable
- the flow answers, after confirm:
  - what was actually removed
  - what was recorded

## Task 5: Fixture-Based Validation and Gate

### Goal

Prove the coding slice against realistic comparison cases instead of synthetic happy-path only.

### Validation layers

- narrow package tests first
- app-model tests second
- manual or scripted fixture walkthrough third

### Required fixture scenarios

- one mainstream app uninstall
- one developer-heavy app uninstall
- one `Smart Clean` scenario with newly supported target class
- one unsupported scenario that must fail closed visibly

### Gate outputs

- evidence summary for `ATL-229`
- short gate review for `ATL-230`
- any claim narrowing needed in UI or release-facing docs

## Recommended Coding Order

1. freeze fixtures and target classes
2. implement one `Smart Clean` selective-parity increment
3. land uninstall preview taxonomy changes
4. land uninstall trust cues and completion evidence
5. rerun fixture validation and produce gate evidence

## Commands To Prefer During Implementation

```bash
swift test --package-path Packages
swift test --package-path Apps
swift test --package-path Packages --filter AtlasInfrastructureTests
swift test --package-path Apps --filter AtlasAppModelTests
```

Add narrower filters once the exact tests are created.

## Done Criteria

- `Smart Clean` parity increment is real and test-backed
- `Apps` preview is structurally richer and more trustworthy
- fixture validation shows visible improvement against the current baseline
- docs remain honest about supported vs unsupported behavior
