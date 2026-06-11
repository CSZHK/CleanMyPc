import AtlasDesignSystem
import AtlasDomain
import Foundation

// MARK: - Stage constants (feature-side mirror of AtlasWorkflowStageMap)

/// 0-based stage ordinals for the smart-clean workflow skeleton (spec §2.3).
/// Apps' `AtlasWorkflowStageMap` is the resolution truth; these constants only
/// name the indexes on the feature side (locked together by an Apps test).
public enum SmartCleanStage {
    public static let scan = 0
    public static let review = 1
    public static let execute = 2
    public static let receipt = 3
    public static let count = 4
}

// MARK: - Workflow view state (shell-owned, passed by value)

/// Snapshot of the per-route workflow ViewState plus the stage resolution,
/// supplied by the shell on every render (decision A: resolve-on-render —
/// `currentStage` is derived from live model state, never stored truth).
/// Mutations flow back through `onStateChange`; the shell persists them on
/// `AtlasAppModel` so they survive route switches (spec §2.3).
public struct SmartCleanWorkflowState: Equatable, Sendable {
    /// Resolved current stage (render truth, computed by the shell).
    public var currentStage: Int
    /// Stage the user is looking at; only meaningful when < `currentStage`
    /// (read-only look-back) or == receipt while a failure receipt exists.
    public var displayedStage: Int
    public var planNumber: Int?
    public var receiptCode: String?
    public var selectedIDs: Set<String>
    public var riskFilter: String?
    public var evidenceSelectionID: String?
    public var drawerPresented: Bool
    public var rescanConfirmationPending: Bool
    /// Resolution flags (spec §2.3 sub-states).
    public var isScanInProgress: Bool
    public var isReviewEmpty: Bool
    public var isExecutionError: Bool

    public init(
        currentStage: Int = SmartCleanStage.scan,
        displayedStage: Int = SmartCleanStage.scan,
        planNumber: Int? = nil,
        receiptCode: String? = nil,
        selectedIDs: Set<String> = [],
        riskFilter: String? = nil,
        evidenceSelectionID: String? = nil,
        drawerPresented: Bool = false,
        rescanConfirmationPending: Bool = false,
        isScanInProgress: Bool = false,
        isReviewEmpty: Bool = false,
        isExecutionError: Bool = false
    ) {
        self.currentStage = currentStage
        self.displayedStage = displayedStage
        self.planNumber = planNumber
        self.receiptCode = receiptCode
        self.selectedIDs = selectedIDs
        self.riskFilter = riskFilter
        self.evidenceSelectionID = evidenceSelectionID
        self.drawerPresented = drawerPresented
        self.rescanConfirmationPending = rescanConfirmationPending
        self.isScanInProgress = isScanInProgress
        self.isReviewEmpty = isReviewEmpty
        self.isExecutionError = isExecutionError
    }
}

// MARK: - Pure builders (unit-tested)

/// Pure mapping from domain models to evidence-panel content, action-bar
/// promise copy, and stage predicates. Everything here is fail-closed
/// (spec §1.6): no recovery sentence, box, or badge without real backing data.
public enum SmartCleanEvidenceBuilder {

    // MARK: Stage predicates

    /// Look-back is read-only (spec §2.3 回看 = 只读快照).
    public static func isReadOnly(displayedStage: Int, currentStage: Int) -> Bool {
        displayedStage < currentStage
    }

    /// The stage that actually renders. Rules:
    /// - look-back (`displayed < current`) shows the displayed stage read-only;
    /// - after a mid-run failure (current = ③ error) the receipt is reachable
    ///   explicitly via 「查看回执」 when a receipt record exists;
    /// - anything else follows the resolved current stage (resolve-on-render).
    public static func effectiveStage(displayedStage: Int, currentStage: Int, hasReceipt: Bool) -> Int {
        if displayedStage < currentStage {
            return max(displayedStage, SmartCleanStage.scan)
        }
        if displayedStage == SmartCleanStage.receipt,
           currentStage == SmartCleanStage.execute,
           hasReceipt {
            return SmartCleanStage.receipt
        }
        return currentStage
    }

    /// Completed (tappable, look-back) stage indexes for the stage bar.
    public static func completedStages(currentStage: Int, effectiveStage: Int) -> Set<Int> {
        Set(0..<max(currentStage, effectiveStage))
    }

    // MARK: Action-bar promise (spec §1.6 三式, state-driven)

    /// - all recoverable  → 「执行前自动建立恢复点 · 保留 N 天 · 全程录入台账」
    /// - partially        → 「X/Y 项可恢复 · 保留 N 天 · 全程录入台账」
    /// - none / no selection → nil (no ⛨ sentence at all — fail-closed)
    public static func promise(recoverableCount: Int, totalCount: Int, retentionDays: Int) -> String? {
        guard totalCount > 0, recoverableCount > 0 else {
            return nil
        }
        if recoverableCount >= totalCount {
            return AtlasL10n.string("smartclean.promise.full", retentionDays)
        }
        return AtlasL10n.string("smartclean.promise.partial", recoverableCount, totalCount, retentionDays)
    }

    /// Recovery stats for the current selection, judged against the plan's
    /// real recovery metadata. Selected findings without a matching plan item
    /// count as NOT recoverable (fail-closed).
    public static func recoveryStats(selectedFindingIDs: Set<String>, plan: ActionPlan) -> (recoverable: Int, total: Int) {
        let recoverable = plan.items
            .filter { selectedFindingIDs.contains($0.id.uuidString) && $0.recoverable }
            .count
        return (min(recoverable, selectedFindingIDs.count), selectedFindingIDs.count)
    }

    /// Mono action-bar metric: 「X GB · N 项」 of the current selection.
    public static func metricText(selectedBytes: Int64, selectedCount: Int) -> String? {
        guard selectedCount > 0 else {
            return nil
        }
        return AtlasL10n.string("smartclean.stage.metric.selected", AtlasFormatters.byteCount(selectedBytes), selectedCount)
    }

    // MARK: Search (per-screen filter; applies to the ② list only)

    public static func searchFiltered(_ findings: [Finding], query: String) -> [Finding] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return findings
        }
        return findings.filter { finding in
            [finding.title, finding.detail, AtlasL10n.localizedCategory(finding.category), finding.risk.title]
                .joined(separator: " ")
                .lowercased()
                .contains(trimmed)
        }
    }

    // MARK: Single-selection evidence (why / evidence KV / recovery)

    public static func content(for finding: Finding, planItem: ActionItem?, retentionDays: Int) -> AtlasEvidenceContent {
        AtlasEvidenceContent(
            title: finding.title,
            whyText: whyText(for: finding),
            evidence: evidenceItems(for: finding),
            recoveryText: recoveryText(planItem: planItem, retentionDays: retentionDays)
        )
    }

    /// Why-safe explanation: the finding's own explanation field, falling back
    /// to the generated per-category explanation (same source as the legacy row).
    public static func whyText(for finding: Finding) -> String {
        if let explanation = finding.explanation, !explanation.isEmpty {
            return explanation
        }
        return AtlasFindingExplanations.explanation(
            for: finding.storageCategory ?? .systemCache,
            risk: finding.risk,
            fileAge: finding.fileAge
        )
    }

    /// Mono KV rows. Only rows with real backing data render: path(s), size,
    /// category, source detail, and file age when known.
    public static func evidenceItems(for finding: Finding) -> [AtlasEvidenceItem] {
        var items: [AtlasEvidenceItem] = []
        let paths = finding.targetPaths ?? []
        if let first = paths.first {
            items.append(AtlasEvidenceItem(id: "path", label: AtlasL10n.string("smartclean.evidence.path"), value: first))
            if paths.count > 1 {
                items.append(AtlasEvidenceItem(
                    id: "path.more",
                    label: AtlasL10n.string("smartclean.evidence.path"),
                    value: AtlasL10n.string("smartclean.evidence.path.more", paths.count - 1)
                ))
            }
        }
        items.append(AtlasEvidenceItem(id: "size", label: AtlasL10n.string("smartclean.evidence.size"), value: AtlasFormatters.byteCount(finding.bytes)))
        items.append(AtlasEvidenceItem(
            id: "category",
            label: AtlasL10n.string("smartclean.evidence.category"),
            value: finding.storageCategory?.title ?? AtlasL10n.localizedCategory(finding.category)
        ))
        if let modified = finding.fileAge?.lastModifiedDate {
            items.append(AtlasEvidenceItem(id: "modified", label: AtlasL10n.string("smartclean.evidence.lastModified"), value: AtlasFormatters.shortDate(modified)))
        } else if let created = finding.fileAge?.creationDate {
            items.append(AtlasEvidenceItem(id: "created", label: AtlasL10n.string("smartclean.evidence.created"), value: AtlasFormatters.shortDate(created)))
        }
        if !finding.detail.isEmpty {
            items.append(AtlasEvidenceItem(id: "source", label: AtlasL10n.string("smartclean.evidence.source"), value: finding.detail))
        }
        return items
    }

    /// Recovery sentence only when the plan really records this item as
    /// recoverable; nil suppresses the ⛨ box entirely (fail-closed §1.6).
    public static func recoveryText(planItem: ActionItem?, retentionDays: Int) -> String? {
        guard let planItem, planItem.recoverable else {
            return nil
        }
        return AtlasL10n.string("smartclean.stage.evidence.recovery.single", retentionDays)
    }

    // MARK: Evidence panel state (whole-panel derivation)

    /// Maps the workflow situation to the evidence-panel state machine:
    /// ③ → `.executing` row stream (a leading danger row carries the real
    /// failure reason — per-item fates are not invented); ② → `.single` for an
    /// explicit row selection, else `.aggregate` of the checked set; anything
    /// else → `.empty`.
    public static func panelState(
        effectiveStage: Int,
        isExecutionError: Bool,
        executionIssue: String?,
        evidenceSelectionID: String?,
        findings: [Finding],
        selectedFindings: [Finding],
        plan: ActionPlan,
        retentionDays: Int
    ) -> AtlasEvidenceState {
        if effectiveStage == SmartCleanStage.execute {
            var rows: [(title: String, status: AtlasTone, detail: String?)] = []
            if isExecutionError, let executionIssue {
                rows.append((title: AtlasL10n.string("smartclean.status.executionFailed"), status: .danger, detail: executionIssue))
            }
            rows.append(contentsOf: plan.items.map { (title: $0.title, status: AtlasTone.neutral, detail: nil) })
            return .executing(rows: rows)
        }
        if effectiveStage == SmartCleanStage.review {
            if let evidenceSelectionID,
               let finding = findings.first(where: { $0.id.uuidString == evidenceSelectionID }) {
                let planItem = plan.items.first(where: { $0.id == finding.id })
                return .single(content(for: finding, planItem: planItem, retentionDays: retentionDays))
            }
            if !selectedFindings.isEmpty {
                return .aggregate(aggregate(selectedFindings: selectedFindings, plan: plan, retentionDays: retentionDays))
            }
        }
        return .empty
    }

    // MARK: Aggregate evidence (multi-selection)

    public static func aggregate(selectedFindings: [Finding], plan: ActionPlan, retentionDays: Int) -> AtlasEvidenceAggregate {
        let totalBytes = selectedFindings.reduce(Int64(0)) { $0 + $1.bytes }
        let breakdown: [(label: String, count: Int, tone: AtlasTone)] = RiskLevel.allCases.compactMap { risk in
            let count = selectedFindings.filter { $0.risk == risk }.count
            guard count > 0 else { return nil }
            return (label: risk.title, count: count, tone: risk.atlasTone)
        }
        let ids = Set(selectedFindings.map(\.id.uuidString))
        let stats = recoveryStats(selectedFindingIDs: ids, plan: plan)
        let commonRecovery: String? = (stats.total > 0 && stats.recoverable == stats.total)
            ? AtlasL10n.string("smartclean.stage.evidence.recovery.aggregate", stats.total, retentionDays)
            : nil
        return AtlasEvidenceAggregate(
            count: selectedFindings.count,
            totalText: AtlasFormatters.byteCount(totalBytes),
            riskBreakdown: breakdown,
            commonRecoveryText: commonRecovery
        )
    }
}
