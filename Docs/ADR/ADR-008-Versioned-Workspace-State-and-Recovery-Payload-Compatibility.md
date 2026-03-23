# ADR-008: Versioned Workspace State and Recovery Payload Compatibility

## Status

Accepted

## Context

Atlas persists a local workspace-state file and stores recovery payloads for both `Finding` and app uninstall flows. Those payloads have already evolved in place: app recovery entries gained uninstall evidence, and the active roadmap now explicitly calls for payload stability, older-state compatibility, and more trustworthy history behavior.

Without an explicit persistence envelope, Atlas can only rely on best-effort shape decoding. That makes future recovery hardening riskier and leaves migration implicit. The `Apps` flow also risks showing stale preview or stale footprint counts after restore unless restored app payloads are reconciled with fresh app inventory.

## Decision

- Atlas persists workspace state inside a versioned JSON envelope containing `schemaVersion`, `savedAt`, `snapshot`, `currentPlan`, and `settings`.
- Atlas continues to decode legacy top-level `AtlasWorkspaceState` files and rewrites them into the current envelope after a successful load when possible.
- `AppRecoveryPayload` carries an explicit `schemaVersion` and remains backward-compatible with the older raw-`AppFootprint` recovery payload shape.
- App restore flows clear stale uninstall preview state and refresh app inventory before the `Apps` surface reuses footprint counts.

## Consequences

- Atlas now has an explicit persistence contract for future migration work instead of relying on implicit shape matching alone.
- Older state files remain loadable while the repo transitions to the versioned envelope.
- App recovery payloads become safer to evolve because compatibility is now a stated requirement.
- The `Apps` surface becomes more trustworthy after restore because it no longer depends only on stale pre-uninstall preview state.

## Alternatives Considered

- Keep the unversioned top-level state file and rely on ad hoc per-type decoding: rejected because it scales poorly as recovery payloads evolve.
- Break compatibility and require a fresh state file: rejected because it damages trust in `History` and `Recovery`.
- Refresh app inventory only on explicit user action after restore: rejected because it leaves a visible stale-evidence gap in a trust-critical workflow.
