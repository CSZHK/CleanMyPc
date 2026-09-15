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
    /// `P1-9`：执行开始时刻（已用时显示用）。
    private let executionStartedAt: Date?
    private let isCurrentPlanFresh: Bool
    private let canExecutePlan: Bool
    /// 契约一：计划层结果（带 source）。视图按 `kind` 分流 —— `.advisory` 不走错误态（NEW-1）。
    private let planOutcome: AtlasActionOutcome?
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
        executionStartedAt: Date? = nil,
        isCurrentPlanFresh: Bool = false,
        canExecutePlan: Bool = false,
        planOutcome: AtlasActionOutcome? = nil,
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
        self.executionStartedAt = executionStartedAt
        self.isCurrentPlanFresh = isCurrentPlanFresh
        self.canExecutePlan = canExecutePlan
        self.planOutcome = planOutcome
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
                    // Look-back read-only enforcement (review fix C1, spec §2.3
                    // 回看 = 只读快照): disable the whole stage-content subtree when
                    // isReadOnly — every action (① 开始扫描/重新校验, ② checkboxes/
                    // 重扫, ③ 查看回执) stays inert. The 「返回当前阶段」 banner lives
                    // outside this subtree and the action bar is gated by the model.
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
        // Drawer outside-tap (review fix I2, spec §2.4): a scrim replaces
        // `.simultaneousGesture` which raced row/checkbox mutations (toggle +
        // dismiss from one render snapshot; dismiss clobbered the toggle). The
        // scrim sits above the list, below the drawer: row taps hit the row and
        // never reach the scrim, so the mutations can't collide; empty-area taps
        // hit the scrim and dismiss.
        .overlay {
            if isDrawerLayout, state.drawerPresented {
                Color.clear.contentShape(Rectangle())
                    .onTapGesture { dismissDrawer() }
                    .accessibilityHidden(true)
            }
        }
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
            AtlasDestructiveConfirmationMessage(executeConfirmation)
        }
    }

    /// 契约二 §2.2(1) 四问（`P0-5`）：真正能回答后果的 `N/M` 此前只在主按钮
    /// 下方的 promise 行里，弹窗把它丢了。现取同一 `recoveryStats` 计算带入弹窗。
    private var executeConfirmation: AtlasDestructiveConfirmation {
        let stats = SmartCleanEvidenceBuilder.recoveryStats(
            selectedFindingIDs: selectedFindingIDs,
            plan: plan
        )
        let facts = AtlasDestructiveFacts(
            object: AtlasL10n.string("confirm.destructive.object.items", stats.total),
            destination: AtlasL10n.string("confirm.destructive.destination.recoveryArea", retentionDays),
            recovery: stats.recoverable > 0
                ? AtlasL10n.string("confirm.destructive.recovery", retentionDays)
                : AtlasL10n.string("confirm.destructive.recovery.none")
        )
        return .recoverable(
            facts,
            recoverableCount: AtlasL10n.string(
                "confirm.destructive.recoverableCount",
                stats.recoverable,
                stats.total
            )
        )
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

    /// `P1-7`：**当前可见**（风险筛选 + 搜索后）的条目 id —— 全选作用于它，
    /// 与用户在 ② 页看到的列表一致，不会偷偷选中被筛掉的行。
    private var visibleFindingIDs: Set<String> {
        let searched = SmartCleanEvidenceBuilder.searchFiltered(findings, query: searchText)
        guard let raw = state.riskFilter, let risk = RiskLevel(rawValue: raw) else {
            return Set(searched.map(\.id.uuidString))
        }
        return Set(searched.filter { $0.risk == risk }.map(\.id.uuidString))
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
                planOutcome: planOutcome,
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
                hasPlanNumber: state.planNumber != nil,
                evidenceFocus: $evidenceFocus,
                onToggle: { id in mutate { $0.selectedIDs.formSymmetricDifference([id]) } },
                onSelectAll: { select in mutate { $0.selectedIDs = select ? visibleFindingIDs : [] } },
                onSetRiskFilter: { filter in mutate { $0.riskFilter = filter } },
                onSelectEvidence: { id in mutate { $0.evidenceSelectionID = id } },
                onOpenEvidence: { id in mutate { $0.evidenceSelectionID = id; $0.drawerPresented = true } },
                onRequestRescan: rescanTapped
            )
        default:
            SmartCleanExecuteStageView(
                plan: plan,
                isExecuting: isExecutingPlan,
                executionStartedAt: executionStartedAt,
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
            // Fail-closed (round-7): never echo a planned freed-bytes figure on
            // a failure-path receipt — the receipt body suppresses it too.
            receiptFreedBytes: executionReceipt?.failureReason == nil
                ? (executionReceipt?.estimatedFreedBytes ?? 0)
                : 0,
            hasPlanNumber: state.planNumber != nil
        ))
        // UI-test contract (review fix I3) + keyboard (review fix #9): the scan
        // stage primary carries `smartclean.runScan` + `.defaultAction`. The
        // receipt stage's 「新的扫描」 is a different surface (copy-derived id).
        let isScanPrimary = (model.intent == .rescan && effectiveStage == SmartCleanStage.scan)
        // 守卫基座（规格 §9 纪律 4）：`I-4` 要能点到「执行已选 N 项」以打开破坏性弹窗。
        let primaryIdentifier: String? = {
            if isScanPrimary { return "smartclean.runScan" }
            if model.intent == .execute { return "smartclean.executeSelection" }
            return nil
        }()
        return AtlasActionBar(
            primaryTitle: model.title, primaryEnabled: model.isEnabled,
            onPrimary: { perform(model.intent) },
            promise: model.promise, metricText: model.metricText, progress: model.progress,
            primaryIdentifier: primaryIdentifier,
            primaryKeyboardShortcut: isScanPrimary ? .defaultAction : nil
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
        case .viewLedger:
            // `P1-9`：执行中的只读出口。执行本身不受影响 —— worker 仍在跑。
            onNavigateToLedger()
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
