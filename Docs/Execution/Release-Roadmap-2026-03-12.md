# Internal Beta Hardening and Conditional Release Roadmap — 2026-03-12

## Product Conclusion

Atlas for Mac should not optimize around public beta dates right now. The correct near-term program is `internal beta hardening`: execution truthfulness first, recovery credibility second, signed public distribution later when Apple release credentials exist.

This plan assumes:

- the frozen MVP module list does not change
- direct distribution remains the eventual release route
- no public beta or GA milestone is active until signing credentials are available

## Starting Evidence

- `Docs/Execution/Current-Status-2026-03-07.md` marks Atlas as internal-beta ready.
- `Docs/Execution/Beta-Gate-Review.md` passes the beta candidate gate with conditions.
- `Docs/Execution/Execution-Chain-Audit-2026-03-09.md` identifies the two biggest trust gaps:
  - silent fallback from XPC to scaffold worker
  - partial real execution and non-physical restore behavior
- `Docs/Execution/Release-Signing.md` shows public distribution is blocked by missing Apple release credentials on the current machine.

## Active Phase Plan

### Phase 1: Internal Beta Hardening

- Dates: `2026-03-16` to `2026-03-28`
- Outcome: a truthful internal-beta build that no longer overclaims execution or recovery capability

#### Workstreams

- `System Agent`
  - remove or development-gate silent XPC fallback in release-facing flows
  - surface explicit user-facing errors when real worker execution is unavailable
- `QA Agent`
  - rerun clean-machine validation for first launch, language switching, and install flow
  - rerun `Smart Clean` and `Apps` end-to-end manual flows against packaged artifacts
- `UX Agent` + `Docs Agent`
  - tighten copy where `Recovery` or `Smart Clean` implies broader on-disk behavior than shipped

#### Exit Gate

- latest packaged build passes internal beta checklist again
- unsupported execution paths are visible and honest
- recovery language matches the current shipped restore model

### Phase 2: Smart Clean Execution Credibility

- Dates: `2026-03-31` to `2026-04-18`
- Outcome: highest-value safe cleanup paths have proven real side effects

#### Workstreams

- `System Agent` + `Core Agent`
  - expand real `Smart Clean` execute coverage for top safe target classes
  - carry executable structured targets through the worker path
  - route privileged cleanup through the helper boundary where necessary
- `QA Agent`
  - add stronger `scan -> execute -> rescan` contract coverage
  - verify history and completion states only claim real success
- `Mac App Agent`
  - align completion and failure states with true execution outcomes

#### Exit Gate

- supported cleanup paths show real post-execution scan improvement
- unsupported paths fail clearly
- history only claims completion when the filesystem side effect happened

### Phase 3: Recovery Credibility

- Dates: `2026-04-21` to `2026-05-09`
- Outcome: Atlas's recovery promise is either physically true for file-backed actions or explicitly narrowed before release planning resumes

#### Workstreams

- `System Agent`
  - implement physical restore for file-backed recoverable actions where safe
  - or freeze a narrower recovery contract if physical restore cannot be landed safely
- `QA Agent`
  - validate restore behavior on real file-backed test cases
- `Docs Agent` + `Product Agent`
  - freeze README, release-note, and in-app recovery wording only after behavior is confirmed

#### Exit Gate

- file-backed recoverable actions either restore physically or are no longer described as if they do
- QA evidence exists for shipped restore behavior
- recovery claims are consistent across docs and product copy

## Conditional Release Plan

This branch is dormant until Apple release credentials exist.

### Conditional Phase A: Signed Public Beta Candidate

- Trigger:
  - `Developer ID Application`
  - `Developer ID Installer`
  - `ATLAS_NOTARY_PROFILE`
- Workstreams:
  - run `./scripts/atlas/signing-preflight.sh`
  - rerun signed packaging
  - validate signed install behavior on a clean machine
  - prepare public beta notes and known limitations
- Exit Gate:
  - signed and notarized artifacts exist
  - clean-machine install verification passes

### Conditional Phase B: Public Beta Learn Loop

- Trigger:
  - Conditional Phase A complete
- Workstreams:
  - run a small hardware-diverse trusted beta cohort
  - triage install, permission, execution, and restore regressions
  - close P0 issues before any GA candidate is named
- Exit Gate:
  - no public-beta P0 remains open
  - primary workflows are validated across more than one machine profile

### Conditional Phase C: GA Candidate and Launch

- Trigger:
  - Conditional Phase B complete
- Workstreams:
  - rerun full acceptance and signed packaging on the GA candidate
  - freeze release notes, notices, acknowledgements, and checksums
  - validate launch-candidate install and first-run flow on a clean machine
- Exit Gate:
  - no open P0 release blocker
  - signed packaging, install validation, and release docs are complete
  - `v1.0` is published

## Workstream Priorities

### Priority 1: Execution Truthfulness

Atlas cannot afford a release where `Smart Clean` appears to succeed while only Atlas state changes. Silent fallback removal, explicit execution failures, and `scan -> execute -> rescan` proof are the current highest-value work.

### Priority 2: Recovery Credibility

`Recovery` is part of Atlas's core trust story. Before broad release planning resumes, Atlas must either ship physical restore for file-backed recoverable actions or narrow its promise to the behavior that actually exists.

### Priority 3: Signed Distribution When Unblocked

Signing and notarization matter, but they are not the active critical path until credentials exist. When the credentials arrive, Gatekeeper-safe installation becomes a release gate, not a background task.

## Decision Rules

- Do not add P1 modules during this roadmap window.
- Do not call the current branch `public beta`.
- Do not claim broader cleanup coverage than the worker/helper path can prove.
- Do not claim physical recovery until file-backed restore is validated.
