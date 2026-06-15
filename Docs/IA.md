# Information Architecture

## Primary Navigation

Sidebar is grouped into two labeled sections plus a docked tail (Calm Ledger v3, spec §2.1):

- **Work**
  - `Overview`
  - `Smart Clean`
  - `File Organizer`
  - `Apps`
- **Records**
  - `Ledger` (was `History`; zh 台账, en Ledger)
  - `Permissions`
- **Docked tail**
  - `Settings`
  - `About`

> The `Startup` module's sidebar slot remains contingent on a separate D-010 update and must not ship before that approval (spec §0.3). `Storage` remains scaffolded at the package layer and is not in the sidebar.

## MVP Navigation Notes

- `Ledger` is the renamed `History` module — it holds recovery entry points, numbered plans (№), restore points, and the archive of past runs. Package name `AtlasFeaturesHistory` is retained; only the user-facing name and route identifier changed (D-012).
- `About` is the split-out acknowledgements / version / update-check surface (formerly a section of `Settings`).
- `File Organizer` is recognized as an in-scope production module (shipped in v1.0.8, D-012).
- `Storage` remains scaffolded at the package layer but is not part of the app shell sidebar.

## Screen Responsibilities

> Rewritten per Calm Ledger v3 spec §3. Warm-paper surfaces are confined to the Ledger screen and the per-plan receipt view; all other screens use the cool work surface.

### Overview

- Greeting + status capsule row (disk / restore points / permissions)
- "Next step" recommendation banner (priority table, spec §3)
- Left: command deck — health ring + module entry rows
- Right: ledger stream — recent 3–5 № entries (warm-paper cards), each tappable into the Ledger

### Smart Clean

- Full work-module skeleton (spec §2.3): title + plan № subtitle + stage bar + list region + evidence panel + docked action bar
- Four-stage state machine: ① scan → ② review → ③ execute → ④ receipt
- Filter chips: All / Safe / Review / Advanced + category
- Evidence panel includes source-signature provenance
- Receipt (④) links into the global Ledger

### File Organizer

- Full work-module skeleton. Five stages: ① scan → ② rules → ③ dry-run preview → ④ execute → ⑤ receipt
- "Rules" stage main area is a rule editor; evidence panel answers "why is this file classified as X"
- Preview = current dry-run; list shows intended moves + conflict markers

### Apps

- Simplified skeleton (no stage bar)
- Per-app single-select (no batch uninstall — regression red line)
- List: app rows (icon / name / mono size / leftover badge)
- Evidence panel: 10-category footprint + uninstall-plan preview + leftover estimate
- Action bar surfaces only when an app is selected and an uninstall plan is ready

### Ledger (was History)

- Warm-paper full page. serif title + "Export Report" (footer note: "本报告由 Atlas 在本机生成，仅供个人参考")
- Stats row + filter chips (recoverable / all / archived)
- Left: timeline (in-progress pinned to top); right: detail panel (mono execution data + included-items list + restore-all / restore-item + stamp watermark variant)
- Bottom: "earlier archive" collapsible

### Permissions

- Progress-ring hero + permission rows
- Per-row three-section evidence expansion: why needed / impact scope / how to authorize
- Limited-mode callout re-skinned

### Settings

- Three-section tabs retained. Recovery section strengthened: retention days + exclusion paths + recovery-zone occupancy (mono). Trust section retained + document sheet re-skinned (spec §3.1)

### About

- Re-skin only (version mono, QR code, update check)

## Global Surfaces

- Toolbar search (per-screen list/timeline filtering; disabled during scan/execute — not a global cross-screen search)
- Scan-receipt chip (hidden when no receipt exists; spec §2.1)
- Task center bell (badge retained; re-skinned, "Open History" CTA → "Open Ledger", running tasks prefixed with №)
- Stage bar (shared across Smart Clean / File Organizer work modules, spec §2.3)
- Evidence panel (resident in work modules; collapses to a non-modal drawer below 880pt content width, spec §2.4)
- Action bar (docked dark surface; status-driven promise text + mono totals; shrinks to primary button + stamp below 740pt)
- Confirmation sheets
- AtlasErrorState (inline + full variants; row-level failure variant in execute stage)
- Permission explainer sheet
