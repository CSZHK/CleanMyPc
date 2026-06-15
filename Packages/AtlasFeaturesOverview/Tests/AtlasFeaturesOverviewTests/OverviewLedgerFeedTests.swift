import XCTest
@testable import AtlasFeaturesOverview
import AtlasDesignSystem
import AtlasDomain
import Foundation

@MainActor
final class OverviewLedgerFeedTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_730_000_000)

    private func run(kind: TaskKind, status: TaskStatus, daysAgo: Double, id: UUID = UUID()) -> TaskRun {
        let started = now.addingTimeInterval(-daysAgo * 86_400)
        return TaskRun(
            id: id,
            kind: kind,
            status: status,
            summary: "summary-\(id.uuidString.prefix(4))",
            startedAt: started,
            finishedAt: status == .running || status == .queued ? nil : started.addingTimeInterval(60)
        )
    }

    // MARK: - feedData (wiring + recency + cap at 5)

    func testFeedDataCapsAtFiveMostRecent() {
        let runs = (1...10).map { i in
            run(kind: .scan, status: .completed, daysAgo: Double(i))
        }
        let feed = OverviewLedgerFeed.feedData(taskRuns: runs, planNumber: { _ in nil }, now: now)
        XCTAssertEqual(feed.entries.count, OverviewLedgerFeed.maxEntries)
        // The most recent run (1 day ago) should be first.
        XCTAssertEqual(feed.entries.first?.title, TaskKind.scan.title)
    }

    func testFeedDataEmptyForNoRuns() {
        let feed = OverviewLedgerFeed.feedData(taskRuns: [], planNumber: { _ in nil }, now: now)
        XCTAssertEqual(feed.entries.count, 0)
    }

    // MARK: - № chronological fallback rule (mirror of Batch J LedgerEntryMapping)

    func testStoredNumberWinsOverFallback() {
        // r1 has a stored №; r2 does not. The fallback for r2 must be
        // strictly greater than the stored № (no collision).
        let r1 = run(kind: .scan, status: .completed, daysAgo: 1)
        let r2 = run(kind: .scan, status: .completed, daysAgo: 2)
        let stored: [UUID: Int] = [r1.id: 42]
        let nums = OverviewLedgerFeed.chronologicalDisplayNumbers(
            for: [r1, r2],
            planNumber: { stored[$0.id] }
        )
        XCTAssertEqual(nums[r1.id], 42, "stored counter number wins")
        XCTAssertGreaterThan(nums[r2.id] ?? 0, 42, "fallback must be strictly greater than stored max")
    }

    func testFallbackNewestGetsHighestCountingDown() {
        // Three legacy runs (no stored №). Newest gets the highest fallback,
        // counting down by activity date. storedMax = 0, count = 3 ⇒ band [1, 3].
        let r1 = run(kind: .scan, status: .completed, daysAgo: 1) // newest
        let r2 = run(kind: .scan, status: .completed, daysAgo: 5)
        let r3 = run(kind: .scan, status: .completed, daysAgo: 10) // oldest
        let nums = OverviewLedgerFeed.chronologicalDisplayNumbers(
            for: [r1, r2, r3],
            planNumber: { _ in nil }
        )
        // Newest (r1) gets 3, then 2, 1 (newest highest, all distinct).
        XCTAssertEqual(nums[r1.id], 3)
        XCTAssertEqual(nums[r2.id], 2)
        XCTAssertEqual(nums[r3.id], 1)
    }

    /// Multi-fallback regression (review round-1 fix): with a stored № and ≥2
    /// legacy runs, the OLD `max(count, storedMax) + 1` seed counted fallbacks
    /// DOWN into the stored band (here r3 would have been 5, colliding with the
    /// stored 5). The strictly-above-storedMax band makes all fallbacks disjoint
    /// from the stored set for any count — no longer an "accepted" edge.
    func testFallbackDoesNotCollideWithStoredWhenStoredIsMax() {
        // count = 3, storedMax = 5 ⇒ fallback band = [6, 7] (storedMax + count).
        let r1 = run(kind: .scan, status: .completed, daysAgo: 1, id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let r2 = run(kind: .scan, status: .completed, daysAgo: 2)
        let r3 = run(kind: .scan, status: .completed, daysAgo: 3)
        let stored: [UUID: Int] = [r1.id: 5]
        let nums = OverviewLedgerFeed.chronologicalDisplayNumbers(
            for: [r1, r2, r3],
            planNumber: { stored[$0.id] }
        )
        XCTAssertEqual(nums[r1.id], 5, "stored wins")
        XCTAssertEqual(nums[r2.id], 7, "newer legacy run = storedMax + count = 7")
        XCTAssertEqual(nums[r3.id], 6, "older legacy run = storedMax + count - 1 = 6")
        // Hard invariant: stored and fallback sets are disjoint; all distinct.
        let allValues = Array(nums.values)
        XCTAssertEqual(Set(allValues).count, allValues.count, "no two runs share a №")
        XCTAssertTrue((nums[r2.id]! > 5) && (nums[r3.id]! > 5), "every fallback strictly above stored max (5) — no collision")
    }

    // MARK: Status / metric text wiring

    func testFeedEntryStatusInProgressForRunningRun() {
        let r = run(kind: .scan, status: .running, daysAgo: 0)
        let feed = OverviewLedgerFeed.feedData(taskRuns: [r], planNumber: { _ in nil }, now: now)
        XCTAssertEqual(feed.entries.first?.status, .inProgress)
    }

    func testFeedEntryStatusVerifiedForCompletedRun() {
        let r = run(kind: .scan, status: .completed, daysAgo: 1)
        let feed = OverviewLedgerFeed.feedData(taskRuns: [r], planNumber: { _ in nil }, now: now)
        XCTAssertEqual(feed.entries.first?.status, .verified)
    }

    func testFeedEntryStatusArchivedForFailedRun() {
        let r = run(kind: .scan, status: .failed, daysAgo: 1)
        let feed = OverviewLedgerFeed.feedData(taskRuns: [r], planNumber: { _ in nil }, now: now)
        XCTAssertEqual(feed.entries.first?.status, .archived)
    }

    func testFeedEntryMetricTextIsShortDateForFinishedRun() {
        let r = run(kind: .scan, status: .completed, daysAgo: 1)
        let feed = OverviewLedgerFeed.feedData(taskRuns: [r], planNumber: { _ in nil }, now: now)
        XCTAssertNotNil(feed.entries.first?.metricText)
        XCTAssertFalse(feed.entries.first?.metricText?.isEmpty ?? true)
    }

    func testFeedEntryMetricTextIsRunningLabelForUnfinishedRun() {
        let r = run(kind: .scan, status: .running, daysAgo: 0)
        let feed = OverviewLedgerFeed.feedData(taskRuns: [r], planNumber: { _ in nil }, now: now)
        XCTAssertEqual(feed.entries.first?.metricText, "进行中") // overview.feed.metric.running (zh default)
    }

    func testFeedEntryIdIsStableRunPrefix() {
        let r = run(kind: .scan, status: .completed, daysAgo: 1)
        let feed = OverviewLedgerFeed.feedData(taskRuns: [r], planNumber: { _ in nil }, now: now)
        XCTAssertEqual(feed.entries.first?.id, "run.\(r.id.uuidString)")
    }

    // MARK: - Plan number closure wiring

    func testPlanNumberClosurePassesThroughToEntries() {
        let r = run(kind: .executePlan, status: .completed, daysAgo: 1)
        let feed = OverviewLedgerFeed.feedData(
            taskRuns: [r],
            planNumber: { _ in 99 }
        )
        XCTAssertEqual(feed.entries.first?.number, 99)
    }
}
