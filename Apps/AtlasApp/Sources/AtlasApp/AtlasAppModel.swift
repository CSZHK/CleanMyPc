import AtlasApplication
import AtlasCoreAdapters
import AtlasDesignSystem
import AtlasDomain
import AtlasFeaturesFileOrganizer
import AtlasFeaturesSmartClean
import AtlasInfrastructure
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class AtlasAppModel: ObservableObject {
    @Published var selection: AtlasRoute? = .overview
    let snapshotFilter = AtlasSnapshotFilter()
    @Published var isTaskCenterPresented = false
    @Published private(set) var snapshot: AtlasWorkspaceSnapshot
    @Published private(set) var currentPlan: ActionPlan
    @Published private(set) var currentAppPreview: ActionPlan?
    @Published private(set) var currentPreviewedAppID: UUID?
    @Published private(set) var latestAppRestoreRefreshStatus: AtlasAppPostRestoreRefreshStatus?
    @Published private(set) var settings: AtlasSettings
    @Published private(set) var isHealthSnapshotRefreshing = false
    @Published private(set) var isScanRunning = false
    @Published private(set) var isPlanRunning = false
    @Published private(set) var isPermissionsRefreshing = false
    @Published private(set) var isAppActionRunning = false
    @Published private(set) var activePreviewAppID: UUID?
    @Published private(set) var activeUninstallAppID: UUID?
    @Published private(set) var restoringRecoveryItemID: UUID?
    @Published private(set) var latestScanSummary: String
    @Published private(set) var latestAppsSummary: String
    @Published private(set) var latestPermissionsSummary: String
    @Published private(set) var latestScanProgress: Double = 0
    @Published private(set) var isCurrentSmartCleanPlanFresh: Bool
    @Published private(set) var smartCleanPlanIssue: String?
    @Published private(set) var smartCleanExecutionIssue: String?
    // Smart-clean execution outcome (Batch I): drives the ④ receipt stage via
    // AtlasWorkflowStageMap resolve-on-render. Reset whenever a new scan starts
    // or the plan is superseded. The receipt holds only real execution facts
    // (recovery delta, retention at run time — spec §1.6 fail-closed).
    @Published private(set) var smartCleanExecutionCompleted = false
    @Published private(set) var smartCleanExecutionReceipt: SmartCleanExecutionReceipt?
    /// Transient per-call success flag set by `restoreRecoveryItemCore`
    /// (review fix #6); read by the undo path to decide whether to clear
    /// `smartCleanExecutionCompleted` or surface a failure toast instead.
    private var lastRestoreDidSucceed = false
    @Published private(set) var latestUpdateResult: AtlasAppUpdate?
    @Published private(set) var isCheckingForUpdate = false
    @Published private(set) var updateCheckNotice: String?
    @Published private(set) var updateCheckError: String?

    // Toast state — public setter needed for AtlasToastContainer Binding
    @Published var toasts: [AtlasToastItem] = []

    // Workflow ViewState per route (Calm Ledger §2.3) — hosted here, not in
    // feature @State: AppShellView rebuilds feature views with .id(route), so
    // stage/selection/filter must survive route switches (§7 red line).
    @Published private(set) var workflowStates: [AtlasRoute: AtlasWorkflowViewState] = [:]

    // File Organizer state
    @Published private(set) var fileOrganizerEntries: [FileOrganizerEntry] = []
    @Published private(set) var isFileOrganizerScanning = false
    @Published private(set) var isFileOrganizerClassifying = false
    @Published private(set) var isFileOrganizerExecuting = false
    @Published private(set) var fileOrganizerScanSummary: String
    @Published private(set) var fileOrganizerProgress: Double = 0
    @Published private(set) var currentFileOrganizerPlan: ActionPlan
    @Published private(set) var isFileOrganizerPlanFresh = false
    @Published private(set) var fileOrganizerPlanIssue: String?
    @Published private(set) var fileOrganizerExecutionIssue: String?
    @Published private(set) var scannedFolders: [String] = []
    @Published private(set) var fileOrganizerRules: [FileOrganizerRule]
    @Published private(set) var fileOrganizerExecutionCompleted = false
    @Published private(set) var fileOrganizerMovedCount = 0
    /// Module receipt (spec §2.3 ⑤ / §1.6 fail-closed): populated from real
    /// execution output when `fileOrganizerExecutionCompleted` flips true;
    /// cleared by `supersedePlan(.fileOrganizer)` / new scan. Mirrors
    /// `smartCleanExecutionReceipt` shape. Rendered read-only by the receipt
    /// stage view; every field is backed by real execution data.
    @Published private(set) var fileOrganizerExecutionReceipt: FileOrganizerExecutionReceipt?

    private let repository: AtlasWorkspaceRepository
    private let workspaceController: AtlasWorkspaceController
    private let updateChecker = AtlasUpdateChecker()
    private let ledgerNumberStore: any AtlasLedgerNumberStoring
    private let notificationPermissionRequester: @Sendable () async -> Bool
    private var filterCancellationToken: AnyCancellable?
    private var didRequestInitialHealthSnapshot = false
    private var didRequestInitialPermissionSnapshot = false
    private var pendingRestoreSnapshotCategoryCounts: [AtlasAppEvidenceCategory: Int]?

    init(
        repository: AtlasWorkspaceRepository = AtlasWorkspaceRepository(),
        workerService: (any AtlasWorkerServing)? = nil,
        preferXPCWorker: Bool? = nil,
        allowScaffoldFallback: Bool? = nil,
        xpcRequestConfiguration: AtlasXPCRequestConfiguration = AtlasXPCRequestConfiguration(),
        xpcRequestExecutor: AtlasXPCDataRequestExecutor? = nil,
        notificationPermissionRequester: (@Sendable () async -> Bool)? = nil,
        ledgerNumberStore: (any AtlasLedgerNumberStoring)? = nil
    ) {
        let state = repository.loadState()
        self.repository = repository
        self.ledgerNumberStore = ledgerNumberStore ?? AtlasUserDefaultsLedgerNumberStore()
        self.snapshot = state.snapshot
        self.currentPlan = state.currentPlan
        self.settings = state.settings
        AtlasL10n.setCurrentLanguage(state.settings.language)
        self.latestScanSummary = AtlasL10n.string("model.scan.ready")
        self.latestAppsSummary = AtlasL10n.string("model.apps.ready")
        self.latestAppRestoreRefreshStatus = nil
        self.latestPermissionsSummary = AtlasL10n.string("model.permissions.ready")
        self.isCurrentSmartCleanPlanFresh = false
        self.smartCleanPlanIssue = nil
        self.smartCleanExecutionIssue = nil
        self.fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.ready")
        self.currentFileOrganizerPlan = ActionPlan(title: "", items: [], estimatedBytes: 0)
        self.fileOrganizerRules = state.settings.fileOrganizerCustomRules ?? AtlasScaffoldFixtures.fileOrganizerRules
        let directWorker = AtlasScaffoldWorkerService(
            repository: repository,
            healthSnapshotProvider: MoleHealthAdapter(),
            smartCleanScanProvider: MoleSmartCleanAdapter(),
            appsInventoryProvider: MacAppsInventoryAdapter(),
            helperExecutor: AtlasPrivilegedHelperClient(),
            fileOrganizerScanProvider: AtlasFileOrganizerScanner(),
            fileOrganizerClassifier: AtlasFileOrganizerClassifier()
        )
        let prefersXPCWorker = preferXPCWorker ?? (ProcessInfo.processInfo.environment["ATLAS_PREFER_XPC_WORKER"] == "1")
        let shouldAllowScaffoldFallback = allowScaffoldFallback
            ?? (ProcessInfo.processInfo.environment["ATLAS_ALLOW_SCAFFOLD_FALLBACK"] == "1")
        let defaultWorker: any AtlasWorkerServing = prefersXPCWorker
            ? AtlasPreferredWorkerService(
                requestConfiguration: xpcRequestConfiguration,
                requestExecutor: xpcRequestExecutor,
                fallbackWorker: directWorker,
                allowFallback: shouldAllowScaffoldFallback
            )
            : directWorker
        self.workspaceController = AtlasWorkspaceController(
            worker: workerService ?? defaultWorker
        )
        self.notificationPermissionRequester = notificationPermissionRequester ?? {
            // Bare executables (swift run) have no LaunchServices bundleProxy, and
            // UNUserNotificationCenter.current() throws an ObjC NSInternalInconsistencyException
            // that Swift cannot catch. Degrade to "not granted" outside a real .app bundle.
            guard Bundle.main.bundleIdentifier != nil else { return false }
            return await withCheckedContinuation { continuation in
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
        self.filterCancellationToken = snapshotFilter.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        syncAppearance()
    }

    var appLanguage: AtlasLanguage {
        settings.language
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.6"
    }

    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "6"
    }

    func checkForUpdate() async {
        guard !isCheckingForUpdate else { return }

        isCheckingForUpdate = true
        defer { isCheckingForUpdate = false }

        updateCheckNotice = nil
        updateCheckError = nil

        do {
            let result = try await updateChecker.checkForUpdate(currentVersion: appVersion)
            withAnimation(.snappy(duration: 0.24)) {
                latestUpdateResult = result
            }
        } catch let error as AtlasUpdateCheckerError {
            withAnimation(.snappy(duration: 0.24)) {
                latestUpdateResult = nil
            }
            switch error {
            case .noPublishedRelease:
                updateCheckNotice = error.localizedDescription
            case .requestFailed:
                updateCheckError = error.localizedDescription
            }
        } catch {
            withAnimation(.snappy(duration: 0.24)) {
                latestUpdateResult = nil
            }
            updateCheckError = error.localizedDescription
        }
    }

    func searchText(for route: AtlasRoute) -> String {
        snapshotFilter.searchText(for: route)
    }

    func setSearchText(_ text: String, for route: AtlasRoute) {
        snapshotFilter.setSearchText(text, for: route)
    }

    var filteredSnapshot: AtlasWorkspaceSnapshot {
        snapshotFilter.filteredSnapshot(from: snapshot)
    }

    var filteredFindings: [Finding] {
        snapshotFilter.filteredFindings(from: snapshot)
    }

    var filteredApps: [AppFootprint] {
        snapshotFilter.filteredApps(from: snapshot)
    }

    var filteredTaskRuns: [TaskRun] {
        snapshotFilter.filteredTaskRuns(from: snapshot)
    }

    var filteredRecoveryItems: [RecoveryItem] {
        snapshotFilter.filteredRecoveryItems(from: snapshot)
    }

    var filteredPermissionStates: [PermissionState] {
        snapshotFilter.filteredPermissionStates(from: snapshot)
    }

    var filteredFileOrganizerEntries: [FileOrganizerEntry] {
        snapshotFilter.filteredFileOrganizerEntries(from: snapshot)
    }

    var taskCenterTaskRuns: [TaskRun] {
        snapshot.taskRuns
    }

    var taskCenterSummary: String {
        let activeTaskCount = snapshot.taskRuns.filter { taskRun in
            taskRun.status == .queued || taskRun.status == .running
        }.count

        if activeTaskCount == 0 {
            return AtlasL10n.string("model.taskcenter.none")
        }

        let key = activeTaskCount == 1 ? "model.taskcenter.active.one" : "model.taskcenter.active.other"
        return AtlasL10n.string(key, activeTaskCount)
    }

    var isWorkflowBusy: Bool {
        isHealthSnapshotRefreshing
            || isScanRunning
            || isPlanRunning
            || isPermissionsRefreshing
            || isAppActionRunning
            || restoringRecoveryItemID != nil
            || isFileOrganizerScanning
            || isFileOrganizerClassifying
            || isFileOrganizerExecuting
    }

    var canExecuteCurrentSmartCleanPlan: Bool {
        !currentPlan.items.isEmpty && isCurrentSmartCleanPlanFresh && currentSmartCleanPlanHasExecutableTargets
    }

    var currentSmartCleanPlanHasExecutableTargets: Bool {
        let executableItems = currentPlan.items.filter { $0.effectiveExecutionBoundary(findings: snapshot.findings).isExecutable }
        guard !executableItems.isEmpty else {
            return false
        }
        return executableItems.allSatisfy { !$0.resolvedTargetPaths(findings: snapshot.findings).isEmpty }
    }

    var canExecuteFileOrganizerPlan: Bool {
        !currentFileOrganizerPlan.items.isEmpty && isFileOrganizerPlanFresh
    }

    func refreshHealthSnapshotIfNeeded() async {
        guard !didRequestInitialHealthSnapshot else {
            return
        }

        didRequestInitialHealthSnapshot = true
        await refreshHealthSnapshot()
    }

    func refreshPermissionsIfNeeded() async {
        guard !didRequestInitialPermissionSnapshot else {
            return
        }

        didRequestInitialPermissionSnapshot = true
        await inspectPermissions()
    }

    func refreshHealthSnapshot() async {
        guard !isHealthSnapshotRefreshing else {
            return
        }

        isHealthSnapshotRefreshing = true

        do {
            let output = try await workspaceController.healthSnapshot()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
            }
        } catch {
            latestScanSummary = error.localizedDescription
        }

        isHealthSnapshotRefreshing = false
    }

    func inspectPermissions() async {
        guard !isPermissionsRefreshing else {
            return
        }

        isPermissionsRefreshing = true
        latestPermissionsSummary = AtlasL10n.string("model.permissions.refreshing")

        do {
            let output = try await workspaceController.inspectPermissions()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
            }

            let grantedCount = output.snapshot.permissions.filter(\.isGranted).count
            latestPermissionsSummary = AtlasL10n.string(
                output.snapshot.permissions.count == 1 ? "model.permissions.summary.one" : "model.permissions.summary.other",
                grantedCount,
                output.snapshot.permissions.count
            )
        } catch {
            latestPermissionsSummary = error.localizedDescription
        }

        isPermissionsRefreshing = false
    }

    func runSmartCleanScan() async {
        guard !isScanRunning else {
            return
        }

        selection = .smartClean
        isScanRunning = true
        latestScanSummary = AtlasL10n.string("model.scan.submitting")
        latestScanProgress = 0
        smartCleanExecutionIssue = nil
        // A new scan cycle supersedes the previous execution outcome (§2.3).
        smartCleanExecutionCompleted = false
        smartCleanExecutionReceipt = nil

        do {
            let output = try await workspaceController.startScan()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentPlan = output.actionPlan ?? currentPlan
                latestScanSummary = output.summary
                latestScanProgress = output.progressFraction
                isCurrentSmartCleanPlanFresh = output.actionPlan != nil
                smartCleanPlanIssue = nil
                smartCleanExecutionIssue = nil
            }
            if output.actionPlan != nil {
                // Scan produced a plan → assign ledger № + scan receipt (§2.3),
                // then seed the plan-scoped selection with every finding so the
                // default review state matches the legacy execute-all behavior.
                assignPlanNumber(for: .smartClean)
                updateWorkflowState(for: .smartClean) { state in
                    state.selectedIDs = Set(output.snapshot.findings.map(\.id.uuidString))
                }
            }
        } catch {
            latestScanSummary = error.localizedDescription
            latestScanProgress = 0
            smartCleanPlanIssue = error.localizedDescription
        }

        isScanRunning = false
    }

    /// Rebuilds the plan preview. `findingIDs == nil` keeps the legacy
    /// behavior (all current findings); the ② review screen passes the checked
    /// subset so the executed plan matches the selection (Batch I — same
    /// controller API, FileOrganizer-style optional parameter).
    @discardableResult
    func refreshPlanPreview(findingIDs: [UUID]? = nil) async -> Bool {
        smartCleanExecutionIssue = nil
        do {
            let output = try await workspaceController.previewPlan(findingIDs: findingIDs ?? snapshot.findings.map(\.id))
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentPlan = output.actionPlan
                latestScanSummary = output.summary
                latestScanProgress = min(max(latestScanProgress, 1), 1)
                isCurrentSmartCleanPlanFresh = true
                smartCleanPlanIssue = nil
                smartCleanExecutionIssue = nil
            }
            if workflowState(for: .smartClean).planNumber == nil, !output.actionPlan.items.isEmpty {
                // First numbered appearance of this plan (cached findings
                // revalidated without a scan): assign № + receipt so every
                // executable plan is ledger-addressable, then seed selection.
                assignPlanNumber(for: .smartClean)
                updateWorkflowState(for: .smartClean) { state in
                    state.selectedIDs = Set(output.actionPlan.items.map(\.id.uuidString))
                }
            }
            return true
        } catch {
            latestScanSummary = error.localizedDescription
            smartCleanPlanIssue = error.localizedDescription
            return false
        }
    }

    func executeCurrentPlan() async {
        guard !isPlanRunning, !currentPlan.items.isEmpty else {
            return
        }

        selection = .smartClean
        isPlanRunning = true
        smartCleanExecutionIssue = nil
        // Narrow-layout drawer residue (review fix #12): collapse the evidence
        // drawer when execution starts so the progress/receipt view isn't
        // obscured by a stale evidence panel left open from ②.
        updateWorkflowState(for: .smartClean) { state in state.drawerPresented = false }
        // Receipt provenance (Batch I): plan facts + recovery baseline, so the
        // ④ receipt and the undo toast carry only real execution outcomes.
        let executedPlan = currentPlan
        let recoveryIDsBefore = Set(snapshot.recoveryItems.map(\.id))
        let workflowSnapshot = workflowState(for: .smartClean)

        do {
            let output = try await workspaceController.executePlan(planID: currentPlan.id)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                latestScanSummary = output.summary
                latestScanProgress = output.progressFraction
                smartCleanPlanIssue = nil
                smartCleanExecutionIssue = nil
            }
            let newRecoveryItems = output.snapshot.recoveryItems.filter { !recoveryIDsBefore.contains($0.id) }
            let receipt = SmartCleanExecutionReceipt(
                planNumber: workflowSnapshot.planNumber,
                receiptCode: workflowSnapshot.receiptCode,
                completedAt: Date(),
                executedItemCount: executedPlan.items.count,
                estimatedFreedBytes: executedPlan.estimatedBytes,
                summary: output.summary,
                recoveryItemIDs: newRecoveryItems.map(\.id),
                recoveryBytes: newRecoveryItems.reduce(Int64(0)) { $0 + $1.bytes },
                retentionDays: settings.recoveryRetentionDays
            )
            smartCleanExecutionReceipt = receipt
            smartCleanExecutionCompleted = true
            postSmartCleanExecutionToast(for: receipt)
            let didRefreshPlan = await refreshPlanPreview()
            if !didRefreshPlan {
                isCurrentSmartCleanPlanFresh = false
            }
        } catch {
            latestScanSummary = error.localizedDescription
            smartCleanExecutionIssue = error.localizedDescription
            // Partial-completion receipt (③ error → 「查看回执」, spec §2.3):
            // failure reason only — no invented recovery facts (fail-closed).
            smartCleanExecutionReceipt = SmartCleanExecutionReceipt(
                planNumber: workflowSnapshot.planNumber,
                receiptCode: workflowSnapshot.receiptCode,
                completedAt: Date(),
                executedItemCount: executedPlan.items.count,
                estimatedFreedBytes: executedPlan.estimatedBytes,
                summary: error.localizedDescription,
                recoveryItemIDs: [],
                recoveryBytes: 0,
                retentionDays: settings.recoveryRetentionDays,
                failureReason: error.localizedDescription
            )
        }

        isPlanRunning = false
    }

    /// 「已入账 №N · 撤销」 global toast (spec §2.3 Undo): tap opens the ledger
    /// (回链红线 §1.6); the undo action restores exactly the recovery items
    /// this run created — same items the ledger restore buttons target — and
    /// only renders when the run really produced recovery items (fail-closed).
    private func postSmartCleanExecutionToast(for receipt: SmartCleanExecutionReceipt) {
        let toastID = UUID()
        let message = receipt.planNumber.map { AtlasL10n.string("smartclean.toast.recorded", $0) } ?? receipt.summary
        // Undo gate aligned with the ④ receipt stamp (review fix #5): the same
        // `hasRestorePoint` predicate (IDs non-empty AND bytes > 0) decides
        // whether the undo action is offered. A run that recorded recovery
        // entries but zero bytes (e.g. metadata-only) can't meaningfully undo,
        // so the toast omits the action and the receipt hides its stamp too.
        let hasUndo = receipt.hasRestorePoint
        var undoAction: (@MainActor @Sendable () -> Void)?
        if hasUndo {
            undoAction = { [weak self] in
                self?.dismissToast(id: toastID)
                Task { await self?.undoSmartCleanExecution() }
            }
        }
        let toast = AtlasToastItem(
            id: toastID,
            message: message,
            tone: .success,
            systemImage: "checkmark.seal",
            actionTitle: hasUndo ? AtlasL10n.string("smartclean.undo.banner.action") : nil,
            onAction: undoAction,
            onTap: { [weak self] in
                self?.navigate(to: .ledger)
            }
        )
        withAnimation(AtlasMotion.standard) {
            toasts.append(toast)
        }
    }

    /// Undo of the latest smart-clean run: sequentially restores the recovery
    /// items recorded on the execution receipt through the existing
    /// `restoreRecoveryItem` chain (same recovery point as the ledger's
    /// restore entry points — 双入口一份真相, spec §2.3).
    ///
    /// Review fix #6: only clear `smartCleanExecutionCompleted` when at least one
    /// restore actually succeeded. If every restore failed (helper offline,
    /// files missing), the execution result stays recorded and a failure toast is
    /// surfaced — never silently clear state we could not reverse.
    func undoSmartCleanExecution() async {
        guard let receipt = smartCleanExecutionReceipt else {
            return
        }
        // Determine which recorded recovery items are still present and restorable.
        let restorableIDs = receipt.recoveryItemIDs.filter { itemID in
            snapshot.recoveryItems.contains { $0.id == itemID }
        }
        // Nothing recorded AND nothing restorable ⇒ no-op success: clear the
        // execution state as before (a run with no recovery delta has nothing to
        // reverse). This is distinct from #6's failure case below.
        if receipt.recoveryItemIDs.isEmpty && restorableIDs.isEmpty {
            smartCleanExecutionCompleted = false
            smartCleanExecutionReceipt = nil
            return
        }
        var anyRestored = false
        for itemID in restorableIDs {
            let didRestore = await restoreRecoveryItemReportingSuccess(itemID)
            if didRestore { anyRestored = true }
        }
        if anyRestored {
            smartCleanExecutionCompleted = false
            smartCleanExecutionReceipt = nil
        } else if !restorableIDs.isEmpty {
            // #6: items were present to restore but every restore failed — surface
            // it instead of silently clearing execution state we could not reverse.
            postSmartCleanUndoFailedToast()
        } else {
            // Items were recorded but none are currently restorable (already
            // consumed / evicted elsewhere): treat as no-op success and clear.
            smartCleanExecutionCompleted = false
            smartCleanExecutionReceipt = nil
        }
    }

    /// Failure toast for an undo that could not reverse any recovery item
    /// (review fix #6): the user tapped 「撤销」 and nothing came back. Tapping
    /// the toast opens the ledger where the recovery entries still live.
    private func postSmartCleanUndoFailedToast() {
        let toastID = UUID()
        let toast = AtlasToastItem(
            id: toastID,
            message: AtlasL10n.string("smartclean.undo.failed.message"),
            tone: .warning,
            systemImage: "exclamationmark.triangle",
            onTap: { [weak self] in
                self?.navigate(to: .ledger)
            }
        )
        withAnimation(AtlasMotion.standard) {
            toasts.append(toast)
        }
    }

    func refreshApps() async {
        await reloadAppsInventory(
            navigateToApps: true,
            resetPreview: true,
            restoreStatus: latestAppRestoreRefreshStatus
        )
    }

    func previewAppUninstall(appID: UUID) async {
        guard !isAppActionRunning else {
            return
        }

        selection = .apps
        isAppActionRunning = true
        activePreviewAppID = appID
        activeUninstallAppID = nil
        latestAppRestoreRefreshStatus = nil

        do {
            let output = try await workspaceController.previewAppUninstall(appID: appID)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentAppPreview = output.actionPlan
                currentPreviewedAppID = appID
                latestAppsSummary = output.summary
            }
        } catch {
            latestAppsSummary = error.localizedDescription
        }

        activePreviewAppID = nil
        isAppActionRunning = false
    }

    func rescanLeftovers(appID: UUID) async {
        guard !isAppActionRunning else {
            return
        }

        selection = .apps
        isAppActionRunning = true
        activePreviewAppID = appID
        activeUninstallAppID = nil
        // Clear stale snapshot counts from any prior restore cycle
        pendingRestoreSnapshotCategoryCounts = nil

        do {
            let output = try await workspaceController.previewAppUninstall(appID: appID)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentAppPreview = output.actionPlan
                currentPreviewedAppID = appID
                latestAppsSummary = output.summary
                // Clear divergence state after re-scan
                if var status = latestAppRestoreRefreshStatus {
                    status.evidenceDivergenceDetected = false
                    status.divergentCategories = []
                    latestAppRestoreRefreshStatus = status
                }
            }
        } catch {
            latestAppsSummary = error.localizedDescription
        }

        activePreviewAppID = nil
        isAppActionRunning = false
    }

    func executeAppUninstall(appID: UUID) async {
        guard !isAppActionRunning else {
            return
        }

        selection = .apps
        isAppActionRunning = true
        activePreviewAppID = nil
        activeUninstallAppID = appID
        latestAppRestoreRefreshStatus = nil

        do {
            let output = try await workspaceController.executeAppUninstall(appID: appID, planID: currentAppPreview?.id)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentAppPreview = nil
                currentPreviewedAppID = nil
                latestAppsSummary = output.summary
            }
        } catch {
            latestAppsSummary = error.localizedDescription
        }

        activeUninstallAppID = nil
        isAppActionRunning = false
    }

    func restoreRecoveryItem(_ itemID: UUID) async {
        guard restoringRecoveryItemID == nil else {
            return
        }

        await restoreRecoveryItemCore(itemID)
    }

    /// Core restore that reports per-call success (review fix #6): the undo path
    /// needs to know whether at least one item really came back before it is safe
    /// to clear `smartCleanExecutionCompleted`. Existing callers (apps restore,
    /// ledger) still use `restoreRecoveryItem` which ignores the result.
    @discardableResult
    private func restoreRecoveryItemReportingSuccess(_ itemID: UUID) async -> Bool {
        guard restoringRecoveryItemID == nil else {
            return false
        }
        await restoreRecoveryItemCore(itemID)
        return lastRestoreDidSucceed
    }

    /// Shared restore body; sets `lastRestoreDidSucceed` so callers can branch.
    private func restoreRecoveryItemCore(_ itemID: UUID) async {
        lastRestoreDidSucceed = false

        let restoredItem = snapshot.recoveryItems.first(where: { $0.id == itemID })
        // Capture snapshot category counts for divergence detection after reload
        pendingRestoreSnapshotCategoryCounts = restoredItem?.appRecoveryPayload.flatMap {
            Self.categoryCountsFromSnapshot($0.uninstallSnapshot)
        }
        let restoreStatus = restoredItem?.appRecoveryPayload.map { payload in
            // Prefer snapshot reviewOnlyItemCount over legacy evidence count:
            // legacy mapping (AtlasAppFootprintEvidenceCategory) drops 4 categories
            // (savedState, containers, groupContainers, miscLeftovers), so
            // uninstallEvidence.reviewOnlyItemCount undercounts when a snapshot exists.
            let snapshotItemCount = payload.uninstallSnapshot?.reviewOnlyItemCount
            let legacyItemCount = payload.uninstallEvidence.reviewOnlyItemCount
            let bestItemCount = snapshotItemCount ?? legacyItemCount
            return AtlasAppPostRestoreRefreshStatus(
                appName: payload.app.name,
                bundleIdentifier: payload.app.bundleIdentifier,
                bundlePath: payload.app.bundlePath,
                state: .refreshing,
                recordedLeftoverItems: max(bestItemCount, payload.app.leftoverItems)
            )
        }
        let shouldRefreshAppsAfterRestore = restoreStatus != nil
        restoringRecoveryItemID = itemID
        if let restoreStatus {
            latestAppRestoreRefreshStatus = restoreStatus
        }

        do {
            let output = try await workspaceController.restoreItems(itemIDs: [itemID])
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                latestScanSummary = output.summary
                smartCleanExecutionIssue = nil
                if shouldRefreshAppsAfterRestore {
                    currentAppPreview = nil
                    currentPreviewedAppID = nil
                    latestAppsSummary = output.summary
                }
            }
            lastRestoreDidSucceed = true
            if shouldRefreshAppsAfterRestore {
                await reloadAppsInventory(
                    navigateToApps: false,
                    resetPreview: true,
                    loadingSummary: output.summary,
                    restoreStatus: restoreStatus
                )
            } else {
                await refreshPlanPreview()
            }
        } catch {
            // Clear transient restore state to prevent stale data from leaking
            // into the next refreshApps() call, which would produce false divergence.
            pendingRestoreSnapshotCategoryCounts = nil
            latestAppRestoreRefreshStatus = nil

            let persistedState = repository.loadState()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = persistedState.snapshot
                currentPlan = persistedState.currentPlan
                settings = persistedState.settings
            }
            syncAppearance()
            latestScanSummary = error.localizedDescription
        }

        restoringRecoveryItemID = nil
    }

    func setRecoveryRetentionDays(_ days: Int) async {
        await updateSettings { settings in
            settings.recoveryRetentionDays = days
        }
    }

    func setNotificationsEnabled(_ isEnabled: Bool) async {
        if isEnabled, snapshot.permissions.first(where: { $0.kind == .notifications })?.isGranted != true {
            _ = await notificationPermissionRequester()
        }
        await updateSettings { settings in
            settings.notificationsEnabled = isEnabled
        }
        await inspectPermissions()
    }

    func requestNotificationPermission() async {
        _ = await notificationPermissionRequester()
        await inspectPermissions()
    }

    func setLanguage(_ language: AtlasLanguage) async {
        // Always apply — even if settings already match, UI may be stale
        AtlasL10n.setCurrentLanguage(language)
        withAnimation(.snappy(duration: 0.2)) {
            settings.language = language
        }
        refreshLocalizedReadySummaries()

        // Persist in background
        await updateSettings { _ in }

        if !snapshot.findings.isEmpty {
            await refreshPlanPreview()
        }
        currentAppPreview = nil
        currentPreviewedAppID = nil
        latestAppRestoreRefreshStatus = nil
    }

    func setTheme(_ theme: AtlasTheme) async {
        withAnimation(.snappy(duration: 0.2)) {
            settings.theme = theme
        }
        NSApp.appearance = theme.nsAppearance
        await updateSettings { _ in }
    }

    func refreshCurrentRoute() async {
        switch selection ?? .overview {
        case .overview:
            await refreshHealthSnapshot()
        case .smartClean:
            await runSmartCleanScan()
        case .fileOrganizer:
            break  // File Organizer requires user to select folders and tap scan; no auto-scan on route change
        case .apps:
            await refreshApps()
        case .ledger:
            break
        case .permissions:
            await inspectPermissions()
        case .settings, .about:
            break
        }
    }

    func navigate(to route: AtlasRoute) {
        withAnimation(.snappy(duration: 0.2)) {
            selection = route
        }
    }

    func openTaskCenter() {
        withAnimation(.snappy(duration: 0.2)) {
            isTaskCenterPresented = true
        }
    }

    func closeTaskCenter() {
        withAnimation(.snappy(duration: 0.2)) {
            isTaskCenterPresented = false
        }
    }

    func toggleTaskCenter() {
        withAnimation(.snappy(duration: 0.2)) {
            isTaskCenterPresented.toggle()
        }
    }

    // MARK: - Workflow ViewState (Calm Ledger §2.3)

    /// Read accessor — returns a default-initialized state for routes that have
    /// no stored state yet (no dictionary write on read).
    func workflowState(for route: AtlasRoute) -> AtlasWorkflowViewState {
        workflowStates[route] ?? AtlasWorkflowViewState()
    }

    func updateWorkflowState(for route: AtlasRoute, _ mutate: (inout AtlasWorkflowViewState) -> Void) {
        var state = workflowStates[route] ?? AtlasWorkflowViewState()
        mutate(&state)
        workflowStates[route] = state
    }

    /// Assigns the next ledger № and derives the scan receipt for a freshly
    /// produced plan (called on scan completion). № change clears the
    /// plan-scoped selection/filter (spec §2.3 selection scope = single plan).
    func assignPlanNumber(for route: AtlasRoute, scanDate: Date = Date()) {
        let number = nextLedgerNumber()
        let receipt = AtlasLedgerReceipt.code(findings: snapshot.findings, scanDate: scanDate)
        updateWorkflowState(for: route) { state in
            if state.planNumber != number {
                state.selectedIDs = []
                state.riskFilter = nil
            }
            state.planNumber = number
            state.receiptCode = receipt
            state.currentStage = AtlasWorkflowStageMap.reviewStage
            state.displayedStage = AtlasWorkflowStageMap.reviewStage
            state.rescanConfirmationPending = false
        }
    }

    /// Rescan confirmed: the old № is void (its task runs stay in the ledger;
    /// Batch J renders the superseded status), the workflow returns to ① scan.
    func supersedePlan(for route: AtlasRoute) {
        if route == .smartClean {
            // The superseded plan is void: its execution outcome and freshness
            // go with it, so resolve-on-render lands on ① (无计划/已失效) and
            // can never get stuck on ② or ④ between confirm and the new scan.
            smartCleanExecutionCompleted = false
            smartCleanExecutionReceipt = nil
            isCurrentSmartCleanPlanFresh = false
        }
        updateWorkflowState(for: route) { state in
            state.planNumber = nil
            state.receiptCode = nil
            state.selectedIDs = []
            state.riskFilter = nil
            state.evidenceSelectionID = nil
            state.drawerPresented = false
            state.currentStage = AtlasWorkflowStageMap.scanStage
            state.displayedStage = AtlasWorkflowStageMap.scanStage
            state.rescanConfirmationPending = false
        }
    }

    /// Cmd+Shift+R intent — only raises the flag; the confirmation dialog
    /// („当前计划 №N 将作废") is presented by the feature screen (Batch I),
    /// which calls `supersedePlan(for:)` on confirm.
    func requestRescanConfirmation(for route: AtlasRoute) {
        updateWorkflowState(for: route) { state in
            state.rescanConfirmationPending = true
        }
    }

    private func nextLedgerNumber() -> Int {
        // First use seeds from the existing task-run count + 1 (PER da8c42f).
        ledgerNumberStore.next(fallbackBase: snapshot.taskRuns.count + 1)
    }

    /// Ledger № prefix for an ACTIVE task-center row (spec §3.1): only
    /// queued/running runs of a workflow that currently holds a plan №.
    func workflowPlanNumber(for taskRun: TaskRun) -> Int? {
        guard taskRun.status == .running || taskRun.status == .queued else {
            return nil
        }
        switch taskRun.kind {
        case .scan, .executePlan:
            return workflowStates[.smartClean]?.planNumber
        case .organizeFiles:
            return workflowStates[.fileOrganizer]?.planNumber
        case .uninstallApp, .restore, .inspectPermissions:
            return nil
        }
    }

    // MARK: - Toast Management

    func showToast(_ message: String, tone: AtlasTone = .neutral, systemImage: String? = nil) {
        let toast = AtlasToastItem(message: message, tone: tone, systemImage: systemImage)
        withAnimation(AtlasMotion.standard) {
            toasts.append(toast)
        }
    }

    func dismissToast(id: UUID) {
        withAnimation(AtlasMotion.standard) {
            toasts.removeAll { $0.id == id }
        }
    }

    private func updateSettings(_ mutate: (inout AtlasSettings) -> Void) async {
        var updated = settings
        mutate(&updated)

        do {
            let output = try await workspaceController.updateSettings(updated)
            AtlasL10n.setCurrentLanguage(output.settings.language)
            withAnimation(.snappy(duration: 0.2)) {
                settings = output.settings
            }
            syncAppearance()
        } catch {
            latestAppsSummary = error.localizedDescription
        }
    }

    private func syncAppearance() {
        // Optional-chain: bare `swift test` runs have no NSApplication (NSApp is nil).
        // With a real app instance the assignment behaves exactly as before.
        NSApp?.appearance = settings.theme.nsAppearance
    }

    private func refreshLocalizedReadySummaries() {
        if !isScanRunning && !isPlanRunning {
            latestScanSummary = AtlasL10n.string("model.scan.ready")
        }
        if !isAppActionRunning {
            latestAppsSummary = AtlasL10n.string("model.apps.ready")
        }
        if !isPermissionsRefreshing {
            latestPermissionsSummary = AtlasL10n.string("model.permissions.ready")
        }
        if !isFileOrganizerScanning && !isFileOrganizerExecuting {
            fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.ready")
        }
    }

    // MARK: - File Organizer

    func runFileOrganizerScan(folderPaths: [String]) async {
        guard !isFileOrganizerScanning else { return }

        isFileOrganizerScanning = true
        fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.scanning")
        fileOrganizerProgress = 0
        scannedFolders = folderPaths
        fileOrganizerExecutionIssue = nil
        fileOrganizerExecutionCompleted = false
        fileOrganizerMovedCount = 0
        fileOrganizerExecutionReceipt = nil

        if folderPaths.count <= 1 {
            // Single folder — scan directly, no per-folder progress
            do {
                let output = try await workspaceController.fileOrganizerScan(folderPaths: folderPaths)
                withAnimation(.snappy(duration: 0.24)) {
                    snapshot = output.snapshot
                    fileOrganizerEntries = output.entries
                    fileOrganizerScanSummary = output.summary
                    fileOrganizerProgress = output.progressFraction
                    isFileOrganizerPlanFresh = false
                    fileOrganizerPlanIssue = nil
                }
            } catch {
                fileOrganizerScanSummary = error.localizedDescription
                fileOrganizerProgress = 0
                fileOrganizerPlanIssue = error.localizedDescription
            }
        } else {
            // Multiple folders — single call with all paths
            let folderNames = folderPaths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
            fileOrganizerScanSummary = AtlasL10n.string("fileorganizer.progress.scanningFolder", folderNames, 1, 1)
            fileOrganizerProgress = 0.1

            do {
                let output = try await workspaceController.fileOrganizerScan(folderPaths: folderPaths)
                withAnimation(.snappy(duration: 0.24)) {
                    snapshot = output.snapshot
                    fileOrganizerEntries = output.entries
                    fileOrganizerScanSummary = output.summary
                    fileOrganizerProgress = output.progressFraction
                    isFileOrganizerPlanFresh = false
                    fileOrganizerPlanIssue = nil
                }
            } catch {
                fileOrganizerScanSummary = error.localizedDescription
                fileOrganizerProgress = 0
                fileOrganizerPlanIssue = error.localizedDescription
            }
        }

        isFileOrganizerScanning = false
    }

    func classifyFileOrganizerEntries(entryIDs: [UUID]) async {
        guard !isFileOrganizerClassifying else { return }

        isFileOrganizerClassifying = true
        fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.classifying")

        do {
            let output = try await workspaceController.fileOrganizerClassify(entryIDs: entryIDs)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                fileOrganizerEntries = output.entries
                fileOrganizerScanSummary = output.summary
            }
        } catch {
            fileOrganizerScanSummary = error.localizedDescription
        }

        isFileOrganizerClassifying = false
    }

    func refreshFileOrganizerPreview(entryIDs: [UUID]) async {
        fileOrganizerExecutionIssue = nil
        do {
            let output = try await workspaceController.fileOrganizerPreviewPlan(entryIDs: entryIDs)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentFileOrganizerPlan = output.actionPlan
                fileOrganizerScanSummary = output.summary
                isFileOrganizerPlanFresh = true
                fileOrganizerPlanIssue = nil
                fileOrganizerExecutionIssue = nil
            }
            // Calm Ledger §2.3: every executable plan is ledger-addressable.
            // Assign № + receipt on the plan's first fresh appearance — WITHOUT
            // the SmartClean-specific side effects (the shared assignPlanNumber
            // also clears selectedIDs/riskFilter and forces stage; FileOrganizer
            // owns its own entry selection and stage is resolve-on-render
            // anyway). (review round-1: FileOrganizer plans were never numbered,
            // so the receipt chip / №N markers / task-center row stayed empty.)
            if workflowState(for: .fileOrganizer).planNumber == nil, !output.actionPlan.items.isEmpty {
                let number = nextLedgerNumber()
                let receipt = AtlasLedgerReceipt.code(forPlan: output.actionPlan, scanDate: Date())
                updateWorkflowState(for: .fileOrganizer) { state in
                    state.planNumber = number
                    state.receiptCode = receipt
                }
            }
        } catch {
            fileOrganizerScanSummary = error.localizedDescription
            fileOrganizerPlanIssue = error.localizedDescription
        }
    }

    func updateFileOrganizerDestination(_ path: String) async {
        await updateSettings { settings in
            settings.fileOrganizerDestinationBasePath = path
        }
    }

    func updateFileOrganizerRecursiveScan(_ recursive: Bool) async {
        await updateSettings { settings in
            settings.fileOrganizerRecursiveScan = recursive
        }
    }

    func updateFileOrganizerRules(_ rules: [FileOrganizerRule]) async {
        await updateSettings { settings in
            settings.fileOrganizerCustomRules = rules
        }
        fileOrganizerRules = rules
    }

    func undoFileOrganizerExecution() async {
        guard let recoveryItem = snapshot.recoveryItems.first(where: { item in
            if case .fileOrganizer = item.payload { return true }
            return false
        }) else { return }

        restoringRecoveryItemID = recoveryItem.id
        do {
            let output = try await workspaceController.restoreItems(itemIDs: [recoveryItem.id])
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                fileOrganizerEntries = []
                currentFileOrganizerPlan = ActionPlan(title: "", items: [], estimatedBytes: 0)
                isFileOrganizerPlanFresh = false
                fileOrganizerExecutionCompleted = false
                fileOrganizerMovedCount = 0
                fileOrganizerExecutionReceipt = nil
                fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.ready")
            }
        } catch {
            // Worker may have partially succeeded — verify files actually returned to original locations
            let allRestored = recoveryItem.restoreMappings?.allSatisfy { mapping in
                let restored = FileManager.default.fileExists(atPath: (mapping.originalPath as NSString).expandingTildeInPath)
                let sourceGone = !FileManager.default.fileExists(atPath: (mapping.trashedPath as NSString).expandingTildeInPath)
                return restored && sourceGone
            } ?? false
            if allRestored {
                withAnimation(.snappy(duration: 0.24)) {
                    snapshot.recoveryItems.removeAll { $0.id == recoveryItem.id }
                    snapshot.fileOrganizerEntries = []
                    fileOrganizerEntries = []
                    currentFileOrganizerPlan = ActionPlan(title: "", items: [], estimatedBytes: 0)
                    isFileOrganizerPlanFresh = false
                    fileOrganizerExecutionCompleted = false
                    fileOrganizerMovedCount = 0
                    fileOrganizerExecutionReceipt = nil
                    fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.ready")
                }
            } else {
                fileOrganizerExecutionIssue = error.localizedDescription
            }
        }
        restoringRecoveryItemID = nil
    }

    func executeFileOrganizerPlan() async {
        guard !isFileOrganizerExecuting, !currentFileOrganizerPlan.items.isEmpty else { return }

        isFileOrganizerExecuting = true
        fileOrganizerExecutionIssue = nil

        do {
            let output = try await workspaceController.fileOrganizerExecutePlan(planID: currentFileOrganizerPlan.id)
            let movedCount = output.movedCount
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                fileOrganizerEntries = output.snapshot.fileOrganizerEntries
                fileOrganizerMovedCount = movedCount
                fileOrganizerScanSummary = AtlasL10n.string("fileorganizer.callout.executionComplete.detail", movedCount)
                fileOrganizerProgress = output.progressFraction
                isFileOrganizerPlanFresh = false
                fileOrganizerPlanIssue = nil
                fileOrganizerExecutionIssue = nil
                fileOrganizerExecutionCompleted = true
                // Receipt (§1.6 fail-closed): every field from real execution
                // output. planNumber/receiptCode come from the workflow state
                // (assigned at scan completion). Summary uses the localized
                // callout already computed from movedCount above.
                let foStored = workflowState(for: .fileOrganizer)
                fileOrganizerExecutionReceipt = FileOrganizerExecutionReceipt(
                    planNumber: foStored.planNumber,
                    receiptCode: foStored.receiptCode,
                    completedAt: Date(),
                    movedItemCount: movedCount,
                    summary: fileOrganizerScanSummary,
                    failureReason: nil
                )
            }
        } catch {
            fileOrganizerScanSummary = error.localizedDescription
            fileOrganizerExecutionIssue = error.localizedDescription
            // Partial-completion receipt (spec §2.3 ④ error → 「查看回执」):
            // the run may have moved some files before failing. movedCount here
            // is the pre-run snapshot (the success path overwrote it inside the
            // do-block); we surface a partial receipt so the user can review
            // what landed where and restore via the ledger. Fail-closed §1.6:
            // every field is real — the failureReason is the worker's error.
            let foStored = workflowState(for: .fileOrganizer)
            fileOrganizerExecutionReceipt = FileOrganizerExecutionReceipt(
                planNumber: foStored.planNumber,
                receiptCode: foStored.receiptCode,
                completedAt: Date(),
                movedItemCount: fileOrganizerMovedCount,
                summary: fileOrganizerScanSummary,
                failureReason: error.localizedDescription
            )
        }

        isFileOrganizerExecuting = false
    }

    func dryRunFileOrganizerPlan() async {
        guard !currentFileOrganizerPlan.items.isEmpty else { return }
        let itemCount = currentFileOrganizerPlan.items.count
        let estimatedBytes = currentFileOrganizerPlan.estimatedBytes
        do {
            let output = try await workspaceController.fileOrganizerDryRun(planID: currentFileOrganizerPlan.id)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentFileOrganizerPlan = output.actionPlan
                fileOrganizerScanSummary = output.summary
            }
            let sizeStr = ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
            let msg = AtlasL10n.string(
                itemCount == 1
                    ? "fileorganizer.dryRun.success.one"
                    : "fileorganizer.dryRun.success.other",
                "\(itemCount)", sizeStr
            )
            showToast(msg, tone: .success, systemImage: "checkmark.circle")
        } catch {
            showToast(
                AtlasL10n.string("fileorganizer.dryRun.error", error.localizedDescription),
                tone: .danger,
                systemImage: "exclamationmark.triangle"
            )
        }
    }

    private func reloadAppsInventory(
        navigateToApps: Bool,
        resetPreview: Bool,
        loadingSummary: String? = nil,
        restoreStatus: AtlasAppPostRestoreRefreshStatus? = nil
    ) async {
        guard !isAppActionRunning else {
            return
        }

        if navigateToApps {
            selection = .apps
        }
        isAppActionRunning = true
        activePreviewAppID = nil
        activeUninstallAppID = nil
        if resetPreview {
            currentAppPreview = nil
            currentPreviewedAppID = nil
        }
        latestAppsSummary = loadingSummary ?? AtlasL10n.string("model.apps.refreshing")

        do {
            let output = try await workspaceController.listApps()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                latestAppsSummary = output.summary
                latestAppRestoreRefreshStatus = refreshedAppRestoreStatus(
                    from: restoreStatus ?? latestAppRestoreRefreshStatus,
                    apps: output.apps
                )
            }
        } catch {
            latestAppsSummary = error.localizedDescription
            // Clear stale snapshot counts — the refresh failed so we can't compare
            pendingRestoreSnapshotCategoryCounts = nil
            if let existingStatus = restoreStatus ?? latestAppRestoreRefreshStatus {
                latestAppRestoreRefreshStatus = AtlasAppPostRestoreRefreshStatus(
                    appName: existingStatus.appName,
                    bundleIdentifier: existingStatus.bundleIdentifier,
                    bundlePath: existingStatus.bundlePath,
                    state: .stale,
                    recordedLeftoverItems: existingStatus.recordedLeftoverItems,
                    refreshedLeftoverItems: nil,
                    issueDescription: error.localizedDescription
                )
            }
        }

        isAppActionRunning = false
    }

}

private extension RecoveryItem {
    var appRecoveryPayload: AtlasAppRecoveryPayload? {
        guard case let .app(payload)? = payload else {
            return nil
        }
        return payload
    }
}

private extension AtlasAppModel {
    func refreshedAppRestoreStatus(
        from status: AtlasAppPostRestoreRefreshStatus?,
        apps: [AppFootprint]
    ) -> AtlasAppPostRestoreRefreshStatus? {
        guard let status else {
            return nil
        }

        guard let refreshedApp = apps.first(where: {
            $0.bundlePath == status.bundlePath || $0.bundleIdentifier == status.bundleIdentifier
        }) else {
            return AtlasAppPostRestoreRefreshStatus(
                appName: status.appName,
                bundleIdentifier: status.bundleIdentifier,
                bundlePath: status.bundlePath,
                state: .stale,
                recordedLeftoverItems: status.recordedLeftoverItems,
                refreshedLeftoverItems: nil,
                issueDescription: status.issueDescription
            )
        }

        // Detect evidence divergence: compare fresh scan evidenceSummary against snapshot group counts
        let snapshotCounts = pendingRestoreSnapshotCategoryCounts
        let freshSummary = refreshedApp.evidenceSummary
        var divergentCategories: [AtlasAppEvidenceCategory] = []
        var divergenceDetected = false

        if let snapshotCounts, let freshSummary {
            for category in AtlasAppEvidenceCategory.allCases {
                let snapshotCount = snapshotCounts[category] ?? 0
                let freshCount = freshSummary[category] ?? 0
                if snapshotCount != freshCount {
                    divergentCategories.append(category)
                }
            }
            divergenceDetected = !divergentCategories.isEmpty
        }

        // Clear the pending snapshot counts after use
        pendingRestoreSnapshotCategoryCounts = nil

        return AtlasAppPostRestoreRefreshStatus(
            appName: refreshedApp.name,
            bundleIdentifier: refreshedApp.bundleIdentifier,
            bundlePath: refreshedApp.bundlePath,
            state: .refreshed,
            recordedLeftoverItems: status.recordedLeftoverItems,
            refreshedLeftoverItems: refreshedApp.leftoverItems,
            issueDescription: nil,
            evidenceDivergenceDetected: divergenceDetected,
            divergentCategories: divergentCategories
        )
    }

    /// Extract per-category counts from a snapshot, using path-level granularity to match
    /// `MacAppsInventoryAdapter.computeEvidenceSummary` which counts individual existing paths
    /// per category (e.g., supportFiles may count 2 if both `{appName}` and `{bundleID}` paths
    /// exist). Using `group.items.count` (number of candidate URLs that existed on disk at
    /// capture time) aligns with the adapter's path-level counting.
    static func categoryCountsFromSnapshot(_ snapshot: AtlasAppUninstallEvidenceSnapshot?) -> [AtlasAppEvidenceCategory: Int]? {
        guard let snapshot else { return nil }
        var counts: [AtlasAppEvidenceCategory: Int] = [:]
        for group in snapshot.reviewOnlyGroups {
            counts[group.category] = group.items.count
        }
        return counts
    }
}
