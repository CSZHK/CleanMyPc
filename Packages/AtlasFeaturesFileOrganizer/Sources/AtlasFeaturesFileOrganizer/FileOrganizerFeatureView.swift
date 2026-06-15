import AtlasDesignSystem
import AtlasDomain
import SwiftUI

/// File Organizer — five-segment Calm Ledger workflow skeleton (spec §2.3/§3):
/// ①扫描 ②规则 ③预演 ④执行 ⑤回执. Stage truth is resolve-on-render (decision A):
/// the shell derives `state.currentStage` via `FileOrganizerStageMap.resolve`;
/// this view never writes it. User-mutable state flows back through
/// `onStateChange` and persists per-route on the app model.
public struct FileOrganizerFeatureView: View {
    @Environment(\.atlasContentWidth) private var contentWidth
    @State private var showExecuteConfirmation = false
    @State private var actionBarInset: CGFloat = 0
    @State private var isRuleEditorPresented = false
    @State private var selectedFolders: [String]

    private let entries: [FileOrganizerEntry]
    private let plan: ActionPlan
    private let scanSummary: String
    private let scanProgress: Double
    private let isScanning: Bool
    private let isClassifying: Bool
    private let isExecutingPlan: Bool
    private let isPlanFresh: Bool
    private let canExecutePlan: Bool
    private let planIssue: String?
    private let executionIssue: String?
    private let executionReceipt: FileOrganizerExecutionReceipt?
    private let movedCount: Int
    private let scannedFolders: [String]
    private let rules: [FileOrganizerRule]
    private let destinationBasePath: String
    private let isRecursiveScan: Bool
    private let searchText: String
    private let state: FileOrganizerWorkflowState
    private let onStateChange: (FileOrganizerWorkflowState) -> Void
    private let onStartScan: ([String]) -> Void
    private let onClassify: ([UUID]) -> Void
    private let onRefreshPreview: ([UUID]) -> Void
    private let onExecutePlan: () -> Void
    private let onDryRun: () -> Void
    private let onUpdateDestination: (String) -> Void
    private let onUpdateRecursiveScan: (Bool) -> Void
    private let onUpdateRules: ([FileOrganizerRule]) -> Void
    private let onUndoExecution: (() -> Void)?
    private let onNavigateToLedger: () -> Void

    public init(
        entries: [FileOrganizerEntry] = [],
        plan: ActionPlan = ActionPlan(title: "", items: [], estimatedBytes: 0),
        scanSummary: String = "",
        scanProgress: Double = 0,
        isScanning: Bool = false,
        isClassifying: Bool = false,
        isExecutingPlan: Bool = false,
        isPlanFresh: Bool = false,
        canExecutePlan: Bool = false,
        planIssue: String? = nil,
        executionIssue: String? = nil,
        executionReceipt: FileOrganizerExecutionReceipt? = nil,
        movedCount: Int = 0,
        scannedFolders: [String] = [],
        rules: [FileOrganizerRule] = [],
        destinationBasePath: String = "~/Organized",
        isRecursiveScan: Bool = false,
        searchText: String = "",
        state: FileOrganizerWorkflowState = FileOrganizerWorkflowState(),
        onStateChange: @escaping (FileOrganizerWorkflowState) -> Void = { _ in },
        onStartScan: @escaping ([String]) -> Void = { _ in },
        onClassify: @escaping ([UUID]) -> Void = { _ in },
        onRefreshPreview: @escaping ([UUID]) -> Void = { _ in },
        onExecutePlan: @escaping () -> Void = {},
        onDryRun: @escaping () -> Void = {},
        onUpdateDestination: @escaping (String) -> Void = { _ in },
        onUpdateRecursiveScan: @escaping (Bool) -> Void = { _ in },
        onUpdateRules: @escaping ([FileOrganizerRule]) -> Void = { _ in },
        onUndoExecution: (() -> Void)? = nil,
        onNavigateToLedger: @escaping () -> Void = {}
    ) {
        self.entries = entries; self.plan = plan; self.scanSummary = scanSummary
        self.scanProgress = scanProgress; self.isScanning = isScanning
        self.isClassifying = isClassifying; self.isExecutingPlan = isExecutingPlan
        self.isPlanFresh = isPlanFresh; self.canExecutePlan = canExecutePlan
        self.planIssue = planIssue; self.executionIssue = executionIssue
        self.executionReceipt = executionReceipt; self.movedCount = movedCount
        self.scannedFolders = scannedFolders; self.rules = rules
        // Seed from the model's last-scanned folders so a custom selection
        // survives route switches (feature-local @State is destroyed when
        // AppShellView rebuilds this view on navigation — §7 red line). The
        // model persists scannedFolders; empty ⇒ first run ⇒ sensible defaults
        // (round-3).
        _selectedFolders = State(initialValue: scannedFolders.isEmpty ? ["~/Desktop", "~/Downloads"] : scannedFolders)
        self.destinationBasePath = destinationBasePath; self.isRecursiveScan = isRecursiveScan
        self.searchText = searchText; self.state = state; self.onStateChange = onStateChange
        self.onStartScan = onStartScan; self.onClassify = onClassify
        self.onRefreshPreview = onRefreshPreview; self.onExecutePlan = onExecutePlan
        self.onDryRun = onDryRun; self.onUpdateDestination = onUpdateDestination
        self.onUpdateRecursiveScan = onUpdateRecursiveScan; self.onUpdateRules = onUpdateRules
        self.onUndoExecution = onUndoExecution; self.onNavigateToLedger = onNavigateToLedger
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("fileorganizer.screen.title"),
            subtitle: AtlasL10n.string("fileorganizer.screen.subtitle"),
            maxContentWidth: AtlasLayout.maxWorkflowWidth,
            actionBar: { AnyView(actionBar) }
        ) {
            stageHeader

            if isReadOnly {
                FileOrganizerReadOnlyBanner { mutate { $0.displayedStage = $0.currentStage } }
            }

            if effectiveStage == FileOrganizerStage.receipt {
                receiptContent
            } else {
                HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                    stageContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .disabled(isReadOnly)

                    if showsSidePanel {
                        evidencePanel
                            .frame(width: AtlasLayout.evidencePanelMinWidth)
                    }
                }
            }
        }
        .overlay {
            if isDrawerLayout, state.drawerPresented {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { dismissDrawer() }
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .trailing) {
            if isDrawerLayout, state.drawerPresented {
                FileOrganizerEvidenceDrawer(bottomInset: actionBarInset, onDismiss: dismissDrawer) {
                    evidencePanel
                }
            }
        }
        .onPreferenceChange(AtlasActionBarHeightKey.self) { actionBarInset = $0 }
        .confirmationDialog(
            AtlasL10n.string("fileorganizer.confirm.execute.title"),
            isPresented: $showExecuteConfirmation,
            titleVisibility: .visible
        ) {
            Button(AtlasL10n.string("fileorganizer.action.execute"), role: .destructive) {
                onExecutePlan()
            }
            Button(AtlasL10n.string("confirm.cancel"), role: .cancel) {}
        } message: {
            Text(AtlasL10n.string("fileorganizer.confirm.execute.message"))
        }
        .sheet(isPresented: $isRuleEditorPresented) {
            FileOrganizerRuleEditorView(rules: rules) { updatedRules in
                onUpdateRules(updatedRules)
                isRuleEditorPresented = false
            }
        }
    }

    // MARK: Derived stage state

    private var effectiveStage: Int {
        FileOrganizerStagePredicates.effectiveStage(
            displayedStage: state.displayedStage, currentStage: state.currentStage,
            hasReceipt: executionReceipt != nil)
    }
    private var isReadOnly: Bool {
        FileOrganizerStagePredicates.isReadOnly(displayedStage: effectiveStage, currentStage: state.currentStage)
    }
    private var isDrawerLayout: Bool { contentWidth < AtlasLayout.evidencePanelBreakpoint }
    private var showsSidePanel: Bool { !isDrawerLayout && effectiveStage != FileOrganizerStage.receipt }

    private var stageHeader: some View {
        FileOrganizerStageHeader(
            planNumber: state.planNumber, receiptCode: state.receiptCode,
            effectiveStage: effectiveStage,
            completedStages: FileOrganizerStagePredicates.completedStages(
                currentStage: state.currentStage, effectiveStage: effectiveStage),
            onSelectStage: { index in mutate { $0.displayedStage = index } }
        )
    }

    // MARK: Stage content router

    @ViewBuilder
    private var stageContent: some View {
        switch effectiveStage {
        case FileOrganizerStage.scan:
            scanStage
        case FileOrganizerStage.rules:
            rulesStage
        case FileOrganizerStage.preview:
            previewStage
        default:
            FileOrganizerExecuteStageView(
                plan: plan,
                isExecuting: isExecutingPlan,
                progress: scanProgress,
                summary: scanSummary,
                executionIssue: state.isExecutionError ? executionIssue : nil,
                onViewReceipt: { mutate { $0.displayedStage = FileOrganizerStage.receipt } }
            )
        }
    }

    @ViewBuilder
    private var scanStage: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            FileOrganizerScanStageView(
                isScanning: isScanning,
                isClassifying: isClassifying,
                scanSummary: scanSummary,
                scanProgress: scanProgress,
                hasCachedEntries: !entries.isEmpty || !plan.items.isEmpty,
                planIssue: planIssue,
                onStartScan: { onStartScan(selectedFolders) }
            )
            FileOrganizerConfigurationSection(
                selectedFolders: $selectedFolders,
                destinationBasePath: destinationBasePath,
                isRecursiveScan: isRecursiveScan,
                isDisabled: isScanning || isClassifying || isExecutingPlan,
                onUpdateDestination: onUpdateDestination,
                onUpdateRecursiveScan: onUpdateRecursiveScan
            )
        }
    }

    @ViewBuilder
    private var rulesStage: some View {
        FileOrganizerRulesStageView(
            entries: entries,
            searchQuery: searchText,
            rules: rules,
            selectedIDs: state.selectedIDs,
            evidenceSelectionID: state.evidenceSelectionID,
            isReadOnly: isReadOnly,
            showsEvidenceButton: isDrawerLayout,
            isRulesEmpty: state.isRulesEmpty && entries.isEmpty,
            conflictingIDs: FileOrganizerEvidenceBuilder.conflictingEntryIDs(entries),
            largeFileIDs: FileOrganizerEvidenceBuilder.largeFileIDs(entries),
            duplicateFileIDs: FileOrganizerEvidenceBuilder.duplicateFileIDs(entries),
            onToggle: { id in mutate { if state.selectedIDs.contains(id) { $0.selectedIDs.remove(id) } else { $0.selectedIDs.insert(id) } } },
            onSelectAll: { select in mutate { $0.selectedIDs = select ? Set(entries.map(\.id)) : [] } },
            onSelectEvidence: { id in mutate { $0.evidenceSelectionID = id } },
            onOpenEvidence: { id in mutate { $0.evidenceSelectionID = id; $0.drawerPresented = true } },
            onOpenRuleEditor: { isRuleEditorPresented = true },
            onRequestRescan: { onStartScan(selectedFolders) }
        )
    }

    @ViewBuilder
    private var previewStage: some View {
        FileOrganizerPreviewStageView(
            entries: entries,
            plan: plan,
            searchQuery: searchText,
            selectedIDs: state.selectedIDs,
            conflictingIDs: FileOrganizerEvidenceBuilder.conflictingEntryIDs(entries),
            planIssue: planIssue,
            isReadOnly: isReadOnly
        )
    }

    @ViewBuilder
    private var receiptContent: some View {
        if let executionReceipt {
            FileOrganizerReceiptView(
                receipt: executionReceipt,
                onUndo: onUndoExecution,
                onNavigateToLedger: onNavigateToLedger
            )
        } else {
            AtlasEmptyState(
                title: AtlasL10n.string("fileorganizer.receipt.missing.title"),
                detail: AtlasL10n.string("fileorganizer.receipt.missing.detail"),
                systemImage: "doc.text",
                tone: .neutral
            )
        }
    }

    // MARK: Evidence panel

    private var evidencePanel: some View {
        AtlasEvidencePanel(state: FileOrganizerEvidenceBuilder.panelState(
            entries: entries,
            selectedID: state.evidenceSelectionID,
            selectedIDs: state.selectedIDs,
            rules: rules
        ))
    }

    // MARK: Action bar

    private var actionBar: some View {
        let model = FileOrganizerActionBarModel.resolve(actionBarInputs)
        let isScanPrimary = (model.intent == .rescan && effectiveStage == FileOrganizerStage.scan)
        return AtlasActionBar(
            primaryTitle: model.title, primaryEnabled: model.isEnabled,
            onPrimary: { perform(model.intent) },
            promise: model.promise, metricText: model.metricText, progress: model.progress,
            primaryIdentifier: isScanPrimary ? "fileorganizer.runScan" : nil,
            primaryKeyboardShortcut: isScanPrimary ? .defaultAction : nil
        )
    }

    private var actionBarInputs: FileOrganizerActionBarModel.Inputs {
        FileOrganizerActionBarModel.Inputs(
            effectiveStage: effectiveStage, isReadOnly: isReadOnly,
            isScanning: isScanning || state.isScanInProgress, isClassifying: isClassifying,
            isExecuting: isExecutingPlan, isRulesEmpty: state.isRulesEmpty && entries.isEmpty,
            canDryRun: !plan.items.isEmpty && isPlanFresh, canExecutePlan: canExecutePlan,
            scanProgress: scanProgress, selectedCount: state.selectedIDs.count,
            selectedBytes: FileOrganizerEvidenceBuilder.selectedBytes(entries, selectedIDs: state.selectedIDs),
            hasReceipt: executionReceipt != nil, receiptMovedCount: movedCount,
            hasPlanNumber: state.planNumber != nil
        )
    }

    private func perform(_ intent: FileOrganizerActionBarModel.Intent) {
        switch intent {
        case .dryRun:
            onDryRun()
        case .execute:
            showExecuteConfirmation = true
        case .returnToCurrent:
            mutate { $0.displayedStage = $0.currentStage }
        case .viewReceipt:
            mutate { $0.displayedStage = FileOrganizerStage.receipt }
        case .rescan:
            onStartScan(selectedFolders)
        case .none:
            break
        }
    }

    // MARK: Helpers

    private func dismissDrawer() {
        mutate { $0.drawerPresented = false }
    }

    private func mutate(_ transform: (inout FileOrganizerWorkflowState) -> Void) {
        var newState = state
        transform(&newState)
        onStateChange(newState)
    }
}
