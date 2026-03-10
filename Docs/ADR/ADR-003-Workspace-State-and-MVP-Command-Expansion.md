# ADR-003: Workspace State Persistence and MVP Command Expansion

## Status

Accepted

## Context

Atlas for Mac already had a native shell, worker transport, and upstream-backed adapters for health and Smart Clean dry runs, but several frozen MVP flows still depended on in-memory scaffold state. That left history, recovery, settings, and app uninstall behavior incomplete across launches and weakened the value of the worker boundary.

## Decision

- Persist a local JSON-backed workspace state for MVP.
- Store the latest workspace snapshot, current Smart Clean plan, and user settings together.
- Expand the structured worker protocol to cover missing frozen-scope flows: Smart Clean execute, recovery restore, apps list, app uninstall preview/execute, and settings get/set.
- Keep these flows behind the existing application/protocol/worker boundaries instead of adding direct UI-side mutations.

## Consequences

- History, recovery, app removal, and settings now survive beyond a single process lifetime.
- The UI can complete more of the MVP through stable worker commands without parsing or mutating raw script state.
- The protocol surface is larger and must stay synchronized with docs and tests.
- Local JSON persistence is acceptable for MVP, but future production hardening may require a more robust store.

## Alternatives Considered

- Keep all new flows in memory only — rejected because recovery and settings would reset across launches.
- Let the UI mutate app/history/settings state directly — rejected because it breaks the worker-first architecture.
- Introduce a database immediately — rejected because it adds complexity beyond MVP needs.
