import AtlasApplication
import AtlasCoreAdapters
import AtlasDomain
import AtlasInfrastructure
import Combine
import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class AtlasAppModel: ObservableObject {
    @Published var selection: AtlasRoute? = .overview
    @Published private var searchTextByRoute: [AtlasRoute: String] = [:]
    @Published var isTaskCenterPresented = false
    @Published private(set) var snapshot: AtlasWorkspaceSnapshot
    @Published private(set) var currentPlan: ActionPlan
    @Published private(set) var currentAppPreview: ActionPlan?
    @Published private(set) var currentPreviewedAppID: UUID?
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
    @Published private(set) var latestUpdateResult: AtlasAppUpdate?
    @Published private(set) var isCheckingForUpdate = false
    @Published private(set) var updateCheckNotice: String?
    @Published private(set) var updateCheckError: String?

    private let repository: AtlasWorkspaceRepository
    private let workspaceController: AtlasWorkspaceController
    private let updateChecker = AtlasUpdateChecker()
    private let notificationPermissionRequester: @Sendable () async -> Bool
    private var didRequestInitialHealthSnapshot = false
    private var didRequestInitialPermissionSnapshot = false

    init(
        repository: AtlasWorkspaceRepository = AtlasWorkspaceRepository(),
        workerService: (any AtlasWorkerServing)? = nil,
        preferXPCWorker: Bool? = nil,
        allowScaffoldFallback: Bool? = nil,
        xpcRequestConfiguration: AtlasXPCRequestConfiguration = AtlasXPCRequestConfiguration(),
        xpcRequestExecutor: AtlasXPCDataRequestExecutor? = nil,
        notificationPermissionRequester: (@Sendable () async -> Bool)? = nil
    ) {
        let state = repository.loadState()
        self.repository = repository
        self.snapshot = state.snapshot
        self.currentPlan = state.currentPlan
        self.settings = state.settings
        AtlasL10n.setCurrentLanguage(state.settings.language)
        self.latestScanSummary = AtlasL10n.string("model.scan.ready")
        self.latestAppsSummary = AtlasL10n.string("model.apps.ready")
        self.latestPermissionsSummary = AtlasL10n.string("model.permissions.ready")
        self.isCurrentSmartCleanPlanFresh = false
        self.smartCleanPlanIssue = nil
        self.smartCleanExecutionIssue = nil
        let directWorker = AtlasScaffoldWorkerService(
            repository: repository,
            healthSnapshotProvider: MoleHealthAdapter(),
            smartCleanScanProvider: MoleSmartCleanAdapter(),
            appsInventoryProvider: MacAppsInventoryAdapter(),
            helperExecutor: AtlasPrivilegedHelperClient()
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
            await withCheckedContinuation { continuation in
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    var appLanguage: AtlasLanguage {
        settings.language
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.3"
    }

    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "4"
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
        searchTextByRoute[route, default: ""]
    }

    func setSearchText(_ text: String, for route: AtlasRoute) {
        searchTextByRoute[route] = text
    }

    var filteredSnapshot: AtlasWorkspaceSnapshot {
        var filtered = snapshot
        filtered.findings = filter(snapshot.findings, route: .overview) { finding in
            [finding.title, finding.detail, AtlasL10n.localizedCategory(finding.category), finding.risk.title]
        }
        filtered.apps = filter(snapshot.apps, route: .overview) { app in
            [app.name, app.bundleIdentifier, app.bundlePath, "\(app.leftoverItems)"]
        }
        filtered.taskRuns = filter(snapshot.taskRuns, route: .overview) { task in
            [task.kind.title, task.status.title, task.summary]
        }
        filtered.recoveryItems = filter(snapshot.recoveryItems, route: .overview) { item in
            [item.title, item.detail, item.originalPath]
        }
        filtered.permissions = filter(snapshot.permissions, route: .overview) { permission in
            [
                permission.kind.title,
                permission.rationale,
                permissionStatusText(for: permission)
            ]
        }
        return filtered
    }

    var filteredFindings: [Finding] {
        filter(snapshot.findings, route: .smartClean) { finding in
            [finding.title, finding.detail, AtlasL10n.localizedCategory(finding.category), finding.risk.title]
        }
    }

    var filteredApps: [AppFootprint] {
        filter(snapshot.apps, route: .apps) { app in
            [app.name, app.bundleIdentifier, app.bundlePath, "\(app.leftoverItems)"]
        }
    }

    var filteredTaskRuns: [TaskRun] {
        filter(snapshot.taskRuns, route: .history) { task in
            [task.kind.title, task.status.title, task.summary]
        }
    }

    var filteredRecoveryItems: [RecoveryItem] {
        filter(snapshot.recoveryItems, route: .history) { item in
            [item.title, item.detail, item.originalPath]
        }
    }

    var filteredPermissionStates: [PermissionState] {
        filter(snapshot.permissions, route: .permissions) { permission in
            [
                permission.kind.title,
                permission.rationale,
                permissionStatusText(for: permission)
            ]
        }
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
    }

    var canExecuteCurrentSmartCleanPlan: Bool {
        !currentPlan.items.isEmpty && isCurrentSmartCleanPlanFresh && currentSmartCleanPlanHasExecutableTargets
    }

    var currentSmartCleanPlanHasExecutableTargets: Bool {
        let executableItems = currentPlan.items.filter { $0.kind != .inspectPermission && $0.kind != .reviewEvidence }
        guard !executableItems.isEmpty else {
            return false
        }
        return executableItems.allSatisfy { !resolvedTargetPaths(for: $0).isEmpty }
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
        } catch {
            latestScanSummary = error.localizedDescription
            latestScanProgress = 0
            smartCleanPlanIssue = error.localizedDescription
        }

        isScanRunning = false
    }

    @discardableResult
    func refreshPlanPreview() async -> Bool {
        smartCleanExecutionIssue = nil
        do {
            let output = try await workspaceController.previewPlan(findingIDs: snapshot.findings.map(\.id))
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentPlan = output.actionPlan
                latestScanSummary = output.summary
                latestScanProgress = min(max(latestScanProgress, 1), 1)
                isCurrentSmartCleanPlanFresh = true
                smartCleanPlanIssue = nil
                smartCleanExecutionIssue = nil
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

        do {
            let output = try await workspaceController.executePlan(planID: currentPlan.id)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                latestScanSummary = output.summary
                latestScanProgress = output.progressFraction
                smartCleanPlanIssue = nil
                smartCleanExecutionIssue = nil
            }
            let didRefreshPlan = await refreshPlanPreview()
            if !didRefreshPlan {
                isCurrentSmartCleanPlanFresh = false
            }
        } catch {
            latestScanSummary = error.localizedDescription
            smartCleanExecutionIssue = error.localizedDescription
        }

        isPlanRunning = false
    }

    func refreshApps() async {
        await reloadAppsInventory(navigateToApps: true, resetPreview: true)
    }

    func previewAppUninstall(appID: UUID) async {
        guard !isAppActionRunning else {
            return
        }

        selection = .apps
        isAppActionRunning = true
        activePreviewAppID = appID
        activeUninstallAppID = nil

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

    func executeAppUninstall(appID: UUID) async {
        guard !isAppActionRunning else {
            return
        }

        selection = .apps
        isAppActionRunning = true
        activePreviewAppID = nil
        activeUninstallAppID = appID

        do {
            let output = try await workspaceController.executeAppUninstall(appID: appID)
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

        let restoredItem = snapshot.recoveryItems.first(where: { $0.id == itemID })
        let shouldRefreshAppsAfterRestore = restoredItem?.isAppPayload == true
        restoringRecoveryItemID = itemID

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
            if shouldRefreshAppsAfterRestore {
                await reloadAppsInventory(
                    navigateToApps: false,
                    resetPreview: true,
                    loadingSummary: output.summary
                )
            } else {
                await refreshPlanPreview()
            }
        } catch {
            let persistedState = repository.loadState()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = persistedState.snapshot
                currentPlan = persistedState.currentPlan
                settings = persistedState.settings
            }
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
        guard settings.language != language else {
            return
        }

        await updateSettings { settings in
            settings.language = language
            settings.acknowledgementText = AtlasL10n.acknowledgement(language: language)
            settings.thirdPartyNoticesText = AtlasL10n.thirdPartyNotices(language: language)
        }

        AtlasL10n.setCurrentLanguage(language)
        refreshLocalizedReadySummaries()
        if !snapshot.findings.isEmpty {
            await refreshPlanPreview()
        }
        currentAppPreview = nil
        currentPreviewedAppID = nil
    }

    func refreshCurrentRoute() async {
        switch selection ?? .overview {
        case .overview:
            await refreshHealthSnapshot()
        case .smartClean:
            await runSmartCleanScan()
        case .apps:
            await refreshApps()
        case .history:
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

    private func updateSettings(_ mutate: (inout AtlasSettings) -> Void) async {
        var updated = settings
        mutate(&updated)

        do {
            let output = try await workspaceController.updateSettings(updated)
            AtlasL10n.setCurrentLanguage(output.settings.language)
            withAnimation(.snappy(duration: 0.2)) {
                settings = output.settings
            }
        } catch {
            latestAppsSummary = error.localizedDescription
        }
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
    }

    private func reloadAppsInventory(
        navigateToApps: Bool,
        resetPreview: Bool,
        loadingSummary: String? = nil
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
            }
        } catch {
            latestAppsSummary = error.localizedDescription
        }

        isAppActionRunning = false
    }

    private func filter<Element>(
        _ elements: [Element],
        route: AtlasRoute,
        fields: (Element) -> [String]
    ) -> [Element] {
        let query = searchText(for: route)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else {
            return elements
        }

        return elements.filter { element in
            fields(element)
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }
}

private extension RecoveryItem {
    var isAppPayload: Bool {
        if case .app = payload {
            return true
        }
        return false
    }
}

private extension AtlasAppModel {
    func resolvedTargetPaths(for item: ActionItem) -> [String] {
        if let targetPaths = item.targetPaths, !targetPaths.isEmpty {
            return targetPaths
        }

        guard let finding = snapshot.findings.first(where: { $0.id == item.id }) else {
            return []
        }

        return finding.targetPaths ?? []
    }
}

private extension AtlasAppModel {
    func permissionStatusText(for permission: PermissionState) -> String {
        if permission.isGranted {
            return AtlasL10n.string("common.granted")
        }
        return permission.kind.isRequiredForCurrentWorkflows
            ? AtlasL10n.string("permissions.status.required")
            : AtlasL10n.string("permissions.status.optional")
    }
}
