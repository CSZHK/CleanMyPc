# Smart Clean Safe Coverage Slice — 2026-03-24

## Goal

Formalize the next batch of high-confidence Smart Clean roots outside app containers without widening into higher-risk cleanup classes.

## Scope

This slice covers only user-owned developer and CLI cache roots that already fit Atlas's current Trash-backed recovery model:

- `~/.swiftpm/cache/*`
- `~/.cache/swift-package-manager/*`
- `~/.pytest_cache/*`
- `~/.aws/cli/cache/*`

## Why These Roots

- They are user-owned and sit outside app containers.
- They are cache-oriented rather than primary user data.
- They can be removed and physically restored through the current Trash-backed model.
- They deepen developer-aware cleanup coverage without reopening deferred scope or broader system cleaning.

## No-Go Boundaries

Do not expand this slice into:

- `Group Containers`
- generic `Library/Application Support`
- package-manager source or dependency stores that may contain primary working state
- `SourcePackages/checkouts`
- `Homebrew` as a new management surface
- privacy-cleaning or non-MVP modules

## Expected User-Facing Behavior

- Supported findings under these roots appear as directly executable Smart Clean actions.
- Unsupported roots still downgrade to `review-only` / inspection states instead of being presented as executable.
- Executed items under these roots satisfy `scan -> execute -> rescan`.

## Validation

- contract tests prove support detection for each root above
- at least one root in this slice proves `scan -> execute -> rescan`
- release-facing coverage docs list these roots explicitly

## Exit Criteria

- the slice is documented
- support detection is covered by automated tests
- one root proves end-to-end execution and rescan improvement
- acceptance docs reflect the new supported fixture options
