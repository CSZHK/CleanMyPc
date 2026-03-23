# Changelog

All notable changes to Atlas for Mac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
