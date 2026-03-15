# Backlog

## Board Model

### Status

- `Backlog`
- `Ready`
- `In Progress`
- `In Review`
- `Blocked`
- `Done`
- `Frozen`

### Priority

- `P0` — required for MVP viability
- `P1` — important but can follow MVP
- `P2` — exploratory or future work

## MVP Scope

- `Overview`
- `Smart Clean`
- `Apps`
- `History`
- `Recovery`
- `Permissions`
- `Settings`

## Deferred to P1

- `Storage treemap`
- `Menu Bar`
- `Automation`

## Epics

- `EPIC-01` Brand and Compliance
- `EPIC-02` Information Architecture and Interaction Design
- `EPIC-03` Protocol and Domain Model
- `EPIC-04` App Shell and Engineering Scaffold
- `EPIC-05` Scan and Action Plan
- `EPIC-06` Apps and Uninstall
- `EPIC-07` History and Recovery
- `EPIC-08` Permissions and System Integration
- `EPIC-09` Quality and Verification
- `EPIC-10` Packaging, Signing, and Release
- `EPIC-16` Beta Stabilization and Execution Truthfulness
- `EPIC-17` Signed Public Beta Packaging
- `EPIC-18` Public Beta Feedback and Trust Closure
- `EPIC-19` GA Recovery and Execution Hardening
- `EPIC-20` GA Launch Readiness
- `EPIC-21` Marketing Site and Direct Distribution Landing Page

## Now / Next / Later

### Now

- Week 1 scope freeze
- Week 2 design freeze for core screens
- Week 3 architecture and protocol freeze

### Next

- Week 4 scaffold creation
- Week 5 scan pipeline
- Week 6 action-plan preview and execute path

### Later

- Week 7 apps flow
- Week 8 permissions, history, recovery
- Week 9 helper integration
- Week 10 hardening
- Week 11 beta candidate
- Week 12 release-readiness review

## Seed Issues

### Week 1

- `ATL-001` Freeze naming rules — `Product Agent`
- `ATL-002` Freeze MVP scope — `Product Agent`
- `ATL-003` Define goals and metrics — `Product Agent`
- `ATL-004` Start decision and risk log — `Product Agent`
- `ATL-005` Draft `IA v1` — `UX Agent`
- `ATL-006` Draft three core flows — `UX Agent`
- `ATL-007` Draft page-state matrix — `UX Agent`
- `ATL-008` Define domain models — `Core Agent`
- `ATL-009` Define protocol — `Core Agent`
- `ATL-010` Define task state and errors — `Core Agent`
- `ATL-011` Draft worker/helper boundary — `System Agent`
- `ATL-012` Draft permission matrix — `System Agent`
- `ATL-013` Audit upstream reusable capabilities — `Adapter Agent`
- `ATL-014` Report JSON adaptation blockers — `Adapter Agent`
- `ATL-017` Create acceptance matrix — `QA Agent`
- `ATL-019` Draft attribution docs — `Docs Agent`
- `ATL-020` Week 1 gate review — `Product Agent`

### Week 2

- `ATL-021` `Overview` high-fidelity design — `UX Agent`
- `ATL-022` `Smart Clean` high-fidelity design — `UX Agent`
- `ATL-023` `Apps` high-fidelity design — `UX Agent`
- `ATL-024` Permission explainer sheets — `UX Agent`
- `ATL-025` Freeze `Protocol v1.1` — `Core Agent`
- `ATL-026` Freeze persistence model — `Core Agent`
- `ATL-027` Draft worker XPC interface — `System Agent`
- `ATL-028` Draft helper allowlist — `System Agent`
- `ATL-029` Draft package and target graph — `Mac App Agent`
- `ATL-030` Draft navigation and state model — `Mac App Agent`
- `ATL-031` Draft scan adapter chain — `Adapter Agent`
- `ATL-032` Draft app-footprint adapter chain — `Adapter Agent`
- `ATL-034` MVP acceptance matrix v1 — `QA Agent`
- `ATL-036` Attribution file v1 — `Docs Agent`
- `ATL-037` Third-party notices v1 — `Docs Agent`
- `ATL-040` Week 2 gate review — `Product Agent`

### Week 3

- `ATL-041` Freeze `Architecture v1` — `Core Agent` + `System Agent`
- `ATL-042` Freeze `Protocol Schema v1` — `Core Agent`
- `ATL-043` Freeze error registry — `Core Agent`
- `ATL-044` Freeze task state machine — `Core Agent`
- `ATL-045` Freeze persistence model — `Core Agent`
- `ATL-046` Freeze worker XPC method set — `System Agent`
- `ATL-047` Freeze helper action allowlist — `System Agent`
- `ATL-048` Freeze helper validation rules — `System Agent`
- `ATL-049` Freeze app-shell route map — `Mac App Agent`
- `ATL-050` Freeze package dependency graph — `Mac App Agent`
- `ATL-052` Freeze scan adapter path — `Adapter Agent`
- `ATL-053` Freeze apps list adapter path — `Adapter Agent`
- `ATL-056` Draft contract test suite — `QA Agent`
- `ATL-060` Week 3 gate review — `Product Agent`

## Post-MVP Polish Track

### Current Status

- `Complete` — UI audit completed with explicit `P0 / P1 / P2` remediation directions in `Docs/Execution/UI-Audit-2026-03-08.md`.
- `Complete` — frozen MVP workflows are implemented end to end.
- `Complete` — post-MVP polish for trust, hierarchy, loading states, keyboard flow, and accessibility.
- `Complete` — Chinese-first bilingual localization framework with persisted app-language switching.
- `Open` — manual localization QA and release-signing/notarization remain as the main next steps.

### Focus

- Make the existing MVP feel safe, clear, and native before expanding scope.
- Prioritize first-use trust, smooth feedback, and visual consistency across the frozen MVP modules.
- Keep polish work inside `Overview`, `Smart Clean`, `Apps`, `History`, `Recovery`, `Permissions`, and `Settings`.

### Epics

- `EPIC-11` First-Run Activation and Permission Trust
- `EPIC-12` Smart Clean Explainability and Execution Confidence
- `EPIC-13` Apps Uninstall Confidence and Recovery Clarity
- `EPIC-14` Visual System and Interaction Consistency
- `EPIC-15` Perceived Performance and State Coverage

### Now / Next / Later

#### Now

- Run manual bilingual QA on a clean machine
- Validate first-launch behavior with a fresh workspace-state file
- Prepare signed packaging inputs if external distribution is needed

#### Next

- Add additional supported languages only after translation QA and copy governance are in place
- Revisit post-beta manual polish items that require human UX review rather than more structural engineering work
- Convert the current unsigned packaging flow into a signed and notarized release path

#### Later

- Extend localization coverage to future deferred modules when scope reopens
- Add localization linting or snapshot checks if the language matrix expands
- Revisit copy tone and translation review during release hardening

### Seed Issues

#### Polish Week 1

- `ATL-101` Audit state coverage for all MVP screens — `UX Agent`
- `ATL-102` Define polish scorecard and acceptance targets — `Product Agent`
- `ATL-103` Refresh shared design tokens and card hierarchy — `Mac App Agent`
- `ATL-104` Polish `Smart Clean` scan controls, preview hierarchy, and execution feedback — `Mac App Agent`
- `ATL-105` Polish `Apps` uninstall preview, leftovers messaging, and recovery cues — `Mac App Agent`
- `ATL-106` Rewrite trust-critical copy for permissions, destructive actions, and restore paths — `UX Agent`
- `ATL-107` Add loading, empty, error, and partial-permission states to the primary screens — `Mac App Agent`
- `ATL-108` Add narrow UI verification for first-run, scan, and uninstall flows — `QA Agent`
- `ATL-110` Polish Week 1 gate review — `Product Agent`

#### Polish Week 2

- `ATL-111` Tighten `Overview` information density and recommendation ranking — `UX Agent`
- `ATL-112` Improve `History` readability and restore confidence markers — `Mac App Agent`
- `ATL-113` Improve `Permissions` guidance for limited mode and just-in-time prompts — `UX Agent`
- `ATL-114` Normalize cross-screen action labels, confirmation sheets, and completion summaries — `Docs Agent`
- `ATL-115` Measure perceived latency and remove avoidable visual jumps in core flows — `QA Agent`
- `ATL-116` Polish Week 2 gate review — `Product Agent`

## Internal Beta Hardening Track

### Current Status

- `Complete` — frozen MVP is implemented and internally beta-ready.
- `Blocked` — release trust still depends on removing silent fallback and tightening execution/recovery honesty.
- `Dormant` — signed public beta work is inactive until Apple signing/notarization credentials exist.

### Focus

- Keep the roadmap inside the frozen MVP modules.
- Hard-fix execution truthfulness before any broader distribution plan resumes.
- Make recovery claims match shipped restore behavior.
- Keep signed public beta work as a conditional branch, not the active mainline.

### Epics

- `EPIC-16` Beta Stabilization and Execution Truthfulness
- `EPIC-17` Signed Public Beta Packaging
- `EPIC-18` Public Beta Feedback and Trust Closure
- `EPIC-19` GA Recovery and Execution Hardening
- `EPIC-20` GA Launch Readiness

### Now / Next / Later

#### Now

- Remove or gate silent fallback in release-facing execution flows
- Run bilingual manual QA on a clean machine
- Validate packaged first-launch behavior with a fresh state file
- Tighten release-facing copy where execution or recovery is overstated

#### Next

- Expand real `Smart Clean` execute coverage for the highest-value safe targets
- Add stronger `scan -> execute -> rescan` contract coverage
- Implement physical restore for file-backed recoverable actions, or narrow product claims
- Freeze recovery-related copy only after behavior is proven

#### Later

- Obtain Apple signing and notarization credentials
- Produce signed and notarized `.app`, `.dmg`, and `.pkg` artifacts
- Validate signed install behavior on a clean machine
- Run a small hardware-diverse public beta cohort only after signed distribution is available

### Seed Issues

#### Release Phase 1: Beta Stabilization

- `ATL-201` Remove or development-gate silent XPC fallback in release-facing execution flows — `System Agent`
- `ATL-202` Add explicit failure states when real worker execution is unavailable — `Mac App Agent`
- `ATL-203` Run bilingual manual QA on a clean machine — `QA Agent`
- `ATL-204` Validate fresh-state first launch from packaged artifacts — `QA Agent`
- `ATL-205` Narrow release-facing recovery and execution copy where needed — `UX Agent` + `Docs Agent`
- `ATL-206` Beta stabilization gate review — `Product Agent`

#### Release Phase 2: Smart Clean Execution Credibility

- `ATL-211` Expand real `Smart Clean` execute coverage for top safe target classes — `System Agent`
- `ATL-212` Carry executable structured targets through the worker path — `Core Agent`
- `ATL-213` Add stronger `scan -> execute -> rescan` contract coverage — `QA Agent`
- `ATL-214` Make history and completion states reflect real side effects only — `Mac App Agent`
- `ATL-215` Execution credibility gate review — `Product Agent`

#### Release Phase 3: Recovery Credibility

- `ATL-221` Implement physical restore for file-backed recoverable actions where safe — `System Agent`
- `ATL-222` Validate shipped restore behavior on real file-backed test cases — `QA Agent`
- `ATL-223` Narrow README, in-app, and release-note recovery claims if needed — `Docs Agent` + `Product Agent`
- `ATL-224` Freeze recovery contract and acceptance evidence — `Product Agent`
- `ATL-225` Recovery credibility gate review — `Product Agent`

#### Conditional Release Phase 4: Signed Distribution and External Beta

- `ATL-231` Obtain Apple release signing credentials — `Release Agent`
- `ATL-232` Pass `signing-preflight.sh` on the release machine — `Release Agent`
- `ATL-233` Produce signed and notarized native artifacts — `Release Agent`
- `ATL-234` Validate signed DMG and PKG install on a clean machine — `QA Agent`
- `ATL-235` Run a trusted hardware-diverse signed beta cohort — `Product Agent`
- `ATL-236` Triage public-beta issues before any GA candidate naming — `Product Agent`

#### Launch Surface Phase 5: Landing Page and Domain

- `ATL-241` Finalize landing-page PRD, CTA policy, and bilingual information architecture — `Product Agent`
- `ATL-242` Design and implement the marketing site in `Apps/LandingSite/` — `Mac App Agent`
- `ATL-243` Add GitHub Pages deployment workflow and environment protection — `Release Agent`
- `ATL-244` Bind and verify a dedicated custom domain with HTTPS enforcement — `Release Agent`
- `ATL-245` Surface release-channel state, download guidance, and prerelease install help on the page — `UX Agent`
- `ATL-246` Add privacy-respecting analytics and launch QA for desktop/mobile — `QA Agent`

## Definition of Ready

- Scope is clear and bounded
- Dependencies are listed
- Owner Agent is assigned
- Acceptance criteria are testable
- Deliverable format is known

## Definition of Done

- Acceptance criteria are satisfied
- Relevant docs are updated
- Decision log is updated if scope or architecture changed
- Risks and blockers are recorded
- Handoff notes are attached
