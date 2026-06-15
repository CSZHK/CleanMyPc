import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Entry mapping (pure functions, spec §3 台账左时间线 / §1.6 №)

/// Maps task runs + recovery items into `AtlasLedgerEntryModel`s and assigns
/// each a display № (spec §1.6 / PER Decision Log 2026-06-10):
///
/// - Stored № (from the shell's monotonic counter) wins when present;
/// - For task runs without a stored № (created before the counter existed),
///   a **chronological fallback** number is computed by descending activity
///   date — newest run gets the highest number, so it never collides with a
///   fresh counter allocation (those start above the existing run count + 1).
///
/// `planNumber(for:)` is the shell-owned closure passed in at construction;
/// everything below is a pure function so the mapping + numbering rule are
/// unit-testable without an app model.
public enum LedgerEntryMapping {

    /// Stable entry id so timeline selection survives re-renders (prefixed to
    /// avoid collisions between task-run and recovery-item UUIDs).
    public static func entryID(for run: TaskRun) -> String { "run.\(run.id.uuidString)" }
    public static func entryID(for item: RecoveryItem) -> String { "recovery.\(item.id.uuidString)" }

    /// Build the timeline entries. `planNumber(for:)` returns the stored №
    /// when the run is an active scan/execute run (shell counter), else nil —
    /// in which case the chronological fallback fills in a display number.
    public static func entries(
        taskRuns: [TaskRun],
        recoveryItems: [RecoveryItem],
        retentionDays: Int,
        planNumber: (TaskRun) -> Int?
    ) -> [AtlasLedgerEntryModel] {
        let runNumbers = chronologicalDisplayNumbers(for: taskRuns, planNumber: planNumber)
        var models: [AtlasLedgerEntryModel] = []
        models.reserveCapacity(taskRuns.count + recoveryItems.count)

        for run in taskRuns {
            let number = runNumbers[run.id] ?? 0
            models.append(entry(for: run, displayNumber: number))
        }
        for item in recoveryItems {
            models.append(entry(for: item, retentionDays: retentionDays))
        }
        return models
    }

    /// One task run → one ledger entry (pure). Status maps to the design
    /// system's `AtlasLedgerEntryStatus`; in-progress runs pin to the top.
    public static func entry(for run: TaskRun, displayNumber: Int) -> AtlasLedgerEntryModel {
        AtlasLedgerEntryModel(
            id: entryID(for: run),
            number: displayNumber,
            title: run.kind.title,
            detail: run.summary,
            metricText: metricText(for: run),
            status: status(for: run)
        )
    }

    /// One recovery item → one ledger entry (pure). Days-left is computed from
    /// the item's expiry; an expired/open window renders as `.archived`.
    public static func entry(for item: RecoveryItem, retentionDays: Int) -> AtlasLedgerEntryModel {
        AtlasLedgerEntryModel(
            id: entryID(for: item),
            number: 0, // recovery items are not plan-numbered; № belongs to the run
            title: item.title,
            detail: item.detail,
            metricText: AtlasFormatters.byteCount(item.bytes),
            status: status(for: item, now: Date())
        )
    }

    // MARK: Numbering rule (PER Decision Log 2026-06-10, spec §1.6)

    /// Assigns a display № to each task run:
    /// 1. If the shell's counter has a № for this run (`planNumber(for:)`),
    ///    use it directly.
    /// 2. Otherwise assign a chronological fallback: sort runs by activity
    ///    date descending, the newest gets `seedBase`, counting down by index.
    ///    `seedBase = max(runs.count, max(stored №)) + 1` so every fallback №
    ///    is **strictly greater** than any stored № (no collision) while a
    ///    later fresh counter allocation (which starts above runs.count) still
    ///    clears the fallback band. The `+ 1` is load-bearing — see the body.
    ///
    /// Returns a `[UUID: Int]` keyed by run id. Recovery items are not plan-
    /// numbered and are excluded.
    public static func chronologicalDisplayNumbers(
        for taskRuns: [TaskRun],
        planNumber: (TaskRun) -> Int?
    ) -> [UUID: Int] {
        // First pass: collect runs with a stored counter №.
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

        // Seed the highest fallback so it sits strictly above any stored
        // counter № AND above any future counter allocation (counter starts
        // at runs.count + 1, PER da8c42f). The `+ 1` is load-bearing: without
        // it, when `max(count, storedMax) == storedMax` the index-0 fallback
        // run would land on `seedBase - 0 == storedMax`, colliding with the
        // stored entry at that №. Adding 1 makes every fallback № strictly
        // greater than the stored max (and fresh allocations stay above the
        // run count, so they never collide with fallback either).
        let seedBase = max(taskRuns.count, result.values.max() ?? 0) + 1
        let sortedDesc = fallbackRuns.sorted { lhs, rhs in
            if lhs.activityDate == rhs.activityDate {
                return lhs.startedAt > rhs.startedAt
            }
            return lhs.activityDate > rhs.activityDate
        }
        for (index, run) in sortedDesc.enumerated() {
            // Newest unnumbered run = highest fallback, counting down.
            result[run.id] = seedBase - index
        }
        return result
    }

    // MARK: Status / metric (pure)

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

    private static func status(for item: RecoveryItem, now: Date) -> AtlasLedgerEntryStatus {
        guard let expiresAt = item.expiresAt else {
            return .verified // no expiry ⇒ permanently recoverable record
        }
        if expiresAt <= now {
            return .archived
        }
        let daysLeft = max(0, Calendar.current.dateComponents([.day], from: now, to: expiresAt).day ?? 0)
        return .recoverable(daysLeft: daysLeft)
    }

    private static func metricText(for run: TaskRun) -> String? {
        if let finished = run.finishedAt {
            return AtlasFormatters.shortDate(finished)
        }
        return AtlasL10n.string("ledger.timeline.metric.running")
    }
}

// MARK: - Timeline view (wraps AtlasLedgerTimeline)

/// Left-rail ledger timeline (spec §3). Delegates rendering to the design
/// system's `AtlasLedgerTimeline`; this view owns the `selection` binding so
/// the coordinator (LedgerFeatureView) can drive the detail panel from it.
public struct LedgerTimelineView: View {
    private let entries: [AtlasLedgerEntryModel]
    @Binding private var selection: String?

    public init(entries: [AtlasLedgerEntryModel], selection: Binding<String?>) {
        self.entries = entries
        self._selection = selection
    }

    public var body: some View {
        AtlasLedgerTimeline(entries: entries, selection: $selection)
    }
}

// MARK: - TaskRun helpers (file-private; mirrors legacy HistoryFeatureView scope)

private extension TaskRun {
    /// Activity date = finishedAt if present else startedAt (mirrors the
    /// legacy history view's grouping key — behavior preserved).
    var activityDate: Date {
        finishedAt ?? startedAt
    }

    var isActive: Bool {
        status == .queued || status == .running
    }

    /// "Recent archive" window = completed/failed/cancelled within 7 days
    /// (mirrors legacy HistoryFeatureView; behavior preserved).
    var isRecentArchive: Bool {
        guard !isActive else { return false }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return activityDate >= sevenDaysAgo
    }
}
