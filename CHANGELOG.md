# Changelog

All notable changes to Atlas for Mac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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

### Attribution

- Built in part on the open-source [Mole](https://github.com/tw93/mole) project (MIT) by tw93 and contributors
