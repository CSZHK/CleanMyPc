# Smart Clean QA Checklist — 2026-03-09

## Goal

Provide a focused acceptance checklist for validating the current `Smart Clean` real-execution subset and physical recovery path.

## Preconditions

- Use a local machine where `Smart Clean` scan can run successfully
- Start from a fresh or known workspace-state file when possible
- Prefer disposable cache/test paths under the current user home directory

## Test Matrix

### 1. Real scan still works

- [ ] Run `Smart Clean` scan
- [ ] Confirm the page shows a non-empty cleanup plan for at least one supported target
- [ ] Confirm the plan shows `Estimated Space` / `预计释放空间`

Expected:
- Scan completes successfully
- The current cleanup plan is generated from real findings

### 2. Real execution for safe target

Recommended sample targets:
- a disposable file under `~/Library/Caches/...`
- a disposable `__pycache__` directory
- a disposable file under `~/Library/Developer/Xcode/DerivedData/...`

Steps:
- [ ] Create a disposable target under a supported path
- [ ] Run scan and confirm the target appears in the plan
- [ ] Run the plan
- [ ] Confirm the target disappears from its original path
- [ ] Confirm a recovery entry is created

Expected:
- Execution is accepted
- The file or directory is moved to Trash
- History and recovery both update

### 3. Scan → execute → rescan

- [ ] Run scan and note the item count / estimated space for the test target
- [ ] Run the plan for that target
- [ ] Run a fresh scan again

Expected:
- The previously executed target no longer appears in scan results
- Estimated space decreases accordingly
- The app does not rediscover the same target immediately unless the target still exists physically

### 4. Physical restore

- [ ] Select the recovery item created from the executed target
- [ ] Run restore
- [ ] Confirm the file or directory returns to its original path
- [ ] Run scan again if relevant

Expected:
- Restore succeeds
- The item reappears at the original path
- If the restored item still qualifies as reclaimable, a new scan can rediscover it

### 5. Unsupported target fails closed

Use an item that is scanned but not currently covered by the structured safe execution subset.

- [ ] Run scan until the unsupported item appears in the plan
- [ ] Attempt execution

Expected:
- Atlas rejects execution instead of claiming success
- The rejection reason explains that executable cleanup targets are unavailable or unsupported
- No misleading drop in reclaimable space is shown as if cleanup succeeded

### 6. Worker/XPC fallback honesty

- [ ] Simulate or observe worker unavailability in a development environment without `ATLAS_ALLOW_SCAFFOLD_FALLBACK=1`
- [ ] Attempt a release-facing execution action

Expected:
- Atlas surfaces a concrete failure
- It does not silently fall back to scaffold behavior and report success

## Regression Checks

- [ ] `Apps` uninstall still works for bundle removal
- [ ] Existing app/package tests remain green
- [ ] `clean.sh --dry-run` still starts and exports cleanup lists successfully

## Pass Criteria

A Smart Clean execution change is acceptable only if all of the following are true:

- supported targets are physically moved to Trash
- executed targets disappear on the next scan
- recovery can physically restore executed targets when mappings are present
- unsupported targets fail closed
- the UI does not imply broader execution coverage than what is actually implemented
