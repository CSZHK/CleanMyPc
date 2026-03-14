# Changelog

All notable changes to Atlas for Mac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
