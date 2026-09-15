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
        /// `P1-9`：执行中跳台账（只读）。执行态此前是 `intent: .none` —— action bar
        /// **完全无可点动作**，用户以为卡死时的自然反应（切页面）没有正规出口。
        case viewLedger
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
            // `P1-9`：执行中**不作无意义的不确定态**，且 action bar 不得完全无可点动作。
            // worker 只在完成时上报进度，故进度条保持不确定（不伪造百分比），
            // 但给出真实可得的确定性信息（已用时，见 ③ 阶段的 TimelineView）
            // 与一个只读出口（查看台账）。
            return SmartCleanActionBarModel(
                title: AtlasL10n.string("smartclean.stage.actionbar.viewLedger"),
                isEnabled: true, promise: nil, metricText: nil,
                progress: nil, intent: .viewLedger
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
            // ③ settled state here is the error state (running was handled above).
            // 契约一 §1.2(3)（`P1-11`）：**禁止渲染一个点了不动的控件**。
            // 此前 `hasReceipt == false` 时按钮置灰，而错误态内嵌的 action 又因
            // `effectiveStage` 退回而无效 —— 失败后唯一的出路点了没反应。
            guard inputs.hasReceipt else {
                return SmartCleanActionBarModel(
                    title: AtlasL10n.string("smartclean.stage.actionbar.rescan"),
                    isEnabled: true,
                    promise: AtlasL10n.string("action.receipt.missing.title"),
                    // fail-closed（§1.6）：worker 未返回就失败时，本次到底动了几项
                    // 无从确认，不得编造。只说得出「已选 N 项」。
                    metricText: AtlasL10n.string("action.receipt.missing.counts", inputs.selectedCount),
                    progress: nil, intent: .rescan
                )
            }
            return SmartCleanActionBarModel(
                title: AtlasL10n.string("smartclean.stage.actionbar.viewReceipt"),
                isEnabled: true, promise: nil, metricText: nil,
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
