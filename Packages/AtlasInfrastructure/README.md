# AtlasInfrastructure

## Responsibility

- Persistence
- Logging and audit events
- Permission inspection
- Process, helper, and XPC transport support
- Worker-boundary orchestration for MVP flows

## Current Implementation

- `AtlasWorkspaceRepository` persists the workspace snapshot, current plan, and settings as local JSON state.
- `AtlasScaffoldWorkerService` now backs scan, preview, execute, restore, apps, uninstall, and settings flows through structured protocol requests.
- `AtlasPermissionInspector` performs best-effort macOS permission checks for Full Disk Access, Accessibility, and Notifications.
- `AtlasPrivilegedHelperClient` invokes the allowlisted helper executable using structured JSON payloads.
- `AtlasXPCWorkerClient` and `AtlasXPCListenerDelegate` provide the real app-to-worker transport boundary using `NSXPCConnection` with structured `Data` payloads.
- `AtlasPreferredWorkerService` prefers the bundled XPC service and falls back to the in-process worker when needed.
- `AtlasAuditStore` records audit-friendly task events.
