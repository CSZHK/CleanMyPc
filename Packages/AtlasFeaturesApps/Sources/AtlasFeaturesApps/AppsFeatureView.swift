import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct AppsFeatureView: View {
    private let apps: [AppFootprint]
    private let previewPlan: ActionPlan?
    private let currentPreviewedAppID: UUID?
    private let summary: String
    private let isRunning: Bool
    private let activePreviewAppID: UUID?
    private let activeUninstallAppID: UUID?
    private let onRefreshApps: () -> Void
    private let onPreviewAppUninstall: (UUID) -> Void
    private let onExecuteAppUninstall: (UUID) -> Void

    @State private var selectedAppID: UUID?

    public init(
        apps: [AppFootprint] = AtlasScaffoldFixtures.apps,
        previewPlan: ActionPlan? = nil,
        currentPreviewedAppID: UUID? = nil,
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
            subtitle: AtlasL10n.string("apps.screen.subtitle")
        ) {
            AtlasCallout(
                title: previewPlan == nil ? AtlasL10n.string("apps.callout.default.title") : AtlasL10n.string("apps.callout.preview.title"),
                detail: previewPlan == nil
                    ? AtlasL10n.string("apps.callout.default.detail")
                    : AtlasL10n.string("apps.callout.preview.detail"),
                tone: previewPlan == nil ? .neutral : .warning,
                systemImage: previewPlan == nil ? "app.badge.minus" : "list.clipboard.fill"
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

                    LazyVGrid(columns: AtlasLayout.metricColumns, spacing: AtlasSpacing.lg) {
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
                GeometryReader { proxy in
                    let isWide = proxy.size.width >= 760
                    let sidebarWidth = min(max(proxy.size.width * 0.32, 260), 300)

                    Group {
                        if isWide {
                            HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                                appsSidebar
                                    .frame(width: sidebarWidth)
                                    .frame(maxHeight: .infinity)

                                appDetailPanel
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                                appsSidebar
                                    .frame(minHeight: 260, maxHeight: 260)

                                appDetailPanel
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(height: 560)
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
                    tone: .neutral
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

            ScrollView {
                if let selectedApp {
                    AppDetailView(
                        app: selectedApp,
                        previewPlan: selectedAppMatchingPreview,
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AtlasSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
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
    let isBuildingPreview: Bool
    let isUninstalling: Bool
    let isBusy: Bool
    let onPreview: () -> Void
    let onUninstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            HStack(alignment: .top, spacing: AtlasSpacing.lg) {
                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    Text(app.name)
                        .font(AtlasTypography.sectionTitle)

                    Text(app.bundleIdentifier)
                        .font(AtlasTypography.body)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: AtlasSpacing.lg)

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
                AtlasKeyValueRow(
                    title: AtlasL10n.string("apps.detail.path"),
                    value: app.bundlePath,
                    detail: app.bucket.title
                )
            }

            if let previewPlan {
                AtlasInfoCard(
                    title: AtlasL10n.string("apps.preview.title"),
                    subtitle: previewPlan.title,
                    tone: .warning
                ) {
                    LazyVGrid(columns: AtlasLayout.metricColumns, spacing: AtlasSpacing.lg) {
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
                            value: "\(previewPlan.items.filter(\.recoverable).count)",
                            detail: AtlasL10n.string("apps.preview.metric.recoverable.detail"),
                            tone: .success,
                            systemImage: "arrow.uturn.backward.circle"
                        )
                    }

                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ForEach(previewPlan.items) { item in
                            AtlasDetailRow(
                                title: item.title,
                                subtitle: item.detail,
                                footnote: item.recoverable ? AtlasL10n.string("apps.preview.row.recoverable") : AtlasL10n.string("apps.preview.row.review"),
                                systemImage: icon(for: item.kind),
                                tone: item.recoverable ? .success : .warning
                            ) {
                                AtlasStatusChip(
                                    item.recoverable ? AtlasL10n.string("common.recoverable") : AtlasL10n.string("common.manualReview"),
                                    tone: item.recoverable ? .success : .warning
                                )
                            }
                        }
                    }
                }
            }

            HStack(alignment: .center, spacing: AtlasSpacing.md) {
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

                Button(isUninstalling ? AtlasL10n.string("apps.uninstall.running") : AtlasL10n.string("apps.uninstall.action")) {
                    onUninstall()
                }
                .buttonStyle(.atlasPrimary)
                .disabled(isBusy || previewPlan == nil)
                .accessibilityIdentifier("apps.uninstall.\(app.id.uuidString)")
                .accessibilityHint(AtlasL10n.string("apps.uninstall.hint"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func icon(for kind: ActionItem.Kind) -> String {
        switch kind {
        case .removeCache:
            return "trash"
        case .removeApp:
            return "app.badge.minus"
        case .archiveFile:
            return "archivebox"
        case .inspectPermission:
            return "lock.shield"
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
