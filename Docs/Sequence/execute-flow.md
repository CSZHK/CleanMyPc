# Execute Flow

## Actors

- User
- AtlasApp
- AtlasWorkerClient
- AtlasWorkerXPC
- AtlasPrivilegedHelper
- AtlasStore

## Sequence

1. User previews a plan and confirms execution.
2. App sends `task.execute`.
3. Worker splits actions into privileged and non-privileged work.
4. Worker performs non-privileged actions directly.
5. Worker submits allowlisted privileged actions to helper when needed.
6. Worker streams progress, warnings, and per-item results.
7. Worker persists task result and recoverable items.
8. App renders a result page with success, warnings, and recovery actions.
