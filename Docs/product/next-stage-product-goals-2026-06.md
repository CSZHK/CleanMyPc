# Atlas for Mac — Next-Stage Product Goals

- **Date**: 2026-06-05
- **Status**: Draft — Product Strategy Review
- **Scope**: Post-MVP Phase 2 planning (after EPIC-A through EPIC-C delivery)
- **Baseline**: v1.0.8 stable, 377 tests, all MVP modules production-ready
- **Author**: Product Analysis (claude.ai/code)

---

## 1. Current Product State

### 1.1 Delivered Capability Matrix

| Module | Status | Lines | Tests | Key Capability |
|--------|--------|-------|-------|----------------|
| Overview | Production | 432 | 9 | Dashboard, system metrics, recommendations, activity |
| Smart Clean | Production | 714 | 11 | Scan → classify → plan → execute, risk-based, undo |
| Apps | Production | 925 | 10+ | 10-category evidence model, fingerprint verification, v2 schema |
| File Organizer | Production | 940 | 75 | Rule engine, conflict detection, undo, thumbnail cache |
| History | Production | 1390 | 9 | Recovery items, schema migration (v1→v2), evidence rendering |
| Permissions | Production | 337 | 9 | System permission scanning, status chips, conditional callouts |
| Settings | Production | 342 | 9 | Theme switching, language picker, persistence |
| Storage | Placeholder | 51 | Minimal | Summary view only |
| About | Production | 217 | 2 | App info, version check, social QR codes |

**Design System**: 12+ components (Skeleton, Toast, UndoBanner, FilterChip, SegmentedControl, Tooltip), bilingual (zh-Hans + en).

### 1.2 Roadmap Progress

| Milestone | Target | Status |
|-----------|--------|--------|
| M1: Internal Beta Hardening | Execution truthfulness | Done |
| M2: Apps Evidence Execution | 10-category evidence model | Done (v1.0.8) |
| M3: Smart Clean Coverage | Safe-root expansion | Done |
| M4: Recovery Payload Hardening | Versioned schema, migration | Done |
| M5: Release Readiness | Signing, automation | Blocked (signing credentials) |
| Conditional A-C: External Beta → GA | Signed distribution | Blocked (signing credentials) |

**Current blocker**: Apple Developer ID signing and notarization credentials unavailable. Product path is complete; release path is gated externally.

### 1.3 Strategic Position (per Competitive-Strategy-Plan-2026-03-21)

Atlas positions as a **trust-first native Mac maintenance workspace** with three strategic pillars:

1. **Trust Moat** — recovery-first, explainable, fail-closed, auditable
2. **Selective Parity** — close visible gaps in Smart Clean and Apps without breadth racing
3. **Visible Differentiation** — make trust architecture apparent in UI, not just code

**No-Go boundaries (D-010)**: Storage treemap, Menu Bar, Automation remain frozen unless decision log is updated explicitly.

### 1.4 Known Gaps

- **Storage** module is a placeholder (51 lines)
- **Toast** and **Tooltip** components defined but unused in views
- No E2E integration tests (unit + view tests only)
- No signed/notarized distribution path yet
- No public beta or GA artifacts

---

## 2. Market & User Pain Point Analysis

### 2.1 Competitive Landscape

| Competitor | Type | Strengths | Weaknesses |
|------------|------|-----------|------------|
| **CleanMyMac** (MacPaw) | Paid subscription | Market leader, all-in-one breadth, Apple-notarized | Cluttered new UI, features removed in new version, subscription fatigue, "snake oil" perception |
| **Tencent Lemon** | Free (China market) | Native GUI breadth, large-file/duplicate/privacy/startup items | Trust concerns, not developer-aware |
| **Pearcleaner** | Open source | Uninstall depth, macOS-native integration | Limited scope beyond uninstall |
| **Mole** (tw93) | Open source CLI | Developer cleanup, automation, breadth | CLI-only, no GUI, no recovery |
| **DaisyDisk** | Paid one-time | Visual storage treemap, fast scanning | Single-purpose, no cleanup/management |
| **OnyX** | Free | Deep maintenance scripts, hidden settings | Technical UI, no guidance, risky for non-experts |
| **Sensei** | Paid | Performance monitoring + cleaning | Niche, limited distribution |

### 2.2 High-Frequency User Pain Points (from community research)

| Pain Point | Frequency | Current Solutions | Gap |
|------------|-----------|-------------------|-----|
| Apps silently add to Login Items / LaunchAgents | Very High | System Settings (limited), `launchctl` (CLI only) | No good GUI that shows ALL items (including hidden LaunchAgents/Daemons) with clear management |
| Xcode/Simulator/Docker bloat accumulation | High (developers) | Manual cleanup, Mole CLI | No GUI tool with recovery for developer caches |
| Subscription fatigue for cleaning tools | High | Free alternatives (OnyX, AppCleaner) | No premium one-time-purchase alternative with trust architecture |
| Trust deficit — "is this app snake oil?" | High | Word of mouth, Apple notarization | No tool that visibly explains every action and proves recovery |
| Hidden system clutter (caches, logs, old updates) | Medium | CleanMyMac, OnyX | Atlas already covers this; gap is awareness |
| Storage visualization — "what's eating my disk?" | Medium | DaisyDisk, GrandPerspective | Not integrated with cleanup workflow |
| Privacy — what apps access camera/mic/location? | Growing | Apple Privacy Report (limited) | No third-party tool explains permission footprint well |

### 2.3 Market Signal Summary

1. **Trust is the #1 differentiator opportunity** — CleanMyMac's reputation is eroding; users actively seek transparent alternatives
2. **Startup/Login Item management is the most underserved pain point** — no good native GUI exists
3. **Developer cleanup is a growing niche** — Mole proves demand exists but offers no GUI
4. **Subscription fatigue is real** — users prefer one-time purchases or truly free tools
5. **Community values lightweight over bloated** — Reddit/MacRumors consistently favor minimal, transparent tools

---

## 3. Candidate Goals Evaluation (ICE Framework)

### Scoring Criteria

- **Impact** (1-10): How many users does this help? How painful is the problem?
- **Confidence** (1-10): How certain are we this is the right direction? How well understood is the solution?
- **Ease** (1-10): How much existing architecture can we reuse? How complex is the implementation?

### Scoring Matrix

| # | Candidate Goal | Impact | Confidence | Ease | ICE Score |
|---|----------------|--------|------------|------|-----------|
| A | **Startup & Background Service Manager** | 9 | 7 | 7 | **441** |
| B | **Developer Deep Clean Toolkit** | 6 | 8 | 8 | **384** |
| C | **Storage Visualizer (Treemap)** | 9 | 6 | 3 | **162** |
| D | **Menu Bar Utility** | 6 | 7 | 6 | **252** |
| E | **Privacy & Permission Audit** | 8 | 5 | 5 | **200** |
| F | **Smart Automation (Trust-Gated)** | 7 | 5 | 6 | **210** |
| G | **Performance Monitor** | 5 | 7 | 6 | **210** |
| H | **Duplicate File Finder** | 6 | 4 | 4 | **96** |

### Scoring Rationale

**A. Startup & Background Service Manager (441)**
- Impact 9: Login items pain is universal, daily annoyance; users report apps re-adding themselves, hidden LaunchAgents invisible in System Settings
- Confidence 7: Technical paths well-understood (filesystem plists + ServiceManagement API), but product-market fit is unvalidated — no user survey, no beta feedback, no demand signal data. Web search anecdotes provide directional signal only. Requires pre-commitment user validation.
- Ease 7: Extends Smart Clean / Apps scan pattern; 4 startup-item layers with distinct privilege requirements; helper boundary needed for system-level items

**B. Developer Deep Clean Toolkit (384)**
- Impact 6: Developer segment is niche but high-value; MoleSmartCleanAdapter already covers many developer categories (DerivedData, npm, pnpm, Python, cargo, gradle, node_modules, pods, carthage, etc.) — the incremental value is smaller than it appears
- Confidence 8: Clear technical paths (Mole adapter exists); well-known cache locations; developer cleanup is a stated PRD differentiator
- Ease 8: MoleSmartCleanAdapter already classifies 20+ developer patterns; scan infrastructure proven; only genuinely new scan roots need wiring

**C. Storage Visualizer (162)**
- Impact 9: Visual storage analysis is a "wow" feature; DaisyDisk proves market demand
- Confidence 6: Treemap rendering in SwiftUI requires custom work; accessibility for treemap is non-trivial; no production SwiftUI treemap component exists
- Ease 3: Competing with DaisyDisk's 10+ years of custom rendering optimization (Metal/OpenGL); SwiftUI treemap at scale is unsolved; accessibility patterns undefined

**D. Menu Bar Utility (252)**
- Impact 6: Nice-to-have for daily engagement but not a purchase driver
- Confidence 7: MenuBar scaffold exists; macOS menu bar API is mature but has quirks with SwiftUI lifecycle
- Ease 6: Moderate complexity; need careful design to avoid resource-heavy perception

---

## 4. Top 3 Recommended Goals

### Recommendation 1: Startup & Background Service Manager

**Goal Description**

A new module that scans, explains, and manages all startup items, login items, LaunchAgents, and LaunchDaemons on the user's Mac. Users see every background service that runs automatically, understand what each one does, who installed it, and whether it's safe to disable or remove — with full recovery.

**ICE Score: 441** | **Priority: P0 (Phase 2)** | **Estimated Complexity: Medium-High**

**Target User Scenarios**

1. **Frustrated User**: "Why does my Mac take 2 minutes to boot? I disabled everything in System Settings but apps keep re-adding themselves."
   → Atlas shows all 47 startup items including the 12 hidden LaunchAgents System Settings doesn't display, with risk ratings and one-click disable.

2. **Security-Conscious User**: "I don't recognize half these background processes. Are they safe?"
   → Atlas explains each service: which app installed it, what it does, whether it's signed, and whether other users report it as safe.

3. **Developer**: "I installed Docker, Figma, and 10 other tools. Now I have 30 background services I don't understand."
   → Atlas groups services by installing app, shows resource impact, and lets the developer selectively disable without uninstalling.

**Success Metrics**

- % of users who discover hidden startup items they didn't know about
- Average startup items disabled per session
- Boot time improvement reported (before/after)
- Recovery success rate for disabled items
- Scan-to-action conversion rate

**Architecture Fit**

```
Extends:
  Smart Clean / Apps scan pattern (filesystem-based scanning + classification)
  AtlasDomain (Finding, ActionPlan models)
  AtlasProtocol (AtlasCommand extension — add ScanStartupItems, ManageStartupItem)
  AtlasInfrastructure (worker scanning)

Startup Item Layers (4 distinct privilege levels):
  Layer 1: ~/Library/LaunchAgents/*.plist
    → User-space, plist-based auto-start items
    → Can read + disable (unload via launchctl bootout) without helper
    → Most common layer, highest user visibility

  Layer 2: /Library/LaunchAgents/*.plist
    → System-level, admin-privileged auto-start items
    → Can read without helper; disable requires helper (admin privilege)
    → Installed by apps requesting system-wide auto-start

  Layer 3: /Library/LaunchDaemons/*.plist
    → System-level, root-owned background services
    → Can read without helper; disable requires helper (root privilege)
    → Often invisible to users; highest security relevance

  Layer 4: SMAppService API (macOS 13+)
    → Modern API-based registration (SMLoginItemManagerEnabled)
    → Query via ServiceManagement framework, not filesystem
    → Managed via SMAppService.loginItems(for:) or similar
    → Some apps use this instead of plist-based agents

Privilege Boundary:
  - Layer 1: Atlas worker handles directly (user-space)
  - Layer 2-3: Atlas helper required (elevated operations via existing helper boundary)
  - Layer 4: API query + user-space management
  - System items (Layer 2-3) shown as informational when helper unavailable

New:
  StartupScanAdapter → reads 4 layers (plist scanning + ServiceManagement API)
  StartupItem model → name, bundle, signer, installSource, layer, impact, riskLevel
  StartupFeatureView → list, group-by-app, explain, disable/enable with layer awareness

Reuses:
  scan → classify → explain → act pipeline (Smart Clean / Apps pattern)
  Risk-based grouping (Safe / Review / Advanced)
  Recovery-first execution (undo = re-enable via launchctl bootstrap or plist restore)
  History recording for all changes
  Existing helper boundary for Layer 2-3 elevated operations
```

**Estimated Complexity: Medium-High**
- New feature package: `AtlasFeaturesStartup`
- New domain models: `AtlasStartupItem`, `AtlasStartupCategory`
- New adapter: `StartupScanAdapter` (4 layers: filesystem plists + ServiceManagement API)
- New protocol commands: `ScanStartupItems`, `ManageStartupItem` (with layer-aware privilege routing)
- Helper integration: Layer 2-3 operations route through existing AtlasWorkerXPC helper boundary
- Recovery edge cases: apps that re-add LaunchAgents (e.g., Figma, Docker); disabled agents that break app functionality; plist conflicts during re-enable
- UI: ~700-900 lines (list + detail + explain + manage + layer indicators)
- Timeline: 3-4 weeks

---

### Recommendation 2: Developer Deep Clean Toolkit

**Goal Description**

Deepen the Smart Clean module with developer-specific cleanup categories: Xcode (DerivedData, Archives, Simulator data, Device Support files), Docker (unused images, containers, volumes, build cache), and language package manager caches (Homebrew, npm, pip, cargo, gem, Swift PM). Each category shows exact sizes, last-access times, and safe-to-clean recommendations with recovery.

**ICE Score: 384** | **Priority: P1 (Phase 2)** | **Estimated Complexity: Medium-Low**

**Target User Scenarios**

1. **iOS Developer**: "My Mac is full but I need to keep my current Xcode projects. What can I safely delete?"
   → Atlas shows: DerivedData (12 GB, last accessed 3 weeks ago, Safe to clean), Old Simulator runtimes (8 GB, iOS 15/16, Safe), Device Support files for 7 old iOS versions (4 GB, Safe). Total: 24 GB recoverable with recovery.

2. **Full-Stack Developer**: "Between Docker, Homebrew, and npm, I have 40 GB of caches."
   → Atlas categorizes by tool, shows what's actively used vs stale, and recommends cleanup with confidence scores. Docker dangling images (6 GB, no container references, Safe).

3. **Creative Developer**: "I switch between Xcode projects, Unity, and Flutter. My disk is always full."
   → Atlas shows build artifact accumulation across all tools, grouped by category and freshness.

**Success Metrics**

- Developer cache space reclaimed per session (target: >5 GB average)
- % of developers who discover caches they forgot about
- Xcode-specific cleanup adoption rate
- Recovery usage rate for developer cleanups (should be low = trust signal)

**Architecture Fit**

```
Extends:
  SmartCleanFeatureView (add "Developer" category filter)
  AtlasCoreAdapters/MoleSmartCleanAdapter (556 lines, already classifies 20+ developer patterns)
  AtlasInfrastructure (worker scan paths)

Already covered by MoleSmartCleanAdapter (classification + title detection):
  ~/Library/Developer/Xcode/DerivedData/*        → "Xcode DerivedData"
  ~/.npm/*, ~/_cacache/*                          → "npm cache" / "npm npx" / "npm logs"
  ~/Library/pnpm/store/*                          → "pnpm store"
  ~/__pycache__/*                                 → "Python bytecode cache"
  ~/.next/cache/*                                 → "Next.js build cache"
  ~/.oh-my-zsh/cache/*                            → "Oh My Zsh cache"
  Classification only (storageCategory): .cargo, .rustup, .gradle, .m2, .pyenv, .nvm,
    .poetry, .pip, .composer, .bundle, node_modules, Pods, Carthage, .vite, .turbo

Genuinely new scan roots (not yet covered by Mole clean script):
  ~/Library/Developer/Xcode/Archives/*            → Xcode release archives
  ~/Library/Developer/CoreSimulator/Devices/*     → iOS Simulator data
  ~/Library/Developer/Xcode/iOS DeviceSupport/*   → Old device support files
  ~/.docker/desktop/*                             → Docker Desktop data
  ~/Library/Containers/com.docker.docker/*         → Docker container volumes
  ~/Library/Caches/Homebrew/*                     → Homebrew download cache
  ~/.cache/pip/*                                  → pip package cache
  ~/.gem/cache/*                                  → Ruby gem cache

Reuses:
  Risk classification (Safe / Review / Advanced)
  Recovery-first model
  History and audit trail
  Scan → plan → execute pipeline
```

**Estimated Complexity: Medium-Low**
- No new feature package needed — extends Smart Clean
- MoleSmartCleanAdapter already classifies 20+ developer patterns — most work is scan root wiring, not new logic
- Genuinely new scan roots: ~8 paths (Docker, Simulator, Archives, Homebrew, pip, gem, DeviceSupport)
- UI: Filter chip addition + developer-specific summary cards
- Timeline: 1-2 weeks

---

### Recommendation 3: Storage Visualizer

**Goal Description**

Replace the placeholder Storage module with a visual treemap showing disk usage by category, folder, and file type. Users see where their storage is going at a glance, drill down into categories, and can take cleanup action directly from the visualization — bridging the gap between DaisyDisk's analysis and Atlas's cleanup workflow.

**ICE Score: 162** | **Priority: P1 (Phase 2, second half)** | **Estimated Complexity: High**

**Stepping-Stone Approach**

DaisyDisk has 10+ years of custom rendering optimization. Competing directly with a full treemap in v1 is high-risk. Instead, use a progressive approach:

| Phase | Visualization | Complexity | Accessibility | Timeline |
|-------|--------------|------------|---------------|----------|
| **2C-v1** | Sunburst / Ring Chart + Category Bars | Medium | Well-supported (linear reading order) | 2-3 weeks |
| **2C-v2** | Full Treemap (custom SwiftUI renderer) | High | Requires custom VoiceOver patterns | 3-4 additional weeks |

v1 delivers visual storage understanding with category drill-down and cleanup navigation. v2 adds treemap for power users.

**Target User Scenarios**

1. **Disk-Pressure User**: "My 256 GB MacBook is always full but I don't know what's using the space."
   → Atlas shows a treemap: 60 GB System, 45 GB Apps, 30 GB Media, 20 GB Developer caches, 15 GB Other. Tap "Developer caches" → jump to Smart Clean. Tap "Apps" → see uninstall candidates.

2. **Visual Thinker**: "I need to SEE what's on my disk, not just read numbers."
   → Atlas provides an interactive treemap with drill-down, similar to DaisyDisk but with integrated cleanup actions.

3. **Decision-Maker**: "I need to decide: delete old photos or clean caches? Show me the numbers."
   → Atlas shows category breakdowns with actionable cleanup suggestions per category.

**Success Metrics**

- Storage visualization engagement rate (% of users who interact)
- Drill-down-to-action conversion rate
- Average space identified vs average space reclaimed
- User satisfaction with storage understanding (qualitative)

**Architecture Fit**

```
Extends:
  StorageFeatureView (replace placeholder)
  AtlasDesignSystem (new visualization components)

New (v1 — Sunburst + Category Bars):
  StorageScanAdapter → fast directory traversal with size aggregation
  StorageNode model → hierarchical tree with sizes
  SunburstView → SwiftUI ring/arc chart (native PieChart or custom)
  CategoryBarView → horizontal stacked bars showing proportional storage
  Category mapper → map folders to Atlas categories (System, Apps, Media, Developer, Caches, Other)

New (v2 — Treemap, future iteration):
  TreemapView → custom SwiftUI squarified treemap renderer
  TreemapAccessibility → custom VoiceOver navigation patterns
  Metal/Canvas performance optimization for large volumes

Integration:
  Category tap → navigate to relevant module (Smart Clean, Apps, etc.)
  Bridge between visualization and cleanup action
```

**Estimated Complexity: High**
- New feature package: `AtlasFeaturesStorage` (full implementation)
- v1 (Sunburst + Bars): 2-3 weeks — achievable with SwiftUI Charts or custom ArcShape
- v2 (Treemap): 3-4 additional weeks — requires custom rendering, no production SwiftUI reference
- Fast directory scanning performance optimization (shared across v1/v2)
- Timeline: 2-3 weeks (v1) + 3-4 weeks (v2) = 5-7 weeks total

---

## 5. Phased Execution Plan

### Phase 2A: Startup & Background Service Manager (Week 1-4)

```
Week 0 (pre-commitment): User validation
  - Survey or interview 5-10 target users on startup item management pain
  - Confirm this is a purchase driver, not just a nice-to-have
  - If validation fails → skip to Phase 2B; reassess priorities

Week 1: Domain models + scan adapter
  - AtlasStartupItem, AtlasStartupCategory models (with layer field)
  - StartupScanAdapter Layer 1 (~/Library/LaunchAgents) + Layer 4 (SMAppService)
  - Unit tests for scan classification

Week 2: System-level layers + privilege routing
  - StartupScanAdapter Layer 2-3 (/Library/LaunchAgents, /Library/LaunchDaemons)
  - Helper integration for elevated read/disable operations
  - Risk classification (signed vs unsigned, system vs user)

Week 3: UI + recovery
  - StartupFeatureView (list, group-by-app, explain, manage)
  - Layer indicators in UI (user/system/root badge)
  - Recovery model (re-enable + plist backup for remove actions)
  - Recovery edge cases: re-adding apps, broken functionality warnings

Week 4: Integration + validation
  - Recovery verification tests
  - History integration
  - Gate review
```

### Phase 2B: Developer Deep Clean (Week 5-6)

```
Week 5: Genuinely new scan roots
  - Wire Docker, Simulator, Archives, DeviceSupport, Homebrew, pip, gem scan paths
  - (DerivedData, npm, pnpm, Python, Next.js, Oh My Zsh already covered by MoleSmartCleanAdapter)
  - Staleness classification enrichment for developer categories

Week 6: UI + validation
  - Smart Clean "Developer" filter chip
  - Developer-specific summary cards
  - Recovery testing for developer caches
  - Gate review
```

### Phase 2C: Storage Visualizer — Sunburst v1 (Week 7-9)

```
Week 7-8: Core visualization (Sunburst + Category Bars)
  - StorageScanAdapter (fast directory traversal)
  - SunburstView (SwiftUI ring chart)
  - CategoryBarView (horizontal stacked bars)
  - Category mapping to Atlas categories

Week 9: Integration + validation
  - Category tap → navigate to relevant module
  - Storage summary in Overview
  - Performance optimization for initial scan
  - Gate review
```

### Phase 2C-v2: Storage Visualizer — Treemap (Week 10-13, future iteration)

```
Week 10-12: Custom treemap renderer
  - Squarified treemap layout algorithm
  - SwiftUI custom drawing
  - Drill-down navigation

Week 13: Polish + validation
  - Custom VoiceOver accessibility patterns
  - Animation and interaction refinement
  - Performance optimization for large volumes (>500 GB)
  - Gate review
```

---

## 6. Decision Gate

### Decisions Required Before Execution

1. **D-010 Update**: Approve Startup & Background Service Manager as a new MVP module (currently outside frozen scope). Requires explicit decision log entry.

2. **D-010 Clarification**: Confirm Developer Deep Clean is an extension of Smart Clean (inside existing MVP flow) vs. a new module. Recommended: extend Smart Clean to avoid scope expansion.

3. **D-004 Revisit**: Storage Visualizer was explicitly deferred. Confirm readiness to start P1 work.

4. **Pre-commitment User Validation**: Before committing to Phase 2A (Startup module), run lightweight user validation — survey or interview with 5-10 target users — to confirm startup/login item management is a real purchase driver, not just a web-search anecdote. Confidence=7 reflects this gap.

5. **Resource Allocation**: Phase 2 runs in parallel with Release Readiness (EPIC-D) when signing credentials become available. Confirm priority order if both paths are active.

### Relationship to EPIC-D (Release Readiness)

`Docs/Backlog.md` §"Current Mainline Priority Order" mandates EPIC-D as the next mainline epic. Phase 2 is only appropriate while EPIC-D is externally blocked (missing signing credentials).

**Rules:**

| Condition | Action |
|-----------|--------|
| EPIC-D blocked (no signing credentials) | Phase 2 work may proceed |
| Signing credentials arrive during Phase 2 | Phase 2 **pauses immediately**; EPIC-D resumes with full priority |
| EPIC-D gate review passes | Phase 2 resumes from last checkpoint |
| Phase 2A-2C all complete before EPIC-D unblocks | EPIC-D proceeds normally |

**Checkpoint Protocol**: At the end of each Phase 2 sub-phase (2A, 2B, 2C), write a `.agent/per-*-progress.md` checkpoint so work can resume cleanly after an EPIC-D interruption.

### Verification Checklist

- [x] Recommendations align with competitive strategy (trust-first, selective parity)
- [x] No conflict with existing REQ/CHG — all current epics are complete
- [x] Technical feasibility confirmed — existing architecture supports all three goals
- [x] No-Go boundaries respected — no duplicate finder, no privacy-cleaning expansion, no GPL code reuse
- [x] ICE scores recalibrated after codebase evidence review (Startup 441, Developer 384, Storage 162)
- [ ] Decision D-010 update approved for Startup module
- [ ] Pre-commitment user validation completed for Startup module (5-10 target users)
- [ ] Phase 2 execution plan reviewed and accepted
- [ ] EPIC-D pause/resume rules acknowledged
- [ ] Resource allocation confirmed

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Startup module scope creep (trying to be a full process manager) | Medium | High | Strict scope: only manage auto-start items, not running processes |
| Developer cache locations change across macOS/Xcode versions | Low | Medium | Version-specific scan paths, graceful degradation |
| Treemap performance on large volumes (>1 TB) | Medium | Medium | Start with Sunburst v1 (simpler rendering); treemap deferred to v2 with progressive loading |
| Signing credentials arrive mid-Phase 2 | Medium | High | EPIC-D takes priority; Phase 2 pauses with checkpoint; resume from `.agent/per-*-progress.md` |
| Startup items management conflicts with macOS SIP | Low | High | Only manage user-space items (Layer 1); system items (Layer 2-3) shown as informational; SMAppService (Layer 4) via API only |
| Startup item validation fails (not a real user pain) | Medium | Medium | Pre-commitment user validation gate before Phase 2A; if invalid, skip to Phase 2B |
| Apps re-add LaunchAgents after disable (Figma, Docker) | High | Medium | Show "this app may re-enable itself" warning; offer scheduled re-check option |

---

## 8. Success Metrics (Phase 2 Overall)

| Metric | Target | Measurement |
|--------|--------|-------------|
| New modules shipped | 2 (Startup + Storage) | Release artifacts |
| Developer cache coverage | 6+ tool categories | Scan root count |
| Test coverage | >450 total tests (up from 377) | Test suite |
| User-visible new capability | Startup management + visual storage | Feature checklist |
| Competitive differentiation vs CleanMyMac | Transparent startup management, developer cleanup | Feature comparison |
| Recovery guarantee maintained | 100% of destructive actions recoverable | Recovery test suite |

---

## Appendix A: Sources

### Market Research
- [Macworld: Best Mac Cleaner Apps 2026](https://www.macworld.com/article/673271/best-mac-cleaner-tested-compared.html)
- [Reddit: Honest opinions on CleanMyMac X](https://www.reddit.com/r/mac/comments/1byybwm/question_discussion_what_is_everyones_honest/)
- [MacRumors: Is CleanMyMac legit or snake oil?](https://forums.macrumors.com/threads/is-cleanmymac-actually-legit-or-snake-oil.2476091/)
- [Setapp: Best Mac Cleaner Software](https://setapp.com/how-to/best-mac-cleaner-software)
- [VaultSort: Best Mac Cleaner Apps](https://www.vaultsort.com/blog/best-mac-cleaner-apps)
- [TheSweetBits: We Tested 20+ Mac Cleaner Apps](https://thesweetbits.com/best-mac-cleaner-software/)

### Internal Documents
- `Docs/PRD.md` — Product Requirements
- `Docs/ROADMAP.md` — Release Roadmap
- `Docs/Backlog.md` — Backlog and Epics
- `Docs/DECISIONS.md` — Decision Log (D-001 through D-011)
- `Docs/RISKS.md` — Risk Register
- `Docs/Execution/Competitive-Strategy-Plan-2026-03-21.md` — Competitive Strategy
- `Docs/Execution/Open-Source-Competitor-Research-2026-03-21.md` — Competitor Research
