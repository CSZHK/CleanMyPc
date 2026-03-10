# ADR-005: Localization Framework and App-Language Preference

## Status

Accepted

## Context

Atlas for Mac needed a real multilingual foundation rather than scattered hard-coded English strings. The user requirement was to support Chinese and English first, default to Chinese, and keep the language choice aligned across the app shell, settings, and worker-generated summaries.

## Decision

- Add a package-scoped localization layer with structured resources in `AtlasDomain` so the Swift package graph can share one localization source.
- Persist the app-language preference in `AtlasSettings` and default it to `zh-Hans`.
- Inject the selected locale at the app shell while also using the persisted setting to localize worker-generated summaries and settings-derived copy.
- Keep localized legal copy derived from the selected language rather than treating it as ad hoc free text.

## Consequences

- The app now supports `简体中文` and `English` with Chinese as the default user experience.
- Settings persistence, protocol payloads, and local workspace state now include the app-language preference.
- UI automation needs stable identifiers rather than relying only on visible text, because visible labels can now change by language.
- Future languages can be added by extending the shared localization resources rather than editing each screen in isolation.

## Alternatives Considered

- Use system language only and skip an in-app switch — rejected because the requirement explicitly needed in-app Chinese/English switching.
- Store language only in app-local UI state — rejected because worker-generated summaries and persisted settings copy would drift from the selected language.
- Localize each feature independently without a shared resource layer — rejected because it would create duplication and drift across the package graph.
