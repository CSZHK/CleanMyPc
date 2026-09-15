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
    /// 契约一（规格 §1.2(1)）：Apps 屏**只订阅自己 source 的结果**。
    ///
    /// `F-07`：`restoreRecoveryItemCore` 把 apps 恢复的摘要写进了
    /// `.apps` 的执行槽（`AtlasAppModel.swift:1134`），但全仓**零读取点** ——
    /// 原先可见的 `latestAppsSummary` 摘要就此变成不可见。本参数把它接回渲染。
    /// `.succeeded` 不渲染（避免与 `summary` 状态行重复），`.failed` 走
    /// `AtlasErrorState`、`.advisory`/`.unavailable` 走非错误态 —— 与规格 §1.2(1)
    /// 「保留既有渲染形态」一致。
    private let outcome: AtlasActionOutcome?
    private let isRunning: Bool
    private let activePreviewAppID: UUID?
    private let activeUninstallAppID: UUID?
    private let onRefreshApps: () -> Void
    private let onPreviewAppUninstall: (UUID) -> Void
    private let onExecuteAppUninstall: (UUID) -> Void
    private let onRescanLeftovers: (UUID) -> Void
    private let onSelectionChange: (UUID?) -> Void

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
        outcome: AtlasActionOutcome? = nil,
        isRunning: Bool = false,
        activePreviewAppID: UUID? = nil,
        activeUninstallAppID: UUID? = nil,
        onRefreshApps: @escaping () -> Void = {},
        onPreviewAppUninstall: @escaping (UUID) -> Void = { _ in },
        onExecuteAppUninstall: @escaping (UUID) -> Void = { _ in },
        onRescanLeftovers: @escaping (UUID) -> Void = { _ in },
        initialSelectedAppID: UUID? = nil,
        onSelectionChange: @escaping (UUID?) -> Void = { _ in }
    ) {
        self.apps = apps
        self.previewPlan = previewPlan
        self.currentPreviewedAppID = currentPreviewedAppID
        self.restoreRefreshStatus = restoreRefreshStatus
        self.summary = summary
        self.outcome = outcome
        self.isRunning = isRunning
        self.activePreviewAppID = activePreviewAppID
        self.activeUninstallAppID = activeUninstallAppID
        self.onRefreshApps = onRefreshApps
        self.onPreviewAppUninstall = onPreviewAppUninstall
        self.onExecuteAppUninstall = onExecuteAppUninstall
        self.onRescanLeftovers = onRescanLeftovers
        self.onSelectionChange = onSelectionChange
        // Retention window is a fixed Atlas default (14d) — Apps does not yet
        // carry its own retention field; mirroring the legacy detail copy.
        self.retentionDays = 14
        // Seed from the model-persisted selection so it survives route switches
        // (round-14 §7 red line — mirrors the Ledger pattern).
        //
        // `P2-10`：**不再回退到第一个应用**。此前 `?? Self.sortedApps(apps).first?.id`
        // 让用户一进屏就看到 Xcode 被高亮选中、右侧证据面板铺满它的足迹，而列表
        // 副标题写的是「**选择一个**应用」—— 用户从没选过。对不懂技术的用户，
        // 「已经被选中」天然带推荐含义（像 Atlas 在建议卸载它）。
        _selectedAppID = State(initialValue: initialSelectedAppID)
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
        .onAppear {
            syncSelection()
            onSelectionChange(selectedAppID) // persist resolved selection (round-14 §7)
        }
        .onChange(of: sortedAppIDs) { _, _ in syncSelection() }
        .onChange(of: selectedAppID) { _, _ in onSelectionChange(selectedAppID) }
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
            AtlasDestructiveConfirmationMessage(uninstallConfirmation)
        }
    }

    /// 契约二 §2.2(1) 四问（`P0-3`）：这是全产品唯一真正删掉应用包的最终确认，
    /// 此前正文对「能不能找回、多久内、从哪儿找」**只字未提**。
    private var uninstallConfirmation: AtlasDestructiveConfirmation {
        let items = previewPlan?.items ?? []
        let total = items.count
        let recoverable = items.filter(\.recoverable).count
        let facts = AtlasDestructiveFacts(
            object: AtlasL10n.string("confirm.destructive.object.app", selectedApp?.name ?? ""),
            destination: AtlasL10n.string("confirm.destructive.destination.recoveryArea", retentionDays),
            recovery: recoverable > 0
                ? AtlasL10n.string("confirm.destructive.recovery", retentionDays)
                : AtlasL10n.string("confirm.destructive.recovery.none")
        )
        return .recoverable(
            facts,
            recoverableCount: AtlasL10n.string("confirm.destructive.recoverableCount", recoverable, total)
        )
    }

    // MARK: - 契约一 §1.2(1)：本 source 的结果就地呈现

    /// `F-07` 的落点：把 `.apps` source 的执行结果接回渲染。
    ///
    /// **只渲染非 `.succeeded`**：`.succeeded` 的摘要已由 `refreshApps` 之后的
    /// `summary` 状态行承载（`latestAppsSummary = output.summary`），再渲染一遍
    /// 就是同一句话出现两次。真正会丢的是**失败**：恢复**失败**时
    /// `restoreRecoveryItemCore` 只把错误写进本槽，而 `reloadAppsInventory`
    /// 根本不会被调用（见 `AtlasAppModel.swift` 的 catch 分支），
    /// 于是 `summary` 仍停在上一轮的乐观值 —— 用户看到「一切正常」。
    @ViewBuilder
    private var actionOutcomeBanner: some View {
        if let outcome, !outcome.isSuccess {
            if outcome.isError {
                AtlasErrorState(
                    title: AtlasL10n.string("apps.outcome.failed.title"),
                    message: outcome.message,
                    layout: .inlineRow
                )
                .accessibilityIdentifier("apps.outcome.failed")
            } else {
                AtlasCallout(
                    title: AtlasL10n.string("apps.outcome.advisory.title"),
                    detail: outcome.message,
                    tone: .warning,
                    systemImage: "exclamationmark.triangle"
                )
                .accessibilityIdentifier("apps.outcome.advisory")
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

                actionOutcomeBanner

                LazyVGrid(columns: inventoryMetricColumns, spacing: AtlasSpacing.lg) {
                    // Round-21: inventory totals are SCREEN-LEVEL aggregates, so they
                    // read the unfiltered `allSortedApps` — not the filter-narrowed
                    // `sortedApps`. Toggling "leftovers only" must not shrink
                    // Listed/Footprint/Leftovers (it previously did, and diverged
                    // from the chip count in `listPanel` which already uses the
                    // unfiltered set).
                    AtlasMetricCard(
                        title: AtlasL10n.string("apps.metric.listed.title"),
                        value: "\(allSortedApps.count)",
                        detail: AtlasL10n.string("apps.metric.listed.detail"),
                        tone: .neutral,
                        systemImage: "square.stack.3d.up"
                    )
                    AtlasMetricCard(
                        title: AtlasL10n.string("apps.metric.footprint.title"),
                        value: AtlasFormatters.byteCount(allSortedApps.map(\.bytes).reduce(0, +)),
                        detail: AtlasL10n.string("apps.metric.footprint.detail"),
                        tone: .warning,
                        systemImage: "shippingbox"
                    )
                    AtlasMetricCard(
                        title: AtlasL10n.string("apps.metric.leftovers.title"),
                        value: "\(allSortedApps.map(\.leftoverItems).reduce(0, +))",
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

    /// All apps, sorted, ignoring the leftovers-only filter. Screen-level
    /// aggregates (the inventory card) read this so a transient filter never
    /// changes the totals (round-21 — mirrors the chip count in `listPanel`).
    private var allSortedApps: [AppFootprint] { Self.sortedApps(apps) }

    private var sortedAppIDs: [UUID] { sortedApps.map(\.id) }

    private var selectedApp: AppFootprint? {
        guard let selectedAppID else { return nil }
        // Resolve against the FULL unfiltered set, not the filter-narrowed list,
        // so toggling "leftovers only" doesn't clobber a selected app that has
        // no leftovers — the evidence panel keeps showing it; the list just
        // shows no row highlight under the filter (mirrors the Ledger round-9
        // fix; syncSelection then only auto-selects when the id is genuinely
        // absent from all apps).
        return Self.sortedApps(apps).first(where: { $0.id == selectedAppID })
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
        // `P2-10`：此处**不再**自动选中第一个应用（同一个缺陷的第二处写入点）。
        // 没有选中项就让它空着 —— 右侧面板如实显示空态，与列表副标题
        // 「选择一个应用」一致。原来那行 `if selectedApp == nil { … .first?.id }`
        // 已删除；取代它的"列表为空时清空"是空操作，一并去掉。
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
