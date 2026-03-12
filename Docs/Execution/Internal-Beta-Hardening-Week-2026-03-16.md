# Internal Beta Hardening Week Plan

## Window

- `2026-03-16` to `2026-03-20`

## Goal

Convert the current internal-beta candidate into a more truthful and defensible build by completing clean-machine validation, tightening first-run confidence, and strengthening the real `Smart Clean` execution evidence for the most valuable safe targets.

## Scope

Keep work inside the frozen MVP modules:

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
- signed public beta work

## Must Deliver

- Clean-machine bilingual QA for first launch, language switching, install path, `Smart Clean`, `Apps`, and `History/Recovery`
- Fresh-state verification using a new workspace-state file and the latest packaged build
- One concrete increment in real `Smart Clean` execute coverage for high-value safe targets
- Stronger `scan -> execute -> rescan` verification for supported `Smart Clean` paths
- A current recovery-boundary note that distinguishes physical restore from model-only restore

## Backlog Mapping

- `ATL-203` Run bilingual manual QA on a clean machine
- `ATL-204` Validate fresh-state first launch from packaged artifacts
- `ATL-211` Expand real `Smart Clean` execute coverage for top safe target classes
- `ATL-213` Add stronger `scan -> execute -> rescan` contract coverage
- `ATL-214` Make history and completion states reflect real side effects only

## Day Plan

- `Day 1` Repackage the current build, run clean-machine bilingual QA, and log all trust or first-run defects
- `Day 2` Validate fresh-state behavior end to end, then close any launch, language, or stale-state regressions found on Day 1
- `Day 3` Implement the next safe-target execution increment for `Smart Clean`
- `Day 4` Add or tighten `scan -> execute -> rescan` coverage and verify history/completion summaries only claim real side effects
- `Day 5` Re-run focused verification, update execution docs, and hold an internal hardening gate review

## Owner Tasks

- `Product Agent`
  - keep execution hardening inside frozen MVP scope
  - decide whether any newly discovered recovery wording needs to narrow further before the next build
- `UX Agent`
  - review first-run, failure, and restore-adjacent wording on the validating build
  - flag any UI text that still implies universal physical restore or universal direct execution
- `Mac App Agent`
  - close first-run and state-presentation issues from clean-machine QA
  - keep `Smart Clean` failure and completion surfaces aligned with real worker outcomes
- `System Agent`
  - extend real `Smart Clean` execution support for the selected safe target classes
  - preserve fail-closed behavior for unsupported targets
- `Core Agent`
  - help carry executable structured targets and result summaries through the worker/application path
- `QA Agent`
  - run clean-machine validation and maintain the issue list
  - add and rerun `scan -> execute -> rescan` verification
- `Docs Agent`
  - update execution notes and recovery-boundary wording when evidence changes

## Validation Plan

### Manual

- Install the latest packaged build on a clean machine
- Verify default app language and switching to `English`
- Verify fresh-state launch with a new workspace-state file
- Run `Smart Clean` scan, preview, execute, and rescan for the supported safe-path fixture
- Verify `History` / `Recovery` wording still matches actual restore behavior

### Automated

- `swift test --package-path Packages`
- `swift test --package-path Apps`
- focused `scan -> execute -> rescan` coverage for the newly supported safe targets
- `./scripts/atlas/full-acceptance.sh` after implementation work lands

## Exit Criteria

- Clean-machine QA is complete and documented
- Fresh-state launch behavior is verified on the latest packaged build
- At least one new high-value safe target class has real `Smart Clean` execution support
- `scan -> execute -> rescan` evidence exists for the newly supported path
- No user-facing copy in the validating build overclaims physical restore or direct execution
- Week-end gate can either pass or fail with a short explicit blocker list

## Known Blockers

- Public release work remains blocked by missing Apple signing and notarization credentials
- Recovery still requires explicit wording discipline wherever physical restore is not yet guaranteed
