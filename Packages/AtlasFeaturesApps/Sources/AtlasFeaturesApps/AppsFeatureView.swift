import AtlasDesignSystem
import AtlasDomain
import SwiftUI

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

    @State private var selectedAppID: UUID?
    @State private var browserWidth: CGFloat?

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
        onExecuteAppUninstall: @escaping (UUID) -> Void = { _ in }
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
        _selectedAppID = State(initialValue: Self.sortedApps(apps).first?.id)
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("apps.screen.title"),
            subtitle: AtlasL10n.string("apps.screen.subtitle"),
            maxContentWidth: AtlasLayout.maxWorkspaceWidth
        ) {
            AtlasCallout(
                title: screenCalloutTitle,
                detail: screenCalloutDetail,
                tone: screenCalloutTone,
                systemImage: screenCalloutSystemImage
            )

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

            AtlasInfoCard(
                title: AtlasL10n.string("apps.browser.title"),
                subtitle: AtlasL10n.string("apps.browser.subtitle"),
                tone: selectedAppMatchingPreview == nil ? .neutral : .warning
            ) {
                Group {
                    if isWideBrowserLayout {
                        HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                            appsSidebar
                                .frame(width: sidebarWidth)
                                .frame(maxHeight: .infinity)

                            appDetailPanel
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                            appsSidebar
                                .frame(minHeight: 240, idealHeight: 320, maxHeight: 400)

                            appDetailPanel
                                .frame(maxWidth: .infinity)
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
                    if newWidth > 0 {
                        browserWidth = newWidth
                    }
                }
            }
        }
        .onAppear(perform: syncSelection)
        .onChange(of: sortedAppIDs) { _, _ in
            syncSelection()
        }
    }

    private var sortedApps: [AppFootprint] {
        Self.sortedApps(apps)
    }

    private var sortedAppIDs: [UUID] {
        sortedApps.map(\.id)
    }

    private var effectiveBrowserWidth: CGFloat {
        let measuredWidth = browserWidth ?? contentWidth
        return max(measuredWidth, 0)
    }

    private var isWideBrowserLayout: Bool {
        effectiveBrowserWidth >= AtlasLayout.browserSplitThreshold
    }

    private var sidebarWidth: CGFloat {
        min(max(effectiveBrowserWidth * 0.3, 220), 280)
    }

    private var detailMetricColumns: [GridItem] {
        let estimatedDetailWidth = isWideBrowserLayout
            ? max(effectiveBrowserWidth - sidebarWidth - AtlasSpacing.xl - (AtlasSpacing.xl * 2), 320)
            : effectiveBrowserWidth
        return AtlasLayout.adaptiveMetricColumns(for: estimatedDetailWidth)
    }

    private var inventoryMetricColumns: [GridItem] {
        AtlasLayout.adaptiveMetricColumns(for: contentWidth)
    }

    private var groupedApps: [AppGroup] {
        var groups: [AppGroup] = []
        let grouped = Dictionary(grouping: sortedApps, by: \.bucket)

        for bucket in AppBucket.displayOrder {
            guard let items = grouped[bucket], !items.isEmpty else {
                continue
            }
            groups.append(AppGroup(id: bucket.rawValue, title: bucket.title, tone: bucket.tone, apps: items))
        }

        return groups
    }

    private var selectedApp: AppFootprint? {
        guard let selectedAppID else {
            return nil
        }
        return sortedApps.first(where: { $0.id == selectedAppID })
    }

    private var selectedAppMatchingPreview: ActionPlan? {
        guard currentPreviewedAppID == selectedApp?.id else {
            return nil
        }
        return previewPlan
    }

    private var selectedAppRestoreRefreshStatus: AtlasAppPostRestoreRefreshStatus? {
        guard let selectedApp, let restoreRefreshStatus else {
            return nil
        }
        guard restoreRefreshStatus.bundlePath == selectedApp.bundlePath
            || restoreRefreshStatus.bundleIdentifier == selectedApp.bundleIdentifier else {
            return nil
        }
        return restoreRefreshStatus
    }

    private var screenCalloutTitle: String {
        guard let restoreRefreshStatus else {
            return previewPlan == nil
                ? AtlasL10n.string("apps.callout.default.title")
                : AtlasL10n.string("apps.callout.preview.title")
        }
        return restoreRefreshStatus.state.calloutTitle
    }

    private var screenCalloutDetail: String {
        guard let restoreRefreshStatus else {
            return previewPlan == nil
                ? AtlasL10n.string("apps.callout.default.detail")
                : AtlasL10n.string("apps.callout.preview.detail")
        }
        return restoreRefreshStatus.state.calloutDetail(status: restoreRefreshStatus)
    }

    private var screenCalloutTone: AtlasTone {
        guard let restoreRefreshStatus else {
            return previewPlan == nil ? .neutral : .warning
        }
        return restoreRefreshStatus.state.tone
    }

    private var screenCalloutSystemImage: String {
        guard let restoreRefreshStatus else {
            return previewPlan == nil ? "app.badge.minus" : "list.clipboard.fill"
        }
        return restoreRefreshStatus.state.systemImage
    }

    private var appsSidebar: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            Text(AtlasL10n.string("apps.list.title"))
                .font(AtlasTypography.label)
                .foregroundStyle(.secondary)

            if sortedApps.isEmpty {
                AtlasEmptyState(
                    title: AtlasL10n.string("apps.list.empty.title"),
                    detail: AtlasL10n.string("apps.list.empty.detail"),
                    systemImage: "square.stack.3d.up.slash",
                    tone: .neutral,
                    actionTitle: AtlasL10n.string("emptystate.action.refresh"),
                    onAction: onRefreshApps
                )
            } else {
                List(selection: $selectedAppID) {
                    ForEach(groupedApps) { group in
                        Section {
                            ForEach(group.apps) { app in
                                AppSidebarRow(app: app)
                                    .tag(app.id)
                                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                            }
                        } header: {
                            AppSidebarSectionHeader(title: group.title, count: group.apps.count, tone: group.tone)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AtlasSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.cardRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
    }

    private var appDetailPanel: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            Text(AtlasL10n.string("apps.detail.title"))
                .font(AtlasTypography.label)
                .foregroundStyle(.secondary)

            Group {
                ScrollView {
                    Group {
                        if let selectedApp {
                            AppDetailView(
                                app: selectedApp,
                                previewPlan: selectedAppMatchingPreview,
                                restoreRefreshStatus: selectedAppRestoreRefreshStatus,
                                metricColumns: detailMetricColumns,
                                isBuildingPreview: activePreviewAppID == selectedApp.id,
                                isUninstalling: activeUninstallAppID == selectedApp.id,
                                isBusy: isRunning,
                                onPreview: { onPreviewAppUninstall(selectedApp.id) },
                                onUninstall: { onExecuteAppUninstall(selectedApp.id) }
                            )
                        } else {
                            AtlasEmptyState(
                                title: AtlasL10n.string("apps.detail.empty.title"),
                                detail: AtlasL10n.string("apps.detail.empty.detail"),
                                systemImage: "cursorarrow.click",
                                tone: .neutral
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedAppID)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AtlasSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.cardRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
    }

    private func syncSelection() {
        if selectedApp == nil {
            selectedAppID = sortedApps.first?.id
        }
    }

    private static func sortedApps(_ apps: [AppFootprint]) -> [AppFootprint] {
        apps.sorted { lhs, rhs in
            if lhs.bytes == rhs.bytes {
                if lhs.leftoverItems == rhs.leftoverItems {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.leftoverItems > rhs.leftoverItems
            }
            return lhs.bytes > rhs.bytes
        }
    }
}

private struct AppSidebarRow: View {
    let app: AppFootprint

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                Image(systemName: "app.fill")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(app.leftoverItems > 0 ? AtlasColor.warning : AtlasColor.brand)
                    .accessibilityHidden(true)

                Text(app.name)
                    .font(AtlasTypography.rowTitle)
                    .lineLimit(1)

                Spacer(minLength: AtlasSpacing.sm)

                Text(AtlasFormatters.byteCount(app.bytes))
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Text(app.bundleIdentifier)
                .font(AtlasTypography.bodySmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                AtlasStatusChip(
                    AtlasL10n.string("apps.list.row.leftovers", app.leftoverItems),
                    tone: app.leftoverItems > 0 ? .warning : .success
                )

                Spacer(minLength: AtlasSpacing.sm)

                Text(app.bucket.title)
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AtlasSpacing.xxs)
        .accessibilityElement(children: .contain)
    }
}

private struct AppSidebarSectionHeader: View {
    let title: String
    let count: Int
    let tone: AtlasTone

    var body: some View {
        HStack(alignment: .center, spacing: AtlasSpacing.sm) {
            Text(title)
                .font(AtlasTypography.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: AtlasSpacing.sm)

            Text("\(count)")
                .font(AtlasTypography.captionSmall)
                .foregroundStyle(tone.tint)
        }
        .textCase(nil)
    }
}

private struct AppDetailView: View {
    let app: AppFootprint
    let previewPlan: ActionPlan?
    let restoreRefreshStatus: AtlasAppPostRestoreRefreshStatus?
    let metricColumns: [GridItem]
    let isBuildingPreview: Bool
    let isUninstalling: Bool
    let isBusy: Bool
    let onPreview: () -> Void
    let onUninstall: () -> Void

    @State private var showUninstallConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AtlasSpacing.lg) {
                    headerCopy
                    Spacer(minLength: AtlasSpacing.lg)
                    headerMeta
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                    headerCopy
                    headerMeta
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            AtlasCallout(
                title: previewPlan == nil
                    ? AtlasL10n.string("apps.detail.callout.preview.title")
                    : AtlasL10n.string("apps.detail.callout.ready.title"),
                detail: previewPlan == nil
                    ? AtlasL10n.string("apps.detail.callout.preview.detail")
                    : AtlasL10n.string("apps.detail.callout.ready.detail"),
                tone: previewPlan == nil ? .neutral : .warning,
                systemImage: previewPlan == nil ? "eye" : "checkmark.shield.fill"
            )

            VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                AtlasKeyValueRow(
                    title: AtlasL10n.string("apps.detail.size"),
                    value: AtlasFormatters.byteCount(app.bytes),
                    detail: AtlasL10n.string("apps.metric.footprint.detail")
                )
                AtlasKeyValueRow(
                    title: AtlasL10n.string("apps.detail.leftovers"),
                    value: "\(app.leftoverItems)",
                    detail: AtlasL10n.string("apps.metric.leftovers.detail")
                )
                AtlasMachineTextBlock(
                    title: AtlasL10n.string("apps.detail.path"),
                    value: app.bundlePath,
                    detail: app.bucket.title
                )
            }

            if let restoreRefreshStatus {
                AtlasInfoCard(
                    title: AtlasL10n.string("apps.restore.refresh.card.title"),
                    subtitle: AtlasL10n.string("apps.restore.refresh.card.subtitle"),
                    tone: restoreRefreshTone
                ) {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        AtlasCallout(
                            title: restoreRefreshTitle,
                            detail: restoreRefreshDetail,
                            tone: restoreRefreshTone,
                            systemImage: restoreRefreshSystemImage
                        )

                        AtlasKeyValueRow(
                            title: AtlasL10n.string("apps.restore.refresh.recorded.title"),
                            value: "\(restoreRefreshStatus.recordedLeftoverItems)",
                            detail: AtlasL10n.string("apps.restore.refresh.recorded.detail")
                        )

                        if let refreshedLeftoverItems = restoreRefreshStatus.refreshedLeftoverItems {
                            AtlasKeyValueRow(
                                title: AtlasL10n.string("apps.restore.refresh.current.title"),
                                value: "\(refreshedLeftoverItems)",
                                detail: AtlasL10n.string("apps.restore.refresh.current.detail")
                            )
                        }
                    }
                }
            }

            if let previewPlan {
                let recoverableItems = previewPlan.items.filter(\.recoverable)
                let reviewOnlyItems = previewPlan.items.filter { !$0.recoverable }
                AtlasInfoCard(
                    title: AtlasL10n.string("apps.preview.title"),
                    subtitle: previewPlan.title,
                    tone: .warning
                ) {
                    LazyVGrid(columns: metricColumns, spacing: AtlasSpacing.lg) {
                        AtlasMetricCard(
                            title: AtlasL10n.string("apps.preview.metric.size.title"),
                            value: AtlasFormatters.byteCount(previewPlan.estimatedBytes),
                            detail: AtlasL10n.string("apps.preview.metric.size.detail"),
                            tone: .warning,
                            systemImage: "shippingbox"
                        )
                        AtlasMetricCard(
                            title: AtlasL10n.string("apps.preview.metric.actions.title"),
                            value: "\(previewPlan.items.count)",
                            detail: AtlasL10n.string("apps.preview.metric.actions.detail"),
                            tone: .neutral,
                            systemImage: "list.bullet.rectangle"
                        )
                        AtlasMetricCard(
                            title: AtlasL10n.string("apps.preview.metric.recoverable.title"),
                            value: "\(recoverableItems.count)",
                            detail: AtlasL10n.string("apps.preview.metric.recoverable.detail"),
                            tone: .success,
                            systemImage: "arrow.uturn.backward.circle"
                        )
                        AtlasMetricCard(
                            title: AtlasL10n.string("apps.preview.metric.reviewOnly.title"),
                            value: "\(reviewOnlyItems.count)",
                            detail: AtlasL10n.string("apps.preview.metric.reviewOnly.detail"),
                            tone: reviewOnlyItems.isEmpty ? .neutral : .warning,
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }

                    AtlasCallout(
                        title: AtlasL10n.string(
                            reviewOnlyItems.isEmpty
                                ? "apps.preview.callout.safe.title"
                                : "apps.preview.callout.review.title"
                        ),
                        detail: AtlasL10n.string(
                            reviewOnlyItems.isEmpty
                                ? "apps.preview.callout.safe.detail"
                                : "apps.preview.callout.review.detail"
                        ),
                        tone: reviewOnlyItems.isEmpty ? .success : .warning,
                        systemImage: reviewOnlyItems.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )

                    if !recoverableItems.isEmpty {
                        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                            ForEach(recoverableItems) { item in
                                AtlasDetailRow(
                                    title: item.title,
                                    subtitle: item.detail,
                                    footnote: AtlasL10n.string("apps.preview.row.recoverable"),
                                    systemImage: item.kind.atlasSystemImage,
                                    tone: .success
                                ) {
                                    AtlasStatusChip(
                                        AtlasL10n.string("common.recoverable"),
                                        tone: .success
                                    )
                                }
                            }
                        }
                    }

                    if !reviewOnlyItems.isEmpty {
                        AtlasInfoCard(
                            title: AtlasL10n.string("apps.preview.reviewOnly.title"),
                            subtitle: AtlasL10n.string(
                                reviewOnlyItems.count == 1
                                    ? "apps.preview.reviewOnly.subtitle.one"
                                    : "apps.preview.reviewOnly.subtitle.other",
                                reviewOnlyItems.count
                            ),
                            tone: .neutral
                        ) {
                            VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                                ForEach(reviewOnlyItems) { item in
                                    VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                                        AtlasDetailRow(
                                            title: item.title,
                                            subtitle: item.detail,
                                            footnote: AtlasL10n.string("apps.preview.reviewOnly.footnote"),
                                            systemImage: item.kind.atlasSystemImage,
                                            tone: .neutral
                                        ) {
                                            AtlasStatusChip(
                                                AtlasL10n.string("common.manualReview"),
                                                tone: .warning
                                            )
                                        }

                                        if let evidencePaths = item.evidencePaths, !evidencePaths.isEmpty {
                                            AtlasMachineTextBlock(
                                                title: AtlasL10n.string("apps.preview.reviewOnly.paths.title"),
                                                value: evidencePaths.joined(separator: "\n"),
                                                detail: AtlasL10n.string(
                                                    evidencePaths.count == 1
                                                        ? "apps.preview.reviewOnly.paths.detail.one"
                                                        : "apps.preview.reviewOnly.paths.detail.other",
                                                    evidencePaths.count
                                                )
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: AtlasSpacing.md) {
                    previewButton
                    uninstallButton
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                    previewButton
                    uninstallButton
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            Text(app.name)
                .font(AtlasTypography.sectionTitle)

            Text(app.bundleIdentifier)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerMeta: some View {
        VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
            Text(AtlasFormatters.byteCount(app.bytes))
                .font(AtlasTypography.cardMetric)
                .foregroundStyle(.primary)

            AtlasStatusChip(
                AtlasL10n.string("apps.list.row.leftovers", app.leftoverItems),
                tone: app.leftoverItems > 0 ? .warning : .success
            )
        }
    }

    private var previewButton: some View {
        Group {
            if previewPlan == nil {
                Button(isBuildingPreview ? AtlasL10n.string("apps.preview.running") : AtlasL10n.string("apps.preview.action")) {
                    onPreview()
                }
                .buttonStyle(.atlasPrimary)
            } else {
                Button(isBuildingPreview ? AtlasL10n.string("apps.preview.running") : AtlasL10n.string("apps.preview.action")) {
                    onPreview()
                }
                .buttonStyle(.atlasSecondary)
            }
        }
        .disabled(isBusy)
        .accessibilityIdentifier("apps.preview.\(app.id.uuidString)")
        .accessibilityHint(AtlasL10n.string("apps.preview.hint"))
    }

    private var uninstallButton: some View {
        Button(isUninstalling ? AtlasL10n.string("apps.uninstall.running") : AtlasL10n.string("apps.uninstall.action")) {
            showUninstallConfirmation = true
        }
        .buttonStyle(.atlasPrimary)
        .disabled(isBusy || previewPlan == nil)
        .accessibilityIdentifier("apps.uninstall.\(app.id.uuidString)")
        .accessibilityHint(AtlasL10n.string("apps.uninstall.hint"))
        .confirmationDialog(
            AtlasL10n.string("apps.confirm.uninstall.title"),
            isPresented: $showUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button(AtlasL10n.string("apps.uninstall.action"), role: .destructive) {
                onUninstall()
            }
            Button(AtlasL10n.string("confirm.cancel"), role: .cancel) {}
        } message: {
            Text(AtlasL10n.string("apps.confirm.uninstall.message", app.name))
        }
    }

    private var restoreRefreshTitle: String {
        if let state = restoreRefreshStatus?.state {
            return state.calloutTitle
        }
        return AtlasL10n.string("apps.restore.refresh.card.title")
    }

    private var restoreRefreshDetail: String {
        guard let restoreRefreshStatus else {
            return AtlasL10n.string("apps.restore.refresh.card.subtitle")
        }
        return restoreRefreshStatus.state.calloutDetail(status: restoreRefreshStatus)
    }

    private var restoreRefreshTone: AtlasTone {
        restoreRefreshStatus?.state.tone ?? .neutral
    }

    private var restoreRefreshSystemImage: String {
        restoreRefreshStatus?.state.systemImage ?? "arrow.triangle.2.circlepath"
    }

}

// MARK: - Shared Restore Refresh UI Mapping

extension AtlasAppPostRestoreRefreshState {
    var calloutTitle: String {
        switch self {
        case .refreshing: return AtlasL10n.string("apps.restore.refresh.pending.title")
        case .refreshed:  return AtlasL10n.string("apps.restore.refresh.refreshed.title")
        case .stale:      return AtlasL10n.string("apps.restore.refresh.stale.title")
        }
    }

    func calloutDetail(status: AtlasAppPostRestoreRefreshStatus) -> String {
        switch self {
        case .refreshing:
            return AtlasL10n.string("apps.restore.refresh.pending.detail", status.appName)
        case .refreshed:
            return AtlasL10n.string(
                "apps.restore.refresh.refreshed.detail",
                status.appName,
                status.refreshedLeftoverItems ?? 0,
                status.recordedLeftoverItems
            )
        case .stale:
            return AtlasL10n.string(
                "apps.restore.refresh.stale.detail",
                status.appName,
                status.recordedLeftoverItems
            )
        }
    }

    var tone: AtlasTone {
        switch self {
        case .refreshing: return .neutral
        case .refreshed:  return .success
        case .stale:      return .warning
        }
    }

    var systemImage: String {
        switch self {
        case .refreshing: return "arrow.triangle.2.circlepath"
        case .refreshed:  return "checkmark.arrow.trianglehead.clockwise"
        case .stale:      return "exclamationmark.arrow.trianglehead.clockwise"
        }
    }
}

private struct AppGroup: Identifiable {
    let id: String
    let title: String
    let tone: AtlasTone
    let apps: [AppFootprint]
}

private enum AppBucket: String, CaseIterable {
    case large
    case leftovers
    case other

    static let displayOrder: [AppBucket] = [.large, .leftovers, .other]

    var title: String {
        switch self {
        case .large:
            return AtlasL10n.string("apps.group.large")
        case .leftovers:
            return AtlasL10n.string("apps.group.leftovers")
        case .other:
            return AtlasL10n.string("apps.group.other")
        }
    }

    var tone: AtlasTone {
        switch self {
        case .large:
            return .warning
        case .leftovers:
            return .neutral
        case .other:
            return .success
        }
    }
}

private extension AppFootprint {
    var bucket: AppBucket {
        if bytes >= 2_000_000_000 {
            return .large
        }
        if leftoverItems > 0 {
            return .leftovers
        }
        return .other
    }
}

private struct BrowserWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
