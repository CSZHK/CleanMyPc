# XPC

This directory contains XPC service targets for Atlas for Mac.

## Current Entry

- `AtlasWorkerXPC/` hosts the non-privileged worker service.
- The service wires in health, Smart Clean, app inventory, persistence, and helper-client integrations.
- `Package.swift` exposes the worker target for local builds and early integration verification.
