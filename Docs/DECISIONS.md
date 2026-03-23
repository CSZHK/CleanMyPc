# Decision Log

## Frozen Decisions

### D-001 Naming

- Internal product name: `Atlas for Mac`
- User-facing naming must not use `Mole`

### D-002 Open-Source Attribution

- Atlas for Mac is an independent product
- Upstream attribution must acknowledge Mole by tw93 and contributors
- Shipped materials must include MIT notice when upstream-derived code is distributed

### D-003 Distribution

- MVP distribution target is direct distribution
- Use `Developer ID + Hardened Runtime + Notarization`
- Do not target Mac App Store for MVP

### D-004 MVP Scope

- In scope: `Overview`, `Smart Clean`, `Apps`, `History`, `Recovery`, `Permissions`, `Settings`
- Out of MVP: `Storage treemap`, `Menu Bar`, `Automation`

### D-005 Process Boundaries

- UI must not parse terminal output directly
- Privileged actions must go through a structured helper boundary
- Worker owns long-running orchestration and progress streaming

### D-006 MVP Persistence and Command Surface

- MVP workspace state is persisted locally as a structured JSON store
- Settings, history, recovery, Smart Clean execute, and app uninstall flows use structured worker commands
- UI state should reflect repository-backed worker results instead of direct mutation

### D-007 Helper Execution and Native Packaging

- Destructive helper actions use a structured executable boundary with path validation
- Native MVP packaging uses `xcodegen + xcodebuild`, then embeds the helper into the app bundle
- Tagged GitHub Releases should publish the native `.zip`, `.dmg`, and `.pkg` assets from CI using the same packaging scripts as local release builds
- If CI lacks `Developer ID` release credentials, tagged native assets may still be published as development-signed prereleases instead of blocking the packaging path entirely
- Signing and notarization remain optional release-time steps driven by credentials
- Internal packaging should prefer a stable local app-signing identity over ad hoc signing whenever possible so macOS permission state does not drift across rebuilds

### D-008 App Language Preference and Localization

- MVP now supports `简体中文` and `English` through a persisted app-language preference
- The default app language is `简体中文`
- User-facing shell copy is localized through package-scoped resources instead of hard-coded per-screen strings
- The language preference is stored alongside other settings so worker-generated summaries stay aligned with UI language

### D-009 Execution Capability Honesty

- User-facing execution flows must fail closed when real disk-backed execution is unavailable
- Atlas must not silently fall back to scaffold behavior for release-facing cleanup execution
- Smart Clean execute must not claim success until real filesystem side effects are implemented

### D-010 Competitive Response Stays Inside Frozen MVP

- Atlas responds to competitor pressure through `selective parity`, not breadth racing
- `Mole` and `Tencent Lemon Cleaner` set the main comparison pressure for `Smart Clean`
- `Pearcleaner` and `Tencent Lemon Cleaner` set the main comparison pressure for `Apps`
- Competitor response work must deepen existing MVP flows rather than reopen deferred scope
- `Storage treemap`, `Menu Bar`, and `Automation` remain out of scope unless the decision log is updated explicitly
- Atlas should compete as an `explainable, recovery-first Mac maintenance workspace`, not as a generic all-in-one cleaner

### D-011 Versioned Workspace State and Recovery Payload Compatibility

- Persisted workspace state uses a versioned JSON envelope instead of an unversioned top-level payload
- Atlas must continue decoding older top-level workspace-state files and rewrite them into the current envelope when possible
- App recovery payloads carry an explicit schema version and must remain backward-compatible with legacy app-only recovery payload shapes
- App payload restores must refresh app inventory before `Apps` reuses footprint counts or uninstall preview state

## Update Rule

Add a new decision entry whenever product scope, protocol, privilege boundaries, release route, or recovery model changes.
