import AtlasDesignSystem
import AtlasDomain
import AtlasFeaturesAbout
import AtlasFeaturesApps
import AtlasFeaturesHistory
import AtlasFeaturesOverview
import AtlasFeaturesPermissions
import AtlasFeaturesSettings
import AtlasFeaturesSmartClean
import SwiftUI

struct AppShellView: View {
    @ObservedObject var model: AtlasAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                ForEach(AtlasRoute.SidebarSection.allCases) { section in
                    Section(section.title) {
                        ForEach(section.routes) { route in
                            SidebarRouteRow(route: route)
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
            .id(model.appLanguage)
            .navigationTitle(AtlasL10n.string("app.name"))
            .navigationSplitViewColumnWidth(min: AtlasLayout.sidebarMinWidth, ideal: AtlasLayout.sidebarIdealWidth)
            .listStyle(.sidebar)
            .accessibilityIdentifier("atlas.sidebar")
        } detail: {
            let route = model.selection ?? .overview

            detailContent(for: route)
                .toolbar {
                    ToolbarItem {
                        taskCenterToolbarButton
                    }
                }
                .animation(AtlasMotion.slow, value: model.selection)
        }
        .navigationSplitViewStyle(.balanced)
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
                summary: model.taskCenterSummary
            ) {
                model.closeTaskCenter()
                model.navigate(to: .history)
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
                .id(route)
                .transition(reduceMotion ? .opacity : AtlasTransition.fadeSlide)
        default:
            detailView(for: route)
                .id(route)
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
                onStartSmartClean: {
                    model.navigate(to: .smartClean)
                    Task { await model.runSmartCleanScan() }
                },
                onNavigateToSmartClean: {
                    model.navigate(to: .smartClean)
                },
                onNavigateToHistory: {
                    model.navigate(to: .history)
                },
                onNavigateToPermissions: {
                    model.navigate(to: .permissions)
                    Task { await model.inspectPermissions() }
                }
            )
        case .smartClean:
            SmartCleanFeatureView(
                findings: model.filteredFindings,
                plan: model.currentPlan,
                scanSummary: model.latestScanSummary,
                scanProgress: model.latestScanProgress,
                isScanning: model.isScanRunning,
                isExecutingPlan: model.isPlanRunning,
                isCurrentPlanFresh: model.isCurrentSmartCleanPlanFresh,
                canExecutePlan: model.canExecuteCurrentSmartCleanPlan,
                planIssue: model.smartCleanPlanIssue,
                executionIssue: model.smartCleanExecutionIssue,
                onStartScan: {
                    Task { await model.runSmartCleanScan() }
                },
                onRefreshPreview: {
                    Task { await model.refreshPlanPreview() }
                },
                onExecutePlan: {
                    Task { await model.executeCurrentPlan() }
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
                }
            )
        case .history:
            HistoryFeatureView(
                taskRuns: model.filteredTaskRuns,
                recoveryItems: model.filteredRecoveryItems,
                restoringItemID: model.restoringRecoveryItemID,
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
                onSetLanguage: { language in
                    Task { await model.setLanguage(language) }
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

    private var activeTaskCount: Int {
        model.snapshot.taskRuns.filter { taskRun in
            taskRun.status == .queued || taskRun.status == .running
        }.count
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

private struct SidebarRouteRow: View {
    let route: AtlasRoute

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

                Text(route.subtitle)
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
        .accessibilityLabel("\(route.title). \(route.subtitle)")
        .accessibilityHint(route.shortcutNumber.isEmpty ? "" : AtlasL10n.string("sidebar.route.hint", route.shortcutNumber))
    }
}

private extension AtlasRoute {
    /// Per-route theme color for sidebar icon gradients and visual accents.
    var themeColor: Color {
        switch self {
        case .overview:    return AtlasColor.brand
        case .smartClean:  return AtlasColor.success
        case .apps:        return AtlasColor.accent
        case .history:     return AtlasColor.info
        case .permissions: return AtlasColor.warning
        case .settings:    return AtlasColor.textSecondary
        case .about:       return AtlasColor.brand
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
        case .apps:
            return "3"
        case .history:
            return "4"
        case .permissions:
            return "5"
        case .settings:
            return ","
        case .about:
            return ""
        }
    }
}
