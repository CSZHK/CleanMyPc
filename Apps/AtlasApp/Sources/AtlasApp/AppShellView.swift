import AtlasDesignSystem
import AtlasDomain
import AtlasFeaturesAbout
import AtlasFeaturesApps
import AtlasFeaturesFileOrganizer
import AtlasFeaturesHistory
import AtlasFeaturesOverview
import AtlasFeaturesPermissions
import AtlasFeaturesSettings
import AtlasFeaturesSmartClean
import SwiftUI

struct AppShellView: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Action-bar height reported by the AtlasScreen actionBar slot — lifts the
    /// toast container above the pinned bar (spec §4.3 共存规则).
    @State private var actionBarHeight: CGFloat = 0

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                AtlasSidebarWordmark()
                    .padding(.horizontal, AtlasSpacing.lg)
                    .padding(.top, AtlasSpacing.md)
                    .padding(.bottom, AtlasSpacing.xs)

                List(selection: $model.selection) {
                    ForEach(AtlasRoute.SidebarSection.allCases) { section in
                        Section(section.title) {
                            ForEach(section.routes) { route in
                                SidebarRouteRow(route: route, context: sidebarContext)
                                    .tag(route)
                            }
                        }
                    }

                    Section {
                        SidebarRouteRow(route: .settings)
                            .tag(AtlasRoute.settings)
                        SidebarRouteRow(route: .about)
                            .tag(AtlasRoute.about)
                    }
                }
                .listStyle(.sidebar)
            }
            .id(model.appLanguage)
            .navigationTitle(AtlasL10n.string("app.name"))
            .navigationSplitViewColumnWidth(min: AtlasLayout.sidebarMinWidth, ideal: AtlasLayout.sidebarIdealWidth)
            .accessibilityIdentifier("atlas.sidebar")
        } detail: {
            let route = model.selection ?? .overview

            detailContent(for: route)
                .toolbar {
                    // Scan-receipt chip (spec §2.1): current module's latest
                    // receipt; hidden when the route has none.
                    if let receiptCode = model.workflowState(for: route).receiptCode {
                        ToolbarItem {
                            ReceiptChip(code: receiptCode)
                        }
                    }
                    ToolbarItem {
                        taskCenterToolbarButton
                    }
                }
                .animation(AtlasMotion.slow, value: model.selection)
        }
        .tint(AtlasColor.brand)
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(model.settings.theme.colorScheme)
        .overlay(alignment: .topTrailing) {
            AboutUpdateToolbarButton(
                appVersion: model.appVersion,
                appBuild: model.appBuild,
                updateResult: model.latestUpdateResult,
                isCheckingForUpdate: model.isCheckingForUpdate,
                updateCheckNotice: model.updateCheckNotice,
                updateCheckError: model.updateCheckError,
                onCheckForUpdate: {
                    Task { await model.checkForUpdate() }
                }
            )
            .padding(.top, 10)
            .padding(.trailing, 24)
            .ignoresSafeArea(.container, edges: .top)
        }
        .overlay(alignment: .bottomTrailing) {
            // 8s dwell per spec §3.1 (undo toasts need the longer window);
            // queue/concurrency behavior unchanged.
            AtlasToastContainer(items: $model.toasts, autoDismissInterval: 8.0)
                .padding(AtlasSpacing.lg)
                // Coexistence with the pinned action bar: toasts sit above it.
                .padding(.bottom, actionBarHeight)
                .allowsHitTesting(!model.toasts.isEmpty)
        }
        .onPreferenceChange(AtlasActionBarHeightKey.self) { height in
            actionBarHeight = height
        }
        .task {
            await model.refreshHealthSnapshotIfNeeded()
            await model.refreshPermissionsIfNeeded()
        }
        .onChange(of: model.selection, initial: false) { _, selection in
            guard selection == .permissions else {
                return
            }
            Task {
                await model.inspectPermissions()
            }
        }
        .popover(isPresented: $model.isTaskCenterPresented) {
            TaskCenterView(
                taskRuns: model.taskCenterTaskRuns,
                summary: model.taskCenterSummary,
                planNumber: { model.workflowPlanNumber(for: $0) }
            ) {
                model.closeTaskCenter()
                model.navigate(to: .ledger)
            }
            .onExitCommand {
                model.closeTaskCenter()
            }
        }
    }

    @ViewBuilder
    private func detailContent(for route: AtlasRoute) -> some View {
        switch route {
        case .settings, .about:
            detailView(for: route)
                .id("\(route.rawValue)-\(model.appLanguage.rawValue)")
                .transition(reduceMotion ? .opacity : AtlasTransition.fadeSlide)
        default:
            detailView(for: route)
                .id("\(route.rawValue)-\(model.appLanguage.rawValue)")
                .transition(reduceMotion ? .opacity : AtlasTransition.fadeSlide)
                .searchable(
                    text: Binding(
                        get: { model.searchText(for: route) },
                        set: { model.setSearchText($0, for: route) }
                    ),
                    prompt: AtlasL10n.string("app.search.prompt.route", route.searchPromptLabel)
                )
                .accessibilityHint(AtlasL10n.string("app.search.hint.route", route.searchPromptLabel))
        }
    }

    @ViewBuilder
    private func detailView(for route: AtlasRoute) -> some View {
        switch route {
        case .overview:
            OverviewFeatureView(
                snapshot: model.filteredSnapshot,
                isRefreshingHealthSnapshot: model.isHealthSnapshotRefreshing,
                isLoading: model.isHealthSnapshotRefreshing && model.filteredSnapshot.healthSnapshot == nil,
                requiredPermissionsGranted: overviewRequiredPermissionsGranted,
                requiredPermissionsTotal: overviewRequiredPermissionsTotal,
                isCurrentSmartCleanPlanFresh: model.isCurrentSmartCleanPlanFresh,
                currentPlanReclaimableBytes: overviewPlanReclaimableBytes,
                currentPlanFindingCount: model.currentPlan.items.count,
                currentPlanNumber: model.workflowState(for: .smartClean).planNumber,
                latestScanReceiptCode: model.workflowState(for: .smartClean).receiptCode,
                planNumberForRun: { model.workflowPlanNumber(for: $0) },
                onStartSmartClean: {
                    model.navigate(to: .smartClean)
                    Task { await model.runSmartCleanScan() }
                },
                onNavigateToSmartClean: {
                    model.navigate(to: .smartClean)
                },
                onNavigateToApps: {
                    model.navigate(to: .apps)
                },
                onNavigateToFileOrganizer: {
                    model.navigate(to: .fileOrganizer)
                },
                onNavigateToLedger: {
                    model.navigate(to: .ledger)
                },
                onNavigateToPermissions: {
                    model.navigate(to: .permissions)
                    Task { await model.inspectPermissions() }
                },
                onSelectLedgerEntry: { _ in
                    model.navigate(to: .ledger)
                }
            )
        case .smartClean:
            SmartCleanFeatureView(
                findings: model.snapshot.findings,
                plan: model.currentPlan,
                scanSummary: model.latestScanSummary,
                scanProgress: model.latestScanProgress,
                isScanning: model.isScanRunning,
                isExecutingPlan: model.isPlanRunning,
                isCurrentPlanFresh: model.isCurrentSmartCleanPlanFresh,
                canExecutePlan: model.canExecuteCurrentSmartCleanPlan,
                planIssue: model.smartCleanPlanIssue,
                executionIssue: model.smartCleanExecutionIssue,
                executionReceipt: model.smartCleanExecutionReceipt,
                retentionDays: model.settings.recoveryRetentionDays,
                searchText: model.searchText(for: .smartClean),
                state: smartCleanWorkflowState,
                onStateChange: { newState in
                    model.updateWorkflowState(for: .smartClean) { state in
                        // Decision A (resolve-on-render): the view never writes
                        // currentStage — only user-mutable presentation state.
                        state.displayedStage = newState.displayedStage
                        state.selectedIDs = newState.selectedIDs
                        state.riskFilter = newState.riskFilter
                        state.evidenceSelectionID = newState.evidenceSelectionID
                        state.drawerPresented = newState.drawerPresented
                    }
                },
                onStartScan: {
                    Task { await model.runSmartCleanScan() }
                },
                onRefreshPreview: {
                    Task { await model.refreshPlanPreview() }
                },
                onRequestRescan: {
                    // Decision B: the on-screen rescan button raises the same
                    // confirmation flag as Cmd+Shift+R (one shared flow).
                    model.requestRescanConfirmation(for: .smartClean)
                },
                onConfirmRescan: {
                    model.supersedePlan(for: .smartClean)
                    Task { await model.runSmartCleanScan() }
                },
                onCancelRescan: {
                    model.updateWorkflowState(for: .smartClean) { state in
                        state.rescanConfirmationPending = false
                    }
                },
                onExecuteSelection: { findingIDs in
                    Task {
                        // Execute exactly the reviewed selection: when it differs
                        // from the current plan, re-preview through the existing
                        // controller API first (fail-closed: stop on failure).
                        let planIDs = Set(model.currentPlan.items.map(\.id))
                        if Set(findingIDs) != planIDs {
                            guard await model.refreshPlanPreview(findingIDs: findingIDs) else { return }
                        }
                        await model.executeCurrentPlan()
                    }
                },
                onUndoExecution: {
                    Task { await model.undoSmartCleanExecution() }
                },
                onNavigateToLedger: {
                    model.navigate(to: .ledger)
                }
            )
        case .fileOrganizer:
            FileOrganizerFeatureView(
                entries: model.filteredFileOrganizerEntries,
                plan: model.currentFileOrganizerPlan,
                scanSummary: model.fileOrganizerScanSummary,
                scanProgress: model.fileOrganizerProgress,
                isScanning: model.isFileOrganizerScanning,
                isClassifying: model.isFileOrganizerClassifying,
                isExecutingPlan: model.isFileOrganizerExecuting,
                isPlanFresh: model.isFileOrganizerPlanFresh,
                canExecutePlan: model.canExecuteFileOrganizerPlan,
                planIssue: model.fileOrganizerPlanIssue,
                executionIssue: model.fileOrganizerExecutionIssue,
                executionReceipt: model.fileOrganizerExecutionReceipt,
                movedCount: model.fileOrganizerMovedCount,
                scannedFolders: model.scannedFolders,
                rules: model.fileOrganizerRules,
                destinationBasePath: model.settings.fileOrganizerDestinationBasePath,
                isRecursiveScan: model.settings.fileOrganizerRecursiveScan,
                searchText: model.searchText(for: .fileOrganizer),
                state: fileOrganizerWorkflowState,
                onStateChange: { newState in
                    model.updateWorkflowState(for: .fileOrganizer) { state in
                        // Decision A (resolve-on-render): the view never writes
                        // currentStage — only user-mutable presentation state.
                        // UUID→String bridge for the shared per-route host.
                        state.displayedStage = newState.displayedStage
                        state.selectedIDs = Set(newState.selectedIDs.map(\.uuidString))
                        state.evidenceSelectionID = newState.evidenceSelectionID?.uuidString
                        state.drawerPresented = newState.drawerPresented
                    }
                },
                onStartScan: { folders in
                    Task { await model.runFileOrganizerScan(folderPaths: folders) }
                },
                onClassify: { entryIDs in
                    Task { await model.classifyFileOrganizerEntries(entryIDs: entryIDs) }
                },
                onRefreshPreview: { entryIDs in
                    Task { await model.refreshFileOrganizerPreview(entryIDs: entryIDs) }
                },
                onExecutePlan: {
                    Task { await model.executeFileOrganizerPlan() }
                },
                onDryRun: {
                    Task { await model.dryRunFileOrganizerPlan() }
                },
                onUpdateDestination: { path in
                    Task { await model.updateFileOrganizerDestination(path) }
                },
                onUpdateRecursiveScan: { recursive in
                    Task { await model.updateFileOrganizerRecursiveScan(recursive) }
                },
                onUpdateRules: { rules in
                    Task { await model.updateFileOrganizerRules(rules) }
                },
                onUndoExecution: {
                    Task { await model.undoFileOrganizerExecution() }
                },
                onNavigateToLedger: {
                    model.navigate(to: .ledger)
                }
            )
        case .apps:
            AppsFeatureView(
                apps: model.filteredApps,
                previewPlan: model.currentAppPreview,
                currentPreviewedAppID: model.currentPreviewedAppID,
                restoreRefreshStatus: model.latestAppRestoreRefreshStatus,
                summary: model.latestAppsSummary,
                isRunning: model.isAppActionRunning,
                activePreviewAppID: model.activePreviewAppID,
                activeUninstallAppID: model.activeUninstallAppID,
                onRefreshApps: {
                    Task { await model.refreshApps() }
                },
                onPreviewAppUninstall: { appID in
                    Task { await model.previewAppUninstall(appID: appID) }
                },
                onExecuteAppUninstall: { appID in
                    Task { await model.executeAppUninstall(appID: appID) }
                },
                onRescanLeftovers: { appID in
                    Task { await model.rescanLeftovers(appID: appID) }
                }
            )
        case .ledger:
            LedgerFeatureView(
                taskRuns: model.filteredTaskRuns,
                recoveryItems: model.filteredRecoveryItems,
                restoringItemID: model.restoringRecoveryItemID,
                retentionDays: model.settings.recoveryRetentionDays,
                planNumber: { run in model.workflowPlanNumber(for: run) },
                onRestoreItem: { itemID in
                    Task { await model.restoreRecoveryItem(itemID) }
                }
            )
        case .permissions:
            PermissionsFeatureView(
                permissionStates: model.filteredPermissionStates,
                summary: model.latestPermissionsSummary,
                isRefreshing: model.isPermissionsRefreshing,
                onRefresh: {
                    Task { await model.inspectPermissions() }
                },
                onRequestNotificationPermission: {
                    Task { await model.requestNotificationPermission() }
                }
            )
        case .settings:
            SettingsFeatureView(
                settings: model.settings,
                recoveryTotalBytes: model.filteredRecoveryItems.reduce(Int64(0)) { $0 + $1.bytes },
                onSetLanguage: { language in
                    Task { await model.setLanguage(language) }
                },
                onSetTheme: { theme in
                    Task { await model.setTheme(theme) }
                },
                onSetRecoveryRetention: { days in
                    Task { await model.setRecoveryRetentionDays(days) }
                },
                onToggleNotifications: { isEnabled in
                    Task { await model.setNotificationsEnabled(isEnabled) }
                }
            )
        case .about:
            AboutFeatureView()
        }
    }

    /// Decision A (resolve-on-render): the smart-clean stage is derived from
    /// live model state via `AtlasWorkflowStageMap.resolve` on every render.
    /// The stored ViewState contributes only user-mutable presentation fields
    /// (displayed stage, selection, filter, drawer, rescan flag) — there is no
    /// second written stage truth.
    private var smartCleanWorkflowState: SmartCleanWorkflowState {
        let stored = model.workflowState(for: .smartClean)
        let resolution = AtlasWorkflowStageMap.resolve(AtlasWorkflowStageMap.Inputs(
            isScanning: model.isScanRunning,
            isExecuting: model.isPlanRunning,
            executionFailed: model.smartCleanExecutionIssue != nil,
            executionCompleted: model.smartCleanExecutionCompleted,
            isPlanFresh: model.isCurrentSmartCleanPlanFresh,
            findingsCount: model.snapshot.findings.count
        ))
        return SmartCleanWorkflowState(
            currentStage: resolution.current,
            displayedStage: stored.displayedStage,
            planNumber: stored.planNumber,
            receiptCode: stored.receiptCode,
            selectedIDs: stored.selectedIDs,
            riskFilter: stored.riskFilter,
            evidenceSelectionID: stored.evidenceSelectionID,
            drawerPresented: stored.drawerPresented,
            rescanConfirmationPending: stored.rescanConfirmationPending,
            isScanInProgress: resolution.isScanInProgress,
            isReviewEmpty: resolution.isReviewEmpty,
            isExecutionError: resolution.isExecutionError
        )
    }

    /// Decision A (resolve-on-render) — FileOrganizer mirror of
    /// `smartCleanWorkflowState`. The shell derives `currentStage` from live
    /// model state via `FileOrganizerStageMap.resolve` (five segments: ① scan
    /// · ② rules · ③ preview · ④ execute · ⑤ receipt) on every render; the
    /// stored ViewState contributes only user-mutable presentation fields.
    ///
    /// Host/feature type bridge: `AtlasWorkflowViewState.selectedIDs` is keyed
    /// by `String` (Finding-id convention shared with SmartClean) while the
    /// FileOrganizer feature keys selection by `UUID`. We map String↔UUID here
    /// so the single per-route host remains the persistence truth (§2.3 —
    /// feature-local @State does not survive route switches). Invalid UUID
    /// strings are dropped (fail-closed).
    private var fileOrganizerWorkflowState: FileOrganizerWorkflowState {
        let stored = model.workflowState(for: .fileOrganizer)
        let resolution = FileOrganizerStageMap.resolve(FileOrganizerStageMap.Inputs(
            isScanning: model.isFileOrganizerScanning,
            isClassifying: model.isFileOrganizerClassifying,
            isExecuting: model.isFileOrganizerExecuting,
            executionFailed: model.fileOrganizerExecutionIssue != nil,
            executionCompleted: model.fileOrganizerExecutionCompleted,
            isPlanFresh: model.isFileOrganizerPlanFresh,
            hasPreviewResults: model.isFileOrganizerPlanFresh && !model.currentFileOrganizerPlan.items.isEmpty,
            entriesCount: model.filteredFileOrganizerEntries.count
        ))
        return FileOrganizerWorkflowState(
            currentStage: resolution.current,
            displayedStage: stored.displayedStage,
            planNumber: stored.planNumber,
            receiptCode: stored.receiptCode,
            selectedIDs: Set(stored.selectedIDs.compactMap(UUID.init(uuidString:))),
            evidenceSelectionID: stored.evidenceSelectionID.flatMap(UUID.init(uuidString:)),
            drawerPresented: stored.drawerPresented,
            rescanConfirmationPending: stored.rescanConfirmationPending,
            isScanInProgress: resolution.isScanInProgress,
            isRulesEmpty: resolution.isRulesEmpty,
            isExecutionError: resolution.isExecutionError
        )
    }

    private var activeTaskCount: Int {
        model.snapshot.taskRuns.filter { taskRun in
            taskRun.status == .queued || taskRun.status == .running
        }.count
    }

    // Overview: required-permission counts for the recommendation banner.
    private var overviewRequiredPerms: [PermissionState] {
        model.filteredSnapshot.permissions.filter { $0.kind.isRequiredForCurrentWorkflows }
    }
    private var overviewRequiredPermissionsGranted: Int {
        overviewRequiredPerms.filter(\.isGranted).count
    }
    private var overviewRequiredPermissionsTotal: Int {
        overviewRequiredPerms.count
    }
    // Overview: reclaimable bytes for the fresh-plan banner (snapshot value is
    // the authoritative estimate; falls back to 0 when no scan has run).
    private var overviewPlanReclaimableBytes: Int64 {
        model.filteredSnapshot.reclaimableSpaceBytes
    }

    private var sidebarContext: AtlasSidebarContext {
        let snap = model.filteredSnapshot
        let requiredPerms = snap.permissions.filter { $0.kind.isRequiredForCurrentWorkflows }
        return AtlasSidebarContext(
            findingsCount: snap.findings.count,
            reclaimableBytes: snap.reclaimableSpaceBytes,
            appsCount: snap.apps.count,
            recoveryItemsCount: snap.recoveryItems.count,
            requiredPermissionsGranted: requiredPerms.filter(\.isGranted).count,
            requiredPermissionsTotal: requiredPerms.count,
            diskUsedPercent: snap.healthSnapshot?.diskUsedPercent,
            fileOrganizerEntriesCount: snap.fileOrganizerEntries.count
        )
    }

    private var taskCenterToolbarButton: some View {
        Button {
            model.openTaskCenter()
        } label: {
            Label {
                Text(AtlasL10n.string("toolbar.taskcenter"))
            } icon: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: AtlasIcon.taskCenter)
                        .symbolRenderingMode(.hierarchical)

                    if activeTaskCount > 0 {
                        Text(activeTaskCount > 99 ? "99+" : "\(activeTaskCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, activeTaskCount > 9 ? AtlasSpacing.xxs : AtlasSpacing.xs)
                            .padding(.vertical, 2)
                            .background(Capsule(style: .continuous).fill(AtlasColor.accent))
                            .offset(x: 10, y: -8)
                    }
                }
            }
        }
        .help(AtlasL10n.string("toolbar.taskcenter.help"))
        .accessibilityIdentifier("toolbar.taskCenter")
        .accessibilityLabel(AtlasL10n.string("toolbar.taskcenter.accessibilityLabel"))
        .accessibilityHint(AtlasL10n.string("toolbar.taskcenter.accessibilityHint"))
    }
}

/// `ATLAS.` serif wordmark at the sidebar top (spec §2.1) — ledger voice with a
/// brand-colored full stop. Decorative: the app name is announced elsewhere.
private struct AtlasSidebarWordmark: View {
    var body: some View {
        (Text("ATLAS").foregroundStyle(AtlasColor.ink)
            + Text(".").foregroundStyle(AtlasColor.brand))
            .font(AtlasTypography.ledgerFont(size: 15, weight: .bold))
            .accessibilityHidden(true)
    }
}

/// Toolbar scan-receipt chip (spec §2.1/§5.4): mono `#XXXX`, hidden when the
/// current route has no receipt (handled by the caller).
private struct ReceiptChip: View {
    let code: String

    var body: some View {
        Text("#\(code)")
            .font(AtlasTypography.dataCaption)
            .monospacedDigit()
            .foregroundStyle(AtlasColor.textSecondary)
            .padding(.horizontal, AtlasSpacing.sm)
            .padding(.vertical, AtlasSpacing.xxs)
            .background(
                Capsule(style: .continuous)
                    .strokeBorder(AtlasColor.border, lineWidth: 1)
            )
            .help(AtlasL10n.string("toolbar.receipt.help"))
            .accessibilityLabel(AtlasL10n.string("toolbar.receipt.accessibilityLabel", "#\(code)"))
    }
}

private struct SidebarRouteRow: View {
    let route: AtlasRoute
    let dynamicSubtitleText: String

    init(route: AtlasRoute, context: AtlasSidebarContext = AtlasSidebarContext()) {
        self.route = route
        self.dynamicSubtitleText = route.dynamicSubtitle(context: context)
    }

    var body: some View {
        HStack(alignment: .center, spacing: AtlasSpacing.md) {
            ZStack {
                // Blurred gradient circle with per-route theme color
                RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                route.themeColor.opacity(0.18),
                                route.themeColor.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: AtlasLayout.sidebarIconSize, height: AtlasLayout.sidebarIconSize)

                Image(systemName: route.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(route.themeColor)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(route.title)
                    .font(AtlasTypography.rowTitle)

                Text(dynamicSubtitleText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, AtlasSpacing.sm)
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("route.\(route.id)")
        .accessibilityLabel("\(route.title). \(dynamicSubtitleText)")
        .accessibilityHint(route.shortcutNumber.isEmpty ? "" : AtlasL10n.string("sidebar.route.hint", route.shortcutNumber))
    }
}

private extension AtlasRoute {
    /// Per-route theme color for sidebar icon gradients and visual accents.
    var themeColor: Color {
        switch self {
        case .overview:       return AtlasColor.brand
        case .smartClean:     return AtlasColor.success
        case .fileOrganizer:  return AtlasColor.accent
        case .apps:           return AtlasColor.info
        case .ledger:        return AtlasColor.textSecondary
        case .permissions:    return AtlasColor.warning
        case .settings:       return AtlasColor.textSecondary
        case .about:          return AtlasColor.brand
        }
    }

    var searchPromptLabel: String {
        title
    }

    var shortcutNumber: String {
        switch self {
        case .overview:
            return "1"
        case .smartClean:
            return "2"
        case .fileOrganizer:
            return "3"
        case .apps:
            return "4"
        case .ledger:
            return "5"
        case .permissions:
            return "6"
        case .settings:
            return ","
        case .about:
            return ""
        }
    }
}
