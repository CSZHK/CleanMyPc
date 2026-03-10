import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct HistoryFeatureView: View {
    private let taskRuns: [TaskRun]
    private let recoveryItems: [RecoveryItem]
    private let restoringItemID: UUID?
    private let onRestoreItem: (UUID) -> Void

    @State private var selectedSection: HistoryBrowserSection
    @State private var selectedTaskRunID: UUID?
    @State private var selectedRecoveryItemID: UUID?
    @State private var selectedRecoveryFilter: HistoryRecoveryFilter = .all
    @State private var isOlderArchiveExpanded = false

    public init(
        taskRuns: [TaskRun] = AtlasScaffoldFixtures.taskRuns,
        recoveryItems: [RecoveryItem] = AtlasScaffoldFixtures.recoveryItems,
        restoringItemID: UUID? = nil,
        onRestoreItem: @escaping (UUID) -> Void = { _ in }
    ) {
        self.taskRuns = taskRuns
        self.recoveryItems = recoveryItems
        self.restoringItemID = restoringItemID
        self.onRestoreItem = onRestoreItem

        let sortedTaskRuns = Self.sortTaskRuns(taskRuns)
        let sortedRecoveryItems = Self.sortRecoveryItems(recoveryItems)
        _selectedSection = State(initialValue: Self.initialSection(taskRuns: sortedTaskRuns, recoveryItems: sortedRecoveryItems))
        _selectedTaskRunID = State(initialValue: sortedTaskRuns.first?.id)
        _selectedRecoveryItemID = State(initialValue: sortedRecoveryItems.first?.id)
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("history.screen.title"),
            subtitle: AtlasL10n.string("history.screen.subtitle")
        ) {
            AtlasCallout(
                title: screenCalloutTitle,
                detail: screenCalloutDetail,
                tone: screenCalloutTone,
                systemImage: screenCalloutSystemImage
            )

            LazyVGrid(columns: AtlasLayout.metricColumns, spacing: AtlasSpacing.lg) {
                AtlasMetricCard(
                    title: AtlasL10n.string("history.metric.activity.title"),
                    value: "\(visibleEventCount)",
                    detail: activityMetricDetail,
                    tone: .neutral,
                    systemImage: "clock.arrow.circlepath"
                )
                AtlasMetricCard(
                    title: AtlasL10n.string("history.metric.running.title"),
                    value: "\(activeTaskCount)",
                    detail: activeTaskCount == 0
                        ? AtlasL10n.string("history.metric.running.detail.none")
                        : AtlasL10n.string("history.metric.running.detail.active"),
                    tone: activeTaskCount == 0 ? .success : .warning,
                    systemImage: activeTaskCount == 0 ? "checkmark.circle" : "play.circle"
                )
                AtlasMetricCard(
                    title: AtlasL10n.string("history.metric.recovery.title"),
                    value: "\(sortedRecoveryItems.count)",
                    detail: sortedRecoveryItems.isEmpty
                        ? AtlasL10n.string("history.metric.recovery.detail.none")
                        : AtlasL10n.string("history.metric.recovery.detail.available", AtlasFormatters.byteCount(totalRecoveryBytes)),
                    tone: sortedRecoveryItems.isEmpty ? .neutral : recoverySummaryTone,
                    systemImage: sortedRecoveryItems.isEmpty ? "lifepreserver" : "arrow.uturn.backward.circle"
                )
            }

            AtlasInfoCard(
                title: AtlasL10n.string("history.browser.title"),
                subtitle: AtlasL10n.string("history.browser.subtitle"),
                tone: browserTone
            ) {
                VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                    HStack(alignment: .center, spacing: AtlasSpacing.lg) {
                        Picker("", selection: $selectedSection) {
                            ForEach(HistoryBrowserSection.allCases) { section in
                                Text(section.title).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                        .accessibilityIdentifier("history.sectionPicker")

                        Spacer(minLength: AtlasSpacing.lg)

                        Text(browserSummary)
                            .font(AtlasTypography.bodySmall)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { proxy in
                        let isWide = proxy.size.width >= 760
                        let sidebarWidth = min(max(proxy.size.width * 0.32, 250), 290)

                        Group {
                            if isWide {
                                HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                                    browserSidebar
                                        .frame(width: sidebarWidth)
                                        .frame(maxHeight: .infinity)
                                    detailPanel
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                                    browserSidebar
                                        .frame(minHeight: 260, maxHeight: 260)
                                    detailPanel
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .frame(height: 560)
                }
            }
        }
        .onAppear(perform: syncSelection)
        .onChange(of: sortedTaskRunIDs) { _, _ in
            syncSelection()
        }
        .onChange(of: sortedRecoveryItemIDs) { _, _ in
            syncSelection()
        }
        .onChange(of: selectedSection) { _, _ in
            syncSelection()
        }
        .onChange(of: selectedRecoveryFilter) { _, _ in
            syncSelection()
        }
    }

    private var sortedTaskRuns: [TaskRun] {
        Self.sortTaskRuns(taskRuns)
    }

    private var sortedRecoveryItems: [RecoveryItem] {
        Self.sortRecoveryItems(recoveryItems)
    }

    private var sortedTaskRunIDs: [UUID] {
        sortedTaskRuns.map(\.id)
    }

    private var sortedRecoveryItemIDs: [UUID] {
        sortedRecoveryItems.map(\.id)
    }

    private var selectedTaskRun: TaskRun? {
        guard let selectedTaskRunID else {
            return nil
        }
        return sortedTaskRuns.first(where: { $0.id == selectedTaskRunID })
    }

    private var selectedRecoveryItem: RecoveryItem? {
        guard let selectedRecoveryItemID else {
            return nil
        }
        return sortedRecoveryItems.first(where: { $0.id == selectedRecoveryItemID })
    }

    private var visibleEventCount: Int {
        sortedTaskRuns.count + sortedRecoveryItems.count
    }

    private var totalRecoveryBytes: Int64 {
        sortedRecoveryItems.map(\.bytes).reduce(0, +)
    }

    private var activeTaskCount: Int {
        sortedTaskRuns.filter(\.isActive).count
    }

    private var latestVisibleEventDate: Date? {
        let taskDates = sortedTaskRuns.map(\.activityDate)
        let recoveryDates = sortedRecoveryItems.map(\.deletedAt)
        return (taskDates + recoveryDates).max()
    }

    private var soonExpiringRecoveryItems: [RecoveryItem] {
        sortedRecoveryItems.filter(\.isExpiringSoon)
    }

    private var recoveryGroups: [HistoryRecoveryGroup] {
        var groups: [HistoryRecoveryGroup] = []

        let visibleRecoveryItems = sortedRecoveryItems.filter { selectedRecoveryFilter.matches($0) }

        let visibleSoonExpiringRecoveryItems = visibleRecoveryItems.filter(\.isExpiringSoon)
        if !visibleSoonExpiringRecoveryItems.isEmpty {
            groups.append(
                HistoryRecoveryGroup(
                    id: "expiring",
                    title: AtlasL10n.string("history.recovery.group.expiring"),
                    tone: .warning,
                    items: visibleSoonExpiringRecoveryItems
                )
            )
        }

        let remainingItems = visibleRecoveryItems.filter { !$0.isExpiringSoon }
        let groupedItems = Dictionary(grouping: remainingItems, by: \.historyCategory)

        for category in HistoryRecoveryCategory.displayOrder {
            guard let items = groupedItems[category], !items.isEmpty else {
                continue
            }
            groups.append(
                HistoryRecoveryGroup(
                    id: category.rawValue,
                    title: category.title,
                    tone: category.tone,
                    items: items
                )
            )
        }

        return groups
    }

    private var taskRunGroups: [HistoryTaskRunGroup] {
        var groups: [HistoryTaskRunGroup] = []

        let activeItems = sortedTaskRuns.filter(\.isActive)
        if !activeItems.isEmpty {
            groups.append(
                HistoryTaskRunGroup(
                    id: "active",
                    title: AtlasL10n.string("history.archive.group.active"),
                    tone: .warning,
                    items: activeItems
                )
            )
        }

        let archivedItems = sortedTaskRuns.filter { !$0.isActive }
        let recentItems = archivedItems.filter(\.isRecentArchive)
        if !recentItems.isEmpty {
            groups.append(
                HistoryTaskRunGroup(
                    id: "recent",
                    title: AtlasL10n.string("history.archive.group.recent"),
                    tone: .neutral,
                    items: recentItems
                )
            )
        }

        let olderItems = archivedItems.filter { !$0.isRecentArchive }
        if !olderItems.isEmpty {
            groups.append(
                HistoryTaskRunGroup(
                    id: "older",
                    title: AtlasL10n.string("history.archive.group.older"),
                    tone: .neutral,
                    items: olderItems
                )
            )
        }

        return groups
    }

    private var activityMetricDetail: String {
        guard let latestVisibleEventDate else {
            return AtlasL10n.string("history.metric.activity.detail.empty")
        }
        return AtlasL10n.string("history.metric.activity.detail.latest", AtlasFormatters.relativeDate(latestVisibleEventDate))
    }

    private var recoverySummaryTone: AtlasTone {
        soonExpiringRecoveryItems.isEmpty ? .success : .warning
    }

    private var screenCalloutTitle: String {
        if !soonExpiringRecoveryItems.isEmpty {
            return AtlasL10n.string("history.callout.expiring.title")
        }
        if activeTaskCount > 0 {
            return AtlasL10n.string("history.callout.running.title")
        }
        if sortedRecoveryItems.isEmpty {
            return AtlasL10n.string("history.callout.empty.title")
        }
        return AtlasL10n.string("history.callout.recovery.title")
    }

    private var screenCalloutDetail: String {
        if !soonExpiringRecoveryItems.isEmpty {
            return AtlasL10n.string("history.callout.expiring.detail")
        }
        if activeTaskCount > 0 {
            return AtlasL10n.string("history.callout.running.detail")
        }
        if sortedRecoveryItems.isEmpty {
            return AtlasL10n.string("history.callout.empty.detail")
        }
        return AtlasL10n.string("history.callout.recovery.detail")
    }

    private var screenCalloutTone: AtlasTone {
        if !soonExpiringRecoveryItems.isEmpty || activeTaskCount > 0 {
            return .warning
        }
        if sortedRecoveryItems.isEmpty {
            return .neutral
        }
        return .success
    }

    private var screenCalloutSystemImage: String {
        if !soonExpiringRecoveryItems.isEmpty {
            return "exclamationmark.triangle.fill"
        }
        if activeTaskCount > 0 {
            return "play.circle.fill"
        }
        if sortedRecoveryItems.isEmpty {
            return "clock.arrow.circlepath"
        }
        return "lifepreserver.fill"
    }

    private var browserTone: AtlasTone {
        switch selectedSection {
        case .archive:
            return activeTaskCount > 0 ? .warning : .neutral
        case .recovery:
            if sortedRecoveryItems.isEmpty {
                return .neutral
            }
            return recoverySummaryTone
        }
    }

    private var browserSummary: String {
        switch selectedSection {
        case .archive:
            let count = sortedTaskRuns.count
            let key = count == 1 ? "history.browser.summary.archive.one" : "history.browser.summary.archive.other"
            return AtlasL10n.string(key, count)
        case .recovery:
            let count = sortedRecoveryItems.count
            let key = count == 1 ? "history.browser.summary.recovery.one" : "history.browser.summary.recovery.other"
            return AtlasL10n.string(key, count)
        }
    }

    @ViewBuilder
    private var browserSidebar: some View {
        switch selectedSection {
        case .archive:
            browserSidebarContainer {
                if sortedTaskRuns.isEmpty {
                    AtlasEmptyState(
                        title: AtlasL10n.string("history.runs.empty.title"),
                        detail: AtlasL10n.string("history.runs.empty.detail"),
                        systemImage: "clock.arrow.circlepath",
                        tone: .neutral
                    )
                } else {
                    List(selection: $selectedTaskRunID) {
                        ForEach(taskRunGroups) { group in
                            Section {
                                if group.id != "older" || isOlderArchiveExpanded {
                                    ForEach(group.items) { taskRun in
                                        HistoryTaskSidebarRow(
                                            taskRun: taskRun,
                                            isLatest: sortedTaskRuns.first?.id == taskRun.id
                                        )
                                        .tag(taskRun.id)
                                        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                                    }
                                }
                            } header: {
                                HistorySidebarSectionHeader(
                                    title: group.title,
                                    count: group.items.count,
                                    tone: group.tone,
                                    isCollapsible: group.id == "older",
                                    isExpanded: isOlderArchiveExpanded,
                                    onToggle: group.id == "older" ? { isOlderArchiveExpanded.toggle() } : nil
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        case .recovery:
            browserSidebarContainer {
                if sortedRecoveryItems.isEmpty || recoveryGroups.isEmpty {
                    AtlasEmptyState(
                        title: AtlasL10n.string(sortedRecoveryItems.isEmpty ? "history.recovery.empty.title" : "history.recovery.filtered.empty.title"),
                        detail: AtlasL10n.string(sortedRecoveryItems.isEmpty ? "history.recovery.empty.detail" : "history.recovery.filtered.empty.detail"),
                        systemImage: "lifepreserver",
                        tone: .neutral
                    )
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AtlasSpacing.sm) {
                                ForEach(HistoryRecoveryFilter.allCases) { filter in
                                    Group {
                                        if selectedRecoveryFilter == filter {
                                            Button(filter.title) {
                                                selectedRecoveryFilter = filter
                                            }
                                            .buttonStyle(.atlasSecondary)
                                        } else {
                                            Button(filter.title) {
                                                selectedRecoveryFilter = filter
                                            }
                                            .buttonStyle(.atlasGhost)
                                        }
                                    }
                                }
                            }
                        }

                        List(selection: $selectedRecoveryItemID) {
                            ForEach(recoveryGroups) { group in
                                Section {
                                    ForEach(group.items) { item in
                                        HistoryRecoverySidebarRow(item: item)
                                            .tag(item.id)
                                            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                                    }
                                } header: {
                                    HistorySidebarSectionHeader(
                                        title: group.title,
                                        count: group.items.count,
                                        tone: group.tone
                                    )
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
        }
    }

    private func browserSidebarContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            Text(selectedSection.sidebarTitle)
                .font(AtlasTypography.label)
                .foregroundStyle(.secondary)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AtlasSpacing.lg)
        .background(sidebarBackground)
        .overlay(sidebarBorder)
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            Text(AtlasL10n.string("history.detail.title"))
                .font(AtlasTypography.label)
                .foregroundStyle(.secondary)

            ScrollView {
                switch selectedSection {
                case .archive:
                    if let taskRun = selectedTaskRun {
                        HistoryTaskDetailView(
                            taskRun: taskRun,
                            isLatest: sortedTaskRuns.first?.id == taskRun.id
                        )
                    } else {
                        AtlasEmptyState(
                            title: AtlasL10n.string("history.detail.empty.title"),
                            detail: AtlasL10n.string("history.detail.empty.detail"),
                            systemImage: "cursorarrow.click",
                            tone: .neutral
                        )
                    }
                case .recovery:
                    if let item = selectedRecoveryItem {
                        HistoryRecoveryDetailView(
                            item: item,
                            isRestoring: restoringItemID == item.id,
                            canRestore: restoringItemID == nil,
                            onRestore: { onRestoreItem(item.id) }
                        )
                    } else {
                        AtlasEmptyState(
                            title: AtlasL10n.string("history.detail.empty.title"),
                            detail: AtlasL10n.string("history.detail.empty.detail"),
                            systemImage: "cursorarrow.click",
                            tone: .neutral
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.xl)
        .background(detailBackground)
        .overlay(detailBorder)
    }

    private var sidebarBackground: some View {
        RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
            .fill(AtlasColor.cardRaised)
    }

    private var sidebarBorder: some View {
        RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
            .strokeBorder(AtlasColor.border, lineWidth: 1)
    }

    private var detailBackground: some View {
        RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
            .fill(Color.primary.opacity(0.03))
    }

    private var detailBorder: some View {
        RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
            .strokeBorder(AtlasColor.border, lineWidth: 1)
    }

    private func syncSelection() {
        if !sortedTaskRuns.isEmpty, selectedTaskRun == nil {
            selectedTaskRunID = sortedTaskRuns.first?.id
        }

        let visibleRecoveryIDs = Set(recoveryGroups.flatMap { $0.items.map(\.id) })
        if !visibleRecoveryIDs.isEmpty, !visibleRecoveryIDs.contains(selectedRecoveryItemID ?? UUID()) {
            selectedRecoveryItemID = recoveryGroups.first?.items.first?.id
        }

        switch selectedSection {
        case .archive:
            if sortedTaskRuns.isEmpty, !sortedRecoveryItems.isEmpty {
                selectedSection = .recovery
            }
        case .recovery:
            if sortedRecoveryItems.isEmpty, !sortedTaskRuns.isEmpty {
                selectedSection = .archive
            }
        }
    }

    private static func initialSection(taskRuns: [TaskRun], recoveryItems: [RecoveryItem]) -> HistoryBrowserSection {
        if !recoveryItems.isEmpty {
            return .recovery
        }
        if !taskRuns.isEmpty {
            return .archive
        }
        return .recovery
    }

    private static func sortTaskRuns(_ taskRuns: [TaskRun]) -> [TaskRun] {
        taskRuns.sorted { lhs, rhs in
            if lhs.activityDate == rhs.activityDate {
                return lhs.startedAt > rhs.startedAt
            }
            return lhs.activityDate > rhs.activityDate
        }
    }

    private static func sortRecoveryItems(_ recoveryItems: [RecoveryItem]) -> [RecoveryItem] {
        recoveryItems.sorted { lhs, rhs in
            lhs.deletedAt > rhs.deletedAt
        }
    }
}

private enum HistoryBrowserSection: String, CaseIterable, Identifiable {
    case recovery
    case archive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recovery:
            return AtlasL10n.string("history.browser.section.recovery")
        case .archive:
            return AtlasL10n.string("history.browser.section.archive")
        }
    }

    var sidebarTitle: String {
        switch self {
        case .archive:
            return AtlasL10n.string("history.runs.title")
        case .recovery:
            return AtlasL10n.string("history.recovery.title")
        }
    }
}

private enum HistoryRecoveryFilter: String, CaseIterable, Identifiable {
    case all
    case expiring
    case apps
    case developer
    case browsers
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return AtlasL10n.string("history.recovery.filter.all")
        case .expiring:
            return AtlasL10n.string("history.recovery.filter.expiring")
        case .apps:
            return AtlasL10n.string("history.recovery.group.apps")
        case .developer:
            return AtlasL10n.string("history.recovery.group.developer")
        case .browsers:
            return AtlasL10n.string("history.recovery.group.browsers")
        case .system:
            return AtlasL10n.string("history.recovery.group.system")
        }
    }

    func matches(_ item: RecoveryItem) -> Bool {
        switch self {
        case .all:
            return true
        case .expiring:
            return item.isExpiringSoon
        case .apps:
            return item.historyCategory == .apps
        case .developer:
            return item.historyCategory == .developer
        case .browsers:
            return item.historyCategory == .browsers
        case .system:
            return item.historyCategory == .system
        }
    }
}

private struct HistoryRecoveryGroup: Identifiable {
    let id: String
    let title: String
    let tone: AtlasTone
    let items: [RecoveryItem]
}

private struct HistoryTaskRunGroup: Identifiable {
    let id: String
    let title: String
    let tone: AtlasTone
    let items: [TaskRun]
}

private struct HistorySidebarSectionHeader: View {
    let title: String
    let count: Int
    let tone: AtlasTone
    var isCollapsible: Bool = false
    var isExpanded: Bool = true
    var onToggle: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: AtlasSpacing.sm) {
            if isCollapsible, let onToggle {
                Button(action: onToggle) {
                    HStack(spacing: AtlasSpacing.xs) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(AtlasTypography.captionSmall)
                            .foregroundStyle(.secondary)

                        Text(title)
                            .font(AtlasTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(title)
                    .font(AtlasTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AtlasSpacing.sm)

            Text("\(count)")
                .font(AtlasTypography.captionSmall)
                .foregroundStyle(tone.tint)
        }
        .textCase(nil)
    }
}

private struct HistoryTaskSidebarRow: View {
    let taskRun: TaskRun
    let isLatest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                Image(systemName: taskRun.kind.historySystemImage)
                    .font(AtlasTypography.caption)
                    .foregroundStyle(taskRun.status.atlasTone.tint)
                    .accessibilityHidden(true)

                Text(taskRun.kind.title)
                    .font(AtlasTypography.rowTitle)
                    .lineLimit(1)

                Spacer(minLength: AtlasSpacing.sm)

                if isLatest {
                    Text(AtlasL10n.string("history.timeline.latest"))
                        .font(AtlasTypography.captionSmall)
                        .foregroundStyle(AtlasColor.brand)
                }
            }

            Text(taskRun.summary)
                .font(AtlasTypography.bodySmall)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                Text(AtlasFormatters.relativeDate(taskRun.activityDate))
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)

                Spacer(minLength: AtlasSpacing.sm)

                AtlasStatusChip(taskRun.status.title, tone: taskRun.status.atlasTone)
            }
        }
        .padding(.vertical, AtlasSpacing.xxs)
        .accessibilityElement(children: .contain)
    }
}

private struct HistoryRecoverySidebarRow: View {
    let item: RecoveryItem

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(item.isExpiringSoon ? AtlasColor.warning : AtlasColor.success)
                    .accessibilityHidden(true)

                Text(item.title)
                    .font(AtlasTypography.rowTitle)
                    .lineLimit(1)

                Spacer(minLength: AtlasSpacing.sm)

                AtlasStatusChip(
                    item.isExpiringSoon
                        ? AtlasL10n.string("history.recovery.badge.expiring")
                        : AtlasL10n.string("history.recovery.badge.available"),
                    tone: item.isExpiringSoon ? .warning : .success
                )
            }

            Text(item.detail)
                .font(AtlasTypography.bodySmall)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                Text(AtlasFormatters.byteCount(item.bytes))
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)

                Spacer(minLength: AtlasSpacing.sm)

                Text(AtlasFormatters.relativeDate(item.deletedAt))
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AtlasSpacing.xxs)
        .accessibilityElement(children: .contain)
    }
}

private struct HistoryTaskDetailView: View {
    let taskRun: TaskRun
    let isLatest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            HStack(alignment: .top, spacing: AtlasSpacing.lg) {
                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    HStack(spacing: AtlasSpacing.sm) {
                        Text(taskRun.kind.title)
                            .font(AtlasTypography.sectionTitle)

                        if isLatest {
                            Text(AtlasL10n.string("history.timeline.latest"))
                                .font(AtlasTypography.caption)
                                .foregroundStyle(AtlasColor.brand)
                        }
                    }

                    Text(taskRun.summary)
                        .font(AtlasTypography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AtlasSpacing.lg)

                AtlasStatusChip(taskRun.status.title, tone: taskRun.status.atlasTone)
            }

            AtlasCallout(
                title: taskRun.status.historyCalloutTitle,
                detail: taskRun.status.historyCalloutDetail,
                tone: taskRun.status.atlasTone,
                systemImage: taskRun.status.atlasTone.symbol
            )

            VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                AtlasKeyValueRow(
                    title: AtlasL10n.string("history.detail.task.status"),
                    value: taskRun.status.title,
                    detail: taskRun.kind.title
                )
                AtlasKeyValueRow(
                    title: AtlasL10n.string("history.detail.task.started"),
                    value: AtlasFormatters.shortDate(taskRun.startedAt),
                    detail: AtlasFormatters.relativeDate(taskRun.startedAt)
                )
                AtlasKeyValueRow(
                    title: AtlasL10n.string("history.detail.task.finished"),
                    value: taskRun.finishedAt.map(AtlasFormatters.shortDate) ?? AtlasL10n.string("history.detail.task.finished.running"),
                    detail: taskRun.finishedAt.map(AtlasFormatters.relativeDate) ?? AtlasL10n.string("history.timeline.meta.running")
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistoryRecoveryDetailView: View {
    let item: RecoveryItem
    let isRestoring: Bool
    let canRestore: Bool
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            HStack(alignment: .top, spacing: AtlasSpacing.lg) {
                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    Text(item.title)
                        .font(AtlasTypography.sectionTitle)

                    Text(item.detail)
                        .font(AtlasTypography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AtlasSpacing.lg)

                VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
                    AtlasStatusChip(
                        item.isExpiringSoon
                            ? AtlasL10n.string("history.recovery.badge.expiring")
                            : AtlasL10n.string("history.recovery.badge.available"),
                        tone: item.isExpiringSoon ? .warning : .success
                    )

                    Text(AtlasFormatters.byteCount(item.bytes))
                        .font(AtlasTypography.label)
                        .foregroundStyle(.secondary)
                }
            }

            AtlasCallout(
                title: item.isExpiringSoon
                    ? AtlasL10n.string("history.detail.recovery.callout.expiring.title")
                    : AtlasL10n.string("history.detail.recovery.callout.available.title"),
                detail: item.isExpiringSoon
                    ? AtlasL10n.string("history.detail.recovery.callout.expiring.detail")
                    : AtlasL10n.string("history.detail.recovery.callout.available.detail"),
                tone: item.isExpiringSoon ? .warning : .success,
                systemImage: item.isExpiringSoon ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
            )

            VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                AtlasKeyValueRow(
                    title: AtlasL10n.string("history.detail.recovery.size"),
                    value: AtlasFormatters.byteCount(item.bytes),
                    detail: item.detail
                )
                AtlasKeyValueRow(
                    title: AtlasL10n.string("history.detail.recovery.deleted"),
                    value: AtlasFormatters.shortDate(item.deletedAt),
                    detail: AtlasFormatters.relativeDate(item.deletedAt)
                )
                AtlasKeyValueRow(
                    title: AtlasL10n.string("history.detail.recovery.window"),
                    value: item.expiresAt.map(AtlasFormatters.shortDate) ?? AtlasL10n.string("history.detail.recovery.window.open"),
                    detail: item.expiresAt.map(AtlasFormatters.relativeDate) ?? AtlasL10n.string("history.recovery.meta.noexpiry")
                )
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text(AtlasL10n.string("history.recovery.path.label"))
                    .font(AtlasTypography.caption)
                    .foregroundStyle(.secondary)

                Text(item.originalPath)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AtlasSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                    .strokeBorder(AtlasColor.border, lineWidth: 1)
            )

            HStack(alignment: .center, spacing: AtlasSpacing.md) {
                Spacer(minLength: 0)

                Button(isRestoring ? AtlasL10n.string("history.restore.running") : AtlasL10n.string("history.restore.action")) {
                    onRestore()
                }
                .buttonStyle(.atlasPrimary)
                .disabled(!canRestore)
                .accessibilityIdentifier("history.restore.\(item.id.uuidString)")
                .accessibilityHint(AtlasL10n.string("history.restore.hint"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension TaskRun {
    var activityDate: Date {
        finishedAt ?? startedAt
    }

    var isActive: Bool {
        status == .queued || status == .running
    }

    var isRecentArchive: Bool {
        guard !isActive else {
            return false
        }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return activityDate >= sevenDaysAgo
    }
}

private extension RecoveryItem {
    var isExpiringSoon: Bool {
        guard let expiresAt else {
            return false
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return expiresAt <= cutoff
    }

    var historyCategory: HistoryRecoveryCategory {
        switch payload {
        case .app:
            return .apps
        case let .finding(finding):
            switch finding.category.lowercased() {
            case "developer":
                return .developer
            case "browsers":
                return .browsers
            case "system":
                return .system
            case "apps":
                return .apps
            default:
                return .other
            }
        case nil:
            return .other
        }
    }
}

private enum HistoryRecoveryCategory: String, CaseIterable {
    case apps
    case developer
    case browsers
    case system
    case other

    static let displayOrder: [HistoryRecoveryCategory] = [.apps, .developer, .browsers, .system, .other]

    var title: String {
        switch self {
        case .apps:
            return AtlasL10n.string("history.recovery.group.apps")
        case .developer:
            return AtlasL10n.string("history.recovery.group.developer")
        case .browsers:
            return AtlasL10n.string("history.recovery.group.browsers")
        case .system:
            return AtlasL10n.string("history.recovery.group.system")
        case .other:
            return AtlasL10n.string("history.recovery.group.other")
        }
    }

    var tone: AtlasTone {
        switch self {
        case .apps:
            return .warning
        case .developer:
            return .neutral
        case .browsers:
            return .success
        case .system:
            return .warning
        case .other:
            return .neutral
        }
    }
}

private extension TaskKind {
    var historySystemImage: String {
        switch self {
        case .scan:
            return "sparkles"
        case .executePlan:
            return "play.circle"
        case .uninstallApp:
            return "trash"
        case .restore:
            return "arrow.uturn.backward.circle"
        case .inspectPermissions:
            return "lock.shield"
        }
    }
}

private extension TaskStatus {
    var atlasTone: AtlasTone {
        switch self {
        case .queued:
            return .neutral
        case .running:
            return .warning
        case .completed:
            return .success
        case .failed, .cancelled:
            return .danger
        }
    }

    var historyCalloutTitle: String {
        switch self {
        case .queued:
            return AtlasL10n.string("history.detail.task.callout.queued.title")
        case .running:
            return AtlasL10n.string("history.detail.task.callout.running.title")
        case .completed:
            return AtlasL10n.string("history.detail.task.callout.completed.title")
        case .failed, .cancelled:
            return AtlasL10n.string("history.detail.task.callout.failed.title")
        }
    }

    var historyCalloutDetail: String {
        switch self {
        case .queued:
            return AtlasL10n.string("history.detail.task.callout.queued.detail")
        case .running:
            return AtlasL10n.string("history.detail.task.callout.running.detail")
        case .completed:
            return AtlasL10n.string("history.detail.task.callout.completed.detail")
        case .failed, .cancelled:
            return AtlasL10n.string("history.detail.task.callout.failed.detail")
        }
    }
}
