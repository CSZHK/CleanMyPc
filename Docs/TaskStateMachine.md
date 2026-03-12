# Task State Machine

## Task Types

- `scan`
- `execute_clean`
- `execute_uninstall`
- `restore`
- `inspect_permissions`
- `health_snapshot`

## Main States

- `draft`
- `submitted`
- `validating`
- `awaiting_permission`
- `queued`
- `running`
- `cancelling`
- `completed`
- `partial_failed`
- `failed`
- `cancelled`
- `expired`

## Terminal States

- `completed`
- `partial_failed`
- `failed`
- `cancelled`
- `expired`

## Core Transition Rules

- `draft -> submitted`
- `submitted -> validating`
- `validating -> awaiting_permission | queued | failed`
- `awaiting_permission -> queued | cancelled | failed`
- `queued -> running | cancelled`
- `running -> cancelling | completed | partial_failed | failed`
- `cancelling -> cancelled`

## Action Item States

- `pending`
- `running`
- `succeeded`
- `skipped`
- `failed`
- `cancelled`

## Guarantees

- Terminal states are immutable.
- Progress must not move backwards.
- Destructive tasks must be audited.
- Recoverable tasks must leave structured recovery entries until restored or expired.
- Repeated write requests must honor idempotency rules when those flows become externally reentrant.

## Current MVP Notes

- `scan` emits monotonic progress and finishes with a preview-ready plan when the upstream scan adapter succeeds; otherwise the request should fail rather than silently fabricate findings.
- `execute_clean` must not report completion in release-facing flows unless real cleanup side effects have been applied. Fresh preview plans now carry structured execution targets, and unsupported or unstructured targets should fail closed.
- `execute_uninstall` removes an app from the current workspace view and creates a recovery entry.
- `restore` can physically restore items when structured recovery mappings are present, and can still rehydrate a `Finding` or an `AppFootprint` into Atlas state from the recovery payload.
- User-visible task summaries and settings-driven text should reflect the persisted app-language preference when generated.
