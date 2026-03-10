# Workspace Layout

## Top-Level Directories

- `Apps/` — user-facing app targets
- `Packages/` — shared Swift packages
- `XPC/` — XPC service targets
- `Helpers/` — privileged helper targets
- `MenuBar/` — deferred menu-bar target area
- `Testing/` — shared testing support and future test targets
- `Docs/` — product, design, engineering, and compliance documents

## Planned Module Layout

### App Shell

- `Apps/AtlasApp/`
- `Apps/Package.swift`

### Shared Packages

- `Packages/Package.swift`
- `Packages/AtlasDesignSystem/`
- `Packages/AtlasDomain/`
- `Packages/AtlasApplication/`
- `Packages/AtlasProtocol/`
- `Packages/AtlasInfrastructure/`
- `Packages/AtlasCoreAdapters/`
- `Packages/AtlasFeaturesOverview/`
- `Packages/AtlasFeaturesSmartClean/`
- `Packages/AtlasFeaturesApps/`
- `Packages/AtlasFeaturesStorage/`
- `Packages/AtlasFeaturesHistory/`
- `Packages/AtlasFeaturesPermissions/`
- `Packages/AtlasFeaturesSettings/`

### Services

- `XPC/Package.swift`
- `Helpers/Package.swift`
- `XPC/AtlasWorkerXPC/`
- `Helpers/AtlasPrivilegedHelper/`

### Deferred Targets

- `MenuBar/AtlasMenuBar/`

### Test Support

- `Testing/Package.swift`
- `Testing/AtlasTestingSupport/`

## Current Scaffold Conventions

- `Apps/Package.swift` hosts the main `AtlasApp` executable target.
- `Packages/Package.swift` hosts shared library products with sources under `Packages/*/Sources/*`.
- `XPC/Package.swift` and `Helpers/Package.swift` host the worker and helper executable stubs.
- Root `project.yml` also generates an `AtlasWorkerXPC` macOS `xpc-service` target for the app bundle.
- `Testing/Package.swift` hosts shared fixtures and future contract-test helpers.
- `MenuBar/` remains README-only until deferred P1 scope is explicitly reopened.
- Root `project.yml` generates `Atlas.xcodeproj` through `xcodegen` for the native app shell.

## Rule

Create implementation files inside these directories rather than introducing new top-level structures unless an ADR records the change. Keep `project.yml` as the source of truth for regenerating `Atlas.xcodeproj`.
