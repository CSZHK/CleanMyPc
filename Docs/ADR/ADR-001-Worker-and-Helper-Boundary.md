# ADR-001: Worker and Helper Boundary

## Status

Accepted

## Context

Atlas for Mac needs long-running scanning and cleanup operations, but must avoid running privileged or shell-oriented logic directly inside the UI process.

## Decision

- Use a non-privileged worker process for orchestration and progress streaming.
- Use a separate privileged helper for approved structured actions only.
- Disallow arbitrary shell passthrough from the UI.

## Consequences

- Better crash isolation
- Clearer audit boundaries
- More initial setup complexity
