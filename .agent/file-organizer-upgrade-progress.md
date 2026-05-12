# File Organizer Commercial Upgrade — Progress Tracker

## Completed

### [P0-1] 单文件选择/取消选择 ✅ (2026-05-11)
- **Model**: No domain model changes — selection tracked as view state `@State private var selectedEntryIDs: Set<UUID>`
- **View**: Added checkbox toggle per entry row, select all/deselect all buttons, selection count display
- **Callback**: Changed `onRefreshPreview` from `() -> Void` to `([UUID]) -> Void` to pass selected entry IDs
- **AppModel**: `refreshFileOrganizerPreview(entryIDs:)` now filters by provided IDs
- **Localization**: Added `fileorganizer.selection.count`, `fileorganizer.action.selectAll`, `fileorganizer.action.deselectAll` in both en/zh-Hans
- **Tests**: 118/118 passing, no test breakage

### [P0-2] 可配置目标路径 ✅ (2026-05-11)
- **Settings**: Added `fileOrganizerDestinationBasePath: String` to `AtlasSettings` (Codable, backward compatible with default `"~/Organized"`)
- **Protocols**: `AtlasFileOrganizerScanning.scanFolders(_:destinationBasePath:)` and `AtlasFileOrganizerClassifying.classify(_:rules:destinationBasePath:)` now accept destination path
- **Scanner/Classifier**: Use `destinationBasePath` instead of hardcoded `~/Organized/`
- **Worker**: Passes `state.settings.fileOrganizerDestinationBasePath` to scanner and classifier
- **View**: Added destination selector UI with folder picker, displays current path, "Change" button
- **AppModel**: Added `updateFileOrganizerDestination(_:)` to update setting via `updateSettings`
- **Localization**: Added `fileorganizer.destination.title`, `fileorganizer.destination.change` in both en/zh-Hans
- **Tests**: 129/129 passing, updated stub scanners in infrastructure tests

### [P0-3] 递归扫描开关 ✅ (2026-05-11)
- **Settings**: Added `fileOrganizerRecursiveScan: Bool` to `AtlasSettings` (default `false`, backward compatible)
- **Scanner**: `scanFolders(_:destinationBasePath:recursive:)` — when `recursive=true`, uses `[.skipsHiddenFiles]` (no `.skipsSubdirectoryDescendants`); when `false`, uses current behavior
- **View**: Added toggle switch in action buttons area ("包含子文件夹" / "Include Subfolders")
- **AppModel**: Added `updateFileOrganizerRecursiveScan(_:)` via `updateSettings`
- **Localization**: Added `fileorganizer.recursive.title` in both en/zh-Hans
- **Tests**: 129/129 passing, updated stub scanners with `recursive` parameter

### [P0-4] 冲突预检 ✅ (2026-05-11)
- **Conflict detection**: Computed property `conflictingEntryIDs: Set<UUID>` checks `FileManager.fileExists` on each `proposedDestination`
- **Entry list**: Conflicting entries show ⚠ suffix on filename, warning triangle icon, and descriptive footnote ("目标位置已存在同名文件")
- **Plan preview**: Warning callout appears when plan items conflict, showing count and auto-rename explanation
- **Plan items**: Individual conflicting items also show ⚠ suffix and warning icon
- **No model/protocol changes**: Pure view-layer feature, computed from existing data
- **Localization**: Added `fileorganizer.conflict.exists`, `fileorganizer.conflict.callout.title`, `fileorganizer.conflict.callout.detail` in both en/zh-Hans
- **Tests**: 129/129 passing

### [P1-1] 规则编辑器 UI ✅ (2026-05-11)
- **New file**: `FileOrganizerRuleEditorView.swift` — full CRUD rule editor as a sheet
- **Rule list**: Shows all rules with name, extensions, category icon. Tap to edit, swipe to delete
- **Rule edit form**: Name, extensions (comma-separated), category picker, optional subfolder, optional size limits (min/max)
- **Add rule**: Creates new rule with auto-generated ID, opens edit form immediately
- **Wiring**: Replaced `onEditRules: () -> Void` with `onUpdateRules: ([FileOrganizerRule]) -> Void`. "Edit Rules" button in action area opens the sheet
- **AppModel**: `updateFileOrganizerRules(_:)` updates `fileOrganizerRules` published property
- **Localization**: 17 new l10n keys for the rule editor UI in both en/zh-Hans
- **Tests**: 129/129 passing

### [P1-3] 规则持久化 ✅ (2026-05-11)
- **Settings**: Added `fileOrganizerCustomRules: [FileOrganizerRule]?` to `AtlasSettings` (optional, nil = use default fixtures)
- **AppModel**: Init loads custom rules from `settings.fileOrganizerCustomRules` (falls back to `AtlasScaffoldFixtures`). `updateFileOrganizerRules` now persists via `updateSettings`
- **Worker**: Classifier reads `state.settings.fileOrganizerCustomRules` instead of hardcoded fixtures — uses custom rules when available
- **Backward compatible**: `decodeIfPresent` + `encodeIfPresent` — existing persisted settings without custom rules continue to work
- **Tests**: 129/129 passing

### [P3-1/2] Scanner + Classifier 单元测试 ✅ (2026-05-11)
- **New file**: `AtlasFileOrganizerScannerTests.swift` with 22 tests total
- **Scanner tests (12)**: empty dir, single file, all 8 categories, non-recursive skips subdirs, recursive includes subdirs, hidden files skipped, custom destination, trailing slash strip, multiple folders, nonexistent folder, total bytes, category counts
- **Classifier tests (10)**: extension-based, name pattern, size filtering (min/max), custom rule priority over UTType, UTType fallback, existing category fallback, custom destination, empty input, first-match-wins
- **Key finding**: Size-filtered entries fall through to UTType (not existing category) — tests now reflect correct classifier behavior
- **Tests**: 22/22 new tests passing, no regressions in existing tests

### [P2-3] 撤销改进 (inline undo) ✅ (2026-05-11)
- **View**: Added `undoBanner` — branded card with undo icon, file count, explanation text, and "Undo" button. Shown only when `executionCompleted && movedCount > 0`
- **AppModel**: `undoFileOrganizerExecution()` finds the latest `.fileOrganizer` recovery item and restores it. After undo, clears entries, plan, and execution state — returns to clean ready state
- **Callback**: `onUndoExecution: () -> Void` wired through AppShellView
- **Design**: Branded rounded card with subtle brand color background and border — matches Atlas design language
- **Localization**: Added `fileorganizer.undo.title`, `fileorganizer.undo.detail`, `fileorganizer.undo.action` in both en/zh-Hans
- **Tests**: 141/141 passing

### [P2-4] 本地化补全 ✅ (2026-05-11)
- **Worker service**: Localized 3 hardcoded English error reasons → `fileorganizer.error.scanFailed`, `fileorganizer.error.noEntries`, `fileorganizer.error.stalePlan`
- **Audit**: Verified all user-facing strings in Scanner/Classifier are programmatic (SF symbols, file extensions, default paths) — not needing localization
- **View**: All UI strings already use `AtlasL10n.string(...)` — no gaps found
- **Localization**: Added 3 error string keys in both en/zh-Hans
- **Tests**: 141/141 passing

### [P2-5] 大文件/重复文件检测 ✅ (2026-05-11)
- **Computed properties**: `largeFileIDs` (>100MB threshold) and `duplicateFileIDs` (grouped by fileName + bytes, groups with count > 1)
- **Entry row**: Large files show `exclamationmark.circle` icon and "Large file" badge in footnote. Duplicates show `doc.on.doc` icon and "Duplicate" badge
- **Insights section**: `AtlasCallout` with warning tone between metric cards and category sections — shows large file count + total size, and duplicate count
- **Key type**: Used explicit `FileNameBytesKey` struct for Dictionary grouping key (tuple can't be Hashable in this context)
- **Localization**: Added 5 new l10n keys (`fileorganizer.insight.title`, `.large.summary`, `.large.badge`, `.duplicate.summary`, `.duplicate.badge`) in both en/zh-Hans
- **Tests**: 54/54 passing (11 feature + 43 adapter), no regressions

### [P1-2] 规则优先级排序 ✅ (2026-05-11)
- **Rule list**: Changed `ForEach(rules)` to `ForEach(Array(rules.enumerated()), id: \.element.id)` to expose index for reorder
- **Priority badge**: Each rule row shows its position number (1-based) on the left side
- **Move buttons**: Added chevron up/down buttons on each row — move up (index > 0) and move down (index < count - 1), disabled at boundaries
- **Priority hint**: Subtitle on rules card explains "Rules are applied top-to-bottom" when more than 1 rule exists
- **No model/protocol changes**: Classifier already iterates `for rule in rules` (first-match-wins), so array order = priority
- **Localization**: Added `fileorganizer.ruleeditor.priority.hint` in both en/zh-Hans
- **Tests**: 54/54 passing, no regressions

### [P1-4] 规则导入/导出 ✅ (2026-05-11)
- **RulesDocument**: Private `FileDocument` conforming type wrapping `[FileOrganizerRule]` JSON — uses `JSONEncoder`/`JSONDecoder` with `.json` UTType
- **Export button**: "Export" (square.and.arrow.up icon) in rule editor footer — opens `fileExporter` to save rules as JSON. Disabled when rules list is empty
- **Import button**: "Import" (square.and.arrow.down icon) — opens `fileImporter` to select a JSON file, decodes as `[FileOrganizerRule]`, replaces current rules list
- **Security**: Uses `startAccessingSecurityScopedResource()`/`stopAccessingSecurityScopedResource()` for sandbox-safe file access on import
- **No model/protocol changes**: Pure view-layer feature, `FileOrganizerRule` was already `Codable`
- **Localization**: Added `fileorganizer.ruleeditor.import.title`, `fileorganizer.ruleeditor.export.title` in both en/zh-Hans
- **Tests**: 54/54 passing, no regressions

## In Progress

(none)

### [P2-1] 实时扫描进度 ✅ (2026-05-11)
- **AppModel**: Sequential folder scanning — when multiple folders selected, scans one at a time with `fileOrganizerScanSummary` and `fileOrganizerProgress` updated between folders
- **Progress display**: Shows "Scanning Desktop… (1/2)" → "Scanning Downloads… (2/2)" with progress bar filling fractionally
- **Single folder optimization**: Single-folder scans bypass sequential logic — same as before, one call
- **Snapshot merging**: After all folders scanned, merges entries into final snapshot, consolidates intermediate task runs into one
- **Error resilience**: Continues scanning remaining folders if one fails; only reports error if ALL folders fail
- **View unchanged**: Already displays `scanSummary` and `scanProgress` during scanning — data now updates in real-time
- **Localization**: Added `fileorganizer.progress.scanningFolder` in both en/zh-Hans
- **Tests**: 54/54 passing, no regressions

### [P2-2] 文件预览缩略图 ✅ (2026-05-11)
- **FileThumbnailView**: Private struct with `@State private var image: NSImage?` — loads image via `NSImage(contentsOf:)` in `.task(id: path)`, resizes to 64x64 for memory efficiency
- **Entry row**: For `.images` category entries (without conflict/large/duplicate badges), shows a 32x32 thumbnail with rounded corners instead of SF Symbol icon. Falls back to "photo" SF Symbol while loading or if load fails
- **Async loading**: Uses `.task(id: path)` for non-blocking thumbnail rendering — `LazyVStack` ensures only visible rows trigger loads
- **No model/protocol changes**: Pure view-layer feature, reads `entry.path` (already available)
- **No new l10n strings**: No text added — purely visual
- **Tests**: 11/11 feature tests passing, no regressions

## Up Next (priority order)

### P3 — Test Coverage
- [x] P3-3: Boundary condition tests ✅

## Design Decisions
- Selection state lives in `@State` on the view, NOT on `FileOrganizerEntry` — avoids polluting the domain model and breaking Codable persistence
- Auto-select all new entries on scan via `onChange(of: entries)`
- Preview button disabled when no entries are selected (guards against empty plan)
- Destination base path stored in `AtlasSettings` (not separate UserDefaults) — rides on existing persistence infrastructure
- Protocol changes use default parameter values (`= "~/Organized"`) to minimize blast radius on callers
- Scanner/Classifier strip trailing `/` from destination path to avoid double-slash in generated paths
- Recursive scan stored in `AtlasSettings` — consistent with destination path pattern, rides on existing persistence
- Conflict pre-check is purely view-computed (no model/protocol changes) — `FileManager.fileExists` on each `proposedDestination`, acceptable I/O cost for typical entry counts
- Large file threshold is 100MB (hardcoded as static constant on the view) — large enough to avoid noise from typical media files, small enough to catch genuinely concerning sizes
- Duplicate detection uses (fileName, bytes) tuple — fast heuristic that catches true duplicates without expensive hash computation; not a guarantee of identity (two different files could share name + size)
- Rule priority is array order (no separate `priority` field) — classifier iterates `for rule in rules`, first match wins, so array index = priority. Move up/down buttons modify array order directly
- Rule import replaces the full list (not merge) — simpler UX, user can undo by not saving. Import uses `securityScopedResource` for sandbox compliance
- Rule export uses `FileDocument` protocol (`RulesDocument`) — standard SwiftUI sandbox-safe file export, leverages `FileOrganizerRule`'s existing `Codable` conformance
- Scan progress uses sequential folder scanning in AppModel — no protocol/scanner changes needed. Multi-folder scans call `workspaceController.fileOrganizerScan` per folder, updating `@Published` progress properties between calls. Single-folder scans use the original single-call path for zero overhead
- File thumbnails use `NSImage(contentsOf:)` resized to 64x64 in a `.task` modifier — avoids adding `ImageIO` dependency to the feature package. Only shown for `.images` category entries, suppressed when conflict/large/duplicate badges are present to avoid visual noise

### [P3-3] 边界条件测试 ✅ (2026-05-11)
- **Scanner boundary tests (12 new)**:
  - Symlink to file resolved, symlink to outside directory skipped
  - Uppercase extensions (.PNG, .MP4, .PDF) classified correctly
  - File with no extension → `.other`
  - Deep nesting (5 levels) with recursive scan
  - Filenames with spaces, unicode, multiple dots
  - 500-file performance test
  - Duplicate filenames in different subdirs
  - Tilde path expansion
  - Empty folder list
- **Classifier boundary tests (9 new)**:
  - Rule with destinationSubfolder
  - Rule matching either extension OR name pattern
  - Case-insensitive extension matching (.PNG == png)
  - Rule with empty patterns matches nothing
  - Rule with both min and max size
  - Filename with special characters preserved in destination
  - Trailing slash in destination base path
  - Name pattern as substring match
  - 500-entry performance test
- **Tests**: 75/75 total passing (64 adapter + 11 feature), zero failures
