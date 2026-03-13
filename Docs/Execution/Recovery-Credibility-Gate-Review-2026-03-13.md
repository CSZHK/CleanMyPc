# Recovery Credibility Gate Review

## Gate

- `Recovery Credibility`

## Review Date

- `2026-03-13`

## Scope Reviewed

- `ATL-221` implement physical restore for file-backed recoverable actions where safe
- `ATL-222` validate shipped restore behavior on real file-backed test cases
- `ATL-223` narrow README, in-app, and release-note recovery claims if needed
- `ATL-224` freeze recovery contract and acceptance evidence
- `ATL-225` recovery credibility gate review

## Readiness Checklist

- [x] Required P0 tasks complete
- [x] Docs updated
- [x] Risks reviewed
- [x] Open questions below threshold
- [x] Next-stage inputs available

## Evidence Reviewed

- `Docs/Protocol.md`
- `Docs/Execution/Smart-Clean-Execution-Coverage-2026-03-09.md`
- `Docs/Execution/Smart-Clean-QA-Checklist-2026-03-09.md`
- `Docs/Execution/Smart-Clean-Manual-Verification-2026-03-09.md`
- `Docs/Execution/Recovery-Contract-2026-03-13.md`
- `README.md`
- `README.zh-CN.md`
- `Packages/AtlasInfrastructure/Tests/AtlasInfrastructureTests/AtlasInfrastructureTests.swift`
- `Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings`
- `Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings`

## Automated Validation Summary

- `swift test --package-path Packages --filter AtlasInfrastructureTests` — pass
- `swift test --package-path Packages --filter AtlasApplicationTests` — pass
- `swift test --package-path Packages` — pass

## Gate Assessment

### ATL-221 Physical Restore Surface

- File-backed recovery items now restore physically when Atlas recorded `restoreMappings` from a real Trash move.
- Supported direct-trash targets restore back to their original on-disk path.
- Protected app-bundle targets restore through the helper-backed path instead of claiming an unproven direct move.
- Restore remains fail-closed when the source, destination, or capability contract is not satisfied.

### ATL-222 Shipped Restore Evidence

- Automated tests now cover both proven physical restore classes:
  - direct-trash file-backed Smart Clean targets
  - helper-backed app uninstall targets
- State-only recovery remains explicitly covered so Atlas does not regress into overclaiming physical restore.
- Mixed restore summaries are covered so a batch containing both kinds of items stays truthful.
- Expired recovery items are now covered as a fail-closed path and are pruned from active recovery state.
- Restore destination conflicts now return a stable restore-specific rejection instead of being reported as generic success.

### ATL-223 Claim Audit

- README and localized in-app strings already reflect the narrowed recovery promise.
- No new copy narrowing was required in this slice.
- This gate freezes a release-note-safe wording set in `Docs/Execution/Recovery-Contract-2026-03-13.md` so future release notes cannot overstate restore behavior.

### ATL-224 Contract Freeze

- The recovery contract is now explicit, evidence-backed, and tied to shipped protocol fields and worker behavior.
- The contract distinguishes physical restore from Atlas-only state rehydration and documents the exact failure conditions, including expiry and destination conflicts.

## Remaining Limits

- Physical restore is still partial and depends on supported `restoreMappings`.
- Older or unstructured recovery items still restore Atlas state only.
- Broader restore coverage, including additional protected or system-managed targets, must not be described as shipped until new allowlist and QA evidence exist.

## Decision

- `Pass with Conditions`

## Conditions

- Release-facing copy must continue to use the frozen wording in `Docs/Execution/Recovery-Contract-2026-03-13.md`.
- Any future restore-surface expansion must add automated proof for the new target class before copy is widened.
- Candidate-build QA should still rerun the manual restore checklist on packaged artifacts before external distribution.

## Follow-up Actions

- Reuse the frozen recovery contract in future release notes and internal beta notices.
- Add new restore targets only after allowlist review, helper-path review, and contract tests land together.
- Re-run packaged-app manual restore verification when signed distribution work resumes.
