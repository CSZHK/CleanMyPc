import AtlasApplication
import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Ledger feed (spec §3 概览 台账流)

/// Right column of the overview: a warm ledger surface showing the 3–5 most
/// recent № entries, plus a "view full ledger →" link. Each row is clickable
/// and navigates to the ledger screen.
///
/// The display № assignment follows the **same rule** as the ledger screen
/// (Batch J `LedgerEntryMapping.chronologicalDisplayNumbers`): a stored counter
/// № (from `planNumber(for:)`) wins; otherwise a chronological fallback is
/// computed (newest run gets the highest fallback, strictly above any stored
/// № so collisions are impossible). The rule is **re-implemented here** rather
/// than imported — `AtlasFeaturesOverview` deliberately does not depend on
/// `AtlasFeaturesHistory` (per feature-package boundary; spec §0.3).
public struct OverviewLedgerFeed: View {
    /// Display-№ map (UUID → №) and the entries to render.
    public struct FeedData: Equatable {
        public var entries: [AtlasLedgerEntryModel]
        public init(entries: [AtlasLedgerEntryModel]) {
            self.entries = entries
        }
    }

    private let feed: FeedData
    private let onNavigateToLedger: (() -> Void)?
    private let onSelectEntry: ((String) -> Void)?

    public init(
        feed: FeedData,
        onNavigateToLedger: (() -> Void)?,
        onSelectEntry: ((String) -> Void)? = nil
    ) {
        self.feed = feed
        self.onNavigateToLedger = onNavigateToLedger
        self.onSelectEntry = onSelectEntry
    }

    public var body: some View {
        AtlasLedgerSurface(title: AtlasL10n.string("overview.feed.title")) {
            if feed.entries.isEmpty {
                AtlasEmptyState(
                    title: AtlasL10n.string("overview.feed.empty.title"),
                    detail: AtlasL10n.string("overview.feed.empty.detail"),
                    systemImage: "tray",
                    tone: .neutral
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(feed.entries.prefix(OverviewLedgerFeed.maxEntries).enumerated()), id: \.element.id) { idx, entry in
                        feedRow(entry)
                            .atlasLedgerRule() // dotted ledger separator
                        if idx != min(feed.entries.count, OverviewLedgerFeed.maxEntries) - 1 {
                            // the rule sits at the bottom of each non-last row
                        }
                    }
                }

                Button {
                    onNavigateToLedger?()
                } label: {
                    HStack(spacing: AtlasSpacing.xs) {
                        Text(AtlasL10n.string("overview.feed.viewAll"))
                            .font(AtlasTypography.label)
                        Image(systemName: "arrow.right")
                            .font(AtlasTypography.caption)
                    }
                    .foregroundStyle(AtlasColor.brand)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, AtlasSpacing.md)
                }
                .buttonStyle(.plain)
                .disabled(onNavigateToLedger == nil)
                .accessibilityHint(AtlasL10n.string("overview.feed.viewAll.hint"))
            }
        }
    }

    /// Max number of entries the feed renders (spec: 3–5).
    public static let maxEntries = 5

    // MARK: - Row

    @ViewBuilder
    private func feedRow(_ entry: AtlasLedgerEntryModel) -> some View {
        Button {
            onSelectEntry?(entry.id)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: AtlasSpacing.sm) {
                Text("№\(entry.number)")
                    .font(AtlasTypography.ledgerNumber)
                    .foregroundStyle(AtlasColor.brand)
                    .monospacedDigit()

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title)
                        .font(AtlasTypography.rowTitle)
                        .foregroundStyle(AtlasColor.ledgerInk)
                        .lineLimit(1)
                    if let metric = entry.metricText {
                        Text(metric)
                            .font(AtlasTypography.dataCaption)
                            .monospacedDigit()
                            .foregroundStyle(AtlasColor.ledgerSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: AtlasSpacing.sm)

                Text(AtlasL10n.string("overview.feed.row.chevron"))
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.ledgerSecondary)
            }
            .padding(.vertical, AtlasSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AtlasL10n.string("overview.feed.row.a11y", entry.number, entry.title)))
    }

    // MARK: - Pure feed builder (unit-tested)

    /// Build a `FeedData` from task runs. The display № follows the same rule
    /// as `LedgerEntryMapping.chronologicalDisplayNumbers` (Batch J):
    /// - stored № (from `planNumber(for:)`) wins;
    /// - otherwise a chronological fallback is computed, newest run highest,
    ///   with `seedBase = max(runs.count, storedMax) + 1` so a later counter
    ///   allocation (which starts above `runs.count`) never collides.
    ///
    /// `planNumber(for:)` returns the shell-counter № for active scan/execute
    /// runs; for everything else it returns nil and the fallback fills in.
    public static func feedData(
        taskRuns: [TaskRun],
        planNumber: (TaskRun) -> Int?,
        now: Date = Date()
    ) -> FeedData {
        // Limit to recent runs by activity date (newest first), then take 5.
        let recent = taskRuns
            .sorted { lhs, rhs in
                let lhsDate = lhs.finishedAt ?? lhs.startedAt
                let rhsDate = rhs.finishedAt ?? rhs.startedAt
                return lhsDate > rhsDate
            }
            .prefix(maxEntries)

        let numbers = chronologicalDisplayNumbers(for: Array(recent), planNumber: planNumber)

        let entries = recent.map { run -> AtlasLedgerEntryModel in
            let number = numbers[run.id] ?? 0
            return AtlasLedgerEntryModel(
                id: "run.\(run.id.uuidString)",
                number: number,
                title: run.kind.title,
                detail: run.summary,
                metricText: metricText(for: run),
                status: status(for: run)
            )
        }
        return FeedData(entries: entries)
    }

    // MARK: № numbering rule (mirror of LedgerEntryMapping.chronologicalDisplayNumbers)

    /// Assigns a display № to each task run (re-implemented to avoid a cross-
    /// feature-package dependency on AtlasFeaturesHistory). Same rule as Batch J.
    public static func chronologicalDisplayNumbers(
        for taskRuns: [TaskRun],
        planNumber: (TaskRun) -> Int?
    ) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        var fallbackRuns: [TaskRun] = []
        for run in taskRuns {
            if let stored = planNumber(run) {
                result[run.id] = stored
            } else {
                fallbackRuns.append(run)
            }
        }
        guard !fallbackRuns.isEmpty else { return result }

        // +1 is load-bearing (Batch J review fix): without it, when
        // max(count, storedMax) == storedMax the index-0 fallback would
        // collide with the stored entry at that №. Adding 1 keeps every
        // fallback strictly above any stored №.
        let seedBase = max(taskRuns.count, result.values.max() ?? 0) + 1
        let sortedDesc = fallbackRuns.sorted { lhs, rhs in
            let lhsDate = lhs.finishedAt ?? lhs.startedAt
            let rhsDate = rhs.finishedAt ?? rhs.startedAt
            if lhsDate == rhsDate {
                return lhs.startedAt > rhs.startedAt
            }
            return lhsDate > rhsDate
        }
        for (index, run) in sortedDesc.enumerated() {
            result[run.id] = seedBase - index
        }
        return result
    }

    // MARK: Status / metric (pure — mirror of LedgerEntryMapping helpers)

    private static func status(for run: TaskRun) -> AtlasLedgerEntryStatus {
        switch run.status {
        case .queued, .running:
            return .inProgress
        case .completed:
            return .verified
        case .failed, .cancelled:
            return .archived
        }
    }

    private static func metricText(for run: TaskRun) -> String? {
        if let finished = run.finishedAt {
            return AtlasFormatters.shortDate(finished)
        }
        return AtlasL10n.string("overview.feed.metric.running")
    }
}
