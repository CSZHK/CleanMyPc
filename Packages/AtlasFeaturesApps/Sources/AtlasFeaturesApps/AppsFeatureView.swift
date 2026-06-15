import AtlasDesignSystem
import AtlasDomain
import SwiftUI

/// Apps screen (Calm Ledger Batch L1 — simplified skeleton, spec §2.3 Apps 段).
///
/// Single-select app browser: a grouped list on the left, a persistent
/// `AtlasEvidencePanel` on the right showing the selected app's 10-category
/// evidence footprint + uninstall-plan preview + residual estimate (spec §3).
/// The pinned action bar appears only when an app is selected AND its preview
/// plan is ready (no batch uninstall — regression red line).
///
/// Uninstall behavior is unchanged: the primary action delegates to
/// `onPreviewAppUninstall` (build/refresh plan) and `onExecuteAppUninstall`
/// (confirm + execute). The legacy `AppDetailView` with embedded buttons is
/// replaced by the shared `AtlasEvidencePanel` + `AtlasActionBar` chrome.
public struct AppsFeatureView: View {
    @Environment(\.atlasContentWidth) private var contentWidth

    private let apps: [AppFootprint]
    private let previewPlan: ActionPlan?
    private let currentPreviewedAppID: UUID?
    private let restoreRefreshStatus: AtlasAppPostRestoreRefreshStatus?
    private let summary: String
    private let isRunning: Bool
    private let activePreviewAppID: UUID?
    private let activeUninstallAppID: UUID?
    private let onRefreshApps: () -> Void
    private let onPreviewAppUninstall: (UUID) -> Void
    private let onExecuteAppUninstall: (UUID) -> Void
    private let onRescanLeftovers: (UUID) -> Void

    @State private var selectedAppID: UUID?
    @State private var browserWidth: CGFloat?
    @State private var showLeftoversOnly = false
    @State private var showUninstallConfirmation = false

    private let retentionDays: Int

    public init(
        apps: [AppFootprint] = AtlasScaffoldFixtures.apps,
        previewPlan: ActionPlan? = nil,
        currentPreviewedAppID: UUID? = nil,
        restoreRefreshStatus: AtlasAppPostRestoreRefreshStatus? = nil,
        summary: String = AtlasL10n.string("model.apps.ready"),
        isRunning: Bool = false,
        activePreviewAppID: UUID? = nil,
        activeUninstallAppID: UUID? = nil,
        onRefreshApps: @escaping () -> Void = {},
        onPreviewAppUninstall: @escaping (UUID) -> Void = { _ in },
        onExecuteAppUninstall: @escaping (UUID) -> Void = { _ in },
        onRescanLeftovers: @escaping (UUID) -> Void = { _ in }
    ) {
        self.apps = apps
        self.previewPlan = previewPlan
        self.currentPreviewedAppID = currentPreviewedAppID
        self.restoreRefreshStatus = restoreRefreshStatus
        self.summary = summary
        self.isRunning = isRunning
        self.activePreviewAppID = activePreviewAppID
        self.activeUninstallAppID = activeUninstallAppID
        self.onRefreshApps = onRefreshApps
        self.onPreviewAppUninstall = onPreviewAppUninstall
        self.onExecuteAppUninstall = onExecuteAppUninstall
        self.onRescanLeftovers = onRescanLeftovers
        // Retention window is a fixed Atlas default (14d) — Apps does not yet
        // carry its own retention field; mirroring the legacy detail copy.
        self.retentionDays = 14
        _selectedAppID = State(initialValue: Self.sortedApps(apps).first?.id)
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("apps.screen.title"),
            subtitle: AtlasL10n.string("apps.screen.subtitle"),
            maxContentWidth: AtlasLayout.maxWorkspaceWidth,
            actionBar: { AnyView(actionBar) }
        ) {
            if previewPlan != nil || restoreRefreshStatus != nil {
                let callout = screenCallout
                AtlasCallout(
                    title: callout.title,
                    detail: callout.detail,
                    tone: callout.tone,
                    systemImage: callout.systemImage
                )
            }

            inventoryCard

            browserCard
        }
        .onAppear(perform: syncSelection)
        .onChange(of: sortedAppIDs) { _, _ in syncSelection() }
        .confirmationDialog(
            AtlasL10n.string("apps.confirm.uninstall.title"),
            isPresented: $showUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button(AtlasL10n.string("apps.uninstall.action"), role: .destructive) {
                if let id = selectedApp?.id { onExecuteAppUninstall(id) }
            }
            Button(AtlasL10n.string("confirm.cancel"), role: .cancel) {}
        } message: {
            if let app = selectedApp {
                Text(AtlasL10n.string("apps.confirm.uninstall.message", app.name))
            }
        }
    }

    // MARK: - Inventory

    private var inventoryCard: some View {
        AtlasInfoCard(
            title: AtlasL10n.string("apps.inventory.title"),
            subtitle: AtlasL10n.string("apps.inventory.subtitle")
        ) {
            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                Text(summary)
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: inventoryMetricColumns, spacing: AtlasSpacing.lg) {
                    AtlasMetricCard(
                        title: AtlasL10n.string("apps.metric.listed.title"),
                        value: "\(sortedApps.count)",
                        detail: AtlasL10n.string("apps.metric.listed.detail"),
                        tone: .neutral,
                        systemImage: "square.stack.3d.up"
                    )
                    AtlasMetricCard(
                        title: AtlasL10n.string("apps.metric.footprint.title"),
                        value: AtlasFormatters.byteCount(sortedApps.map(\.bytes).reduce(0, +)),
                        detail: AtlasL10n.string("apps.metric.footprint.detail"),
                        tone: .warning,
                        systemImage: "shippingbox"
                    )
                    AtlasMetricCard(
                        title: AtlasL10n.string("apps.metric.leftovers.title"),
                        value: "\(sortedApps.map(\.leftoverItems).reduce(0, +))",
                        detail: AtlasL10n.string("apps.metric.leftovers.detail"),
                        tone: .warning,
                        systemImage: "tray.full"
                    )
                }

                Button(action: onRefreshApps) {
                    Label(isRunning ? AtlasL10n.string("apps.refresh.running") : AtlasL10n.string("apps.refresh.action"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.atlasSecondary)
                .disabled(isRunning)
                .accessibilityIdentifier("apps.refresh")
                .accessibilityHint(AtlasL10n.string("apps.refresh.hint"))
            }
        }
    }

    // MARK: - Browser (list + evidence panel)

    private var browserCard: some View {
        AtlasInfoCard(
            title: AtlasL10n.string("apps.browser.title"),
            subtitle: AtlasL10n.string("apps.browser.subtitle"),
            tone: selectedAppMatchingPreview == nil ? .neutral : .warning
        ) {
            Group {
                if isWideBrowserLayout {
                    HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                        listPanel.frame(width: sidebarWidth)
                            .frame(maxHeight: .infinity)
                        evidencePanel.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                        listPanel.frame(minHeight: 240, idealHeight: 320, maxHeight: 400)
                        evidencePanel.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: isWideBrowserLayout ? 460 : nil, alignment: .topLeading)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: BrowserWidthKey.self, value: proxy.size.width)
                }
            )
            .onPreferenceChange(BrowserWidthKey.self) { newWidth in
                if newWidth > 0 { browserWidth = newWidth }
            }
        }
    }

    private var listPanel: some View {
        AppsListView(
            apps: sortedApps,
            selectedAppID: $selectedAppID,
            showLeftoversOnly: showLeftoversOnly,
            onToggleLeftoversFilter: { showLeftoversOnly.toggle() },
            leftoversCount: Self.sortedApps(apps).filter { $0.leftoverItems > 0 }.count,
            onRefresh: onRefreshApps,
            isRunning: isRunning
        )
    }

    private var evidencePanel: some View {
        AtlasEvidencePanel(state: evidenceState) {
            if let status = selectedAppRestoreRefreshStatus {
                AppsRestoreRefreshSection(status: status, isRunning: isRunning) {
                    if let id = selectedApp?.id { onRescanLeftovers(id) }
                }
            }
        }
    }

    // MARK: - Action bar

    @ViewBuilder
    private var actionBar: some View {
        if AppsEvidencePanelBuilder.shouldShowActionBar(
            selectedApp: selectedApp,
            previewPlan: previewPlan,
            currentPreviewedAppID: currentPreviewedAppID
        ) {
            AppsActionBar(
                selectedApp: selectedApp,
                previewPlan: previewPlan,
                isRunning: isRunning,
                activePreviewAppID: activePreviewAppID,
                activeUninstallAppID: activeUninstallAppID,
                retentionDays: retentionDays,
                onPrimary: { handlePrimaryAction() }
            )
        }
    }

    /// Uninstall flow behavior unchanged (spec red line):
    /// - No plan yet → `onPreviewAppUninstall` (build/refresh the preview).
    /// - Plan ready → confirm dialog → `onExecuteAppUninstall` (execute).
    private func handlePrimaryAction() {
        guard let app = selectedApp else { return }
        if previewPlan != nil {
            showUninstallConfirmation = true
        } else {
            onPreviewAppUninstall(app.id)
        }
    }

    // MARK: - Derived

    private var evidenceState: AtlasEvidenceState {
        AppsEvidencePanelBuilder.panelState(
            app: selectedApp,
            previewPlan: selectedAppMatchingPreview,
            retentionDays: retentionDays
        )
    }

    private var sortedApps: [AppFootprint] {
        let all = Self.sortedApps(apps)
        return showLeftoversOnly ? all.filter { $0.leftoverItems > 0 } : all
    }

    private var sortedAppIDs: [UUID] { sortedApps.map(\.id) }

    private var selectedApp: AppFootprint? {
        guard let selectedAppID else { return nil }
        return sortedApps.first(where: { $0.id == selectedAppID })
    }

    private var selectedAppMatchingPreview: ActionPlan? {
        guard currentPreviewedAppID == selectedApp?.id else { return nil }
        return previewPlan
    }

    private var selectedAppRestoreRefreshStatus: AtlasAppPostRestoreRefreshStatus? {
        guard let selectedApp, let restoreRefreshStatus else { return nil }
        guard restoreRefreshStatus.bundlePath == selectedApp.bundlePath
            || restoreRefreshStatus.bundleIdentifier == selectedApp.bundleIdentifier else { return nil }
        return restoreRefreshStatus
    }

    private var effectiveBrowserWidth: CGFloat {
        max(browserWidth ?? contentWidth, 0)
    }

    private var isWideBrowserLayout: Bool {
        effectiveBrowserWidth >= AtlasLayout.browserSplitThreshold
    }

    private var sidebarWidth: CGFloat {
        min(max(effectiveBrowserWidth * 0.3, 220), 280)
    }

    private var inventoryMetricColumns: [GridItem] {
        AtlasLayout.adaptiveMetricColumns(for: contentWidth)
    }

    // MARK: - Screen callout

    private var screenCallout: (title: String, detail: String, tone: AtlasTone, systemImage: String) {
        if let restoreRefreshStatus {
            let s = restoreRefreshStatus.state
            return (s.calloutTitle, s.calloutDetail(status: restoreRefreshStatus), s.tone, s.systemImage)
        }
        if previewPlan == nil {
            return (
                AtlasL10n.string("apps.callout.default.title"),
                AtlasL10n.string("apps.callout.default.detail"),
                .neutral,
                "app.badge.minus"
            )
        }
        return (
            AtlasL10n.string("apps.callout.preview.title"),
            AtlasL10n.string("apps.callout.preview.detail"),
            .warning,
            "list.clipboard.fill"
        )
    }

    private func syncSelection() {
        if selectedApp == nil { selectedAppID = sortedApps.first?.id }
    }

    private static func sortedApps(_ apps: [AppFootprint]) -> [AppFootprint] {
        AppsListView.sortedApps(apps)
    }
}

// MARK: - Restore refresh UI mapping
// The `AtlasAppPostRestoreRefreshState` presentation mapping lives in
// AppsRestoreRefreshUIMapping.swift (pure localization/tone logic, kept out of
// this view file for the 350-line feature-view discipline).

private struct BrowserWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
