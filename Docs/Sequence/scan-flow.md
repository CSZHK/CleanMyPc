# Scan Flow

## Actors

- User
- AtlasApp
- AtlasWorkerClient
- AtlasWorkerXPC
- AtlasCoreAdapters
- AtlasStore

## Sequence

1. User starts a scan.
2. App sends `scan.start`.
3. Worker validates scope and permissions.
4. Worker invokes one or more adapters.
5. Worker streams progress events.
6. Worker aggregates findings and summary.
7. Worker persists scan summary.
8. App renders grouped findings or a limited-results banner.
