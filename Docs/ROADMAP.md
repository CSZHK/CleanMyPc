# Roadmap

## Current Starting Point

- Date: `2026-03-12`
- Product state: `Frozen MVP complete`
- Validation state: `Internal beta passed with conditions on 2026-03-07`
- Immediate priorities:
  - turn `Apps` review-only evidence into verifiable and comparable uninstall evidence
  - expand `Smart Clean` safe coverage only on the next high-confidence roots
  - harden `Recovery` payload compatibility and restore evidence after execution boundaries stabilize
  - keep release-readiness work behind the product-path epics until signing materials exist
- Release-path blocker:
  - no Apple signing and notarization credentials are available on the current machine

## Roadmap Guardrails

- Keep scope inside the frozen MVP modules:
  - `Overview`
  - `Smart Clean`
  - `Apps`
  - `History`
  - `Recovery`
  - `Permissions`
  - `Settings`
- Do not pull `Storage treemap`, `Menu Bar`, or `Automation` into this roadmap.
- Respond to competitor pressure by deepening the frozen MVP flows rather than adding new surfaces for parity theater.
- Treat trust and recovery honesty as release-critical product work, not polish.
- Keep direct distribution as the only eventual release route.
- Do not plan around public beta dates until signing credentials exist.

## Competitive Strategy Overlay

- Primary breadth comparison pressure comes from `Mole` and `Tencent Lemon Cleaner`.
- Primary `Apps` comparison pressure comes from `Pearcleaner` and `Tencent Lemon Cleaner`.
- Atlas should compete as an `explainable, recovery-first Mac maintenance workspace`, not as a generic all-in-one cleaner.
- The roadmap response is:
  - preserve trust as the primary release gate
  - deepen the `Apps` module first where `Pearcleaner` and `Lemon` set expectations
  - then close the most visible `Smart Clean` safe-coverage gaps users compare against `Mole` and `Lemon`
  - harden `Recovery` only after execution boundaries and evidence models are stable
  - treat release readiness as the final convergence step because signing materials, not packaging mechanics, remain the public-release blocker
  - keep `Storage treemap`, `Menu Bar`, and `Automation` out of scope

## Active Milestones

### Milestone 1: Internal Beta Hardening

- Dates: `2026-03-16` to `2026-03-28`
- Goal: harden the current internal-beta build until user-visible execution and recovery claims are defensible.
- Focus:
  - remove or explicitly development-gate silent XPC fallback
  - show explicit failure states when real worker execution is unavailable
  - rerun bilingual manual QA on a clean machine
  - verify packaged first-launch behavior with a fresh state file
  - tighten README, in-app copy, and help content where recovery or execution is overstated
- Exit criteria:
  - internal beta checklist rerun against the latest packaged build
  - unsupported execution paths fail clearly instead of appearing successful
  - recovery wording matches the shipped restore behavior

### Milestone 2: Apps Evidence Execution

- Dates: `2026-03-31` to `2026-04-11`
- Goal: turn `Apps` review-only evidence from merely visible into verifiable, comparable, and recoverably consistent.
- Focus:
  - define the fixture app baseline for mainstream and developer-heavy uninstall scenarios
  - make preview, completion, and history reflect the same uninstall evidence model
  - define the restore-triggered app-footprint refresh strategy and stale-evidence handling
  - script the manual acceptance flow for uninstall evidence and restore verification
- Exit criteria:
  - supported fixture apps produce consistent evidence across preview, completion, and history
  - restore follows a defined footprint refresh path or shows explicit stale-evidence state
  - the `Apps` acceptance path is scriptable and repeatable

### Milestone 3: Smart Clean Safe Coverage Expansion

- Dates: `2026-04-14` to `2026-05-02`
- Goal: expand only the next batch of high-confidence safe cleanup roots and prove real side effects without widening into high-risk cleanup.
- Focus:
  - add the next safe roots outside app containers
  - stabilize the `review-only` vs `executable` boundary across scan, review, execute, completion, and history
  - strengthen the `scan -> execute -> rescan` evidence chain for the expanded safe roots
  - keep unsupported or high-risk paths explicitly non-executable
- Exit criteria:
  - newly supported safe roots show real post-execution rescan improvement
  - unsupported roots remain clearly marked as `review-only`
  - release-facing surfaces distinguish supported and unsupported execution scope without ambiguity

### Milestone 4: Recovery Payload Hardening

- Dates: `2026-05-05` to `2026-05-23`
- Goal: make recovery state structurally stable, backward-compatible, and historically trustworthy.
- Focus:
  - stabilize the recovery payload schema and versioning contract
  - add migration and compatibility handling for older workspace and history state files
  - deepen `History` detail evidence for restore payloads, conflicts, expiry, and partial restore outcomes
  - add regression coverage for conflict, expired payload, and partial-restore scenarios
- Exit criteria:
  - recovery payloads follow a stable versioned schema
  - older state files migrate cleanly or fail with explicit compatibility behavior
  - `History` detail can explain real restore evidence and degraded outcomes
  - regression coverage exists for the main restore edge cases

### Milestone 5: Release Readiness

- Dates: `2026-05-26` to `2026-06-13`
- Goal: turn the stabilized product path into a repeatable release candidate process, then switch to the signing chain when credentials exist.
- Focus:
  - make `full-acceptance` a routine gate on candidate builds
  - stabilize UI automation for trust-critical MVP flows
  - freeze packaging, install, and launch smoke checks as repeatable release scripts
  - switch from the pre-signing release chain to `Developer ID + notarization` once credentials become available
- Exit criteria:
  - `full-acceptance` runs routinely on candidate builds
  - trust-critical UI automation is stable enough for release gating
  - packaging, install, and launch smoke checks are repeatable
  - the signed chain either passes with credentials present or remains explicitly blocked only by missing credentials

## Conditional Release Branch

These milestones do not start until Milestone `5` is complete and Apple release credentials are available.

### Conditional Milestone A: Signed External Beta Candidate

- Trigger:
  - Milestones `1` through `5` are complete
  - `Developer ID Application` is available
  - `Developer ID Installer` is available
  - `ATLAS_NOTARY_PROFILE` is available
- Goal: produce a signed and notarized external beta candidate.
- Focus:
  - rerun the release scripts on the signed chain
  - validate signed `.app`, `.dmg`, and `.pkg` install paths on a clean machine
  - prepare external beta notes and known limitations
- Exit criteria:
  - signed and notarized artifacts install without bypass instructions
  - clean-machine install verification passes on the signed candidate

### Conditional Milestone B: External Beta Learn Loop

- Trigger:
  - Conditional Milestone A is complete
- Goal: run a small external beta only after the mainline product path is stable.
- Focus:
  - use a hardware-diverse trusted beta cohort
  - triage install, permission, execution, and restore regressions
  - close P0 issues before any GA candidate is named
- Exit criteria:
  - no external-beta P0 remains open
  - primary workflows are validated on more than one machine profile

### Conditional Milestone C: GA Candidate and Launch

- Trigger:
  - Conditional Milestone B is complete
- Goal: publish `v1.0` only after trust, recovery, and signed distribution all align.
- Focus:
  - rerun full acceptance and signed packaging on the GA candidate
  - freeze release notes, notices, acknowledgements, and checksums
  - validate launch candidate install and first-run flow on a clean machine
- Exit criteria:
  - no open P0 release blocker
  - signed packaging, install validation, and release docs are complete
  - `v1.0` artifacts are published

## Current Decision Rules

- Do not call the current workstream `public beta`.
- Do not claim broader cleanup coverage than the worker/helper path can prove.
- Do not claim physical recovery until file-backed restore is actually validated.
- Do not schedule a public release date before signing credentials exist.

## Not In This Roadmap

- `Storage treemap`
- `Menu Bar`
- `Automation`
- new non-MVP modules
