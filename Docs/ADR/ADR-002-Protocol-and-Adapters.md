# ADR-002: Structured Protocol and Adapter Layer

## Status

Accepted

## Context

Existing upstream capabilities are terminal-oriented and not suitable as a direct contract for a native GUI.

## Decision

- Define a structured local JSON protocol.
- Wrap reusable upstream logic behind adapters.
- Keep UI components unaware of script or terminal output format.

## Consequences

- Faster GUI iteration
- Safer schema evolution
- Additional adapter maintenance cost
