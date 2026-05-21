# Atlas for Mac 1.0.6


### Added

- **File Organizer feature** — full scan, classify, plan, execute, undo pipeline with configurable rule engine.
  - Rule editor: create/edit/delete rules with extension patterns, name patterns, category, destination subfolder, and size constraints.
  - Rule import/export (JSON) with error feedback on malformed files.
  - Grouped plan preview with conflict detection and per-category disclosure.
  - Undo banner after execution with one-click rollback support.

- **Building preview state** — Apps detail view now shows a building state with progress indicator and contextual callout during preview generation.

- **Accessibility** — added `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityAddTraits` across FileOrganizer entry rows and About social cards. 28 new localization keys in both en and zh-Hans.

- **Empty states** — FileOrganizer, Storage, and RuleEditor now show `AtlasEmptyState` when no data is available.

### Changed

- **Design system migration** — all feature views migrated from system button styles (`.borderedProminent`, `.bordered`) to Atlas tokens (`.atlasPrimary`, `.atlasSecondary`, `.atlasGhost`). Hardcoded fonts, spacing, and corner radii replaced with `AtlasTypography`, `AtlasSpacing`, `AtlasRadius` tokens.

- **Responsive layouts** — replaced hardcoded width thresholds (`contentWidth >= 480`) with `ViewThatFits(in: .horizontal)` in About social grid and FileOrganizer action buttons.

- **Rule editor** — rewritten from `AtlasScreen` to `NavigationStack` + toolbar pattern with inline delete confirmation alert and import error alert.

- **Storage view** — refactored from raw `HStack`/`VStack` to `AtlasDetailRow` component with `AtlasStatusChip`.

- **History detail panel** — added stable view identity (`.id`) and `withAnimation`-driven transitions replacing per-value `.animation()` modifiers.

- **Overview** — permissions metric card hidden when no required permissions exist.

- **TaskCenter** — panel width changed from fixed 430pt to flexible range (360–520pt).

### Fixed

- Rule editor import now shows error alert instead of silently discarding malformed JSON.
- Size constraint parsing returns `nil` for invalid input instead of silently defaulting to `0` bytes.
- Save button validation includes `namePatterns` field alongside name and extension patterns.
- Removed redundant set operations in FileOrganizer selection `onChange` handler.
- QR code corner radius uses `AtlasRadius.sm` instead of hardcoded value.

## Packaging Status

Native macOS assets in this tag were packaged in development mode because Developer ID release-signing credentials were not configured for this run.

These `.zip`, `.dmg`, and `.pkg` files are intended for internal testing or developer use. macOS Gatekeeper may require `Open Anyway` or a right-click `Open` flow before launch.
