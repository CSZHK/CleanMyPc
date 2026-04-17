# Changelog

All notable changes to Atlas for Mac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.5] - 2026-04-17

### Added

- **Automated Test Suite** — expanded from 148 to 238 tests (+90 new tests).
  - Infrastructure: `AtlasAuditStore` (9), `AtlasSmartCleanExecutionSupport` (16), `AtlasWorkspaceRepository` (7) unit tests.
  - Feature Views: `HistoryFeatureView` (9), `OverviewFeatureView` (9), `PermissionsFeatureView` (9) initialization and state variation tests.
  - Design System: `AtlasTone`, `AtlasElevation`, `AtlasFormatters`, `AtlasSpacing`, `AtlasRadius`, `AtlasLayout`, `AtlasColor`, `AtlasTypography`, `AtlasMotion` property verification tests (24).
  - New test targets in `Packages/Package.swift`: `AtlasFeaturesHistoryTests`, `AtlasFeaturesOverviewTests`, `AtlasFeaturesPermissionsTests`, `AtlasDesignSystemTests`.

- **English README Screenshots** — default screenshots replaced with English localized versions across Docs and LandingSite assets.

## [1.0.4] - 2026-04-07

### Added

- **Screenshot Exporter Shell** — README asset screenshots now render with a full app chrome replica (sidebar + content + gradient icon rows + selected-route highlight) instead of flat content-only views.
  - New `AtlasScreenshotShell` view replicates `AppShellView` sidebar layout with `AtlasRoute.SidebarSection` grouping, per-route gradient icon backgrounds, and selection highlight.
  - Screenshot resolution upgraded from 1600×1100 to 2880×1800 (Retina @2x) for crisper output.
  - Files: `Apps/AtlasApp/Sources/AtlasApp/ReadmeAssetExporter.swift`

- **Design System Components** — extracted reusable UI components into `AtlasDesignSystem/Components/`.
  - `AtlasCircularProgress`: ring-style progress indicator with configurable tone, line width, and text.
  - `AtlasGradientBackground`: brand gradient canvas background.
  - `AtlasHeroCard`: prominent metric display card.
  - `AtlasSectionDisclosure`: expandable section container.
  - `AtlasTransitions`: shared transition and motion constants.

- **Infrastructure Layer** — split monolithic `AtlasInfrastructure.swift` into focused modules.
  - `AtlasAuditStore`, `AtlasPathValidator`, `AtlasPermissionInspector`, `AtlasPrivilegedHelperClient`, `AtlasScaffoldWorkerService`, `AtlasSmartCleanExecutionSupport`, `AtlasWorkspaceRepository`.
  - Added `AtlasSnapshotFilter` for consistent snapshot filtering across features.

- **Feature View Tests** — new test suites for `AppsFeatureView` and `SmartCleanFeatureView` with snapshot-based assertions.

- **Landing Page** — glassmorphism visual upgrade with dark/light theme toggle.

### Changed

- **App Shell** — sidebar and detail content use extracted design system components for consistent animations and transitions.
- **Feature Views** (Overview, Smart Clean, Apps, History, Permissions) — refreshed layouts with improved visual hierarchy and new design system components.
- **Domain Models** — expanded `AtlasRoute` with sidebar section grouping, search prompts, and accessibility labels. Added localization keys for new sidebar sections.
- **Package manifest** — added new test targets and product dependencies for extracted components.

### Fixed

- README screenshots now visually match the running app (sidebar, icons, layout), resolving user feedback that "the screenshots don't look as good as the app."

## [1.0.3] - 2026-03-23

### Added

- `Apps` uninstall preview now records structured review-only evidence groups, including observed paths for support files, caches, preferences, logs, and launch items.
- Added scripted fixture baselines for `Apps` evidence and `Smart Clean` verification through `scripts/atlas/apps-manual-fixtures.sh`, `scripts/atlas/apps-evidence-acceptance.sh`, and the expanded Smart Clean fixture script.
- Added versioned workspace-state persistence and schema-versioned app recovery payloads so future recovery hardening can evolve without immediately dropping older local state.
- Expanded real `Smart Clean` execution coverage for additional high-confidence user-owned roots, including CoreSimulator caches and common developer cache locations such as Gradle, Ivy, and SwiftPM caches.

### Changed

- App restore now clears stale uninstall preview state and refreshes app inventory before the `Apps` surface reuses footprint counts.
- `History` recovery detail now surfaces recorded recovery evidence, including payload schema version, review-only uninstall groups, and restore-path mappings when available.
- `full-acceptance` now treats fixture-script validation as a routine release-readiness gate alongside packaging, install, launch, and UI automation checks.
- Local protocol and persistence contracts were tightened to distinguish versioned workspace-state storage from legacy compatibility fallback, while keeping review-only evidence explicitly non-executable.

### Fixed

- Legacy unversioned workspace-state files now migrate forward into the current persisted envelope instead of breaking on the newer persistence shape.
- Revalidated the `1.0.3` release candidate with package tests, app tests, native packaging, DMG install verification, installed-app launch smoke, and native UI automation.
- Fixed the post-restore `Apps` trust gap where recovered app payloads could leave stale uninstall preview or stale footprint evidence visible until a manual refresh.


## [1.0.2] - 2026-03-14

### Added

- Tag-driven GitHub Releases now publish Atlas native `.zip`, `.dmg`, and `.pkg` assets in addition to the legacy command-line binaries.
- Added `scripts/atlas/prepare-release.sh` to align app version, build number, and changelog scaffolding before tagging a release.

### Changed

- Release automation now falls back to a development-signed prerelease path when `Developer ID` signing credentials are unavailable, instead of blocking native packaging entirely.
- README installation guidance now distinguishes signed public releases from development prereleases and recommends local stable signing for developer packaging.

### Fixed

- `package-native.sh` and `signing-preflight.sh` now support `notarytool` profiles stored in a non-default keychain, which unblocks CI-based notarization.

## [1.0.1] - 2026-03-13

### Added

- Native macOS app with 7 MVP modules: Overview, Smart Clean, Apps, History, Recovery, Permissions, Settings
- Recovery-first cleanup workflow — actions are reversible via Trash before permanent deletion
- Explainable recommendations — every suggestion shows reasoning before execution
- Bilingual UI: Simplified Chinese (default) and English, with persistent language preference
- AtlasDesignSystem shared design tokens: brand colors (teal/mint), typography, 4pt spacing grid, continuous corner radius
- Layered Swift Package architecture with strict dependency direction
- XPC worker architecture for sandboxed operations
- Privileged helper for elevated operations requiring administrator access
- Keyboard navigation and command shortcuts for the main shell
- Accessibility semantics and stable UI-automation identifiers
- Native packaging: `.app`, `.zip`, `.dmg`, `.pkg` artifact generation
- Go-based TUI tools inherited from upstream Mole: disk analyzer (`analyze`) and system monitor (`status`)
- CI/CD: GitHub Actions for formatting, linting, testing, CodeQL scanning, and release packaging

### Fixed

- Recovery restore requests now preflight every selected item before Atlas mutates local recovery state, preventing partial in-memory restore success when a later item fails.
- Helper-backed restore destination conflicts now surface restore-specific errors instead of falling back to a generic execution-unavailable message.
- Expired recovery items are pruned from persisted state and rejected with explicit restore-expired messaging.
- Revalidated the current native release candidate with package tests, app tests, DMG install verification, launch smoke, and native UI automation.

### Attribution

- Built in part on the open-source [Mole](https://github.com/tw93/mole) project (MIT) by tw93 and contributors
