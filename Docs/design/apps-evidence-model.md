# Apps Evidence Model — Design Document

## Overview
This document specifies the unified evidence data model for the Atlas Apps uninstall pipeline. The model provides a single, frozen-at-capture evidence snapshot that flows identically through preview → completion → history rendering.

## Data Model

### New Types (6)

#### AtlasAppEvidenceCategory
```swift
public enum AtlasAppEvidenceCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case appBundle        // The .app bundle itself
    case supportFiles     // ~/Library/Application Support/{appName|bundleID}
    case caches           // ~/Library/Caches/{bundleID}
    case preferences      // ~/Library/Preferences/{bundleID}.plist
    case logs             // ~/Library/Logs/{appName}
    case launchItems      // ~/Library/LaunchAgents/{bundleID}.plist
    case savedState       // ~/Library/Saved Application State/{bundleID}.savedState
    case containers       // ~/Library/Containers/{bundleID}
    case groupContainers  // ~/Library/Group Containers/{groupID} (cross-referenced)
    case miscLeftovers    // Cookies, WebKit, HTTPStorages, ColorSync, Input Methods
}
```

#### AtlasEvidenceSafetyLevel
```swift
public enum AtlasEvidenceSafetyLevel: String, Codable, Hashable, Sendable {
    case safe        // Always safe to remove (caches, logs, saved state)
    case conditional // May contain user data (support files, preferences, containers)
    case protected   // System-level, can affect services (launch daemons, group containers)
}
```

#### AtlasAppEvidenceItem
```swift
public struct AtlasAppEvidenceItem: Identifiable, Codable, Hashable, Sendable {
    public var path: String
    public var bytes: Int64
    public var fileType: AtlasEvidenceFileType   // .file, .directory, .plist, .symlink, .bundle
    public var verified: Bool                    // true if confirmed at execution time

    public var id: String { path }
}
```

#### AtlasAppEvidenceGroup
```swift
public struct AtlasAppEvidenceGroup: Identifiable, Codable, Hashable, Sendable {
    public var category: AtlasAppEvidenceCategory
    public var safetyLevel: AtlasEvidenceSafetyLevel
    public var items: [AtlasAppEvidenceItem]

    public var id: AtlasAppEvidenceCategory { category }
    public var totalBytes: Int64 { items.map(\.bytes).reduce(0, +) }
    public var itemCount: Int { items.count }
}
```

#### AtlasAppUninstallEvidenceSnapshot
```swift
public struct AtlasAppUninstallEvidenceSnapshot: Codable, Hashable, Sendable {
    public var planID: UUID
    public var capturedAt: Date
    public var bundlePath: String
    public var bundleBytes: Int64
    public var groups: [AtlasAppEvidenceGroup]
    public var fingerprintHash: String           // Hasher-based fingerprint of sorted paths (process-local, non-crypto)

    public var reviewOnlyGroups: [AtlasAppEvidenceGroup] {
        groups.filter { $0.category != .appBundle }
    }
    public var reviewOnlyBytes: Int64 {
        reviewOnlyGroups.reduce(0) { $0 + $1.totalBytes }
    }
    public var reviewOnlyItemCount: Int {
        reviewOnlyGroups.reduce(0) { $0 + $1.itemCount }
    }
    public var totalBytes: Int64 {
        groups.reduce(0) { $0 + $1.totalBytes }
    }

    /// Compute fingerprint from current groups for comparison
    public func computeFingerprint() -> String { ... }
}
```

#### AtlasEvidenceFileType
```swift
public enum AtlasEvidenceFileType: String, Codable, Hashable, Sendable {
    case file
    case directory
    case plist
    case symlink
    case bundle
}
```

### Modified Types (4)

#### AppFootprint — add evidenceSummary
```swift
public var evidenceSummary: [AtlasAppEvidenceCategory: Int]?  // nil for legacy data
// leftoverItems becomes computed:
public var leftoverItems: Int {
    evidenceSummary?.values.reduce(0, +) ?? 0
}
```

#### ActionPlan — add evidence fields
```swift
public var evidencePlanID: UUID?              // Links preview to execute
public var estimatedReviewOnlyBytes: Int64?    // Separate from bundle bytes
```

#### AtlasAppRecoveryPayload — v2 with snapshot
```swift
// v2 payload:
public var uninstallSnapshot: AtlasAppUninstallEvidenceSnapshot?

// Legacy decode (init from decoder):
// If uninstallSnapshot is nil, synthesize from uninstallEvidence (v1 field)
```

#### AtlasAppPostRestoreRefreshStatus — add divergence
```swift
public var evidenceDivergenceDetected: Bool
public var divergentCategories: [AtlasAppEvidenceCategory]
public var recommendedAction: RestoreRecommendedAction?
```

## Evidence Category Taxonomy

| Category | Paths | Safety | Recoverable | Notes |
|----------|-------|--------|-------------|-------|
| appBundle | `/Applications/{Name}.app`, `~/Applications/{Name}.app` | safe | ✓ (via trash) | User explicitly chose to uninstall |
| supportFiles | `~/Library/Application Support/{name}`, `~/Library/Application Support/{bundleID}` | conditional | ✓ | May contain user databases, profiles |
| caches | `~/Library/Caches/{bundleID}`, `~/Library/Containers/{bundleID}/Data/Library/Caches` | safe | ✓ | Recreatable by app |
| preferences | `~/Library/Preferences/{bundleID}.plist` | conditional | ✓ | May contain license keys |
| logs | `~/Library/Logs/{name}`, `~/Library/Logs/{bundleID}` | safe | ✓ | Diagnostic data only |
| launchItems | `~/Library/LaunchAgents/{bundleID}.plist`, `/Library/LaunchDaemons/{bundleID}.plist` | protected | ✓ | Can affect system services |
| savedState | `~/Library/Saved Application State/{bundleID}.savedState` | safe | ✓ | Window state only |
| containers | `~/Library/Containers/{bundleID}` | conditional | ✓ | Sandbox data, may include documents |
| groupContainers | `~/Library/Group Containers/{groupID}` | protected | ✓ | **Cross-ref**: only if plist references bundleID |
| miscLeftovers | `~/Library/Cookies/{bundleID}.binarycookies`, `~/Library/WebKit/{bundleID}`, `~/Library/HTTPStorages/{bundleID}`, `~/Library/ColorSync/{name}`, `~/Library/Input Methods/{name}.app` | conditional | ✓ | Mixed bag, varies by type |

## Safety Level Assignment

| Category | Safety Level | Rationale |
|----------|-------------|-----------|
| appBundle | safe | User explicitly chose uninstall |
| caches | safe | Recreatable, no user data |
| logs | safe | Diagnostic only |
| savedState | safe | Window state only |
| supportFiles | conditional | May contain databases, profiles |
| preferences | conditional | May contain license keys, settings |
| containers | conditional | May contain documents in sandbox |
| miscLeftovers | conditional | Varies by type |
| launchItems | protected | Can break system services |
| groupContainers | protected | Shared between app extensions |

## View Consistency Specification

### AtlasEvidenceGroupCard Component
Location: `Packages/AtlasDesignSystem/Sources/AtlasDesignSystem/Components/AtlasEvidenceGroupCard.swift`

**Accepts**: `AtlasAppEvidenceGroup` + `DisplayMode`
```swift
public enum AtlasEvidenceGroupDisplayMode {
    case preview      // Shows category + item count + bytes + safety badge
    case completion   // Shows category + verified status + actual result
    case history      // Shows frozen snapshot + timestamp + safety badge
}
```

**Rendering rules**:
- Preview: all items show `verified: false` + safety badge
- Completion: items verified at execute time show `verified: true`; divergent items show warning icon + "Changed since preview" text
- History: frozen snapshot with capture timestamp; legacy payloads show "Legacy evidence" badge + empty groups

### Preview → Completion → History flow
1. **Preview**: `AtlasAppUninstallEvidenceSnapshot` captured → `AtlasEvidenceGroupCard(mode: .preview)` renders groups
2. **Execute**: Snapshot looked up → fingerprint verified → items marked verified → `AtlasEvidenceGroupCard(mode: .completion)` renders
3. **History**: RecoveryItem.uninstallSnapshot frozen → `AtlasEvidenceGroupCard(mode: .history)` renders

## Restore Refresh Policy

### After restore:
1. `AtlasAppModel.restoreRecoveryItem` triggers `reloadAppsInventory`
2. Fresh inventory runs lightweight evidence summary on restored app
3. Compare group counts with stored snapshot
4. Compute `AtlasAppPostRestoreRefreshStatus`:
   - **Matching counts**: `.refreshed`, divergence = false
   - **Divergent counts**: `.refreshed`, divergence = true, divergentCategories listed, "Re-scan" button offered
   - **App not found**: `.stale` with error message
   - **Bundle path occupied**: `.restoreConflict` error
5. UI shows divergence warning card with "Re-scan leftovers" action → triggers fresh preview

### Stale evidence handling:
- Old `RecoveryItem` with stale snapshot remains in history until expiry
- Re-scanning creates a new preview; does NOT modify old history entry
- User is warned that old snapshot may be stale

## Fixture Matrix

### Mainstream (3)
| App | Expected Categories | Notes |
|-----|-------------------|-------|
| Google Chrome | supportFiles + caches + preferences + logs + launchItems + savedState | Heavy footprint, well-behaved paths |
| Slack | supportFiles + caches + preferences + logs + savedState | Group Containers likely |
| Spotify | supportFiles + caches + preferences + logs + savedState + launchItems | Common user app |

### Developer (3)
| App | Expected Categories | Notes |
|-----|-------------------|-------|
| Xcode CLI tools | supportFiles + caches + preferences + logs + launchItems | Complex Library paths |
| Docker Desktop | supportFiles + caches + logs + launchItems + groupContainers | Daemon, group containers |
| Homebrew app | supportFiles + caches + preferences + miscLeftovers | Non-standard bundle ID |

### Edge Cases (3)
| App | Expected Categories | Notes |
|-----|-------------------|-------|
| MAS sandboxed app | containers + preferences + savedState | Data in Containers only |
| Symlinked bundle | appBundle (resolved) | Verify symlink resolution |
| Dot-separated bundleID | supportFiles + caches + preferences | e.g., `com.example.my.app` |

## Acceptance Criteria
See `iterations/REQ-apps-evidence-execution/requirement.md` for full AC per ATL task.

## Implementation Phases
See `.agent/apps-evidence-execplan.md` for ordered phases with file targets and checkpoint protocol.
