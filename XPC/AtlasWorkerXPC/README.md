# AtlasWorkerXPC

## Responsibility

- Non-privileged task orchestration
- Progress streaming
- Adapter invocation
- Helper-client handoff for allowlisted actions
- Result aggregation and persistence

## Current Implementation

- The XPC service hosts a real `NSXPCListener.service()` entry point.
- Requests cross the worker boundary as structured `Data` payloads that encode Atlas protocol envelopes and results.
- The service injects health, Smart Clean, and local app-inventory adapters.
- Release builds rely on bundled `MoleRuntime` resources for upstream shell-based health and clean workflows.
- The service can invoke the packaged or development helper executable through `AtlasPrivilegedHelperClient`.
- Direct-distribution app runs default to the same real worker implementation in-process; use `ATLAS_PREFER_XPC_WORKER=1` to force the bundled XPC path for runtime validation.
