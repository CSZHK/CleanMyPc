import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Ledger screen coordinator (spec §3 台账 — warm paper home)

/// Full-page warm-paper ledger (spec §3 / §1.2 暖面边界). Coordinates:
/// - serif「维护台账」header + 导出报告 button;
/// - mono metric row (本月活动 / 运行中 / 可恢复+容量);
/// - filter chips (可恢复 / 全部 / 归档 — legacy filter fields preserved);
/// - left timeline (in-progress pinned) / right detail panel / bottom archive;
/// - selection back-link (clicking a timeline entry drives the detail panel).
///
/// Restore on the detail panel calls `onRestoreItem` — the same API and
/// recovery point the legacy HistoryFeatureView used, and the same one the
/// SmartClean undo toast chains into (PER Batch I red line).
public struct LedgerFeatureView: View {
    @Environment(\.atlasContentWidth) private var contentWidth

    private let taskRuns: [TaskRun]
    private let recoveryItems: [RecoveryItem]
    private let restoringItemID: UUID?
    private let retentionDays: Int
    private let planNumber: (TaskRun) -> Int?
    private let onRestoreItem: (UUID) -> Void
    private let onSelectionChange: (LedgerFilter, String?, Bool) -> Void

    @State private var browserWidth: CGFloat?
    @State private var selectedFilter: LedgerFilter
    @State private var selectedEntryID: String?
    @State private var isOlderArchiveExpanded: Bool
    @State private var isExporting = false

    public init(
        taskRuns: [TaskRun] = AtlasScaffoldFixtures.taskRuns,
        recoveryItems: [RecoveryItem] = AtlasScaffoldFixtures.recoveryItems,
        restoringItemID: UUID? = nil,
        retentionDays: Int = 7,
        initialSelectionID: String? = nil,
        initialFilter: LedgerFilter = .all,
        initialArchiveExpanded: Bool = false,
        planNumber: @escaping (TaskRun) -> Int? = { _ in nil },
        onRestoreItem: @escaping (UUID) -> Void = { _ in },
        onSelectionChange: @escaping (LedgerFilter, String?, Bool) -> Void = { _, _, _ in }
    ) {
        self.taskRuns = taskRuns
        self.recoveryItems = recoveryItems
        self.restoringItemID = restoringItemID
        self.retentionDays = retentionDays
        self.planNumber = planNumber
        self.onRestoreItem = onRestoreItem
        self.onSelectionChange = onSelectionChange
        // Seed from the Overview feed's tapped entry (round-4 back-link) and the
        // model-persisted presentation state (round-5: survives route switches).
        // syncSelection still validates the seeded id against all rendered
        // entries, so a stale id (e.g. since-archived) falls back gracefully.
        _selectedEntryID = State(initialValue: initialSelectionID)
        _selectedFilter = State(initialValue: initialFilter)
        _isOlderArchiveExpanded = State(initialValue: initialArchiveExpanded)
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("ledger.screen.title"),
            subtitle: AtlasL10n.string("ledger.screen.subtitle"),
            maxContentWidth: AtlasLayout.maxWorkspaceWidth
        ) {
            AtlasLedgerSurface(title: AtlasL10n.string("ledger.surface.title")) {
                VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                    headerBar
                    metricRow
                    filterChips
                    browserLayout
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(widthProbe)
                }
            }
        }
        .onAppear {
            syncSelection()
            // Persist the resolved (possibly back-link-seeded) selection so a
            // tab round-trip right after a back-link still lands on №N (round-5).
            persistLedgerState()
        }
        .onChange(of: sortedTaskRunIDs) { _, _ in syncSelection() }
        .onChange(of: sortedRecoveryItemIDs) { _, _ in syncSelection() }
        .onChange(of: selectedFilter) { _, _ in
            syncSelection()
            persistLedgerState()
        }
        .onChange(of: selectedEntryID) { _, _ in persistLedgerState() }
        .onChange(of: isOlderArchiveExpanded) { _, _ in persistLedgerState() }
        .sheet(isPresented: $isExporting) { exportPanel }
    }

    // MARK: Header

    private var headerBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button { isExporting = true } label: {
                Label(AtlasL10n.string("ledger.export.button"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.atlasSecondary)
            .accessibilityIdentifier("ledger.export.button")
        }
    }

    // MARK: Metric row (mono data voice)

    private var metricRow: some View {
        LazyVGrid(columns: AtlasLayout.adaptiveMetricColumns(for: contentWidth), spacing: AtlasSpacing.lg) {
            AtlasMetricCard(title: AtlasL10n.string("ledger.metric.activity.title"), value: "\(taskRuns.count + recoveryItems.count)", detail: activityDetail, tone: .neutral, systemImage: "clock.arrow.circlepath")
            AtlasMetricCard(title: AtlasL10n.string("ledger.metric.running.title"), value: "\(activeTaskCount)", detail: runningDetail, tone: activeTaskCount == 0 ? .success : .warning, systemImage: activeTaskCount == 0 ? "checkmark.circle" : "play.circle")
            AtlasMetricCard(title: AtlasL10n.string("ledger.metric.recovery.title"), value: "\(restorableRecoveryItems.count)", detail: recoveryDetail, tone: restorableRecoveryItems.isEmpty ? .neutral : recoveryTone, systemImage: restorableRecoveryItems.isEmpty ? "lifepreserver" : "arrow.uturn.backward.circle")
        }
    }

    private var runningDetail: String {
        activeTaskCount == 0 ? AtlasL10n.string("ledger.metric.running.detail.none") : AtlasL10n.string("ledger.metric.running.detail.active")
    }
    private var recoveryDetail: String {
        restorableRecoveryItems.isEmpty
            ? AtlasL10n.string("ledger.metric.recovery.detail.none")
            : AtlasL10n.string("ledger.metric.recovery.detail.available", AtlasFormatters.byteCount(restorableRecoveryBytes))
    }
    private var activityDetail: String {
        let dates = taskRuns.map(\.activityDate) + recoveryItems.map(\.deletedAt)
        guard let latest = dates.max() else { return AtlasL10n.string("ledger.metric.activity.detail.empty") }
        return AtlasL10n.string("ledger.metric.activity.detail.latest", AtlasFormatters.relativeDate(latest))
    }

    // MARK: Filter chips (legacy fields preserved)

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AtlasSpacing.sm) {
                ForEach(LedgerFilter.allCases) { filter in
                    if selectedFilter == filter {
                        Button(filter.title) { selectedFilter = filter }.buttonStyle(.atlasSecondary)
                    } else {
                        Button(filter.title) { selectedFilter = filter }.buttonStyle(.atlasGhost)
                    }
                }
            }
        }
    }

    // MARK: Browser layout (timeline + detail + archive)

    @ViewBuilder
    private var browserLayout: some View {
        if isWideLayout {
            HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                timelineColumn.frame(width: sidebarWidth).frame(minHeight: 440, alignment: .topLeading)
                detailColumn.frame(maxWidth: .infinity, minHeight: 440, alignment: .topLeading)
            }
        } else {
            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                timelineColumn.frame(minHeight: 240, idealHeight: 320)
                detailColumn.frame(maxWidth: .infinity, minHeight: 240)
            }
        }
    }

    @ViewBuilder
    private var timelineColumn: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            Text(AtlasL10n.string("ledger.timeline.title")).font(AtlasTypography.label).foregroundStyle(.secondary)
            if primaryEntries.isEmpty && archivedEntries.isEmpty {
                AtlasEmptyState(title: AtlasL10n.string("ledger.timeline.empty.title"), detail: AtlasL10n.string("ledger.timeline.empty.detail"), systemImage: "list.bullet.rectangle", tone: .neutral)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        if !primaryEntries.isEmpty {
                            LedgerTimelineView(entries: primaryEntries, selection: entrySelectionBinding)
                        }
                        if !archivedEntries.isEmpty {
                            LedgerArchiveView(entries: archivedEntries, title: AtlasL10n.string("ledger.archive.section.older"), isExpanded: $isOlderArchiveExpanded, selection: entrySelectionBinding)
                        }
                    }
                }
            }
        }
        .padding(AtlasSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: 480, alignment: .topLeading)
        .background(cardBackground)
    }

    @ViewBuilder
    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            Text(AtlasL10n.string("ledger.detail.title")).font(AtlasTypography.label).foregroundStyle(.secondary)
            LedgerDetailView(selection: selection, restoringItemID: restoringItemID, retentionDays: retentionDays, onRestoreItem: onRestoreItem)
        }
        .padding(AtlasSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: 480, alignment: .topLeading)
        .background(cardBackground)
    }

    // MARK: Export (view-layer IO; pure builder in LedgerExportBuilder)

    private var exportPanel: some View {
        VStack(spacing: AtlasSpacing.lg) {
            Text(AtlasL10n.string("ledger.export.panel.title")).font(AtlasTypography.sectionTitle)
            Text(AtlasL10n.string("ledger.export.panel.detail")).font(AtlasTypography.body).foregroundStyle(.secondary)
            HStack(spacing: AtlasSpacing.md) {
                Button(AtlasL10n.string("ledger.export.panel.cancel"), role: .cancel) { isExporting = false }.buttonStyle(.atlasGhost)
                Button(AtlasL10n.string("ledger.export.panel.save")) { saveReport() }.buttonStyle(.atlasPrimary)
            }
        }
        .padding(AtlasSpacing.xl)
        .frame(width: 360)
    }

    private func saveReport() {
        isExporting = false
        let markdown = LedgerExportController.renderReport(
            taskRuns: taskRuns,
            recoveryItems: recoveryItems,
            retentionDays: retentionDays,
            planNumber: planNumber
        )
        LedgerExportController.presentSavePanel(markdown: markdown)
    }

    // MARK: Derived state (legacy grouping logic preserved)

    private var sortedTaskRuns: [TaskRun] {
        taskRuns.sorted { lhs, rhs in
            if lhs.activityDate == rhs.activityDate { return lhs.startedAt > rhs.startedAt }
            return lhs.activityDate > rhs.activityDate
        }
    }
    private var sortedRecoveryItems: [RecoveryItem] { recoveryItems.sorted { $0.deletedAt > $1.deletedAt } }
    private var sortedTaskRunIDs: [UUID] { sortedTaskRuns.map(\.id) }
    private var sortedRecoveryItemIDs: [UUID] { sortedRecoveryItems.map(\.id) }
    private var activeTaskCount: Int { taskRuns.filter(\.isActive).count }
    /// Recovery items that are still RESTORABLE (not expired). The recovery
    /// metric advertises "可恢复项 / Recoverable now", so it must exclude expired
    /// records (round-21: previously counted/summed ALL recoveryItems —
    /// advertising a restore capacity that partly does not exist. The detail
    /// panel already disables restore for expired items via `!item.isExpired`.)
    private var restorableRecoveryItems: [RecoveryItem] {
        recoveryItems.filter { !$0.isExpired }.sorted { $0.deletedAt > $1.deletedAt }
    }
    private var restorableRecoveryBytes: Int64 { restorableRecoveryItems.reduce(Int64(0)) { $0 + $1.bytes } }
    private var recoveryTone: AtlasTone { restorableRecoveryItems.contains(where: \.isExpiringSoon) ? .warning : .success }

    private var runNumbers: [UUID: Int] {
        LedgerEntryMapping.chronologicalDisplayNumbers(for: taskRuns, planNumber: planNumber)
    }

    private var primaryEntries: [AtlasLedgerEntryModel] {
        let activeOrRecent = sortedTaskRuns.filter { $0.isActive || $0.isRecentArchive }
        var entries = activeOrRecent.map { LedgerEntryMapping.entry(for: $0, displayNumber: runNumbers[$0.id] ?? 0) }
        entries += sortedRecoveryItems.filter { selectedFilter.matches(recovery: $0) }
            .map { LedgerEntryMapping.entry(for: $0, retentionDays: retentionDays) }
        return entries
    }

    private var archivedEntries: [AtlasLedgerEntryModel] {
        sortedTaskRuns.filter { !$0.isActive && !$0.isRecentArchive }
            .map { LedgerEntryMapping.entry(for: $0, displayNumber: runNumbers[$0.id] ?? 0) }
    }

    private var selection: LedgerSelection {
        LedgerEntryMapping.resolveSelection(id: selectedEntryID, taskRuns: taskRuns, recoveryItems: recoveryItems)
    }

    private var entrySelectionBinding: Binding<String?> {
        Binding(get: { selectedEntryID }, set: { selectedEntryID = $0 })
    }

    private var effectiveBrowserWidth: CGFloat { max(browserWidth ?? contentWidth, 0) }
    private var isWideLayout: Bool { effectiveBrowserWidth >= AtlasLayout.browserSplitThreshold }
    private var sidebarWidth: CGFloat { min(max(effectiveBrowserWidth * 0.3, 210), 270) }
    private var widthProbe: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: LedgerBrowserWidthKey.self, value: proxy.size.width)
        }
        .onPreferenceChange(LedgerBrowserWidthKey.self) { if $0 > 0 { browserWidth = $0 } }
    }
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
            .fill(AtlasColor.cardRaised)
            .overlay(RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous).strokeBorder(AtlasColor.border, lineWidth: 1))
    }

    private func syncSelection() {
        withAnimation(.easeInOut(duration: 0.2)) {
            // Auto-select first only when the current selection is genuinely
            // unresolvable — never clobber an active user selection just because
            // the filter narrowed the VISIBLE list. `selection` resolves the id
            // against the FULL unfiltered taskRuns/recoveryItems sets, so a
            // recovery item that a filter chip narrowed out of the timeline
            // stays selected (the detail panel still shows it; the timeline just
            // shows no highlight under the new filter) instead of being silently
            // replaced (round-9: the filter-narrowed allEntryIDs check clobbered
            // it; round-1/round-3 covered the archived-run dimension only).
            if selection == .none {
                if let first = primaryEntries.first {
                    selectedEntryID = first.id
                } else if let first = archivedEntries.first {
                    selectedEntryID = first.id
                }
            }
        }
    }

    /// Write the current filter / selection / archive-expand back to the model
    /// so they survive the .id(route) view rebuild on tab round-trips (round-5,
    /// §7 red line — feature-local @State is otherwise destroyed on navigation).
    private func persistLedgerState() {
        onSelectionChange(selectedFilter, selectedEntryID, isOlderArchiveExpanded)
    }
}

// MARK: - Filter (legacy filter fields preserved)

public enum LedgerFilter: String, CaseIterable, Identifiable {
    case all, recoverable, archive
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .all: return AtlasL10n.string("ledger.filter.all")
        case .recoverable: return AtlasL10n.string("ledger.filter.recoverable")
        case .archive: return AtlasL10n.string("ledger.filter.archive")
        }
    }
    /// Pure filter mapping (spec §3 过滤芯片 — legacy fields preserved).
    public func matches(recovery item: RecoveryItem) -> Bool {
        switch self {
        case .all: return true
        case .recoverable: return !item.isExpired
        case .archive: return item.isExpired
        }
    }
}

// MARK: - Private view helpers (RecoveryItem helpers live in LedgerRecoveryHelpers.swift)

// File-private TaskRun helpers — mirrors the legacy HistoryFeatureView scope
// (where this was `private` because everything lived in one file). Kept
// duplicated-and-private rather than module-internal so there is zero risk of
// a same-name internal symbol colliding; the canonical copy lives next to the
// numbering rule in LedgerTimelineView.swift. See review fix M-2.
private extension TaskRun {
    var activityDate: Date { finishedAt ?? startedAt }
    var isActive: Bool { status == .queued || status == .running }
    var isRecentArchive: Bool {
        guard !isActive else { return false }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return activityDate >= sevenDaysAgo
    }
}

private struct LedgerBrowserWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
