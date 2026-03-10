# Architecture

## High-Level Topology

- `AtlasApp` — main macOS application shell
- `AtlasWorkerXPC` — non-privileged worker service
- `AtlasPrivilegedHelper` — allowlisted helper executable for structured destructive actions
- `AtlasCoreAdapters` — wrappers around reusable upstream and local system capabilities
- `AtlasStore` — persistence for runs, rules, recovery, settings, diagnostics, and the app-language preference

## Layering

### Presentation

- SwiftUI scenes and views
- Navigation state
- View models or reducers
- App-language selection and locale injection at the app shell

### Application

- Use cases such as `StartScan`, `PreviewPlan`, `ExecutePlan`, `RestoreItems`
- App uninstall flows: `ListApps`, `PreviewAppUninstall`, `ExecuteAppUninstall`
- Settings flows: `GetSettings`, `UpdateSettings`

### Domain

- `Finding`
- `ActionPlan`
- `ActionItem`
- `TaskRun`
- `RecoveryItem`
- `RecoveryPayload`
- `AppFootprint`
- `PermissionState`
- `AtlasSettings`
- `AtlasLanguage`

### Infrastructure

- XPC transport
- JSON-backed workspace state persistence
- Logging and audit events
- Best-effort permission inspection
- Helper executable client
- Process orchestration

### Execution

- Upstream adapters: `MoleHealthAdapter`, `MoleSmartCleanAdapter`
- Release and packaged worker flows load upstream shell runtime from bundled `MoleRuntime` resources instead of source-tree paths
- Local adapters: `MacAppsInventoryAdapter`
- Recovery-first state mutation for Smart Clean and app uninstall flows
- Allowlisted helper actions for bundle trashing, restoration, and launch-service removal
- Release-facing execution must fail closed when real worker/adapter/helper capability is unavailable; scaffold fallback is development-only by opt-in
- Smart Clean now supports a real Trash-based execution path for a safe structured subset of user-owned targets, plus physical restoration when recovery mappings are present

## Process Boundaries

- UI must not parse shell output directly.
- UI must not execute privileged shell commands directly.
- `AtlasWorkerXPC` owns long-running task orchestration and progress events.
- Direct-distribution builds default to the same real worker implementation in-process; `AtlasWorkerXPC` remains available behind `ATLAS_PREFER_XPC_WORKER=1` for explicit runtime validation.
- `AtlasPrivilegedHelper` accepts structured actions only and validates paths before acting.
- Persistent workspace mutation belongs behind the repository/worker boundary rather than ad hoc UI state.
- UI copy localization is sourced from structured package resources instead of hard-coded per-screen strings.

## Distribution Direction

- Distribution target: `Developer ID + Hardened Runtime + Notarization`
- Initial release target: direct distribution, not Mac App Store
- Native packaging currently uses `xcodegen + xcodebuild`, embeds the helper into `Contents/Helpers/`, and emits `.zip`, `.dmg`, and `.pkg` distribution artifacts.
- Local internal packaging now prefers a stable non-ad-hoc app signature when a usable identity is available, so macOS TCC decisions can survive rebuilds more reliably during development.
- If Apple release certificates are unavailable, Atlas can fall back to a repo-managed local signing keychain for stable app-bundle identity; public release artifacts still require `Developer ID`.

## Security Principles

- Least privilege by default
- Explain permission need before request
- Prefer `Trash` or recovery-backed restore paths
- Audit all destructive actions
