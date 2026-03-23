# Competitive Strategy Plan — 2026-03-21

## Purpose

Turn the findings in [Open-Source-Competitor-Research-2026-03-21.md](./Open-Source-Competitor-Research-2026-03-21.md) into a practical strategy for Atlas for Mac's next execution window.

This plan assumes:

- MVP scope remains frozen to the current modules
- direct distribution remains the only MVP release route
- strategy should improve competitive position by deepening existing flows, not by reopening deferred scope

## Strategic Options Considered

### Option A: Breadth Race

Try to match `Mole` and `Lemon` feature-for-feature as quickly as possible.

- Upside:
  - easier feature checklist comparisons
  - broader marketing claims
- Downside:
  - high scope pressure
  - weakens Atlas's current trust advantage
  - increases risk of half-implemented cleanup claims
  - encourages pulling deferred items like `Storage treemap`

Decision: reject.

### Option B: Trust-Only Niche

Ignore breadth pressure and compete only on recovery, permissions, and execution honesty.

- Upside:
  - strongest alignment with Atlas architecture
  - lowest scope risk
- Downside:
  - leaves obvious product comparison gaps open
  - makes Atlas look elegant but underpowered next to `Mole`, `Lemon`, and `Pearcleaner`

Decision: reject.

### Option C: Recommended Strategy

Compete on `trust-first native workspace`, while selectively closing the most visible parity gaps inside frozen MVP.

- Upside:
  - preserves Atlas's strongest differentiation
  - improves user-visible competitiveness where comparison pressure is highest
  - avoids scope creep
- Downside:
  - requires disciplined prioritization and clear no-go boundaries

Decision: adopt.

## Strategic Thesis

Atlas should not try to become a generic all-in-one cleaner. It should become the most trustworthy native Mac maintenance workspace, then remove the most painful reasons users would otherwise choose `Mole`, `Lemon`, or `Pearcleaner`.

That means:

1. Win on execution honesty, recoverability, auditability, and permission clarity.
2. Close only the highest-pressure breadth gaps inside existing MVP flows.
3. Make Atlas's differentiation visible enough that users can understand it without reading architecture docs.

## Competitive Reading

### `Mole`

Primary pressure:

- broad cleanup coverage
- developer-oriented cleanup
- disk analysis and status breadth
- strong dry-run and automation posture

Atlas response:

- do not chase terminal ergonomics
- close the most visible safe cleanup coverage gaps in `Smart Clean`
- keep the trust advantage by failing closed and showing real side effects only

### `Tencent Lemon Cleaner`

Primary pressure:

- native GUI breadth
- large-file / duplicate / privacy / uninstall / startup-item utility expectations
- Chinese-speaking user familiarity with one-click cleaner workflows

Atlas response:

- stay native and polished
- avoid claiming equivalent breadth until behavior is real
- compete with safer workflows, clearer recommendations, and higher trust in destructive actions

### `Pearcleaner`

Primary pressure:

- uninstall depth
- leftovers and app-adjacent cleanup
- macOS-native integration quality

Atlas response:

- treat `Apps` as a serious competitive surface, not just an MVP checklist module
- deepen uninstall preview and explain what will be removed, what is recoverable, and what remains review-only

### `Czkawka` and `GrandPerspective`

Primary pressure:

- high-performance file hygiene primitives
- treemap-based storage analysis

Atlas response:

- borrow architectural lessons only
- keep `Storage treemap` deferred
- do not import GPL-constrained UI paths into Atlas

## Strategic Pillars

### Pillar 1: Build a Trust Moat

Atlas's strongest defendable position is trust architecture:

- structured worker/helper boundaries
- recoverable destructive actions
- history and auditability
- permission explanations instead of permission ambush
- honest failure when Atlas cannot prove execution

This must remain the primary product story and the primary release gate.

### Pillar 2: Close Selective Parity Gaps

Atlas should close the gaps users notice immediately in side-by-side evaluation:

- `Smart Clean` coverage on high-confidence safe targets users expect from `Mole` and `Lemon`
- `Apps` uninstall depth and leftovers clarity users expect from `Pearcleaner` and `Lemon`

This is selective parity, not full parity. The rule is: only deepen flows already inside frozen MVP.

### Pillar 3: Make Differentiation Visible

Atlas cannot rely on architecture alone. The product must visibly communicate:

- what is recoverable
- what is executable now
- what requires permission and why
- what changed on disk after execution
- what Atlas intentionally refuses to do

If users cannot see these differences in the UI and release materials, Atlas will be compared as "another cleaner" and lose to broader tools.

## 90-Day Execution Direction

### Phase 1: Trust and Claim Discipline

Target outcome:

- Atlas's release-facing claims are narrower than its real behavior, never broader

Priority work:

- execution honesty
- recovery claim discipline
- permission and limited-mode clarity
- visible trust markers in `Smart Clean`, `Apps`, `History`, and `Permissions`

### Phase 2: Smart Clean Competitive Depth

Target outcome:

- the highest-value safe cleanup classes compared against `Mole` and `Lemon` have real execution paths

Priority work:

- expand safe cleanup target coverage
- strengthen `scan -> execute -> rescan` proof
- make history reflect only real side effects

### Phase 3: Recovery Credibility

Target outcome:

- Atlas's recovery promise is provable and product-facing copy can be frozen without caveats that undercut trust

Priority work:

- physical restore where safe
- clear split between file-backed restore and Atlas-only state restore
- explicit validation evidence

### Phase 4: Apps Competitive Depth

Target outcome:

- Atlas's `Apps` module is defensible against `Pearcleaner` and `Lemon` for the most common uninstall decision paths

Priority work:

- deeper uninstall preview taxonomy
- clearer leftovers and footprint reasoning
- visible recoverability and audit cues in the uninstall flow
- fixture-based validation on mainstream and developer-heavy apps

## No-Go Boundaries

The competitor response must not trigger:

- `Storage treemap`
- `Menu Bar`
- `Automation`
- duplicate-file or similar-photo modules as new product surfaces
- privacy-cleaning module expansion outside existing MVP framing
- code reuse from `Lemon`, `GrandPerspective`, or GPL-constrained `Czkawka` paths
- monetization-sensitive reuse from `Pearcleaner`

## Metrics and Gates

### Product Metrics

- first scan completion rate
- scan-to-execution conversion rate
- uninstall preview-to-execute conversion rate
- permission completion rate
- recovery success rate
- user-visible reclaimed space

### Competitive Readiness Gates

- `Smart Clean` can prove meaningful gains on the top safe categories users compare against `Mole` and `Lemon`
- `Apps` uninstall preview is detailed enough that users understand footprint, leftovers, and recoverability before confirmation
- no release-facing copy implies full parity with broader tools when Atlas only supports a narrower subset
- recovery language stays tied to shipped behavior only

## Resulting Strategy Call

For the next planning window, Atlas should be managed as:

- a `trust-first Mac maintenance workspace`
- with `selective parity` against `Mole` and `Lemon` in `Smart Clean`
- with `targeted depth` against `Pearcleaner` and `Lemon` in `Apps`
- while keeping all non-MVP expansion pressure explicitly frozen

This is the narrowest strategy that still improves Atlas's competitive position in a way users will actually feel.
