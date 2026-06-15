import AtlasDesignSystem
import AtlasDomain
import Foundation

/// Pure resolution of the pinned action bar for the file-organizer workflow
/// (spec §2.3 five-segment table, right column): primary title/enabled/intent,
/// the mono selection metric, and the progress capsule while a task runs.
///
/// Mirrors `SmartCleanActionBarModel` shape, adapted to the five-segment
/// FileOrganizer stages. Pure and unit-tested; the coordinator renders it into
/// `AtlasActionBar`.
public struct FileOrganizerActionBarModel: Equatable {
    /// What the primary button does — the coordinator maps intents to effects.
    public enum Intent: Equatable, Sendable {
        /// Run the dry-run (③ preview entry from ② rules).
        case dryRun
        /// Show the execute confirmation, then run the reviewed selection.
        case execute
        /// Leave the read-only look-back (回看) for the live stage.
        case returnToCurrent
        /// Open the ⑤ receipt view (post-failure partial receipt included).
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

    public init(
        title: String,
        isEnabled: Bool,
        promise: String?,
        metricText: String?,
        progress: Double?,
        intent: Intent
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.promise = promise
        self.metricText = metricText
        self.progress = progress
        self.intent = intent
    }

    public struct Inputs: Equatable {
        public var effectiveStage: Int
        public var isReadOnly: Bool
        public var isScanning: Bool
        public var isClassifying: Bool
        public var isExecuting: Bool
        /// ② empty: the scan really returned zero entries (spec §2.3).
        public var isRulesEmpty: Bool
        /// A fresh plan with at least one item exists (enables dry-run/execute).
        public var canDryRun: Bool
        public var canExecutePlan: Bool
        public var scanProgress: Double
        public var selectedCount: Int
        public var selectedBytes: Int64
        public var hasReceipt: Bool
        /// Moved-item count from the receipt (0 ⇒ no metric shown).
        public var receiptMovedCount: Int
        public var hasPlanNumber: Bool

        public init(
            effectiveStage: Int,
            isReadOnly: Bool,
            isScanning: Bool,
            isClassifying: Bool,
            isExecuting: Bool,
            isRulesEmpty: Bool,
            canDryRun: Bool,
            canExecutePlan: Bool,
            scanProgress: Double,
            selectedCount: Int,
            selectedBytes: Int64,
            hasReceipt: Bool,
            receiptMovedCount: Int,
            hasPlanNumber: Bool
        ) {
            self.effectiveStage = effectiveStage
            self.isReadOnly = isReadOnly
            self.isScanning = isScanning
            self.isClassifying = isClassifying
            self.isExecuting = isExecuting
            self.isRulesEmpty = isRulesEmpty
            self.canDryRun = canDryRun
            self.canExecutePlan = canExecutePlan
            self.scanProgress = scanProgress
            self.selectedCount = selectedCount
            self.selectedBytes = selectedBytes
            self.hasReceipt = hasReceipt
            self.receiptMovedCount = receiptMovedCount
            self.hasPlanNumber = hasPlanNumber
        }
    }

    public static func resolve(_ inputs: Inputs) -> FileOrganizerActionBarModel {
        // Live tasks beat everything: the primary slot becomes a progress capsule.
        if inputs.isScanning || inputs.isClassifying {
            return FileOrganizerActionBarModel(
                title: inputs.isScanning
                    ? AtlasL10n.string("fileorganizer.status.scanning")
                    : AtlasL10n.string("fileorganizer.status.classifying"),
                isEnabled: false, promise: nil, metricText: nil,
                progress: inputs.scanProgress, intent: .none
            )
        }
        if inputs.isExecuting {
            return FileOrganizerActionBarModel(
                title: AtlasL10n.string("fileorganizer.status.executing"),
                isEnabled: false, promise: nil, metricText: nil,
                progress: inputs.scanProgress, intent: .none
            )
        }
        // Look-back is read-only: the only action is returning to the live stage.
        if inputs.isReadOnly {
            return FileOrganizerActionBarModel(
                title: AtlasL10n.string("fileorganizer.stage.readonly.return"),
                isEnabled: true, promise: nil, metricText: nil,
                progress: nil, intent: .returnToCurrent
            )
        }
        switch inputs.effectiveStage {
        case FileOrganizerStage.rules where !inputs.isRulesEmpty:
            return FileOrganizerActionBarModel(
                title: AtlasL10n.string("fileorganizer.stage.actionbar.dryRun", inputs.selectedCount),
                isEnabled: inputs.canDryRun && inputs.selectedCount > 0,
                promise: AtlasL10n.string("fileorganizer.promise.dryRun"),
                metricText: metricText(selectedBytes: inputs.selectedBytes, selectedCount: inputs.selectedCount),
                progress: nil, intent: .dryRun
            )
        case FileOrganizerStage.preview:
            return FileOrganizerActionBarModel(
                title: AtlasL10n.string("fileorganizer.stage.actionbar.execute"),
                isEnabled: inputs.canExecutePlan,
                promise: AtlasL10n.string("fileorganizer.promise.execute"),
                metricText: nil,
                progress: nil, intent: .execute
            )
        case FileOrganizerStage.execute:
            // ④ settled state here is the error state (running was handled above):
            // primary = view the partial receipt (spec §2.3 row 7).
            return FileOrganizerActionBarModel(
                title: AtlasL10n.string("fileorganizer.stage.actionbar.viewReceipt"),
                isEnabled: inputs.hasReceipt, promise: nil, metricText: nil,
                progress: nil, intent: .viewReceipt
            )
        case FileOrganizerStage.receipt:
            return FileOrganizerActionBarModel(
                title: AtlasL10n.string(
                    inputs.hasPlanNumber ? "fileorganizer.stage.actionbar.rescan" : "fileorganizer.action.scan"
                ),
                isEnabled: true, promise: nil,
                metricText: inputs.receiptMovedCount > 0
                    ? AtlasL10n.string("fileorganizer.receipt.moved.metric", inputs.receiptMovedCount)
                    : nil,
                progress: nil, intent: .rescan
            )
        default:
            // ① idle (incl. ② zero-entry fallthrough): scan or numbered rescan.
            return FileOrganizerActionBarModel(
                title: AtlasL10n.string(
                    inputs.hasPlanNumber ? "fileorganizer.stage.actionbar.rescan" : "fileorganizer.action.scan"
                ),
                isEnabled: true, promise: nil, metricText: nil,
                progress: nil, intent: .rescan
            )
        }
    }

    /// Mono action-bar metric: 「X GB · N 项」 of the current selection.
    public static func metricText(selectedBytes: Int64, selectedCount: Int) -> String? {
        guard selectedCount > 0 else { return nil }
        return AtlasL10n.string(
            "fileorganizer.stage.metric.selected",
            AtlasFormatters.byteCount(selectedBytes),
            selectedCount
        )
    }
}
