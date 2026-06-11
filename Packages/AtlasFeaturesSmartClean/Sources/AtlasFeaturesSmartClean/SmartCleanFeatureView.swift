import AtlasDesignSystem
import AtlasDomain
import SwiftUI

/// Smart Clean — first full assembly of the Calm Ledger workflow skeleton
/// (spec §2.3): plan-№ title area, four-stage bar, stage-routed content,
/// evidence panel (≥880pt) or non-modal drawer (<880pt), pinned action bar
/// with the state-driven recovery promise (§1.6). Stage truth is
/// resolve-on-render (decision A): the shell derives `state.currentStage` from
/// live model state and this view never writes it; user-mutable view state
/// flows back through `onStateChange` and persists per-route on the app model.
public struct SmartCleanFeatureView: View {
    @Environment(\.atlasContentWidth) private var contentWidth
    @FocusState private var evidenceFocus: String?
    @State private var showExecuteConfirmation = false
    @State private var actionBarInset: CGFloat = 0

    private let findings: [Finding]
    private let plan: ActionPlan
    private let scanSummary: String
    private let scanProgress: Double
    private let isScanning: Bool
    private let isExecutingPlan: Bool
    private let isCurrentPlanFresh: Bool
    private let canExecutePlan: Bool
    private let planIssue: String?
    private let executionIssue: String?
    private let executionReceipt: SmartCleanExecutionReceipt?
    private let retentionDays: Int
    private let searchText: String
    private let state: SmartCleanWorkflowState
    private let onStateChange: (SmartCleanWorkflowState) -> Void
    private let onStartScan: () -> Void
    private let onRefreshPreview: () -> Void
    private let onRequestRescan: () -> Void
    private let onConfirmRescan: () -> Void
    private let onCancelRescan: () -> Void
    private let onExecuteSelection: ([UUID]) -> Void
    private let onUndoExecution: (() -> Void)?
    private let onNavigateToLedger: () -> Void

    public init(
        findings: [Finding] = [],
        plan: ActionPlan = ActionPlan(title: "", items: [], estimatedBytes: 0),
        scanSummary: String = "",
        scanProgress: Double = 0,
        isScanning: Bool = false,
        isExecutingPlan: Bool = false,
        isCurrentPlanFresh: Bool = false,
        canExecutePlan: Bool = false,
        planIssue: String? = nil,
        executionIssue: String? = nil,
        executionReceipt: SmartCleanExecutionReceipt? = nil,
        retentionDays: Int = 7,
        searchText: String = "",
        state: SmartCleanWorkflowState = SmartCleanWorkflowState(),
        onStateChange: @escaping (SmartCleanWorkflowState) -> Void = { _ in },
        onStartScan: @escaping () -> Void = {},
        onRefreshPreview: @escaping () -> Void = {},
        onRequestRescan: @escaping () -> Void = {},
        onConfirmRescan: @escaping () -> Void = {},
        onCancelRescan: @escaping () -> Void = {},
        onExecuteSelection: @escaping ([UUID]) -> Void = { _ in },
        onUndoExecution: (() -> Void)? = nil,
        onNavigateToLedger: @escaping () -> Void = {}
    ) {
        self.findings = findings
        self.plan = plan
        self.scanSummary = scanSummary
        self.scanProgress = scanProgress
        self.isScanning = isScanning
        self.isExecutingPlan = isExecutingPlan
        self.isCurrentPlanFresh = isCurrentPlanFresh
        self.canExecutePlan = canExecutePlan
        self.planIssue = planIssue
        self.executionIssue = executionIssue
        self.executionReceipt = executionReceipt
        self.retentionDays = retentionDays
        self.searchText = searchText
        self.state = state
        self.onStateChange = onStateChange
        self.onStartScan = onStartScan
        self.onRefreshPreview = onRefreshPreview
        self.onRequestRescan = onRequestRescan
        self.onConfirmRescan = onConfirmRescan
        self.onCancelRescan = onCancelRescan
        self.onExecuteSelection = onExecuteSelection
        self.onUndoExecution = onUndoExecution
        self.onNavigateToLedger = onNavigateToLedger
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("smartclean.screen.title"),
            subtitle: AtlasL10n.string("smartclean.screen.subtitle"),
            maxContentWidth: AtlasLayout.maxWorkflowWidth,
            actionBar: { AnyView(actionBar) }
        ) {
            stageHeader

            if isReadOnly {
                SmartCleanReadOnlyBanner { mutate { $0.displayedStage = $0.currentStage } }
            }

            if effectiveStage == SmartCleanStage.receipt {
                receiptContent
            } else {
                HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                    stageContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    if showsSidePanel {
                        evidencePanel
                            .frame(width: AtlasLayout.evidencePanelMinWidth)
                    }
                }
            }
        }
        .simultaneousGesture(outsideTapGesture)
        .overlay(alignment: .trailing) {
            if isDrawerLayout, state.drawerPresented {
                SmartCleanEvidenceDrawer(bottomInset: actionBarInset, onDismiss: dismissDrawer) {
                    evidencePanel
                }
            }
        }
        .onPreferenceChange(AtlasActionBarHeightKey.self) { actionBarInset = $0 }
        .confirmationDialog(
            AtlasL10n.string("smartclean.rescan.title"),
            isPresented: rescanDialogBinding,
            titleVisibility: .visible
        ) {
            Button(AtlasL10n.string("smartclean.rescan.confirm"), role: .destructive, action: onConfirmRescan)
            Button(AtlasL10n.string("confirm.cancel"), role: .cancel, action: onCancelRescan)
        } message: {
            Text(AtlasL10n.string("smartclean.rescan.message", state.planNumber ?? 0))
        }
        .confirmationDialog(
            AtlasL10n.string("smartclean.confirm.execute.title"),
            isPresented: $showExecuteConfirmation,
            titleVisibility: .visible
        ) {
            Button(AtlasL10n.string("smartclean.action.execute"), role: .destructive) {
                onExecuteSelection(selectedFindingUUIDs)
            }
            Button(AtlasL10n.string("confirm.cancel"), role: .cancel) {}
        } message: {
            Text(AtlasL10n.string("smartclean.confirm.execute.message"))
        }
    }

    // MARK: Derived stage state

    private var effectiveStage: Int {
        SmartCleanEvidenceBuilder.effectiveStage(
            displayedStage: state.displayedStage,
            currentStage: state.currentStage,
            hasReceipt: executionReceipt != nil
        )
    }

    private var isReadOnly: Bool {
        SmartCleanEvidenceBuilder.isReadOnly(displayedStage: effectiveStage, currentStage: state.currentStage)
    }

    private var isDrawerLayout: Bool { contentWidth < AtlasLayout.evidencePanelBreakpoint }

    private var showsSidePanel: Bool { !isDrawerLayout && effectiveStage != SmartCleanStage.receipt }

    private var selectedFindingIDs: Set<String> {
        state.selectedIDs.intersection(Set(findings.map(\.id.uuidString)))
    }

    private var selectedFindings: [Finding] {
        findings.filter { selectedFindingIDs.contains($0.id.uuidString) }
    }

    private var selectedFindingUUIDs: [UUID] { selectedFindings.map(\.id) }

    // MARK: Header (plan № + stage bar)

    private var stageHeader: some View {
        SmartCleanStageHeader(
            planNumber: state.planNumber,
            receiptCode: state.receiptCode,
            effectiveStage: effectiveStage,
            completedStages: SmartCleanEvidenceBuilder.completedStages(
                currentStage: state.currentStage,
                effectiveStage: effectiveStage
            ),
            onSelectStage: { index in mutate { $0.displayedStage = index } }
        )
    }

    // MARK: Stage content router

    @ViewBuilder
    private var stageContent: some View {
        switch effectiveStage {
        case SmartCleanStage.scan:
            SmartCleanScanStageView(
                isScanning: state.isScanInProgress || isScanning,
                scanSummary: scanSummary,
                scanProgress: scanProgress,
                hasCachedFindings: !findings.isEmpty || !plan.items.isEmpty,
                planIssue: planIssue,
                onStartScan: onStartScan,
                onRefreshPreview: onRefreshPreview
            )
        case SmartCleanStage.review:
            SmartCleanReviewStageView(
                findings: findings,
                searchQuery: searchText,
                riskFilter: state.riskFilter,
                selectedIDs: selectedFindingIDs,
                evidenceSelectionID: state.evidenceSelectionID,
                isReadOnly: isReadOnly,
                showsEvidenceButton: isDrawerLayout,
                isReviewEmpty: state.isReviewEmpty && findings.isEmpty,
                evidenceFocus: $evidenceFocus,
                onToggle: { id in mutate { $0.selectedIDs.formSymmetricDifference([id]) } },
                onSetRiskFilter: { filter in mutate { $0.riskFilter = filter } },
                onSelectEvidence: { id in mutate { $0.evidenceSelectionID = id } },
                onOpenEvidence: { id in mutate { $0.evidenceSelectionID = id; $0.drawerPresented = true } },
                onRequestRescan: rescanTapped
            )
        default:
            SmartCleanExecuteStageView(
                plan: plan,
                isExecuting: isExecutingPlan,
                progress: scanProgress,
                summary: scanSummary,
                executionIssue: state.isExecutionError ? executionIssue : nil,
                onViewReceipt: { mutate { $0.displayedStage = SmartCleanStage.receipt } }
            )
        }
    }

    @ViewBuilder
    private var receiptContent: some View {
        if let executionReceipt {
            SmartCleanReceiptView(
                receipt: executionReceipt,
                onUndo: onUndoExecution,
                onNavigateToLedger: onNavigateToLedger
            )
        } else {
            AtlasEmptyState(
                title: AtlasL10n.string("smartclean.receipt.missing.title"),
                detail: AtlasL10n.string("smartclean.receipt.missing.detail"),
                systemImage: "doc.text",
                tone: .neutral
            )
        }
    }

    // MARK: Evidence panel

    private var evidencePanel: some View {
        AtlasEvidencePanel(state: SmartCleanEvidenceBuilder.panelState(
            effectiveStage: effectiveStage,
            isExecutionError: state.isExecutionError,
            executionIssue: executionIssue,
            evidenceSelectionID: state.evidenceSelectionID,
            findings: findings,
            selectedFindings: selectedFindings,
            plan: plan,
            retentionDays: retentionDays
        ))
    }

    // MARK: Action bar (promise = state-driven 三式, §1.6 — resolved purely)

    private var actionBar: some View {
        let stats = SmartCleanEvidenceBuilder.recoveryStats(selectedFindingIDs: selectedFindingIDs, plan: plan)
        let model = SmartCleanActionBarModel.resolve(SmartCleanActionBarModel.Inputs(
            effectiveStage: effectiveStage,
            isReadOnly: isReadOnly,
            isScanning: isScanning || state.isScanInProgress,
            isExecuting: isExecutingPlan,
            isReviewZero: state.isReviewEmpty && findings.isEmpty,
            canExecutePlan: canExecutePlan,
            scanProgress: scanProgress,
            selectedCount: selectedFindingIDs.count,
            selectedBytes: selectedFindings.reduce(Int64(0)) { $0 + $1.bytes },
            recoverableCount: stats.recoverable,
            retentionDays: retentionDays,
            hasReceipt: executionReceipt != nil,
            receiptFreedBytes: executionReceipt?.estimatedFreedBytes ?? 0,
            hasPlanNumber: state.planNumber != nil
        ))
        return AtlasActionBar(
            primaryTitle: model.title,
            primaryEnabled: model.isEnabled,
            onPrimary: { perform(model.intent) },
            promise: model.promise,
            metricText: model.metricText,
            progress: model.progress
        )
    }

    private func perform(_ intent: SmartCleanActionBarModel.Intent) {
        switch intent {
        case .execute:
            showExecuteConfirmation = true
        case .returnToCurrent:
            mutate { $0.displayedStage = $0.currentStage }
        case .viewReceipt:
            mutate { $0.displayedStage = SmartCleanStage.receipt }
        case .rescan:
            rescanTapped()
        case .none:
            break
        }
    }

    // MARK: Intents

    /// Rescan / new-scan entry — same confirmation path as Cmd+Shift+R
    /// (decision B): an active № raises the flag (dialog supersedes on
    /// confirm); without one the scan starts directly.
    private func rescanTapped() {
        state.planNumber != nil ? onRequestRescan() : onStartScan()
    }

    private var rescanDialogBinding: Binding<Bool> {
        Binding(
            get: { state.rescanConfirmationPending },
            set: { presented in
                if !presented { onCancelRescan() }
            }
        )
    }

    private var outsideTapGesture: some Gesture {
        TapGesture().onEnded { if state.drawerPresented { dismissDrawer() } }
    }

    private func dismissDrawer() {
        mutate { $0.drawerPresented = false }
        // Focus returns to the triggering row's ⓘ control (spec §2.4).
        evidenceFocus = state.evidenceSelectionID
    }

    private func mutate(_ transform: (inout SmartCleanWorkflowState) -> Void) {
        var newState = state
        transform(&newState)
        onStateChange(newState)
    }
}
