# Changelog

All notable changes to Atlas for Mac will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2.0.0] - 2026-06-17

The「Calm Ledger · 平静台账」full frontend redesign — trust becomes structural
(evidence panels, recovery-point stamps, ledger timeline always visible), across
all 8 screens + shell + design system v3. History is renamed to Ledger
(D-012 contract unfreeze). Pure-frontend: Worker / XPC / protocol behavior
unchanged.

### Added
- **Calm Ledger design system v3** — 9 new components (`AtlasStageBar`,
  `AtlasActionBar`, `AtlasEvidencePanel`, `AtlasLedgerTimeline`,
  `AtlasStampBadge`, `AtlasLedgerSurface`, `AtlasNextActionBanner`,
  `AtlasErrorState`, `AtlasDataText`); tokens recast (colorset palette,
  three-voice typography with Songti cascade, motion/layout tokens, softened
  elevation).
- **SmartClean 4-stage workflow** (scan → review → execute → receipt):
  resolve-on-render stage truth, evidence panel, execution receipt, real undo
  chained to the ledger restore point.
- **FileOrganizer 5-stage pipeline** (scan → rules → preview → execute →
  receipt): custom rule editor, size-band evidence, security boundary
  (destination constrained to home + subfolder sanitization), partial-failure
  honesty (`failedItemCount`).
- **Apps single-select browser**: 10-category footprint evidence panel +
  uninstall-plan preview + residual estimate (fail-closed recovery).
- **Ledger (was History)**: warm-paper four-piece set (archive / detail / export
  / timeline) + № numbering + scan receipt `#XXXX` (SHA256) + Markdown export.
- **Permissions three-section evidence** (why needed / impact scope / how to
  authorize).
- **Overview command column**: health ring + module entries + ledger feed +
  「next step」 recommendation (5-row priority table + snooze cooldown).
- Per-route workflow-state persistence (survives route switches); WCAG AA
  contrast gate script (36 pairs, CI merge gate).

### Changed
- **History → Ledger rename** (route / IA / copy / docs fully synced; D-012
  contract unfreeze of `testPrimaryRoutesMatchFrozenMVP`).
- Window default 1180×740 / min 980×640; sidebar regrouped into 工作 / 记录 with
  `ATLAS.` wordmark.
- Three-voice typography discipline (title / data / body); continuous-corner
  radius tokens.

### Fixed
- **Round-21 full-branch acceptance (12 P2)**: metric honesty (Apps inventory
  reads the unfiltered set, Settings recovery footprint reads the unfiltered
  total, Ledger recoverable metric excludes expired items); accessibility
  (44pt tap targets on rule-editor + segmented control, localized VoiceOver
  chip counts); FileOrganizer execute progress no longer echoes stale scan
  value, conflict detection moved off the render thread, re-scan re-derives
  №/receipt; export now lists recovery items; permission status row relabeled.
- Cumulative round-1…20 review fixes (numbering collisions, selection clobber,
  fail-closed receipts, AA contrast, tap targets, scroll/truncation,
  main-thread blocking).

## [1.0.8] - 2026-05-22

### Fixed
- **FileOrganizer** — multi-folder scan, undo isolation, dry-run feedback.

## [1.0.7] - 2026-05-21

### Added

- **UI/UX overhaul** — 22 improvements across P0–P3 priority levels covering all 6 feature modules.
  - **Skeleton loading** — `AtlasSkeletonCard` and `AtlasSkeletonRow` with shimmer animation replace spinner in Overview first-load state. Respects `accessibilityReduceMotion`.
  - **Toast notifications** — `AtlasToastContainer` + `AtlasToastItem` with auto-dismiss (3s), manual close, and tone-aware styling. Integrated into `AtlasAppModel`.
  - **Undo banner** — `AtlasUndoBanner` shared component for SmartClean post-execution rollback prompt.
  - **Filter chips** — `AtlasFilterChip` for SmartClean risk-level filtering (All / Safe / Review / Advanced) and Apps leftover-only toggle.
  - **Segmented control** — `AtlasSegmentedControl` replacing native `.pickerStyle(.segmented)` in Settings language picker.
  - **Tooltip modifier** — `AtlasTooltipModifier` with hover-activated tooltip, arrow, and placement options (top/bottom/leading/trailing). Applied to Overview metric cards.
  - **Dynamic sidebar subtitles** — sidebar rows now show live context (disk %, findings count, app count, permissions status) via `AtlasSidebarContext`.
  - **Thumbnail cache** — `NSCache`-based `ThumbnailCache` in FileOrganizer avoids repeated disk reads for file thumbnails.

### Changed

- **Callout cleanup** — removed redundant callouts from Settings (all 3 panels), Permissions (duplicate of hero card). Apps callout now conditional on previewPlan/restoreRefreshStatus only.
- **File Organizer** — configuration section collapsed into `AtlasSectionDisclosure` (default collapsed); action buttons (Scan/Preview/Execute) always visible separately. Metric cards switched from `HStack` to responsive `LazyVGrid`.
- **Settings** — tab bar pinned at top, only panel content scrolls. Eliminated nested `ScrollView`.
- **Accessibility** — `AtlasStatusChip` now includes unicode icon prefix (✓/△/✕) per tone. `reduceMotion` checks added to FileOrganizer selection animation and toast transitions. Dynamic Type upper bounds added to `AtlasTypography` fixed-size styles.
- **Window sizing** — `defaultSize(1024×680)` + `NSWindow.minSize(940×640)` prevents split-view collapse.
- **Localization** — 17 new keys in both `en` and `zh-Hans` for sidebar dynamic subtitles, SmartClean filter, and undo banner.

## [1.0.6] - 2026-05-15

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
