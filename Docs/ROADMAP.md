# Roadmap

## Current Starting Point

- Date: `2026-03-12`
- Product state: `Frozen MVP complete`
- Validation state: `Internal beta passed with conditions on 2026-03-07`
- Immediate priorities:
  - remove silent XPC fallback from release-facing trust assumptions
  - make `Smart Clean` execution honesty match real filesystem behavior
  - make `Recovery` claims match shipped restore behavior
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
- Treat trust and recovery honesty as release-critical product work, not polish.
- Keep direct distribution as the only eventual release route.
- Do not plan around public beta dates until signing credentials exist.

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

### Milestone 2: Smart Clean Execution Credibility

- Dates: `2026-03-31` to `2026-04-18`
- Goal: prove that the highest-value safe cleanup paths have real disk-backed side effects.
- Focus:
  - expand real `Smart Clean` execute coverage for top safe target classes
  - carry executable structured targets through the worker path
  - add stronger `scan -> execute -> rescan` contract coverage
  - make history and completion states reflect real side effects only
- Exit criteria:
  - top safe cleanup paths show real post-execution scan improvement
  - history does not claim success without real side effects
  - release-facing docs clearly distinguish supported vs unsupported cleanup paths

### Milestone 3: Recovery Credibility

- Dates: `2026-04-21` to `2026-05-09`
- Goal: close the gap between Atlas's recovery promise and its shipped restore behavior.
- Focus:
  - implement physical restore for file-backed recoverable actions where safe
  - or narrow product and release messaging if physical restore cannot land safely
  - validate restore behavior on real file-backed test cases
  - freeze recovery-related copy only after behavior is confirmed
- Exit criteria:
  - recovery language matches shipped behavior
  - file-backed recoverable actions either restore physically or are no longer described as if they do
  - QA has explicit evidence for restore behavior on the candidate build

## Conditional Release Branch

These milestones do not start until Apple release credentials are available.

### Conditional Milestone A: Signed Public Beta Candidate

- Trigger:
  - `Developer ID Application` is available
  - `Developer ID Installer` is available
  - `ATLAS_NOTARY_PROFILE` is available
- Goal: produce a signed and notarized external beta candidate.
- Focus:
  - pass `./scripts/atlas/signing-preflight.sh`
  - rerun signed packaging
  - validate signed `.app`, `.dmg`, and `.pkg` install paths on a clean machine
  - prepare public beta notes and known limitations
- Exit criteria:
  - signed and notarized artifacts install without bypass instructions
  - clean-machine install verification passes on the signed candidate

### Conditional Milestone B: Public Beta Learn Loop

- Trigger:
  - Conditional Milestone A is complete
- Goal: run a small external beta after internal hardening is already complete.
- Focus:
  - use a hardware-diverse trusted beta cohort
  - triage install, permission, execution, and restore regressions
  - close P0 issues before any GA candidate is named
- Exit criteria:
  - no public-beta P0 remains open
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
