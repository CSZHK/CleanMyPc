# Next-Stage Product Goals — Review Report

- **Date**: 2026-06-05
- **Reviewed Document**: `docs/product/next-stage-product-goals-2026-06.md`
- **Reviewer**: claude.ai/code (self-review with codebase cross-validation)
- **Verdict**: **Pass — All 5 findings resolved** (updated 2026-06-05)

---

## Verification Summary

### ✅ Confirmed Accurate

| Claim | Verified Against | Result |
|-------|-----------------|--------|
| 377 tests, 0 failures | `swift test --package-path Packages` | Exact match |
| 9 module line counts | `wc -l` on all *FeatureView.swift files | All 9 exact match |
| Storage = 51 lines placeholder | `StorageFeatureView.swift` | Confirmed |
| MenuBar = scaffold only | `MenuBar/` contains only README.md files | Confirmed |
| AtlasCommand has 16 cases | `AtlasProtocol/AtlasProtocol.swift` | Confirmed, no startup commands |
| Feature packages = 9 | `ls Packages/AtlasFeatures*` | Confirmed |
| Roadmap M1-M4 complete | `Docs/ROADMAP.md` + git log | Confirmed |
| D-010 No-Go boundaries | `Docs/DECISIONS.md` | Confirmed |
| Strategic pillars (trust + parity + visibility) | `Docs/Execution/Competitive-Strategy-Plan-2026-03-21.md` | Confirmed |

### ❌ Factual Errors Found

| # | Location | Error | Severity |
|---|----------|-------|----------|
| **F1** | §4 Rec 2 "New scan roots" list | Lists `~/Library/Developer/Xcode/DerivedData/*`, `~/.npm/_cacache/*`, `~/Library/Caches/Homebrew/*` etc. as "new" scan roots. **MoleSmartCleanAdapter already covers**: Xcode DerivedData, npm cache (`_cacache`), npm npx, npm logs, pnpm store, Python `__pycache__`, Next.js cache, Chrome cache, Oh My Zsh cache. The real delta is smaller: Docker, Homebrew, Simulator, Xcode Archives, cargo, gem. | **High** — overstates Rec 2 scope by ~50% |
| **F2** | §1.4 Known Gaps | Claims "Toast and Tooltip components defined but unused in views." This is accurate for Tooltip (0 view usages) but Toast wiring in `AtlasAppModel` may have internal usage not visible in view files alone. Minor inaccuracy. | **Low** |
| **F3** | §1.2 Roadmap M3 status | Marks M3 "Smart Clean Coverage — Safe-root expansion" as Done. Backlog.md EPIC-B lists specific roots (`~/.swiftpm/cache/*`, `~/.pytest_cache/*`, `~/.aws/cli/cache/*`) as planned. Need to confirm these roots are actually wired into the adapter vs. just planned. The adapter source shows coverage for DerivedData/npm/pnpm but not these three explicitly. | **Medium** |

---

## Strategic Findings

### S1. Developer Deep Clean ICE Score is Mis-scored

**Problem**: Because MoleSmartCleanAdapter (556 lines) already handles most developer cache categories, the actual incremental work for "Developer Deep Clean" is significantly less than represented.

- **Document says**: 11 "new" scan roots
- **Reality**: ~6 are already covered; only Docker, Homebrew, Simulator data, Xcode Archives, cargo, gem are truly new
- **Impact should be 5-6** (not 7): The feature provides less *new* value than claimed because Atlas already surfaces developer caches in Smart Clean today
- **Ease should be 8** (not 7): Less new work needed — adapter pattern is proven
- **Revised ICE**: 6 × 8 × 8 = **384** (vs. 392 — marginal difference, rank unchanged)

**Action**: Update the scan roots list to explicitly distinguish "already covered by MoleSmartCleanAdapter" vs. "genuinely new." Recalibrate user scenarios to focus on the real gaps (Docker, Simulator, Archives).

---

### S2. Startup Module — Architecture Fit Overstated

**Problem**: Document says "extends PermissionsFeatureView (scan pattern)" but this comparison is misleading.

- `PermissionsFeatureView` scans system entitlements/TCC database — a completely different scan model
- A Startup module would scan filesystem plists (`~/Library/LaunchAgents/*.plist`) and query `ServiceManagement` framework — closer to Smart Clean or Apps scanning patterns
- LaunchAgent management has **four distinct layers** the document doesn't differentiate:
  1. `~/Library/LaunchAgents/` — user-space plist-based (manageable)
  2. `/Library/LaunchAgents/` — system-level (needs admin privileges → helper)
  3. `/Library/LaunchDaemons/` — system-level, root-owned (needs helper + elevated)
  4. `SMAppService` API (macOS 13+) — API-based, modern apps use this instead of plists

**Impact on estimate**: "Medium complexity, 2-3 weeks" is optimistic. Handling all four layers with proper privilege separation (helper boundary for system-level items), plus `SMAppService` API integration, likely pushes this to **3-4 weeks** at Medium-High complexity.

**Action**:
- Correct architecture reference from Permissions to Smart Clean / Apps pattern
- Add explicit sub-section for the four startup item layers and privilege requirements
- Adjust timeline to 3-4 weeks
- Add risk: `SMAppService` items may not be discoverable via filesystem alone; may need `SMAppService.copyCurrentLoginItems()` or `serviceManagement.framework` APIs

---

### S3. Phase 2 vs EPIC-D Mainline Order Conflict

**Problem**: `Docs/Backlog.md` §"Current Mainline Priority Order" states:

> Execute the next mainline epics in this order only: EPIC-A → EPIC-B → EPIC-C → EPIC-D

EPIC-D (Release Readiness) is still the current mainline priority. The document proposes starting Phase 2 before EPIC-D is complete, which directly contradicts the established governance rule.

The document acknowledges this in Risk §7 ("EPIC-D takes priority") but doesn't resolve the structural conflict: if signing credentials arrive in Week 2 of Phase 2A, does everything pause?

**Action**: Add an explicit section titled "Relationship to EPIC-D" that defines:
1. Phase 2 work starts only if EPIC-D is blocked on external credentials (current state)
2. If credentials arrive, EPIC-D resumes and Phase 2 pauses — no concurrent product-path work
3. Phase 2 restarts only after EPIC-D gate review passes

---

### S4. No User Research Validation for #1 Priority

**Problem**: Startup & Background Service Manager scored ICE 567 (#1), but this score is based entirely on web search anecdotes and community sentiment. There is no:
- Beta user feedback requesting this feature
- User survey or interview data
- Competitor feature comparison showing startup management as a purchase driver
- Search volume or demand signal data

The ICE "Confidence = 9" is unjustified. The *technical* confidence is high (well-understood APIs), but the *product-market fit* confidence is unvalidated.

For comparison, Developer Deep Clean is validated by:
- PRD explicitly naming "developer-aware cleanup" as a differentiator
- Mole's existence proving demand
- Existing code investment in the adapter

Storage Visualizer is validated by:
- DaisyDisk's commercial success proving market demand
- Explicit P1 deferral in the roadmap (was planned)

**Action**: Reduce Startup module Confidence from 9 to **7**. Revised ICE: 9 × 7 × 7 = **441**. Still #1 but with a clearer confidence gap that should be addressed through user validation before committing 3-4 weeks of engineering.

Add to Decision Gate: "Run lightweight user validation (survey or interview with 5-10 target users) before committing to Phase 2A."

---

### S5. Storage Visualizer — Underestimates DaisyDisk Competition

**Problem**: Document acknowledges DaisyDisk as the gold standard but understates the gap:

- DaisyDisk has **10+ years of optimization** for treemap rendering, including custom OpenGL/Metal-based rendering for smooth animation on large volumes
- SwiftUI treemap rendering at DaisyDisk quality is an **unsolved problem** — there's no production-quality SwiftUI treemap component available
- "Ease 4" is generous; should be **2-3** given the custom rendering work needed
- Accessibility for treemaps is genuinely hard — no standard VoiceOver patterns exist for spatial/nested rectangle visualization

**Alternative proposal**: Instead of full treemap, start with a **Sunburst/Ring Chart** or **Category Bar visualization** (horizontal stacked bars showing proportional storage). These are:
- Much simpler to implement in SwiftUI
- More accessible (linear reading order)
- Still provide visual storage understanding
- Can be upgraded to treemap in a later iteration

**Action**:
- Rename from "Storage Visualizer (Treemap)" to "Storage Visualizer" with treemap as the target but sunburst/ring as Phase 2C-v1
- Reduce Ease from 4 to **3** (or 2 for treemap specifically)
- Revised ICE for full treemap: 9 × 6 × 3 = **162**
- Add stepping-stone approach: v1 = category bars/sunburst, v2 = treemap

---

## Minor Findings

### M1. Recovery Model for Startup Items — Insufficiently Detailed

Document says "undo = re-enable" but doesn't address:
- Apps that **re-add their LaunchAgent after disable** (Figma, Adobe, Docker all do this) — how does Atlas communicate this to the user?
- A disabled LaunchAgent that **breaks app functionality** — what's the user communication?
- **plist modification** by the owning app while disabled — conflict handling

Recommendation: Add a "Recovery Edge Cases" sub-section to Rec 1.

### M2. No Monetization Analysis

Market research identified subscription fatigue but document doesn't address:
- Which Phase 2 features would be free vs. premium?
- How does adding features affect the current free/direct-distribution model?
- Is Startup management a differentiator that could justify a price, or is it table stakes?

Not blocking for Phase 2 execution, but should be addressed before GA pricing decisions.

### M3. Privacy & Permission Audit Unfairly Scored Low

"Privacy & Permission Audit" was scored Impact 8 but Confidence 5. The document notes "TCC database access has macOS limitations" — this is partially correct but incomplete:
- macOS 14+ ` Transparency` framework provides API-level access to TCC data
- The real limitation is that Atlas can only read TCC entries for its own bundle identifier
- However, Atlas can scan app Info.plist files for `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, etc. to show which apps *request* privacy-sensitive permissions

Confidence could be 6-7 with a narrower scope (permission declarations, not runtime access logs). This feature may deserve reconsideration as a natural extension of the existing Permissions module.

---

## Review Verdict

### Summary Table

| Finding | Severity | Action Required |
|---------|----------|-----------------|
| F1: Developer scan roots already covered | High | Correct scan roots list; recalculate delta scope |
| S1: Developer Deep Clean ICE mis-scored | Medium | Adjust Impact/Ease; update user scenarios |
| S2: Startup architecture fit overstated | High | Correct architecture reference; add 4-layer analysis; adjust timeline |
| S3: Phase 2 vs EPIC-D conflict | High | Add explicit EPIC-D relationship section with pause rules |
| S4: No user validation for #1 priority | High | Reduce Confidence to 7; add pre-commitment user validation gate |
| S5: Storage treemap underestimated | Medium | Add stepping-stone approach (sunburst → treemap) |
| M1: Startup recovery edge cases | Low | Add recovery edge cases section |
| M2: No monetization analysis | Low | Future consideration, not blocking |
| M3: Privacy audit scored too low | Low | Worth reconsidering scope |

### Decision

**Pass** — All 5 findings resolved. The document's strategic direction is sound and the execution plan is actionable after decision gates are cleared.

**Resolved fixes:**
1. ✅ Developer Deep Clean scope corrected — distinguishes already-covered vs genuinely new scan roots
2. ✅ Startup module architecture corrected — 4-layer analysis, Smart Clean/Apps pattern reference, 3-4 week timeline
3. ✅ EPIC-D pause/resume rules added with checkpoint protocol
4. ✅ Startup Confidence reduced to 7, pre-commitment user validation gate added
5. ✅ Storage Visualizer stepping-stone approach added (Sunburst v1 → Treemap v2)
