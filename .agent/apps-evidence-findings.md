# Apps Evidence Execution — Findings Summary

## Current State Analysis

### Evidence Pipeline (as of v1.0.8)
The Apps uninstall flow uses a dual-capture pattern:

1. **Preview** (`previewAppUninstall` line ~461): Validates app exists → calls `makeAppUninstallPreview` → runs `AtlasAppUninstallEvidenceAnalyzer.analyze()` → builds `ActionPlan` with 1 recoverable item (bundle) + N review-only items (leftover categories) → returns to UI
2. **Execute** (`executeAppUninstall` line ~482): Validates app exists → **re-runs analyzer** → trashes bundle via privileged helper → creates `RecoveryItem` with `AtlasAppRecoveryPayload` → creates `TaskRun`

**Critical observation**: Both calls run the analyzer independently. No plan ID, no evidence snapshot, no fingerprint links them.

### Key Source Files
| File | Role | Lines of Interest |
|------|------|------------------|
| `AtlasDomain.swift` | All domain models | 247-280 (Finding), 307-466 (ActionItem/ActionPlan), 550-748 (Evidence/Recovery) |
| `AtlasAppUninstallEvidence.swift` | 5-category analyzer | Full file (108 lines) |
| `AtlasScaffoldWorkerService.swift` | Worker (actor) | 461-480 (preview), 482-549 (execute), ~1343 (makePreview) |
| `AtlasProtocol.swift` | IPC commands | 24-41 (AtlasCommand), 75-85 (AtlasResponse) |
| `MacAppsInventoryAdapter.swift` | App listing | 7 hardcoded paths for leftover count |

### Current Types
- `AtlasFootprintEvidenceCategory` — 5 cases: supportFiles, caches, preferences, logs, launchItems
- `AtlasAppFootprintEvidenceGroup` — category + items
- `AtlasAppFootprintEvidenceItem` — path + bytes
- `AtlasAppUninstallEvidence` — bundlePath + bundleBytes + reviewOnlyGroups
- `AtlasAppRecoveryPayload` — schemaVersion + app (AppFootprint) + uninstallEvidence
- `AtlasAppPostRestoreRefreshStatus` — state + recordedLeftoverItems + refreshedLeftoverItems

### 7 Critical Gaps

| # | Gap | Root Cause | Impact |
|---|-----|-----------|--------|
| 1 | Evidence not verified between preview and execute | Dual independent analyzer calls | User sees different plan than what's recorded |
| 2 | Review-only evidence never cleaned | Execute only trashes .app bundle | Leftover files remain permanently |
| 3 | leftoverItems count diverges from evidence | 7 hardcoded paths vs 5 categories | App list count ≠ preview groups |
| 4 | No preview-to-history continuity | ActionPlan is ephemeral | History shows only TaskRun summary string |
| 5 | estimatedBytes excludes review-only | `estimatedBytes = bundleBytes` | User underestimates total footprint |
| 6 | Stale evidence after restore | Informational only, no action | Restored app may have different leftovers |
| 7 | No per-path evidence in AppFootprint | Only `leftoverItems: Int` | Users can't see what's leftover before preview |

### Existing Safety Mechanisms (to preserve)
- `ActionItem.ExecutionBoundary` — `.reviewOnly` kind returns `.reviewOnly` boundary (non-executable)
- `AtlasHelperAction` — privileged helper for trash/restore
- `AtlasRecoveryPayloadSchemaVersion` — schema versioning with legacy decode
- RecoveryItem legacy decode (line 722) — handles v1 payloads missing `uninstallEvidence`

## Competitive Analysis

### Pearcleaner (open source, on hold)
| Feature | Atlas? | Gap Priority |
|---------|--------|-------------|
| Per-category leftover evidence | ✅ partial (5 categories) | P0 — expand to 10 |
| Orphaned file search | ❌ | P2 — post-EPIC-A |
| Finder Extension | ❌ | Deferred |
| Sentinel auto-cleanup | ❌ | P1 — consider for review-only items |
| System LaunchDaemons path | ✅ covered | Already in analyzer |
| Group Containers | ❌ | P0 — add |
| Saved Application State | ❌ | P0 — add |

### Tencent Lemon Cleaner (open source, active)
| Feature | Atlas? | Gap Priority |
|---------|--------|-------------|
| Per-app profiles | ❌ (100+ hardcoded) | P2 — fixture-based approach |
| PKG uninstall | ❌ | Deferred |
| Disk visualization | ❌ | Deferred (Storage treemap) |

### Atlas Differentiation
1. **Recovery-first**: Every action is recoverable; Pearcleaner has no undo
2. **Explainable findings**: Safety level + category + size breakdown per group
3. **Fingerprint verification**: No competitor does preview→execute integrity check
4. **Divergence detection**: Warn if files changed between preview and execute

## Design Decisions

1. **Single snapshot with fingerprint** — Capture once at preview, verify at execute. Eliminates gaps 1+4 simultaneously.
2. **10 evidence categories** — Flat enum matching Pearcleaner coverage. `AtlasAppEvidenceCategory` supersedes 5-case `AtlasFootprintEvidenceCategory`.
3. **Static safety levels** — safe/conditional/protected per category. Predictable user behavior.
4. **Transient worker storage** — `pendingAppUninstallSnapshots` on actor, non-persisted. Lost on XPC restart → fallback to current behavior.
5. **Optional v2 fields** — `decodeIfPresent` everywhere. No schema bump for `AtlasWorkspaceState`.
6. **Protocol additive change** — planID optional in execute command. Old clients continue working.
7. **Divergence as warning** — Never blocks execution. Attaches warning to RecoveryItem.
8. **Lightweight scan-level summary** — Path-existence-only at listing. Full scan at preview.

## Risk Assessment
| Level | Risk | Status |
|-------|------|--------|
| HIGH | Schema migration breaks existing users | Mitigated: all optional fields, round-trip test |
| HIGH | Group Containers shared by multiple apps | Mitigated: cross-reference check against group container plist |
| HIGH | XPC worker restart loses snapshot | Mitigated: fallback to re-run analyzer (same as today) |
| MEDIUM | Fingerprint false positives | Mitigated: only flag disappeared items, not new items |
| MEDIUM | Performance regression on app listing | Mitigated: path-existence-only, no size computation |
| LOW | Review-only items confuse users | Accepted: clear safety badge + explanation text |
