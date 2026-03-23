# Risk Register

## R-001 XPC and Helper Complexity

- Impact: High
- Probability: Medium
- Owner: `System Agent`
- Risk: Worker/helper setup and privilege boundaries may delay implementation.
- Mitigation: Complete architecture and helper allowlist freeze before scaffold build.

## R-002 Upstream Adapter Instability

- Impact: High
- Probability: High
- Owner: `Adapter Agent`
- Risk: Existing upstream commands may not expose stable structured data.
- Mitigation: Add adapter normalization layer and rewrite hot paths if JSON mapping is brittle.

## R-003 Permission Friction

- Impact: High
- Probability: Medium
- Owner: `UX Agent`
- Risk: Aggressive permission prompts may reduce activation.
- Mitigation: Use just-in-time prompts and support limited mode.

## R-004 Recovery Trust Gap

- Impact: High
- Probability: Medium
- Owner: `Core Agent`
- Risk: Users may not trust destructive actions without clear rollback behavior.
- Mitigation: Prefer reversible actions and preserve detailed history.

## R-005 Scope Creep

- Impact: High
- Probability: High
- Owner: `Product Agent`
- Risk: P1 features may leak into MVP.
- Mitigation: Freeze MVP scope and require explicit decision-log updates for scope changes.

## R-006 Signing and Notarization Surprises

- Impact: High
- Probability: Medium
- Owner: `Release Agent`
- Risk: Helper signing or notarization may fail late in the schedule.
- Mitigation: Keep signed distribution off the active critical path until Apple release credentials exist. Once credentials are available, validate packaging flow before any public beta naming or broad external distribution.

## R-007 Experience Polish Drift

- Impact: High
- Probability: High
- Owner: `Mac App Agent`
- Risk: MVP screens may continue to diverge in spacing, CTA hierarchy, and state handling as teams polish pages independently.
- Mitigation: Route visual and interaction changes through shared design-system components before page-level tweaks land.

## R-008 Trust Gap in Destructive Flows

- Impact: High
- Probability: Medium
- Owner: `UX Agent`
- Risk: Users may still hesitate to run `Smart Clean` or uninstall actions if recovery, review, and consequence messaging stay too subtle.
- Mitigation: Make recoverability, risk level, and next-step guidance visible at decision points and in completion states.

## R-009 State Coverage Debt

- Impact: High
- Probability: Medium
- Owner: `QA Agent`
- Risk: Loading, empty, partial-permission, and failure states may feel unfinished even when the happy path is functional.
- Mitigation: Require state-matrix coverage for primary screens before additional visual polish is considered complete.


## R-010 Localization Drift

- Impact: Medium
- Probability: Medium
- Owner: `Docs Agent`
- Risk: Newly added Chinese and English strings may drift between UI, worker summaries, and future screens if copy changes bypass the shared localization layer.
- Mitigation: Keep user-facing shell copy in shared localization resources and require bilingual QA before release-facing packaging.

## R-011 Smart Clean Execution Trust Gap

- Impact: High
- Probability: High
- Owner: `System Agent`
- Risk: `Smart Clean` execution now supports a real Trash-based path for a safe subset of targets, but unsupported or unstructured findings still cannot be executed and must fail closed. Physical restore also remains partial and depends on structured recovery mappings.
- Mitigation: Add real Smart Clean execution targets and block release-facing execution claims until `scan -> execute -> rescan` proves real disk impact.

## R-012 Silent Worker Fallback Masks Execution Capability

- Impact: High
- Probability: Medium
- Owner: `System Agent`
- Risk: Silent fallback from XPC to the scaffold worker can make user-facing execution appear successful even when the primary worker path is unavailable.
- Mitigation: Restrict fallback to explicit development mode or surface a concrete error when real execution infrastructure is unavailable.

## R-013 Public Beta Coverage Blind Spot

- Impact: High
- Probability: Medium
- Owner: `QA Agent`
- Risk: When signing credentials eventually arrive, a public beta that is too small, too homogeneous, or too unstructured may miss install, permission, or cleanup regressions that only appear on different hardware, macOS states, or trust settings.
- Mitigation: Keep this as a conditional release risk. Use a deliberately hardware-diverse trusted beta cohort, require structured issue intake, and rerun clean-machine install and first-run validation before calling any signed build GA-ready.

## R-014 GA Recovery Claim Drift

- Impact: High
- Probability: Medium
- Owner: `Product Agent`
- Risk: GA release notes, README copy, or in-app messaging may overstate Atlas's recovery model before physical restore is actually shipped for file-backed recoverable actions.
- Mitigation: Treat recovery wording as a gated release artifact. Either ship physical restore for file-backed recoverable actions before GA or narrow all GA-facing recovery claims to the shipped behavior.

## R-015 Launch Surface Trust Drift

- Impact: High
- Probability: Medium
- Owner: `Product Agent`
- Risk: A future landing page or custom-domain launch surface may overstate release readiness, signed-install status, recovery behavior, or permission expectations relative to the actual downloadable build.
- Mitigation: Make release-channel state and install guidance dynamic, keep prerelease warnings visible, and gate launch-surface copy review with the same trust standards used for README and release materials.

## R-016 Competitive Breadth Perception Gap

- Impact: High
- Probability: High
- Owner: `Product Agent`
- Risk: Users comparing Atlas with `Mole` or `Tencent Lemon Cleaner` may conclude Atlas is cleaner in presentation but weaker in practical cleanup breadth if `Smart Clean` execution coverage stays too narrow or too invisible.
- Mitigation: Expand only the highest-value safe target classes inside frozen MVP, and make supported-vs-unsupported execution scope explicit in product copy and UI states.

## R-017 Apps Depth Comparison Gap

- Impact: High
- Probability: Medium
- Owner: `Mac App Agent`
- Risk: Users comparing Atlas with `Pearcleaner` or `Tencent Lemon Cleaner` may find the `Apps` module less credible if uninstall preview taxonomy, leftover visibility, and completion evidence remain too shallow.
- Mitigation: Add fixture-based uninstall benchmarking, deepen supported footprint categories, and surface recoverability/audit cues directly in the `Apps` flow.

## R-018 License Contamination From Competitor Reuse

- Impact: High
- Probability: Medium
- Owner: `Docs Agent`
- Risk: Competitive pressure may tempt reuse of code or assets from `Tencent Lemon Cleaner`, `GrandPerspective`, or GPL-constrained `Czkawka` components, creating license conflict with Atlas's shipping posture. `Pearcleaner` also remains unsuitable for monetized derivative reuse due `Commons Clause`.
- Mitigation: Treat these projects as product and technical references only, require explicit license review before adapting any third-party implementation, and prefer MIT-compatible upstream or original Atlas implementations for shipped code.

## R-019 Release-First Sequencing Drift

- Impact: High
- Probability: Medium
- Owner: `Product Agent`
- Risk: The team may over-rotate toward release mechanics because the packaging chain mostly works, even though the real public-release blocker is still missing signing materials and the sharper product pressure is in `Apps` and `Smart Clean`.
- Mitigation: Keep the active mainline order at `Apps -> Smart Clean -> Recovery -> Release`, and treat the `Developer ID + notarization` switch as the final convergence step once product-path evidence and credentials both exist.
