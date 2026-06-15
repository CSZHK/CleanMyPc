import AtlasDesignSystem
import AtlasDomain
import Foundation

// MARK: - Workflow view state (shell-owned, passed by value)

/// Snapshot of the per-route workflow ViewState plus the stage resolution,
/// supplied by the shell on every render (decision A: resolve-on-render —
/// `currentStage` is derived from live model state, never stored truth).
/// Mutations flow back through `onStateChange`; the shell persists them on
/// `AtlasAppModel` so they survive route switches (spec §2.3).
///
/// Mirrors `SmartCleanWorkflowState` field-for-field; the shell maps the same
/// `AtlasWorkflowViewState` host into this type via `FileOrganizerStageMap`.
public struct FileOrganizerWorkflowState: Equatable, Sendable {
    /// Resolved current stage (render truth, computed by the shell).
    public var currentStage: Int
    /// Stage the user is looking at; only meaningful when < `currentStage`
    /// (read-only look-back) or == receipt while a failure receipt exists.
    public var displayedStage: Int
    public var planNumber: Int?
    public var receiptCode: String?
    public var selectedIDs: Set<UUID>
    public var evidenceSelectionID: UUID?
    public var drawerPresented: Bool
    public var rescanConfirmationPending: Bool
    /// Resolution flags (spec §2.3 sub-states).
    public var isScanInProgress: Bool
    public var isRulesEmpty: Bool
    public var isExecutionError: Bool

    public init(
        currentStage: Int = FileOrganizerStage.scan,
        displayedStage: Int = FileOrganizerStage.scan,
        planNumber: Int? = nil,
        receiptCode: String? = nil,
        selectedIDs: Set<UUID> = [],
        evidenceSelectionID: UUID? = nil,
        drawerPresented: Bool = false,
        rescanConfirmationPending: Bool = false,
        isScanInProgress: Bool = false,
        isRulesEmpty: Bool = false,
        isExecutionError: Bool = false
    ) {
        self.currentStage = currentStage
        self.displayedStage = displayedStage
        self.planNumber = planNumber
        self.receiptCode = receiptCode
        self.selectedIDs = selectedIDs
        self.evidenceSelectionID = evidenceSelectionID
        self.drawerPresented = drawerPresented
        self.rescanConfirmationPending = rescanConfirmationPending
        self.isScanInProgress = isScanInProgress
        self.isRulesEmpty = isRulesEmpty
        self.isExecutionError = isExecutionError
    }
}

// MARK: - Execution receipt (module-internal, spec §2.3 ⑤)

/// Facts of one executed file-organizer plan, captured at execution time.
/// Every field is real data from the execution output — the receipt view never
/// invents values (spec §1.6 fail-closed). Mirrors `SmartCleanExecutionReceipt`
/// shape so the ledger voice is consistent across modules.
public struct FileOrganizerExecutionReceipt: Equatable, Sendable {
    public var planNumber: Int?
    public var receiptCode: String?
    public var completedAt: Date
    public var movedItemCount: Int
    public var summary: String
    /// Set when the run stopped mid-way (④ error → 「查看回执」 partial receipt).
    public var failureReason: String?

    public init(
        planNumber: Int?,
        receiptCode: String?,
        completedAt: Date,
        movedItemCount: Int,
        summary: String,
        failureReason: String? = nil
    ) {
        self.planNumber = planNumber
        self.receiptCode = receiptCode
        self.completedAt = completedAt
        self.movedItemCount = movedItemCount
        self.summary = summary
        self.failureReason = failureReason
    }
}

// MARK: - Pure evidence builders (unit-tested, fail-closed)

/// Pure mapping from domain models to evidence-panel content and stage
/// predicates for the file-organizer workflow. Everything here is fail-closed
/// (spec §1.6): no rule-hit chain, classification sentence, or conflict mark
/// without real backing data.
public enum FileOrganizerEvidenceBuilder {

    // MARK: Search (per-screen filter; applies to ② rules and ③ preview only)

    public static func searchFiltered(_ entries: [FileOrganizerEntry], query: String) -> [FileOrganizerEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return entries
        }
        return entries.filter { entry in
            [entry.fileName, entry.proposedDestination, entry.category.title, entry.category.folderName]
                .joined(separator: " ")
                .lowercased()
                .contains(trimmed)
        }
    }

    // MARK: Conflict detection (fail-closed — uses real filesystem state)

    /// Entries whose proposed destination already exists on disk (move would
    /// clobber). Computed against the real filesystem at render time — no
    /// fabricated conflict marks (spec §1.6).
    public static func conflictingEntryIDs(_ entries: [FileOrganizerEntry]) -> Set<UUID> {
        let fm = FileManager.default
        return Set(entries.compactMap { entry in
            let destPath = (entry.proposedDestination as NSString).expandingTildeInPath
            return fm.fileExists(atPath: destPath) ? entry.id : nil
        })
    }

    // MARK: Rule-hit chain (「此文件为何被分类至 X」)

    /// The rule that classified `entry`, determined by matching the entry's
    /// extension/name/size against the ordered rule list (first match wins,
    /// mirroring the classifier's precedence). Returns nil when no rule
    /// matches — fail-closed: the evidence panel shows the fallback sentence
    /// instead of inventing a rule attribution.
    public static func matchingRule(for entry: FileOrganizerEntry, rules: [FileOrganizerRule]) -> FileOrganizerRule? {
        let ext = (entry.fileName as NSString).pathExtension.lowercased()
        let nameLower = entry.fileName.lowercased()
        for rule in rules {
            if !rule.extensionPatterns.isEmpty {
                if rule.extensionPatterns.contains(where: { $0.lowercased() == ext }) {
                    return rule
                }
            }
            if !rule.namePatterns.isEmpty {
                if rule.namePatterns.contains(where: { nameLower.contains($0.lowercased()) }) {
                    return rule
                }
            }
            if let minSize = rule.minSizeBytes, entry.bytes < minSize {
                continue
            }
            if let maxSize = rule.maxSizeBytes, entry.bytes > maxSize {
                continue
            }
            // A rule with empty patterns but matching category + size range
            // still classifies (catch-all by category).
            if rule.extensionPatterns.isEmpty && rule.namePatterns.isEmpty
                && rule.category == entry.category {
                return rule
            }
        }
        return nil
    }

    /// Human-readable rule-hit chain for one entry: the matched rule name +
    /// category, plus the specific signal that triggered it (extension / name
    /// pattern / size band / catch-all). Fail-closed: when no rule matches,
    /// returns the default-classification sentence (extension-based fallback).
    public static func classificationWhy(
        for entry: FileOrganizerEntry,
        rules: [FileOrganizerRule]
    ) -> String {
        guard let rule = matchingRule(for: entry, rules: rules) else {
            return AtlasL10n.string("fileorganizer.evidence.classify.default", entry.category.title)
        }
        let ext = (entry.fileName as NSString).pathExtension.lowercased()
        if !rule.extensionPatterns.isEmpty && rule.extensionPatterns.contains(where: { $0.lowercased() == ext }) {
            return AtlasL10n.string(
                "fileorganizer.evidence.classify.extension",
                rule.name, ext, entry.category.title
            )
        }
        let nameLower = entry.fileName.lowercased()
        if let pattern = rule.namePatterns.first(where: { nameLower.contains($0.lowercased()) }) {
            return AtlasL10n.string(
                "fileorganizer.evidence.classify.namePattern",
                rule.name, pattern, entry.category.title
            )
        }
        if rule.minSizeBytes != nil || rule.maxSizeBytes != nil {
            return AtlasL10n.string(
                "fileorganizer.evidence.classify.size",
                rule.name, entry.category.title
            )
        }
        return AtlasL10n.string(
            "fileorganizer.evidence.classify.catchall",
            rule.name, entry.category.title
        )
    }

    /// Mono KV rows for one entry's evidence panel: source path, size,
    /// category, proposed destination, and the conflict note when the
    /// destination exists (fail-closed — conflict row only with a real mark).
    public static func evidenceItems(
        for entry: FileOrganizerEntry,
        hasConflict: Bool
    ) -> [AtlasEvidenceItem] {
        var items: [AtlasEvidenceItem] = [
            AtlasEvidenceItem(
                id: "source",
                label: AtlasL10n.string("fileorganizer.evidence.source"),
                value: entry.path
            ),
            AtlasEvidenceItem(
                id: "size",
                label: AtlasL10n.string("fileorganizer.evidence.size"),
                value: AtlasFormatters.byteCount(entry.bytes)
            ),
            AtlasEvidenceItem(
                id: "category",
                label: AtlasL10n.string("fileorganizer.evidence.category"),
                value: entry.category.title
            ),
            AtlasEvidenceItem(
                id: "destination",
                label: AtlasL10n.string("fileorganizer.evidence.destination"),
                value: entry.proposedDestination
            ),
        ]
        if hasConflict {
            items.append(AtlasEvidenceItem(
                id: "conflict",
                label: AtlasL10n.string("fileorganizer.evidence.conflict"),
                value: AtlasL10n.string("fileorganizer.evidence.conflict.detail", entry.proposedDestination)
            ))
        }
        return items
    }

    /// Conflict explanation sentence for an entry whose destination exists.
    /// Empty string when there is no conflict (fail-closed).
    public static func conflictNote(for entry: FileOrganizerEntry, hasConflict: Bool) -> String {
        guard hasConflict else { return "" }
        return AtlasL10n.string("fileorganizer.conflict.exists", entry.proposedDestination)
    }

    // MARK: Move target shortening (preview list compactness)

    /// Shortens a full destination path to `~/Folder/Sub` for the preview list.
    public static func shortenDestination(_ detail: String) -> String {
        // "sourcePath → destPath" → just the dest folder tail.
        guard let dest = detail.components(separatedBy: " → ").last else { return detail }
        let parts = dest.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count >= 2 {
            return "~/" + parts.suffix(2).joined(separator: "/")
        }
        return dest
    }

    // MARK: Metrics (mono, fail-closed)

    public static func totalBytes(_ entries: [FileOrganizerEntry]) -> Int64 {
        entries.reduce(Int64(0)) { $0 + $1.bytes }
    }

    public static func selectedBytes(_ entries: [FileOrganizerEntry], selectedIDs: Set<UUID>) -> Int64 {
        entries.filter { selectedIDs.contains($0.id) }.reduce(Int64(0)) { $0 + $1.bytes }
    }

    // MARK: Insight detectors (large files / duplicates)

    /// 100 MB — files at or above this are flagged "large" in the entry row.
    public static let largeFileThreshold: Int64 = 100 * 1024 * 1024

    public static func largeFileIDs(_ entries: [FileOrganizerEntry]) -> Set<UUID> {
        Set(entries.filter { $0.bytes >= largeFileThreshold }.map(\.id))
    }

    private struct FileNameBytesKey: Hashable {
        let name: String
        let bytes: Int64
    }

    public static func duplicateFileIDs(_ entries: [FileOrganizerEntry]) -> Set<UUID> {
        let groups = Dictionary(grouping: entries, by: { FileNameBytesKey(name: $0.fileName, bytes: $0.bytes) })
        return Set(groups.values.filter { $0.count > 1 }.flatMap { $0.map(\.id) })
    }

    // MARK: Evidence panel content (single selection)

    /// Builds the evidence-panel content for the current selection. Fail-closed:
    /// no selection → the empty-state copy with no evidence rows.
    public static func panelContent(
        entries: [FileOrganizerEntry],
        selectedID: UUID?,
        selectedIDs: Set<UUID>,
        rules: [FileOrganizerRule]
    ) -> AtlasEvidenceContent {
        let entry = entries.first { $0.id == selectedID }
            ?? entries.first { selectedIDs.contains($0.id) }
        guard let entry else {
            return AtlasEvidenceContent(
                title: AtlasL10n.string("fileorganizer.evidence.empty.title"),
                whyText: AtlasL10n.string("fileorganizer.evidence.empty.detail"),
                evidence: [],
                recoveryText: nil
            )
        }
        let conflicting = conflictingEntryIDs(entries)
        let hasConflict = conflicting.contains(entry.id)
        return AtlasEvidenceContent(
            title: entry.fileName,
            whyText: classificationWhy(for: entry, rules: rules),
            evidence: evidenceItems(for: entry, hasConflict: hasConflict),
            recoveryText: nil
        )
    }

    /// Whole-panel state machine (decision-A host contract). Mirrors the
    /// Apps-side `AppsEvidencePanelBuilder.panelState`: no selection → `.empty`
    /// ("select an item" hint); selection → `.single(content)` three-segment.
    /// The recovery ⛨ box is suppressed by `AtlasEvidenceState` when
    /// `recoveryText` is nil (fail-closed §1.6 — file-organizer moves are
    /// reversible via the ledger, but the per-file recovery promise is not
    /// surfaced here until a receipt exists).
    public static func panelState(
        entries: [FileOrganizerEntry],
        selectedID: UUID?,
        selectedIDs: Set<UUID>,
        rules: [FileOrganizerRule]
    ) -> AtlasEvidenceState {
        let entry = entries.first { $0.id == selectedID }
            ?? entries.first { selectedIDs.contains($0.id) }
        guard entry != nil else {
            return .empty
        }
        return .single(panelContent(
            entries: entries, selectedID: selectedID,
            selectedIDs: selectedIDs, rules: rules
        ))
    }
}
