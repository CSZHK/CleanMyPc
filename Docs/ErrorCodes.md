# Error Codes

## Principles

- Use stable machine-readable codes.
- Map each code to a user-facing title, body, and next step.
- Separate recoverable conditions from fatal conditions.

## Registry

- `permission_denied`
- `permission_limited`
- `admin_required`
- `path_protected`
- `path_not_found`
- `action_not_allowed`
- `helper_unavailable`
- `execution_unavailable`
- `worker_crashed`
- `protocol_mismatch`
- `partial_failure`
- `task_cancelled`
- `restore_expired`
- `restore_conflict`
- `idempotency_conflict`

## Mapping Rules

- Use inline presentation for row-level issues.
- Use banners for limited access and incomplete results.
- Use sheets for permission and destructive confirmation flows.
- Use result pages for partial success, cancellation, and recovery outcomes.

## Format

- User-visible format recommendation: `ATLAS-<DOMAIN>-<NUMBER>`
- Example: `ATLAS-EXEC-004`
