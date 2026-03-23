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

Prepare Atlas's next coding phase so that development can start immediately on the two highest-pressure competitive surfaces:

- `Smart Clean` selective parity against `Mole` and `Lemon`
- `Apps` depth and uninstall trust against `Pearcleaner` and `Lemon`

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

## Must Deliver

- A concrete competitor-pressure matrix for `Smart Clean` and `Apps`
- A fixture-backed validation plan for uninstall depth and supported cleanup classes
- One implementation-ready plan for the first selective-parity coding slice
- Updated acceptance criteria for `Smart Clean` and `Apps`
- Updated release-facing beta checklist so validation reflects competitive trust requirements

## Backlog Mapping

- `ATL-211` Expand real `Smart Clean` execute coverage for top safe target classes most likely compared to `Mole` and `Lemon`
- `ATL-214` Make history and completion states reflect real side effects only
- `ATL-226` Build a competitor-pressure matrix for `Apps` using representative `Pearcleaner` and `Lemon` uninstall scenarios
- `ATL-227` Expand uninstall preview taxonomy and leftover evidence for supported app footprint categories
- `ATL-228` Surface recoverability, auditability, and supported-vs-review-only cues directly in the `Apps` flow
- `ATL-229` Validate uninstall depth on mainstream and developer-heavy fixture apps

## Day Plan

- `Day 1`
  - finalize competitor-pressure matrix
  - freeze non-goals and no-go boundaries for selective parity work
- `Day 2`
  - define fixture app set and Smart Clean target-class benchmark set
  - confirm acceptance and validation expectations
- `Day 3`
  - write the detailed implementation plan for the first coding slice
  - identify likely file-touch map and contract-test map
- `Day 4`
  - align beta checklist and MVP acceptance matrix with the selective-parity strategy
  - verify risks and roadmap still match
- `Day 5`
  - hold an internal doc gate for development readiness
  - confirm the next coding session can begin without planning gaps

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
- next coding session can start without another planning pass

## Known Blockers

- signed public beta remains blocked by missing Apple release credentials
- `Smart Clean` breadth still has to stay subordinate to execution honesty
- `Apps` depth work must remain bounded by what Atlas can safely prove and recover
