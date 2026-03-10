# Restore Flow

## Actors

- User
- AtlasApp
- AtlasWorkerClient
- AtlasWorkerXPC
- AtlasPrivilegedHelper
- AtlasStore

## Sequence

1. User selects one or more recovery items.
2. App sends `recovery.restore`.
3. Worker validates recovery windows and target conflicts.
4. Worker restores items directly or via helper when required.
5. Worker persists restore result and updates recovery status.
6. App renders restored, failed, or expired outcomes.
