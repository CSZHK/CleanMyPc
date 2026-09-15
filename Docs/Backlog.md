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
- `EPIC-A` Apps Evidence Execution
- `EPIC-B` Smart Clean Safe Coverage Expansion
- `EPIC-C` Recovery Payload Hardening
- `EPIC-D` Release Readiness
- `EPIC-E` Calm Ledger Frontend Redesign (non-mainline; runs in EPIC-D blockage window per D-012; UI-automation baseline ATL-267 must land AFTER this merges)

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
- `Superseded` — the live post-hardening epic sequence now lives in `Current Mainline Priority Order` below.

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
- Map competitor pressure from `Mole`, `Lemon`, and `Pearcleaner` into frozen-MVP parity work only

#### Next

- Expand real `Smart Clean` execute coverage for the highest-value safe targets most likely compared to `Mole` and `Lemon`
- Add stronger `scan -> execute -> rescan` contract coverage
- Implement physical restore for file-backed recoverable actions, or narrow product claims
- Freeze recovery-related copy only after behavior is proven
- Deepen the `Apps` module against the most obvious `Pearcleaner` and `Lemon` comparison points without expanding beyond MVP

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

- `ATL-211` Expand real `Smart Clean` execute coverage for top safe target classes most likely compared to `Mole` and `Lemon` — `System Agent`
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

#### Release Phase 4: Apps Competitive Depth

- `ATL-226` Build a competitor-pressure matrix for `Apps` using representative `Pearcleaner` and `Lemon` uninstall scenarios — `Product Agent` + `QA Agent`
- `ATL-227` Expand uninstall preview taxonomy and leftover evidence for supported app footprint categories — `Core Agent` + `Mac App Agent`
- `ATL-228` Surface recoverability, auditability, and supported-vs-review-only cues directly in the `Apps` flow — `UX Agent` + `Mac App Agent`
- `ATL-229` Validate uninstall depth on mainstream and developer-heavy fixture apps — `QA Agent`
- `ATL-230` Apps competitive depth gate review — `Product Agent`

#### Conditional Release Phase 5: Signed Distribution and External Beta

- `ATL-231` Obtain Apple release signing credentials — `Release Agent`
- `ATL-232` Pass `signing-preflight.sh` on the release machine — `Release Agent`
- `ATL-233` Produce signed and notarized native artifacts — `Release Agent`
- `ATL-234` Validate signed DMG and PKG install on a clean machine — `QA Agent`
- `ATL-235` Run a trusted hardware-diverse signed beta cohort — `Product Agent`
- `ATL-236` Triage public-beta issues before any GA candidate naming — `Product Agent`

#### Launch Surface Phase 6: Landing Page and Domain

- `ATL-241` Finalize landing-page PRD, CTA policy, and bilingual information architecture — `Product Agent`
- `ATL-242` Design and implement the marketing site in `Apps/LandingSite/` — `Mac App Agent`
- `ATL-243` Add GitHub Pages deployment workflow and environment protection — `Release Agent`
- `ATL-244` Bind and verify a dedicated custom domain with HTTPS enforcement — `Release Agent`
- `ATL-245` Surface release-channel state, download guidance, and prerelease install help on the page — `UX Agent`
- `ATL-246` Add privacy-respecting analytics and launch QA for desktop/mobile — `QA Agent`

## Current Mainline Priority Order

### Current Status

- `Complete` — internal beta hardening established the current execution-honesty baseline.
- `Complete` — `EPIC-A` Apps Evidence Execution, `EPIC-B` Smart Clean Safe Coverage Expansion, and `EPIC-C` Recovery Payload Hardening all delivered in the v1.0.8 stable baseline (confirmed by `Docs/product/next-stage-product-goals-2026-06.md`: all MVP modules production-ready, 377 tests green).
- `Open` — `EPIC-E` Calm Ledger Frontend Redesign in progress on `redesign/calm-ledger`.
- `Blocked` — final public-signing work still depends on `Developer ID` and notarization materials, so release mechanics are not the immediate product-path blocker.

### Order Rule

Execute the next mainline epics in this order only:

1. `EPIC-A` Apps Evidence Execution — **Done** (v1.0.8)
2. `EPIC-B` Smart Clean Safe Coverage Expansion — **Done** (v1.0.8)
3. `EPIC-C` Recovery Payload Hardening — **Done** (v1.0.8)
4. `EPIC-D` Release Readiness — blocked on signing credentials

Reason:

- the clearest competitive differentiation pressure is in `Apps` and `Smart Clean`
- the current release chain is already mostly working in pre-signing form
- the gating blocker for public release remains missing signing materials, not packaging mechanics

### Epics

- `EPIC-A` Apps Evidence Execution
- `EPIC-B` Smart Clean Safe Coverage Expansion
- `EPIC-C` Recovery Payload Hardening
- `EPIC-D` Release Readiness

### Now / Next / Later

#### Now

- `EPIC-E` Calm Ledger Redesign — M0 governance + M1 token layer in progress on `redesign/calm-ledger` (interrupt protocol: design spec §0.3)

#### Next

- `EPIC-D` Release Readiness (unblocks on Apple signing credentials)

#### Later

- Phase 2 product expansion (see `Docs/product/next-stage-product-goals-2026-06.md`), contingent on the redesign merge and EPIC-D release path

### Seed Issues

#### EPIC-A: Apps Evidence Execution

- `ATL-251` Define the fixture app baseline for mainstream and developer-heavy uninstall scenarios — `QA Agent`
- `ATL-252` Make `Apps` preview, completion, and history render the same uninstall evidence model end to end — `Core Agent` + `Mac App Agent`
- `ATL-253` Define the restore-triggered app-footprint refresh policy and stale-evidence behavior after recovery — `Core Agent` + `System Agent`
- `ATL-254` Script the manual acceptance flow for uninstall evidence, restore, and post-restore refresh verification — `QA Agent`
- `ATL-255` Apps evidence execution gate review — `Product Agent`

#### EPIC-A Execution Window

- Planned window: `2026-03-31` to `2026-04-11`
- Detailed execution doc: `Docs/Execution/Apps-Evidence-Execution-Plan-2026-03-24.md`

#### EPIC-A Ordered Execution Sequence

1. `ATL-251` Freeze the fixture matrix and benchmark rubric before implementation starts.
2. `ATL-252` Freeze one uninstall evidence model shared by preview, completion, and history.
3. `ATL-253` Freeze restore refresh and stale-evidence behavior before restore-facing polish.
4. `ATL-254` Turn the fixture flow into a repeatable acceptance script.
5. `ATL-255` Hold a trust-focused gate review before `EPIC-B` starts.

#### EPIC-B: Smart Clean Safe Coverage Expansion

- `ATL-256` Define the next batch of high-confidence safe roots outside app containers and freeze the no-go boundaries — `System Agent`
- `ATL-257` Stabilize `review-only` vs `executable` boundary metadata and UI cues across scan, review, execute, completion, and history — `Core Agent` + `Mac App Agent`
- `ATL-258` Add `scan -> execute -> rescan` evidence capture and contract coverage for the expanded safe roots — `QA Agent`
- `ATL-259` Implement and validate the next safe-root execution slice without widening into high-risk cleanup paths — `System Agent`
- `ATL-260` Smart Clean safe coverage gate review — `Product Agent`

#### EPIC-B Current Slice

- Detailed execution doc: `Docs/Execution/Smart-Clean-Safe-Coverage-Slice-2026-03-24.md`
- Boundary metadata doc: `Docs/Execution/Smart-Clean-Boundary-Metadata-Slice-2026-03-24.md`
- Current bounded roots:
  - `~/.swiftpm/cache/*`
  - `~/.cache/swift-package-manager/*`
  - `~/.pytest_cache/*`
  - `~/.aws/cli/cache/*`

#### EPIC-C: Recovery Payload Hardening

- `ATL-261` Freeze the recovery payload schema, versioning rules, and compatibility contract — `Core Agent`
- `ATL-262` Add migration and compatibility handling for older workspace and history state files — `Core Agent` + `System Agent`
- `ATL-263` Expand `History` detail evidence to show restore payload, conflict, expiry, and partial-restore outcomes — `Mac App Agent`
- `ATL-264` Add regression coverage for restore conflict, expired payload, and partial-restore scenarios — `QA Agent`
- `ATL-265` Recovery payload hardening gate review — `Product Agent`

#### EPIC-D: Release Readiness

- `ATL-266` Make `full-acceptance` a routine gate on the candidate build instead of a one-off release exercise — `QA Agent`
- `ATL-267` Stabilize UI automation for trust-critical `Overview`, `Smart Clean`, `Apps`, `History`, and `Recovery` flows — `QA Agent` + `Mac App Agent`
- `ATL-268` Freeze packaging, install, and launch smoke checks as repeatable release scripts — `Release Agent`
- `ATL-269` Switch from the pre-signing release chain to `Developer ID + notarization` once credentials are available — `Release Agent`
- `ATL-270` Release readiness gate review — `Product Agent`

## Process & Governance Backlog

Carry-forward items that are **product polish**, not process lessons — process lessons go to the
`Agent 教训台账` in `.claude/skills/iteration-governance/SKILL.md`. Entries here exist so that
"recorded" means "scheduled with an owner", not "written into a timeline and forgotten".

- ~~`ATL-271` Make Ledger export honor the active filter, or stop claiming it exports the current view~~ — **`Closed` 2026-09-15** by `REQ-copy-plain-language`: took the second branch of the "or" — `ledger.export.panel.detail` / `ledger.export.empty` no longer claim to export "currently visible" entries, because `LedgerFeatureView.saveReport()` passes the full `taskRuns` / `recoveryItems` sets. — `Mac App Agent`
- `ATL-272` Reclaim or explicitly retain the orphaned keys left by the ledger rename — `Docs Agent`
  > **Corrected 2026-09-15**: the count was recorded as **6** (`history.*` only). The copy gate's C5 dimension measured **310** unreferenced keys across the whole file (26% of 1166) — including entire dead surfaces (`apps.detail.*`, `apps.list.*`, `smartclean.status.*`). Re-scope before working it.
- `ATL-273` `apps.inventory.title`「应用清单」claims a checklist; the list is actually sorted by storage descending, so there is no column to reconcile against — `UX Agent`
- `ATL-274` 「待复核」carries three meanings at once (risk filter chip `risk.review`, risk section name, workflow stage name); the filtered count and the section count need not be equal, so users reasonably read them as the same set — `UX Agent`
- `ATL-275` Two different quantities on the Smart Clean screen both render as 「清理项」 with no unit hint: `smartclean.summary.findingCount` counts scan findings (can be hundreds), while `smartclean.stage.metric.selected` / `receipt.items.value` count plan steps. Users will see the two numbers disagree and suspect a defect — `UX Agent`
- `ATL-276` `fileorganizer.destination.title`「整理目标」renders above the path *value*, while the terminology baseline ruled that the settings section is 「整理目标」 and the path value is 「目标位置」 — the two names are effectively swapped. 「原始位置 / 目标位置」 adds a third near-synonym set — `UX Agent`
- ~~`ATL-277` Both READMEs (`README.md` / `README.zh-CN.md`) reference the same unsuffixed screenshots, so the Chinese README ships English screenshots~~ — **`Closed` 2026-09-15** by `REQ-readme-media-lifecycle`: the exporter now loops `AtlasLanguage.allCases` and emits `atlas-<stem>-{en,zh-Hans}.png`, and each README references its own language. The new six-dimension media gate has a `references` dimension that checks the language match, so it cannot silently regress. — `Docs Agent` + `Mac App Agent`
- `ATL-278` The landing site's own screenshot copies (`Apps/LandingSite/public/images/screenshots/`) are **stale** — byte-different from the regenerated `Docs/Media/README/` set, frozen at 2026-04…06 — while `DESIGN.md` documents the *icon* (not the screenshots) as sourced from `Docs/Media/README/`. `AGENTS.md` calls the site an independent toolchain, so it was deliberately left out of scope; it is the same defect class one directory over — `Mac App Agent` + `Docs Agent`
- `ATL-279` `cover.html` renders `Ledger` and `Ledger №`, but the signed terminology baseline (`REQ-copy-plain-language` P-1 / R-1) retired both in favour of `History` / `#`. **Not changed unilaterally**: it is marketing-art content, and the app still renders `№` at 5 Swift call sites, so changing the cover alone would create a *new* inconsistency. **Needs a product decision** — `Product Agent`
- `ATL-280` The media gate's drift fingerprint hashes **both `Localizable.strings` in full**, so ~77% of copy edits (≥277 of 1166 keys never render into a screenshot) force a needless re-export. Measured and documented as a deliberate over-fire. The precise alternative — have the exporter record the L10n keys it actually resolves and hash only those values — first needs a guard on "all L10n goes through `AtlasL10n`", which is a convention today, not a mechanism — `QA Agent`
- `ATL-281` README screenshots bake in a **pinned** render instant (2025-10-09), so the dates they show never track a release. Making them follow the version needs a build-time input into the exporter — `Mac App Agent`
- `ATL-282` `AtlasScreenshotShell` in `ReadmeAssetExporter.swift` is a hand-copied replica of `AppShellView`. The drift fingerprint catches "the original changed" but **cannot catch "the replica has diverged from the original"** — the replica is what gets rendered, so re-exporting reproduces the same stale shell and turns the gate green again. Root fix is reusing the real shell, rejected as decision D3 (needs an `AtlasAppModel` stub) — `Mac App Agent`

- `ATL-283` `fileorganizer.evidence.destination` ships as `Move target` in `en`, but `Docs/COPY_GUIDELINES.md:99` and the terminology baseline both rule **`Destination` 保留**. The value was changed by `a70bc1b` (that REQ's own plain-language rewrite). **Unresolved on purpose**: fixing it means either overruling a signed terminology decision or updating the glossary — a product call. It also sat behind a 3-week CI failure (see `ATL-284`) — `Docs Agent` + `Product Agent`
- `ATL-284` **Six** test files assert localized label text but never pin `AtlasL10n.currentLanguage`, so their result depends on SwiftPM's test execution order. Confirmed as the cause of a CI failure that ran 2026-08-26 → 2026-09-15 at `FileOrganizerEvidenceBuilderTests.swift:242/244` (passed locally, failed on CI purely on ordering). That one is now pinned; the other five are the same latent trap — `QA Agent`

- `ATL-285` The ruling that "GitHub-hosted runners have no Accessibility grant ⇒ the UI step *necessarily* takes the skip path" is **inference, not observation** — and it is now falsified. `atlas-acceptance.yml` had never succeeded (20+ runs red at step [1/13]), so step [11/13]'s real behaviour was never seen. Its first successful run (`#34984224153`, Xcode 26.6 / `macos-latest`) executed `AtlasAppUITests` and passed 11/11. Counter-evidence is recorded in `AGENTS.md`; the **decision** (keep the `ATLAS_ALLOW_UI_SKIP` escape hatch as defence) may still stand, but its stated rationale needs re-verifying and either updating or reaffirming — `QA Agent` + `Product Agent`
- `ATL-286` **Nothing watches the acceptance workflow.** It was red for 3+ weeks with no alert, no scheduled run, and no visible signal — so a newly wired gate (step [5/13]) could be "connected but never executing" indefinitely and read as protection. Needs either a notification on failure or a periodic health check — `QA Agent`

Source for `ATL-285`..`ATL-286`: the post-push CI investigation on 2026-09-15 (the acceptance workflow had been red for weeks at step [1/13], which meant the new README media gate never actually executed in CI).

Source for `ATL-283`..`ATL-284`: same investigation.

Source for `ATL-273`..`ATL-277`: the adversarial copy review run during `REQ-copy-plain-language` (2026-09-15). Each was traced back to source and confirmed, then deliberately left out of that REQ's scope. They are **pre-existing**, not regressions from it.

Source for `ATL-278`..`ATL-282`: the quality review run during `REQ-readme-media-lifecycle` (2026-09-15). Each was traced to source and confirmed, then deliberately left out of that REQ's scope. `ATL-279` and `ATL-281` need a human call; the rest are tooling work.

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
- Handoff notes follow the six-field delegation protocol — see `Templates/AGENT_HANDOFF_TEMPLATE.md`
