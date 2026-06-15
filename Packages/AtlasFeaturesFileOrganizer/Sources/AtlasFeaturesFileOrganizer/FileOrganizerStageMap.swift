import Foundation

// MARK: - Stage ordinals (spec §2.3 / §3 FileOrganizer — five segments)

/// 0-based stage ordinals for the file-organizer workflow skeleton (spec §2.3).
/// FileOrganizer has **five** segments (① scan · ② rules · ③ preview · ④ execute
/// · ⑤ receipt), unlike SmartClean's four — so it owns its own stage map rather
/// than sharing `AtlasWorkflowStageMap` (Apps-side, four stages). The Apps-side
/// `AtlasWorkflowViewState` host is reused unchanged (its `currentStage` is an
/// opaque `Int`); this enum names the indexes on the feature side.
public enum FileOrganizerStage {
    /// ① 扫描 — scan (no plan yet / scanning in progress).
    public static let scan = 0
    /// ② 规则 — rules (plan fresh: review classified entries + edit rules).
    public static let rules = 1
    /// ③ 预演 — preview (dry-run results: move manifest + conflict marks).
    public static let preview = 2
    /// ④ 执行 — execute (live execution / error state).
    public static let execute = 3
    /// ⑤ 回执 — receipt (module receipt after execution).
    public static let receipt = 4
    /// Segment count for the stage bar.
    public static let count = 5
}

// MARK: - Pure stage resolution (decision A — resolve-on-render)

/// Pure mapping from live model state to the current FileOrganizer stage.
///
/// This is the FileOrganizer analogue of Apps' `AtlasWorkflowStageMap.resolve`
/// (Batch I decision A = resolve-on-render): the shell derives `currentStage`
/// on every render from live model state via `FileOrganizerStageMap.resolve`,
/// and the stored ViewState `currentStage` is bookkeeping only.
///
/// Five-segment precedence (spec §2.3 + Batch L FileOrganizer row):
/// 1. executing  → ④ execute (live)
/// 2. scanning/classifying → ① scan (in progress)
/// 3. executionFailed → ④ execute (error state)
/// 4. executionCompleted → ⑤ receipt
/// 5. previewReady (dry-run results available) → ③ preview
/// 6. planFresh → ② rules (empty when entries == 0)
/// 7. otherwise → ① scan
///
/// "Preview ready" is signalled by `hasPreviewResults`: a fresh plan with at
/// least one item whose dry-run has been requested. The dry-run is an explicit
/// user action (`onDryRun`) that refreshes the plan in place; once it has run,
/// the stage advances from ② to ③ until a new scan/classify supersedes it.
public enum FileOrganizerStageMap {
    /// Model-state snapshot consumed by `resolve(_:)`. Callers map their module
    /// flags in (e.g. `isScanning`, `isClassifying`, `isExecuting`,
    /// `executionIssue != nil`, `executionCompleted`, `isPlanFresh`,
    /// `hasPreviewResults`, `entriesCount`).
    public struct Inputs: Equatable {
        public var isScanning = false
        public var isClassifying = false
        public var isExecuting = false
        /// Execution issue present (e.g. `fileOrganizerExecutionIssue != nil`).
        public var executionFailed = false
        public var executionCompleted = false
        /// Plan fresh — scan/classify produced an actionable plan (② rules).
        public var isPlanFresh = false
        /// Dry-run results are available for the current plan (③ preview). Set
        /// when the user has run `onDryRun` and the plan has not been superseded.
        public var hasPreviewResults = false
        /// Number of classified entries (drives the ② empty state).
        public var entriesCount = 0

        public init(
            isScanning: Bool = false,
            isClassifying: Bool = false,
            isExecuting: Bool = false,
            executionFailed: Bool = false,
            executionCompleted: Bool = false,
            isPlanFresh: Bool = false,
            hasPreviewResults: Bool = false,
            entriesCount: Int = 0
        ) {
            self.isScanning = isScanning
            self.isClassifying = isClassifying
            self.isExecuting = isExecuting
            self.executionFailed = executionFailed
            self.executionCompleted = executionCompleted
            self.isPlanFresh = isPlanFresh
            self.hasPreviewResults = hasPreviewResults
            self.entriesCount = entriesCount
        }
    }

    public struct Resolution: Equatable {
        public var current: Int
        /// ① with live progress (mono path scroll + percent).
        public var isScanInProgress = false
        /// ② empty state — scan finished with 0 entries.
        public var isRulesEmpty = false
        /// ④ error state — failed mid-execution (partial completion enters ledger).
        public var isExecutionError = false

        public init(
            current: Int,
            isScanInProgress: Bool = false,
            isRulesEmpty: Bool = false,
            isExecutionError: Bool = false
        ) {
            self.current = current
            self.isScanInProgress = isScanInProgress
            self.isRulesEmpty = isRulesEmpty
            self.isExecutionError = isExecutionError
        }
    }

    /// Spec §2.3 mapping table (FileOrganizer five-segment variant). Precedence
    /// (most live state wins): executing > scanning > failed > completed >
    /// preview-ready > plan-fresh > no plan.
    public static func resolve(_ inputs: Inputs) -> Resolution {
        if inputs.isExecuting {
            return Resolution(current: FileOrganizerStage.execute)
        }
        if inputs.isScanning || inputs.isClassifying {
            return Resolution(current: FileOrganizerStage.scan, isScanInProgress: true)
        }
        if inputs.executionFailed {
            return Resolution(current: FileOrganizerStage.execute, isExecutionError: true)
        }
        if inputs.executionCompleted {
            return Resolution(current: FileOrganizerStage.receipt)
        }
        if inputs.hasPreviewResults {
            return Resolution(current: FileOrganizerStage.preview)
        }
        if inputs.isPlanFresh {
            return Resolution(current: FileOrganizerStage.rules, isRulesEmpty: inputs.entriesCount == 0)
        }
        return Resolution(current: FileOrganizerStage.scan)
    }
}

// MARK: - Stage predicates (pure, unit-tested)

/// Pure stage helpers shared by the coordinator and the action-bar model. These
/// mirror SmartClean's `SmartCleanEvidenceBuilder` stage predicates, adapted to
/// the five-segment FileOrganizer stage set.
public enum FileOrganizerStagePredicates {
    /// Look-back is read-only (spec §2.3 回看 = 只读快照).
    public static func isReadOnly(displayedStage: Int, currentStage: Int) -> Bool {
        displayedStage < currentStage
    }

    /// The stage that actually renders. Rules:
    /// - look-back (`displayed < current`) shows the displayed stage read-only;
    /// - after a mid-run failure (current = ④ error) the receipt is reachable
    ///   explicitly via 「查看回执」 when a receipt record exists;
    /// - anything else follows the resolved current stage (resolve-on-render).
    public static func effectiveStage(
        displayedStage: Int,
        currentStage: Int,
        hasReceipt: Bool
    ) -> Int {
        if displayedStage < currentStage {
            return max(displayedStage, FileOrganizerStage.scan)
        }
        if displayedStage == FileOrganizerStage.receipt,
           currentStage == FileOrganizerStage.execute,
           hasReceipt {
            return FileOrganizerStage.receipt
        }
        return currentStage
    }

    /// Completed (tappable, look-back) stage indexes for the stage bar.
    public static func completedStages(currentStage: Int, effectiveStage: Int) -> Set<Int> {
        Set(0..<max(currentStage, effectiveStage))
    }
}
