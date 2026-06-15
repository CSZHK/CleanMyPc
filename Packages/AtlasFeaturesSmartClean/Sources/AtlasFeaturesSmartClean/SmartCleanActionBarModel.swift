import AtlasDesignSystem
import AtlasDomain
import Foundation

/// Pure resolution of the pinned action bar for every workflow situation
/// (spec §2.3 table, right column): primary title/enabled/intent, the
/// state-driven recovery promise (§1.6 三式 — via `SmartCleanEvidenceBuilder`),
/// the mono selection metric, and the progress capsule while a task runs.
/// Pure and unit-tested; the coordinator just renders it into `AtlasActionBar`.
public struct SmartCleanActionBarModel: Equatable {
    /// What the primary button does — the coordinator maps intents to effects.
    public enum Intent: Equatable, Sendable {
        /// Show the execute confirmation, then run the reviewed selection.
        case execute
        /// Leave the read-only look-back (回看) for the live stage.
        case returnToCurrent
        /// Open the ④ receipt view (post-failure partial receipt included).
        case viewReceipt
        /// Rescan / new scan — confirmation path when a plan № is active.
        case rescan
        /// Progress mode — no primary action.
        case none
    }

    public var title: String
    public var isEnabled: Bool
    public var promise: String?
    public var metricText: String?
    public var progress: Double?
    public var intent: Intent

    public struct Inputs {
        public var effectiveStage: Int
        public var isReadOnly: Bool
        public var isScanning: Bool
        public var isExecuting: Bool
        /// ② empty: the scan really returned zero findings (spec §2.3 row 6).
        public var isReviewZero: Bool
        public var canExecutePlan: Bool
        public var scanProgress: Double
        public var selectedCount: Int
        public var selectedBytes: Int64
        public var recoverableCount: Int
        public var retentionDays: Int
        public var hasReceipt: Bool
        /// Estimated freed bytes from the receipt (0 ⇒ no metric shown).
        public var receiptFreedBytes: Int64
        public var hasPlanNumber: Bool

        public init(
            effectiveStage: Int,
            isReadOnly: Bool,
            isScanning: Bool,
            isExecuting: Bool,
            isReviewZero: Bool,
            canExecutePlan: Bool,
            scanProgress: Double,
            selectedCount: Int,
            selectedBytes: Int64,
            recoverableCount: Int,
            retentionDays: Int,
            hasReceipt: Bool,
            receiptFreedBytes: Int64,
            hasPlanNumber: Bool
        ) {
            self.effectiveStage = effectiveStage
            self.isReadOnly = isReadOnly
            self.isScanning = isScanning
            self.isExecuting = isExecuting
            self.isReviewZero = isReviewZero
            self.canExecutePlan = canExecutePlan
            self.scanProgress = scanProgress
            self.selectedCount = selectedCount
            self.selectedBytes = selectedBytes
            self.recoverableCount = recoverableCount
            self.retentionDays = retentionDays
            self.hasReceipt = hasReceipt
            self.receiptFreedBytes = receiptFreedBytes
            self.hasPlanNumber = hasPlanNumber
        }
    }

    public static func resolve(_ inputs: Inputs) -> SmartCleanActionBarModel {
        // Live tasks beat everything: the primary slot becomes a progress capsule.
        if inputs.isScanning {
            return SmartCleanActionBarModel(
                title: AtlasL10n.string("smartclean.loading.scan"),
                isEnabled: false, promise: nil, metricText: nil,
                progress: inputs.scanProgress, intent: .none
            )
        }
        if inputs.isExecuting {
            return SmartCleanActionBarModel(
                title: AtlasL10n.string("smartclean.loading.execute"),
                isEnabled: false, promise: nil, metricText: nil,
                // Indeterminate during execution (round-14): scanProgress is the
                // STALE 1.0 from the prior scan — the worker reports progress
                // only on completion — so a determinate value misrepresents a
                // just-started execution as 100% done.
                progress: nil, intent: .none
            )
        }
        // Look-back is read-only: the only action is returning to the live stage.
        if inputs.isReadOnly {
            return SmartCleanActionBarModel(
                title: AtlasL10n.string("smartclean.stage.readonly.return"),
                isEnabled: true, promise: nil, metricText: nil,
                progress: nil, intent: .returnToCurrent
            )
        }
        switch inputs.effectiveStage {
        case SmartCleanStage.review where !inputs.isReviewZero:
            return SmartCleanActionBarModel(
                title: AtlasL10n.string("smartclean.stage.actionbar.execute", inputs.selectedCount),
                isEnabled: inputs.canExecutePlan && inputs.selectedCount > 0,
                // ⛨ promise 三式 (§1.6): full / partial / absent, never static.
                promise: SmartCleanEvidenceBuilder.promise(
                    recoverableCount: inputs.recoverableCount,
                    totalCount: inputs.selectedCount,
                    retentionDays: inputs.retentionDays
                ),
                metricText: SmartCleanEvidenceBuilder.metricText(
                    selectedBytes: inputs.selectedBytes,
                    selectedCount: inputs.selectedCount
                ),
                progress: nil, intent: .execute
            )
        case SmartCleanStage.execute:
            // ③ settled state here is the error state (running was handled above):
            // primary = view the partial receipt (spec §2.3 row 7).
            return SmartCleanActionBarModel(
                title: AtlasL10n.string("smartclean.stage.actionbar.viewReceipt"),
                isEnabled: inputs.hasReceipt, promise: nil, metricText: nil,
                progress: nil, intent: .viewReceipt
            )
        case SmartCleanStage.receipt:
            return SmartCleanActionBarModel(
                title: AtlasL10n.string("smartclean.stage.actionbar.newScan"),
                isEnabled: true, promise: nil,
                metricText: inputs.receiptFreedBytes > 0
                    ? AtlasFormatters.byteCount(inputs.receiptFreedBytes)
                    : nil,
                progress: nil, intent: .rescan
            )
        default:
            // ① idle (incl. ② zero-finding fallthrough): scan or numbered rescan.
            return SmartCleanActionBarModel(
                title: AtlasL10n.string(
                    inputs.hasPlanNumber ? "smartclean.stage.actionbar.rescan" : "smartclean.action.runScan"
                ),
                isEnabled: true, promise: nil, metricText: nil,
                progress: nil, intent: .rescan
            )
        }
    }
}
