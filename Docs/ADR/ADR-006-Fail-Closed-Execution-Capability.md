# ADR-006: Fail-Closed Execution Capability

## Status

Accepted

## Context

Atlas currently mixes real scanning with scaffold/state-based execution in some flows, especially `Smart Clean`. This creates a user trust gap: the product can appear to have cleaned disk space even when a subsequent real scan rediscovers the same data.

The worker selection path also allowed silent fallback from XPC to the scaffold worker, which could mask infrastructure failures and blur the line between real execution and development fallback behavior.

## Decision

- Release-facing execution paths must fail closed when real execution capability is unavailable.
- Silent fallback from XPC to the scaffold worker is opt-in for development only.
- `Smart Clean` scan must reject when the upstream scan adapter fails, instead of silently fabricating findings from scaffold data.
- `Smart Clean` execute must reject while only state-based execution is available, but may execute a real Trash-based path for structured safe targets.
- Recovery may physically restore targets when structured trash-to-original mappings are available.

## Consequences

- Users get a truthful failure instead of a misleading success.
- Development and tests can still opt into scaffold fallback and state-only execution explicitly.
- `Smart Clean` execute now supports a partial real execution path for structured safe targets.
- The system now carries structured executable targets and `scan -> execute -> rescan` contract coverage for that subset.
- Broader Smart Clean categories and full physical recovery coverage still need follow-up implementation.

## Alternatives Considered

- Keep silent fallback and state-only execution — rejected because it misrepresents execution capability.
- Run `bin/clean.sh` directly for plan execution — rejected because the current upstream command surface is not scoped to the reviewed Atlas plan and would bypass recovery-first guarantees.
- Hide the execute button only in UI — rejected because the trust problem exists in the worker boundary, not only the presentation layer.
