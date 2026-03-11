# Contributing to Atlas for Mac

Thank you for your interest in contributing to Atlas for Mac! This guide covers everything you need to get started.

## Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 16+ (Swift 6.0)
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Go 1.24+ (only for legacy CLI components)

## Getting Started

```bash
# Clone the repository
git clone https://github.com/CSZHK/CleanMyPc.git
cd CleanMyPc

# Option A: Run directly
swift run --package-path Apps AtlasApp

# Option B: Open in Xcode
xcodegen generate
open Atlas.xcodeproj
```

## Architecture Overview

Atlas uses a layered Swift Package architecture with strict top-down dependency direction:

```
Apps/AtlasApp              ← App entry point, state management, routing
  ↓
Feature Packages           ← One package per module (Overview, SmartClean, Apps, etc.)
  ↓
AtlasDesignSystem          ← Brand tokens, reusable UI components
AtlasDomain                ← Core models, localization (AtlasL10n)
  ↓
AtlasApplication           ← Workspace controller, repository layer
AtlasInfrastructure        ← Worker management, XPC communication
  ↓
XPC/AtlasWorkerXPC         ← Sandboxed worker service
Helpers/                   ← Privileged helper for elevated operations
```

Each feature package depends only on `AtlasDesignSystem` + `AtlasDomain` and receives callbacks for parent coordination.

## Running Tests

```bash
# Domain, design system, adapters, and shared packages
swift test --package-path Packages

# App-level tests
swift test --package-path Apps

# Run a single test target
swift test --package-path Packages --filter AtlasDomainTests

# Full test suite (includes Go and shell tests)
./scripts/test.sh
```

## Code Quality

Run formatting and linting before committing:

```bash
./scripts/check.sh
```

CI will also run these checks automatically on every push and pull request.

## Code Style

### Swift

- Swift 6.0 with strict concurrency enabled
- Follow existing patterns in the codebase
- Use `AtlasL10n` for all user-facing strings — never hardcode display text

### Design System

All UI should use the shared design tokens from `AtlasDesignSystem`:

- **Colors**: `AtlasColor` — brand (teal), accent (mint), semantic (success/warning/danger/info)
- **Typography**: `AtlasTypography` — screenTitle, heroMetric, sectionTitle, label, body, caption
- **Spacing**: `AtlasSpacing` — 4pt grid (xxs=4, xs=8, sm=12, md=16, lg=20, xl=24, section=32)
- **Radius**: `AtlasRadius` — continuous corners (sm=8, md=12, lg=16)

### File Operations

All cleanup and deletion logic must use safe wrappers. Never use raw `rm -rf` or unguarded file removal. See `SECURITY_AUDIT.md` for details on path validation and deletion boundaries.

## Localization

Atlas supports Simplified Chinese (default) and English.

String files are located at:

```
Packages/AtlasDomain/Sources/AtlasDomain/Resources/zh-Hans.lproj/Localizable.strings
Packages/AtlasDomain/Sources/AtlasDomain/Resources/en.lproj/Localizable.strings
```

When adding user-facing text:

1. Add entries to **both** `.strings` files
2. Access strings via the `AtlasL10n` enum

## Go Components

The `cmd/analyze/` and `cmd/status/` directories contain Go-based TUI tools inherited from the upstream Mole project. These are built separately:

```bash
make build              # Build for current architecture
go run ./cmd/analyze    # Run disk analyzer directly
go run ./cmd/status     # Run system monitor directly
```

## Pull Requests

1. Fork the repository and create a branch from `main`
2. Make your changes
3. Run tests: `swift test --package-path Packages && swift test --package-path Apps`
4. Run quality checks: `./scripts/check.sh`
5. Open a PR targeting `main`

CI will verify formatting, linting, and tests automatically.

## Security

If you discover a security vulnerability, **do not** open a public issue. Please report it privately following the instructions in [SECURITY.md](SECURITY.md).
