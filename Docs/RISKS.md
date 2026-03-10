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
- Mitigation: Validate packaging flow before feature-complete milestone. Current repo now includes native build/package scripts and CI workflow, but signing and notarization still depend on release credentials.

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
