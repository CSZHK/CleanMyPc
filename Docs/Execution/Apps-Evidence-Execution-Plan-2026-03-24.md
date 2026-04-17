# Apps Evidence Execution Plan — 2026-03-24

## Context

The current mainline order is already frozen:

1. `EPIC-A` Apps Evidence Execution
2. `EPIC-B` Smart Clean Safe Coverage Expansion
3. `EPIC-C` Recovery Payload Hardening
4. `EPIC-D` Release Readiness

This document turns `EPIC-A` from roadmap intent into the next implementation-ready execution plan.

Related docs:

- [ROADMAP.md](../ROADMAP.md)
- [Backlog.md](../Backlog.md)
- [Selective-Parity-Week-2026-03-23.md](./Selective-Parity-Week-2026-03-23.md)
- [MVP-Acceptance-Matrix.md](./MVP-Acceptance-Matrix.md)

## Planned Window

- `2026-03-31` to `2026-04-11`

## Goal

Make `Apps` uninstall evidence verifiable, comparable, and recoverably consistent so Atlas can compete credibly with `Pearcleaner` and `Tencent Lemon Cleaner` without expanding beyond frozen MVP.

## Product Rules

- Stay inside `Apps`, `History`, and `Recovery`, with only the minimum supporting changes needed in shared protocol, application, or system layers.
- Do not create new product surfaces or reopen deferred modules.
- Do not overstate uninstall completeness when Atlas only has partial or review-only evidence.
- Keep recoverability, stale evidence, and unsupported states explicit.

## User Outcome

After this epic is complete, a user should be able to:

- preview what Atlas knows about an app uninstall in a structured and explainable way
- see the same evidence model echoed in completion and history
- understand whether restored apps have fresh footprint evidence or stale evidence that needs refresh
- trust that unsupported or ambiguous artifacts are labeled honestly rather than silently merged into a generic total

## Ordered Task List

Execute these tasks in order only.

### 1. `ATL-251` Freeze Fixture App Baseline

#### Purpose

Define the benchmark set that all `Apps` evidence work must satisfy before UI or protocol changes start drifting.

#### Deliverables

- a fixture matrix covering:
  - one mainstream GUI app
  - one developer-heavy app
  - one app with launch-item or service-adjacent artifacts
  - one app with sparse leftovers
- a baseline rubric for:
  - preview evidence
  - completion evidence
  - history evidence
  - restore refresh expectations

#### Validation

- every fixture maps to an actual comparison pressure from `Pearcleaner` or `Lemon`
- every fixture maps to an existing MVP surface
- no fixture assumes new Atlas modules

#### Exit Check

Implementation does not start until the fixture set and scoring rubric are documented.

### 2. `ATL-252` Unify the Uninstall Evidence Model

#### Purpose

Make preview, completion, and history consume the same evidence taxonomy instead of drifting into three loosely related summaries.

#### Deliverables

- one structured uninstall evidence model shared across:
  - preview
  - completion
  - history
- explicit category rules for:
  - application bundle
  - support files
  - caches
  - preferences
  - logs
  - launch/service-adjacent items when Atlas can classify them safely
  - ambiguous or unsupported leftovers
- a file-touch map for protocol, application, infrastructure, feature, and app-shell changes

#### Validation

- the same fixture app produces the same category story before uninstall, after uninstall, and in history
- ambiguous items stay separate from supported evidence
- history never claims more certainty than preview or execution can prove

#### Exit Check

The evidence contract is frozen before trust-cue polish or history-detail copy changes begin.

### 3. `ATL-253` Define Restore Refresh and Stale-Evidence Behavior

#### Purpose

Prevent restore flows from reusing stale app-footprint evidence and undermining trust after recovery.

#### Deliverables

- restore-triggered footprint refresh policy
- stale-evidence state definitions for:
  - refresh pending
  - refresh failed
  - evidence unavailable
- rules for what `Apps`, `History`, and `Recovery` each show in these states

#### Validation

- restored fixtures either refresh through a defined path or show a visible stale-evidence state
- no screen silently presents pre-restore footprint counts as current
- the policy is compatible with current recovery payload constraints

#### Exit Check

No restore-facing UI or history detail ships without an explicit stale-evidence contract.

### 4. `ATL-254` Script the Acceptance Flow

#### Purpose

Turn the fixture and evidence rules into a repeatable acceptance path rather than a one-off doc exercise.

#### Deliverables

- a scripted uninstall acceptance flow covering:
  - preview verification
  - uninstall completion verification
  - history verification
  - restore verification
  - post-restore refresh or stale-state verification
- manual or semi-scripted execution notes suitable for `QA Agent` reuse

#### Validation

- a tester can run the same flow twice on the same fixture set without ambiguous interpretation
- each acceptance step has an expected evidence output
- unsupported scenarios fail clearly instead of blending into the success path

#### Exit Check

`EPIC-A` is not ready for gate review until the acceptance flow is scriptable and repeatable.

### 5. `ATL-255` Gate Review

#### Purpose

Close the epic with a trust-focused review rather than a feature-count review.

#### Deliverables

- a short gate review summarizing:
  - fixture results
  - evidence consistency results
  - restore refresh outcomes
  - open trust gaps
- claim narrowing for UI or release-facing copy if any scenario remains weaker than planned

#### Validation

- all prior task exit checks are satisfied
- any remaining gaps are explicit and bounded
- the next epic (`EPIC-B`) does not start until `EPIC-A` is either passed or narrowed honestly

## Execution Sequence

### Phase A: Benchmark Freeze

- complete `ATL-251`
- reject any implementation work that cannot be tested against the frozen fixture set

### Phase B: Evidence Contract

- complete `ATL-252`
- freeze the structured evidence taxonomy before broad UI polishing

### Phase C: Recovery Consistency

- complete `ATL-253`
- ensure restored-state behavior is explicit before final acceptance scripting

### Phase D: Acceptance and Gate

- complete `ATL-254`
- complete `ATL-255`

## Likely File Touch Map

- `Docs/Execution/MVP-Acceptance-Matrix.md`
- `Docs/Execution/Manual-Test-SOP.md`
- `Docs/Execution/Beta-Acceptance-Checklist.md`
- `Packages/AtlasProtocol/`
- `Packages/AtlasApplication/`
- `Packages/AtlasInfrastructure/`
- `Packages/AtlasFeaturesApps/`
- `Apps/AtlasApp/`
- test targets under `Packages/` or `Testing/`

## Dependencies

- `D-004` MVP scope freeze
- `D-006` structured worker command surface and local persistence
- `D-009` execution capability honesty
- `D-011` versioned workspace state and recovery payload compatibility
- current `Apps`, `History`, and `Recovery` protocol and UI surfaces

## Non-Goals

- new non-MVP modules
- storage treemap or disk-visualization work
- menu bar features
- automation or daemon-style cleanup
- claiming full uninstall parity with broader tools where Atlas lacks proof

## Success Criteria

- supported fixture apps produce a consistent evidence story across preview, completion, and history
- restore behavior either refreshes app evidence or shows explicit stale evidence
- unsupported or ambiguous artifacts remain clearly labeled
- the next coding session can begin with `ATL-251` immediately and does not require another planning pass

## Known Risks

- the evidence model may drift across preview, completion, and history if category rules are not frozen early
- restore flows may display stale footprint evidence if refresh behavior is left implicit
- fixture coverage may become too narrow and accidentally optimize for only happy-path apps

## Execution Outputs

- [Apps-Evidence-Fixture-Baseline-2026-03-24.md](./Apps-Evidence-Fixture-Baseline-2026-03-24.md)
- [Apps-Evidence-Gate-Review-2026-03-24.md](./Apps-Evidence-Gate-Review-2026-03-24.md)
- updated acceptance and SOP docs in `MVP-Acceptance-Matrix.md`, `Manual-Test-SOP.md`, and `Beta-Acceptance-Checklist.md`

## Ready-To-Start Checklist

- [x] fixture matrix drafted
- [x] evidence rubric drafted
- [x] file-touch map reviewed
- [x] acceptance owner confirmed
- [x] restore refresh assumptions documented
