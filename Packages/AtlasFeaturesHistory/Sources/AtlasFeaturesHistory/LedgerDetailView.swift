import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Right-rail detail panel (spec §3 台账右详情面板)

/// Detail panel for the selected ledger entry. Two modes:
/// - **task run**: mono execution data (started/finished/status/summary);
/// - **recovery item**: mono content + restore-point stamp watermark +
///   restore-all / per-item restore actions.
///
/// Restore calls `onRestoreItem(UUID)` — the **same API and recovery point**
/// the legacy HistoryFeatureView used, and the same one the SmartClean undo
/// toast chains into (PER Batch I red line: zero change to restore/delete
/// call semantics).
public struct LedgerDetailView: View {
    private let selection: LedgerSelection
    private let restoringItemID: UUID?
    private let retentionDays: Int
    private let onRestoreItem: (UUID) -> Void

    public init(selection: LedgerSelection, restoringItemID: UUID?, retentionDays: Int, onRestoreItem: @escaping (UUID) -> Void) {
        self.selection = selection
        self.restoringItemID = restoringItemID
        self.retentionDays = retentionDays
        self.onRestoreItem = onRestoreItem
    }

    public var body: some View {
        ScrollView {
            Group {
                switch selection {
                case .none: emptyState
                case .taskRun(let run): taskRunDetail(run)
                case .recoveryItem(let item): recoveryItemDetail(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        AtlasEmptyState(title: AtlasL10n.string("ledger.detail.empty.title"), detail: AtlasL10n.string("ledger.detail.empty.detail"), systemImage: "cursorarrow.click", tone: .neutral)
    }

    // MARK: Task run

    private func taskRunDetail(_ run: TaskRun) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AtlasSpacing.lg) {
                    taskHeaderCopy(run); Spacer(minLength: AtlasSpacing.lg)
                    AtlasStatusChip(run.status.title, tone: run.status.atlasTone)
                }
                VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                    taskHeaderCopy(run)
                    AtlasStatusChip(run.status.title, tone: run.status.atlasTone)
                }
            }
            AtlasCallout(title: run.status.ledgerCalloutTitle, detail: run.status.ledgerCalloutDetail, tone: run.status.atlasTone, systemImage: run.status.atlasTone.symbol)
            monoExecutionData(run)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.lg)
    }

    private func taskHeaderCopy(_ run: TaskRun) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            Text(run.kind.title).font(AtlasTypography.sectionTitle)
            Text(run.summary).font(AtlasTypography.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Mono execution data rows (spec §3 「mono 执行数据」) — voice ② data.
    private func monoExecutionData(_ run: TaskRun) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            AtlasKeyValueRow(title: AtlasL10n.string("ledger.detail.task.status"), value: run.status.title, detail: run.kind.title)
            AtlasKeyValueRow(title: AtlasL10n.string("ledger.detail.task.started"), value: AtlasFormatters.shortDate(run.startedAt), detail: AtlasFormatters.relativeDate(run.startedAt))
            AtlasKeyValueRow(title: AtlasL10n.string("ledger.detail.task.finished"), value: run.finishedAt.map(AtlasFormatters.shortDate) ?? AtlasL10n.string("ledger.detail.task.finished.running"), detail: run.finishedAt.map(AtlasFormatters.relativeDate) ?? AtlasL10n.string("ledger.timeline.metric.running"))
        }
    }

    // MARK: Recovery item

    private func recoveryItemDetail(_ item: RecoveryItem) -> some View {
        ZStack {
            // Restore-point stamp watermark (spec §1.6 / §4.2). Fail-closed:
            // renders only when the item has a physical restore path (real
            // file-backed recovery) — never for state-only records, never with
            // invented bytes/days.
            if item.hasPhysicalRestorePath {
                AtlasStampBadge(title: AtlasL10n.string("ledger.stamp.title"), subtitle: AtlasL10n.string("ledger.stamp.subtitle", AtlasFormatters.byteCount(item.bytes), retentionDays), numberText: "№", style: .watermark)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding([.trailing, .bottom], AtlasSpacing.lg)
            }
            VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AtlasSpacing.lg) {
                        recoveryHeaderCopy(item); Spacer(minLength: AtlasSpacing.lg); recoveryHeaderMeta(item)
                    }
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        recoveryHeaderCopy(item); recoveryHeaderMeta(item).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                AtlasCallout(title: calloutCopy.title(item), detail: calloutCopy.detail(item), tone: calloutCopy.tone(item), systemImage: calloutCopy.symbol(item))
                recoveryContentManifest(item)
                restoreActions(item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AtlasSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous).fill(Color.primary.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous).strokeBorder(AtlasColor.border, lineWidth: 1))
    }

    private func recoveryHeaderCopy(_ item: RecoveryItem) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            Text(item.title).font(AtlasTypography.sectionTitle)
            Text(item.detail).font(AtlasTypography.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func recoveryHeaderMeta(_ item: RecoveryItem) -> some View {
        VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
            AtlasStatusChip(item.isExpiringSoon ? AtlasL10n.string("ledger.recovery.badge.expiring") : AtlasL10n.string("ledger.recovery.badge.available"), tone: item.isExpiringSoon ? .warning : .success)
            Text(AtlasFormatters.byteCount(item.bytes)).font(AtlasTypography.dataMetric).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    /// Mono content manifest (spec §3 「包含清单」) — voice ② data throughout.
    private func recoveryContentManifest(_ item: RecoveryItem) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            AtlasKeyValueRow(title: AtlasL10n.string("ledger.detail.recovery.size"), value: AtlasFormatters.byteCount(item.bytes), detail: item.detail)
            AtlasKeyValueRow(title: AtlasL10n.string("ledger.detail.recovery.deleted"), value: AtlasFormatters.shortDate(item.deletedAt), detail: AtlasFormatters.relativeDate(item.deletedAt))
            AtlasKeyValueRow(title: AtlasL10n.string("ledger.detail.recovery.window"), value: item.expiresAt.map(AtlasFormatters.shortDate) ?? AtlasL10n.string("ledger.detail.recovery.window.open"), detail: item.expiresAt.map(AtlasFormatters.relativeDate) ?? AtlasL10n.string("ledger.recovery.meta.noexpiry"))
            if let mappings = item.restoreMappings, !mappings.isEmpty {
                AtlasMachineTextBlock(title: AtlasL10n.string("ledger.detail.recovery.evidence.restorePaths"), value: mappings.map { "\($0.originalPath)\n-> \($0.trashedPath)" }.joined(separator: "\n\n"), detail: AtlasL10n.string(mappings.count == 1 ? "ledger.detail.recovery.evidence.restorePaths.detail.one" : "ledger.detail.recovery.evidence.restorePaths.detail.other", mappings.count))
            }
        }
    }

    /// Restore actions — same recovery point as the SmartClean undo toast.
    private func restoreActions(_ item: RecoveryItem) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack { Spacer(minLength: 0); restoreButton(item) }
            VStack(alignment: .leading) { restoreButton(item) }
        }
    }

    private func restoreButton(_ item: RecoveryItem) -> some View {
        let isRestoring = restoringItemID == item.id
        let canRestore = restoringItemID == nil && !item.isExpired
        return Button(isRestoring ? restoreTitle(item, running: true) : restoreTitle(item, running: false)) {
            onRestoreItem(item.id)
        }
        .buttonStyle(.atlasPrimary)
        .disabled(!canRestore)
        .accessibilityIdentifier("ledger.restore.\(item.id.uuidString)")
        .accessibilityHint(restoreHint(item))
    }

    private func restoreTitle(_ item: RecoveryItem, running: Bool) -> String {
        let key = running
            ? (item.hasPhysicalRestorePath ? "ledger.restore.running" : "ledger.restore.running.stateOnly")
            : (item.hasPhysicalRestorePath ? "ledger.restore.action" : "ledger.restore.action.stateOnly")
        return AtlasL10n.string(key)
    }

    private func restoreHint(_ item: RecoveryItem) -> String {
        AtlasL10n.string(item.hasPhysicalRestorePath ? "ledger.restore.hint.fileBacked" : "ledger.restore.hint.stateOnly")
    }

    // Callout copy table (legacy behavior preserved, keys renamed ledger.*).
    private var calloutCopy: RecoveryCalloutCopy { RecoveryCalloutCopy() }
}

// MARK: - Selection type (shared with the coordinator)

/// What the timeline currently points the detail panel at. Only a recovery
/// item selection exposes a restore action.
public enum LedgerSelection: Equatable {
    case none
    case taskRun(TaskRun)
    case recoveryItem(RecoveryItem)
}

// MARK: - Callout copy lookup (keeps the switch out of the view body)

private struct RecoveryCalloutCopy {
    func title(_ item: RecoveryItem) -> String {
        switch (item.hasPhysicalRestorePath, item.isExpiringSoon) {
        case (true, true): return AtlasL10n.string("ledger.detail.recovery.callout.expiring.fileBacked.title")
        case (true, false): return AtlasL10n.string("ledger.detail.recovery.callout.available.fileBacked.title")
        case (false, true): return AtlasL10n.string("ledger.detail.recovery.callout.expiring.stateOnly.title")
        case (false, false): return AtlasL10n.string("ledger.detail.recovery.callout.available.stateOnly.title")
        }
    }
    func detail(_ item: RecoveryItem) -> String {
        switch (item.hasPhysicalRestorePath, item.isExpiringSoon) {
        case (true, true): return AtlasL10n.string("ledger.detail.recovery.callout.expiring.fileBacked.detail")
        case (true, false): return AtlasL10n.string("ledger.detail.recovery.callout.available.fileBacked.detail")
        case (false, true): return AtlasL10n.string("ledger.detail.recovery.callout.expiring.stateOnly.detail")
        case (false, false): return AtlasL10n.string("ledger.detail.recovery.callout.available.stateOnly.detail")
        }
    }
    func tone(_ item: RecoveryItem) -> AtlasTone {
        if item.isExpiringSoon { return .warning }
        return item.hasPhysicalRestorePath ? .success : .neutral
    }
    func symbol(_ item: RecoveryItem) -> String {
        if item.isExpiringSoon { return "exclamationmark.triangle.fill" }
        return item.hasPhysicalRestorePath ? "checkmark.circle.fill" : "rectangle.stack.badge.person.crop"
    }
}

// MARK: - Private task-status helpers (legacy behavior preserved; recovery-item
// helpers now live in LedgerRecoveryHelpers.swift — review fix M-1)

private extension TaskStatus {
    var ledgerCalloutTitle: String {
        switch self {
        case .queued: return AtlasL10n.string("ledger.detail.task.callout.queued.title")
        case .running: return AtlasL10n.string("ledger.detail.task.callout.running.title")
        case .completed: return AtlasL10n.string("ledger.detail.task.callout.completed.title")
        case .failed, .cancelled: return AtlasL10n.string("ledger.detail.task.callout.failed.title")
        }
    }
    var ledgerCalloutDetail: String {
        switch self {
        case .queued: return AtlasL10n.string("ledger.detail.task.callout.queued.detail")
        case .running: return AtlasL10n.string("ledger.detail.task.callout.running.detail")
        case .completed: return AtlasL10n.string("ledger.detail.task.callout.completed.detail")
        case .failed, .cancelled: return AtlasL10n.string("ledger.detail.task.callout.failed.detail")
        }
    }
}
