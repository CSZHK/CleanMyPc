# Selective Parity Week — 2026-03-23

## Context

Atlas now has a documented competitive strategy:

- keep MVP frozen
- preserve trust as the primary moat
- selectively close the most visible comparison gaps against `Mole`, `Tencent Lemon Cleaner`, and `Pearcleaner`

This week plan turns that strategy into the next development-ready execution window.

Related docs:

- [Open-Source-Competitor-Research-2026-03-21.md](./Open-Source-Competitor-Research-2026-03-21.md)
- [Competitive-Strategy-Plan-2026-03-21.md](./Competitive-Strategy-Plan-2026-03-21.md)
- [ROADMAP.md](../ROADMAP.md)

## Planned Window

- `2026-03-23` to `2026-03-27`

## Goal

Prepare Atlas's next coding phase with a strict mainline order so development starts on the highest-pressure competitive surfaces first and does not drift into premature release work:

- `EPIC-A` `Apps` evidence execution against `Pearcleaner` and `Lemon`
- `EPIC-B` `Smart Clean` safe coverage expansion against `Mole` and `Lemon`
- `EPIC-C` `Recovery` payload hardening
- `EPIC-D` release readiness only after the product-path epics stabilize

## Scope

Stay inside frozen MVP:

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Recovery`
- `Permissions`
- `Settings`

Do not expand into:

- `Storage treemap`
- `Menu Bar`
- `Automation`
- duplicate-file or similar-photo cleanup as new Atlas modules
- privacy-cleaning as a new standalone module

## Sequencing Rule

Execute the next mainline epics in this order only:

1. `EPIC-A` Apps Evidence Execution
2. `EPIC-B` Smart Clean Safe Coverage Expansion
3. `EPIC-C` Recovery Payload Hardening
4. `EPIC-D` Release Readiness

Why this order:

- the clearest competitive comparison pressure is already concentrated in `Apps` and `Smart Clean`
- the release chain is mostly working in pre-signing form
- public release remains blocked by missing signing materials, not by packaging mechanics

## Must Deliver

- A concrete fixture-backed baseline for `EPIC-A` uninstall evidence work
- One implementation-ready plan for the first `Apps` evidence coding slice
- A bounded target list for the next `Smart Clean` safe roots after `Apps`
- Updated acceptance criteria for `Apps`, `Smart Clean`, and `Recovery`
- Updated release-facing beta checklist so release work stays downstream of the product-path epics

## Backlog Mapping

- `ATL-251` Define the fixture app baseline for mainstream and developer-heavy uninstall scenarios
- `ATL-252` Make `Apps` preview, completion, and history render the same uninstall evidence model end to end
- `ATL-253` Define the restore-triggered app-footprint refresh policy and stale-evidence behavior after recovery
- `ATL-254` Script the manual acceptance flow for uninstall evidence, restore, and post-restore refresh verification
- `ATL-256` Define the next batch of high-confidence safe roots outside app containers and freeze the no-go boundaries
- `ATL-257` Stabilize `review-only` vs `executable` boundary metadata and UI cues across scan, review, execute, completion, and history
- `ATL-261` Freeze the recovery payload schema, versioning rules, and compatibility contract
- `ATL-266` Make `full-acceptance` a routine gate on the candidate build instead of a one-off release exercise

## Day Plan

- `Day 1`
  - freeze the `EPIC-A -> EPIC-D` execution order
  - finalize the fixture app baseline and non-go boundaries for the first `Apps` slice
- `Day 2`
  - define the cross-surface uninstall evidence model for preview, completion, and history
  - confirm restore-refresh expectations and acceptance criteria for `Apps`
- `Day 3`
  - write the detailed implementation plan for the first `Apps` coding slice
  - identify likely file-touch map and contract-test map
- `Day 4`
  - define the next `Smart Clean` safe roots and the `review-only` vs `executable` boundary rules
  - align roadmap, risks, and acceptance docs with the ordered epic sequence
- `Day 5`
  - hold an internal doc gate for development readiness
  - confirm the next coding session can begin with `EPIC-A` and without another sequencing pass

## Owner Tasks

- `Product Agent`
  - keep parity work bounded to visible comparison pressure only
  - reject backlog inflation that does not strengthen the frozen MVP
- `UX Agent`
  - define visible trust cues for supported, unsupported, and review-only actions
  - keep Atlas's UI difference legible against broader cleaner tools
- `Mac App Agent`
  - identify concrete UI surfaces that must change in `Smart Clean`, `Apps`, `History`, and completion states
- `Core Agent`
  - define the preview taxonomy and structured evidence that the UI can actually render
- `System Agent`
  - define which additional safe cleanup classes are realistic next targets for `Smart Clean`
- `QA Agent`
  - define the fixture set, comparison scenarios, and contract-style checks
- `Docs Agent`
  - keep strategy, acceptance, roadmap, and release-check documents aligned

## Validation Plan

### Planning Validation

- every new task maps to existing MVP surfaces
- every new acceptance criterion is testable
- every parity goal has an explicit competitor reference and an explicit Atlas non-goal

### Readiness Validation

- at least one implementation-ready plan exists for the next coding slice
- acceptance matrix and beta checklist reflect the new competitive gates
- no document implies that Atlas is reopening deferred scope

## Exit Criteria

- selective parity work is expressed as tasks, acceptance, and validation rather than just strategy prose
- `Smart Clean` and `Apps` both have explicit competitor-driven targets
- next coding session can start on `EPIC-A` without another planning pass

## Known Blockers

- signed public beta remains blocked by missing Apple release credentials
- `Smart Clean` breadth still has to stay subordinate to execution honesty
- `Apps` depth work must remain bounded by what Atlas can safely prove and recover
- release readiness still cannot close the public-distribution gap until Apple signing materials exist
