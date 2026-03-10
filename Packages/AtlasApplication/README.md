# AtlasApplication

## Responsibility

- Use cases and orchestration interfaces
- Structured application-layer coordination between the app shell and worker boundary

## Planned Use Cases

- `StartScan`
- `PreviewPlan`
- `ExecutePlan`
- `RestoreItems`
- `InspectPermissions`

## Current Scaffold

- `AtlasWorkspaceController` turns structured worker responses into app-facing scan, preview, and permission outputs.
- `AtlasWorkerServing` defines the worker boundary without leaking UI concerns into infrastructure.
