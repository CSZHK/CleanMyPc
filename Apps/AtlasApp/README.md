# AtlasApp

## Responsibility

- Main macOS application target
- `NavigationSplitView` shell for the frozen MVP modules
- Shared app-state wiring for search, task center, and route selection
- Dependency handoff into feature packages and worker-backed Smart Clean actions

## Current Scaffold

- `AtlasApp.swift` — `@main` entry for the macOS app shell
- `AppShellView.swift` — sidebar navigation, toolbar, and task-center popover
- `AtlasAppModel.swift` — shared scaffold state backed by the application-layer workspace controller
- `TaskCenterView.swift` — global task surface placeholder wired to `History`
