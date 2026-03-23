# Open-Source Competitor Research — 2026-03-21

## Objective

Research open-source competitors relevant to `Atlas for Mac` and compare them against Atlas from two angles:

- feature overlap with the frozen MVP
- technical patterns worth copying, avoiding, or tracking

This report is scoped to Atlas MVP as defined in [PRD.md](../PRD.md): `Overview`, `Smart Clean`, `Apps`, `History`, `Recovery`, `Permissions`, and `Settings`. Deferred items such as `Storage treemap`, `Menu Bar`, and `Automation` are treated as adjacent references, not MVP targets.

## Method

- Internal product/architecture baseline:
  - [PRD.md](../PRD.md)
  - [Architecture.md](../Architecture.md)
  - [Smart-Clean-Execution-Coverage-2026-03-09.md](./Smart-Clean-Execution-Coverage-2026-03-09.md)
- External research date:
  - All GitHub and SourceForge metadata in this report was checked on `2026-03-21`.
- External research workflow:
  - 2 focused web searches to identify the relevant open-source landscape
  - deep reads of the most representative projects: `Mole`, `Pearcleaner`, `Czkawka`
  - repo metadata, release metadata, license files, and selected source files for technical verification

## Middle Findings

- There is no single open-source product that matches Atlas's intended combination of `native macOS UI + explainable action plan + history + recovery + permission guidance`.
- The market is fragmented:
  - `Mole` is the closest breadth benchmark for cleanup depth and developer-oriented coverage.
  - `腾讯柠檬清理 / lemon-cleaner` is the closest native-GUI breadth benchmark from the Chinese Mac utility ecosystem.
  - `Pearcleaner` is the strongest open-source benchmark for app uninstall depth on macOS.
  - `Czkawka` is the strongest reusable file-analysis engine pattern, but it is not a Mac maintenance workspace.
  - `GrandPerspective` is the strongest adjacent open-source reference for storage visualization, but Atlas has explicitly deferred treemap from MVP.
- Licensing is a major strategic boundary:
  - `Mole` uses `MIT`, which aligns with Atlas's current reuse strategy.
  - `Pearcleaner` is `Apache 2.0 + Commons Clause`, so it is source-available but not a safe upstream for monetized derivative shipping.
  - `Czkawka` mixes `MIT` and `GPL-3.0-only` depending on component.
  - `GrandPerspective` is `GPL`.
- Atlas's strongest differentiation is architectural trust. Atlas's current weakest point is breadth of release-grade executable cleanup compared with how broad `Mole` already looks to users.

## Executive Summary

If Atlas wants to win in open source, it should not position itself as "another cleaner." That lane is already occupied by `Mole` on breadth and `Pearcleaner` on uninstall specialization. Atlas's credible lane is a `native macOS maintenance workspace` with structured worker/helper boundaries, honest permission handling, and recovery-first operations.

The biggest threat is not that an open-source competitor already matches Atlas end to end. The threat is that users may compare Atlas's current MVP against a combination of `Mole + Pearcleaner + GrandPerspective/Czkawka` and conclude Atlas is cleaner in design but behind in raw capability. That makes execution credibility, uninstall depth, and product messaging more important than adding new surface area.

The one important omission in an open-source-only Mac comparison would be `腾讯柠檬清理 / Tencent lemon-cleaner`, because it is both open-source and closer than most projects to a native GUI maintenance suite. Atlas should treat it as a real comparison point, especially for Chinese-speaking users.

## Landscape Map

| Project | Type | Why it matters to Atlas | Current signal |
| --- | --- | --- | --- |
| `tw93/Mole` | Direct breadth competitor | Closest open-source "all-in-one Mac maintenance" positioning | Very strong community and recent release activity |
| `Tencent/lemon-cleaner` | Direct breadth competitor | Closest open-source native GUI maintenance suite, especially relevant in Chinese market | Established product and recognizable feature breadth |
| `alienator88/Pearcleaner` | Direct module competitor | Strongest open-source benchmark for `Apps` uninstall depth on macOS | Strong adoption, but maintainer bandwidth is constrained |
| `qarmin/czkawka` | Adjacent engine competitor | Best open-source file hygiene / duplicate / temporary-file engine pattern | Mature and active, but not macOS-native |
| `GrandPerspective` | Adjacent UX competitor | Best open-source reference for storage visualization / treemap | Active, but outside Atlas MVP scope |
| `sanketk2020/MacSpaceCleaner` | Emerging minor competitor | Shows appetite for lightweight native Mac cleaners | Low maturity; not a primary benchmark |

## Functional Comparison

Legend:

- `Strong` = clear product strength
- `Partial` = present but narrower or less central
- `No` = not a meaningful capability

| Capability | Atlas for Mac | Mole | Lemon | Pearcleaner | Czkawka | GrandPerspective |
| --- | --- | --- | --- | --- | --- | --- |
| Broad junk / cache cleanup | Partial | Strong | Strong | Partial | Partial | No |
| App uninstall with leftovers | Strong | Strong | Strong | Strong | No | No |
| Developer-oriented cleanup | Strong | Strong | Partial | Partial | Partial | No |
| Disk usage analysis | Partial | Strong | Strong | No | Partial | Strong |
| Live health / system status | Partial | Strong | Strong | No | No | No |
| History / audit trail | Strong | Partial | Low | No | No | No |
| Recovery / restore model | Strong | Partial | No | No | No | No |
| Permission guidance UX | Strong | Low | Partial | Partial | Low | Low |
| Native macOS GUI | Strong | No | Strong | Strong | Partial | Strong |
| CLI / automation surface | Partial | Strong | Low | Partial | Strong | No |

### Notes Behind The Table

- Atlas:
  - Atlas is strongest where it combines cleanup with `History`, `Recovery`, and `Permissions`.
  - Atlas already has real `Apps` list / preview uninstall / execute uninstall flows in the current architecture and protocol, with recovery-backed app uninstall behavior; the remaining question is depth and polish versus Pearcleaner, not whether the module exists.
  - Per [Smart-Clean-Execution-Coverage-2026-03-09.md](./Smart-Clean-Execution-Coverage-2026-03-09.md), real Smart Clean execution is still limited to a safe structured subset. So Atlas's cleanup breadth is not yet at `Mole` level.
- Mole:
  - Mole covers `clean`, `uninstall`, `optimize`, `analyze`, `status`, `purge`, and `installer`, which is broader than Atlas's current release-grade execution coverage.
  - Mole exposes JSON for some commands and has strong dry-run patterns, but it does not center recovery/history as a product promise.
- Lemon:
  - Lemon combines deep cleaning, large-file cleanup, duplicate cleanup, similar-photo cleanup, privacy cleaning, app uninstall, login-item management, and status-bar monitoring in one native Mac app.
  - It is a much more direct GUI comparison than Mole for users who expect a polished desktop utility instead of a terminal-first tool.
- Pearcleaner:
  - Pearcleaner is deep on `Apps`, but it is not a full maintenance workspace.
  - It extends beyond uninstall into Homebrew, PKG, plugin, services, and updater utilities.
- Czkawka:
  - Czkawka is powerful for duplicate finding, big files, temp files, similar media, broken files, and metadata cleanup.
  - It is not a Mac workflow app and does not cover uninstall, permissions guidance, or recovery.
- GrandPerspective:
  - Very strong for treemap-based disk visualization.
  - It is analysis-first, not cleanup-orchestration-first.

## Technical Comparison

| Area | Atlas for Mac | Mole | Lemon | Pearcleaner | Czkawka | GrandPerspective |
| --- | --- | --- | --- | --- | --- | --- |
| App shape | Native macOS app | CLI / TUI plus scripts | Native macOS app | Native macOS app | Cross-platform workspace | Native macOS app |
| Main stack | SwiftUI + AppKit bridges + XPC/helper | Shell + Go | Objective-C/Cocoa + Xcode workspace + pods | SwiftUI + AppKit + helper targets | Rust workspace with core/CLI/GTK/Slint frontends | Cocoa / Objective-C / Xcode project |
| Process boundary | App + worker + privileged helper | Mostly single local toolchain | App plus multiple internal modules/daemons | App + helper + Finder extension + Sentinel monitor | Shared core with multiple frontends | Single app process |
| Privileged action model | Structured helper boundary | Direct shell operations with safety checks | Native app cleanup modules; license files indicate separate daemon licensing | Privileged helper plus Full Disk Access | Mostly user-space file operations | Read/analyze oriented |
| Recoverability | Explicit product-level recovery model | Safety-focused, but not recovery-first | No clear recovery-first model | No clear recovery-first model | No built-in recovery model | Not applicable |
| Auditability | History and structured recovery items | Operation logs | No first-class history model | No first-class history model | No first-class history model | Not applicable |
| Packaging | `.zip`, `.dmg`, `.pkg`, direct distribution | Homebrew, install script, prebuilt binaries | Native app distribution via official site/App ecosystem | DMG/ZIP/Homebrew cask | Large prebuilt binary matrix | SourceForge / App Store / source tree |
| License shape | MIT, with attribution for reused upstream code | MIT | GPL v2 for daemon, GPL v3 for most other modules | Apache 2.0 + Commons Clause | Mixed: MIT plus GPL-3.0-only for some frontends | GPL |

## Competitor Deep Dives

### 1. Mole

#### Why it matters

`Mole` is the closest open-source breadth competitor and also Atlas's most important upstream-adjacent reference. It markets itself as an all-in-one Mac maintenance toolkit and already bundles many of the comparisons users naturally make against commercial utilities.

#### What it does well

- Broad feature surface in one install:
  - cleanup
  - app uninstall
  - disk analyze
  - live status
  - project artifact purge
  - installer cleanup
- Strong developer-user fit:
  - Xcode and Node-related cleanup are explicitly called out
  - `purge` is a strong developer-specific wedge
- Safe defaults are well communicated:
  - dry-run
  - path validation
  - protected directories
  - explicit confirmation
  - operation logs
- Good automation posture:
  - `mo analyze --json`
  - `mo status --json`

#### Technical takeaways

- Repo composition is pragmatic rather than layered:
  - heavy Shell footprint
  - Go core dependencies including `bubbletea`, `lipgloss`, and `gopsutil`
- Distribution is optimized for speed and reach:
  - Homebrew
  - shell install script
  - architecture-specific binaries
- Safety is implemented inside one local toolchain, not via an app-worker-helper separation.

#### Weaknesses relative to Atlas

- Terminal-first experience limits mainstream Mac adoption.
- Product trust is based on careful scripting and dry-run, not on a native explainable workflow with recovery.
- History, audit, and restore are not a first-class user-facing value proposition.

#### Implication for Atlas

`Mole` should be treated as Atlas's primary benchmark for `Smart Clean` breadth and developer-oriented cleanup coverage. Atlas should not try to beat Mole on shell ergonomics. Atlas should beat it on:

- explainability
- permissions UX
- structured execution boundaries
- history / recovery credibility
- native product polish

### 2. Pearcleaner

#### Why it matters

`Pearcleaner` is the strongest open-source benchmark for Atlas's `Apps` module. It is native, widely adopted, and much deeper on uninstall-adjacent workflows than most open-source Mac utilities.

#### What it does well

- Strong uninstall-centered feature cluster:
  - app uninstall
  - orphaned file search
  - file search
  - Homebrew manager
  - PKG manager
  - plugin manager
  - services manager
  - updater
- Native platform integrations:
  - Finder extension
  - helper target
  - Sentinel monitor for automatic cleanup when apps hit Trash
  - CLI support and deep-link automation
- Clear macOS assumptions:
  - Full Disk Access required for search
  - privileged helper required for system-folder actions

#### Technical takeaways

- Repo structure shows native macOS product thinking:
  - `Pearcleaner.xcodeproj`
  - `Pearcleaner`
  - `PearcleanerHelper`
  - `PearcleanerSentinel`
  - `FinderOpen`
- Source confirms a SwiftUI app entrypoint:
  - `import SwiftUI`
  - `@main struct PearcleanerApp: App`
- Helper code confirms XPC-like privileged helper behavior with code-sign validation before accepting client requests.

#### Weaknesses relative to Atlas

- It is not a full maintenance workspace.
- No strong user-facing recovery/history model.
- Maintainer note in the README says updates slowed due to limited spare time, which is a maintainability risk.
- Licensing is a hard boundary:
  - Apache 2.0 with Commons Clause prevents monetized derivative use.

#### Implication for Atlas

For `Apps`, Atlas should benchmark against Pearcleaner rather than against generic cleaners. The gap to close is not "can Atlas delete apps" but:

- uninstall footprint depth
- service / launch item cleanup coverage
- package-manager and installer awareness
- native workflow polish

Atlas should not depend on Pearcleaner code for shipped product behavior due license constraints.

### 3. Tencent Lemon Cleaner

#### Why it matters

`Tencent/lemon-cleaner` is one of the most relevant omissions if Atlas only compares itself with Western or terminal-first open-source tools. It is a native macOS maintenance utility with broad GUI feature coverage and obvious overlap with what many users expect from a Mac cleaning app.

#### What it does well

- Broad native GUI utility bundle:
  - deep scan cleanup
  - large-file cleanup
  - duplicate-file cleanup
  - similar-photo cleanup
  - browser privacy cleanup
  - app uninstall
  - startup item management
  - status-bar monitoring
  - disk space analysis
- Product positioning is close to mainstream cleaner expectations:
  - one-click cleaning
  - software-specific cleanup rules
  - real-time device status in menu bar / status area
- Chinese-market relevance is high:
  - the README and official site are aimed directly at Chinese macOS users and their cleanup habits

#### Technical takeaways

- Repo structure is a classic native Mac app workspace:
  - `Lemon.xcodeproj`
  - `Lemon.xcworkspace`
  - multiple feature modules such as `LemonSpaceAnalyse`, `LemonUninstaller`, `LemonPrivacyClean`, `LemonLoginItemManager`, and `LemonCleaner`
- The repository is primarily `Objective-C` and keeps a separate daemon license file.
- This is a good example of a feature-suite style monolithic Mac utility rather than Atlas's more explicitly layered app/worker/helper model.

#### Weaknesses relative to Atlas

- No visible recovery-first promise comparable to Atlas.
- No obvious user-facing history/audit model.
- Architecture appears more utility-suite oriented than trust-boundary oriented.
- License is restrictive for Atlas reuse:
  - GPL v2 for the daemon
  - GPL v3 for most other modules

#### Implication for Atlas

Lemon is a direct product benchmark, especially for:

- native GUI breadth
- large-file / duplicate / privacy / startup-item utility coverage
- Chinese-language market expectations

Atlas should study Lemon as a product benchmark, but not as a code-reuse candidate.

### 4. Czkawka

#### Why it matters

`Czkawka` is not a direct Mac maintenance workspace competitor, but it is the strongest open-source reference for fast multi-platform file analysis and cleanup primitives.

#### What it does well

- High-performance file hygiene coverage:
  - duplicates
  - empty files/folders
  - big files
  - temp files
  - similar images/videos
  - broken files
  - Exif remover
  - video optimizer
- Strong engineering posture:
  - memory-safe Rust emphasis
  - reusable `czkawka_core`
  - CLI plus multiple GUI frontends
  - explicit note that it does not collect user data or access the Internet
- Platform strategy is mature:
  - macOS, Linux, Windows, FreeBSD, Android

#### Technical takeaways

- Workspace composition is clear:
  - `czkawka_core`
  - `czkawka_cli`
  - `czkawka_gui`
  - `krokiet`
  - `cedinia`
- The newer `Krokiet` frontend is built in `Slint` because the maintainer found GTK inconsistent and high-friction on Windows and macOS.
- This is a strong example of separating reusable scan logic from frontends.

#### Weaknesses relative to Atlas

- It is not macOS-native in product feel.
- It does not cover uninstall, permissions workflow, history, or restore semantics.
- Mixed licensing matters:
  - core/CLI/GTK app are MIT
  - `Krokiet` and `Cedinia` are GPL-3.0-only due Slint-related restrictions

#### Implication for Atlas

`Czkawka` is best used as an engineering reference, not as a product model. Atlas can learn from:

- reusable core logic boundaries
- fast scanning primitives
- cross-front-end separation

Atlas should avoid importing GPL-constrained UI paths into shipping code.

### 5. GrandPerspective

#### Why it matters

`GrandPerspective` is not an MVP competitor but it is the clearest open-source reference for treemap-based storage visualization on macOS.

#### What it does well

- Strong single-purpose focus:
  - visual treemap disk usage analysis
- Mature native Mac implementation:
  - `GrandPerspective.xcodeproj`
  - `main.m`
- Still active:
  - SourceForge tree shows commits in January and February 2026 and a `3.6.3` version update in January 2026.

#### Weaknesses relative to Atlas

- It is an analyzer, not a cleanup workspace.
- GPL license makes it unattractive for direct reuse in Atlas.

#### Implication for Atlas

Keep `GrandPerspective` as a post-MVP reference for `Storage treemap` only. Do not let it pull Atlas out of frozen MVP scope without an explicit product decision update.

### 6. Watchlist: MacSpaceCleaner

`MacSpaceCleaner` is useful as a signal, not as a primary benchmark.

- Positives:
  - native Swift-based Mac utility
  - MIT licensed
  - explicit developer/Xcode cleanup slant
- Limitations:
  - only `136` GitHub stars on `2026-03-21`
  - much weaker ecosystem signal than Mole, Pearcleaner, or Czkawka
  - repository structure is less mature and less informative

It is worth monitoring for specific ideas, but it should not drive Atlas roadmap decisions.

## What Atlas Is Actually Competing With

The real competitive picture is not one app. It is a user assembling a toolkit:

- `Mole` for broad cleanup and monitoring
- `Lemon` for native GUI all-in-one cleanup expectations
- `Pearcleaner` for uninstall depth
- `GrandPerspective` or similar tools for disk visualization
- `Czkawka` for duplicate / large-file hygiene

That means Atlas wins only if it makes the integrated workflow meaningfully safer and easier than stitching together multiple specialist tools.

## Strategic Implications For Atlas

### 1. Atlas should own the trust architecture lane

This is the strongest differentiator that the current open-source set does not combine well:

- explainable findings
- structured worker/helper boundary
- visible permission rationale
- history
- recoverable actions

### 2. `Smart Clean` breadth is the highest product risk

Per [Smart-Clean-Execution-Coverage-2026-03-09.md](./Smart-Clean-Execution-Coverage-2026-03-09.md), Atlas currently executes a safe structured subset of targets. That is honest and correct, but it also means Atlas can lose obvious comparisons to `Mole` unless release messaging stays precise and execution coverage expands.

### 3. `Apps` depth should be benchmarked against Pearcleaner, not generic cleaners

Atlas already includes app uninstall flows, but the market standard for open-source Mac uninstall depth is closer to Pearcleaner's footprint search, services/package awareness, and native integrations.

### 4. License hygiene must stay strict

- `Mole` is the only clearly safe major upstream from this set for Atlas's current MIT-oriented posture.
- `Lemon`, `GrandPerspective`, and parts of `Czkawka` carry GPL constraints and should be treated as product/UX references, not casual reuse candidates.
- `Pearcleaner` and `GrandPerspective` should be treated as product references, not code reuse candidates.
- `Czkawka` components need per-component license review before any adaptation.

### 5. Deferred scope must stay deferred

`GrandPerspective` makes storage treemap look attractive, but Atlas has explicitly deferred `Storage treemap` from MVP. The correct move is to use it as future design reference, not as a reason to reopen MVP.

## Recommended Next Steps

- Product:
  - Position Atlas explicitly as an `explainable, recovery-first Mac maintenance workspace`, not just a cleaner.
- Smart Clean:
  - Expand release-grade execution coverage on the categories users will compare most directly with Mole: caches, developer artifacts, and high-confidence junk roots.
- Apps:
  - Run a gap review against Pearcleaner feature depth for uninstall leftovers, services, package artifacts, and automation entry points.
- Architecture:
  - Keep leaning into worker/helper and structured recovery. That is Atlas's most defensible open-source differentiation.
- Messaging:
  - Be exact about what runs for real today. Over-claiming breadth would erase Atlas's trust advantage.

## Sources

### Internal Atlas docs

1. [PRD.md](../PRD.md)
2. [Architecture.md](../Architecture.md)
3. [Smart-Clean-Execution-Coverage-2026-03-09.md](./Smart-Clean-Execution-Coverage-2026-03-09.md)

### Mole

1. [tw93/Mole](https://github.com/tw93/Mole)
2. [Mole README](https://raw.githubusercontent.com/tw93/Mole/main/README.md)
3. [Mole go.mod](https://raw.githubusercontent.com/tw93/Mole/main/go.mod)
4. [Mole latest release `V1.30.0` published on 2026-03-08](https://github.com/tw93/Mole/releases/tag/V1.30.0)

### Pearcleaner

1. [alienator88/Pearcleaner](https://github.com/alienator88/Pearcleaner)
2. [Pearcleaner README](https://raw.githubusercontent.com/alienator88/Pearcleaner/main/README.md)
3. [Pearcleaner app entrypoint](https://github.com/alienator88/Pearcleaner/blob/main/Pearcleaner/PearcleanerApp.swift)
4. [Pearcleaner helper entrypoint](https://github.com/alienator88/Pearcleaner/blob/main/PearcleanerHelper/main.swift)
5. [Pearcleaner license](https://github.com/alienator88/Pearcleaner/blob/main/LICENSE.md)
6. [Pearcleaner latest release `5.4.3` published on 2025-11-26](https://github.com/alienator88/Pearcleaner/releases/tag/5.4.3)

### Lemon

1. [Tencent/lemon-cleaner](https://github.com/Tencent/lemon-cleaner)
2. [Lemon README](https://raw.githubusercontent.com/Tencent/lemon-cleaner/master/README.md)
3. [腾讯柠檬清理官网](https://lemon.qq.com)

### Czkawka

1. [qarmin/czkawka](https://github.com/qarmin/czkawka)
2. [Czkawka README](https://raw.githubusercontent.com/qarmin/czkawka/master/README.md)
3. [Czkawka Cargo workspace](https://github.com/qarmin/czkawka/blob/master/Cargo.toml)
4. [Krokiet README](https://github.com/qarmin/czkawka/blob/master/krokiet/README.md)
5. [Czkawka latest release `11.0.1` published on 2026-02-21](https://github.com/qarmin/czkawka/releases/tag/11.0.1)

### GrandPerspective

1. [GrandPerspective SourceForge source tree](https://sourceforge.net/p/grandperspectiv/source/ci/master/tree/)

### MacSpaceCleaner

1. [sanketk2020/MacSpaceCleaner](https://github.com/sanketk2020/MacSpaceCleaner)
2. [MacSpaceCleaner README](https://raw.githubusercontent.com/sanketk2020/MacSpaceCleaner/main/README.md)
