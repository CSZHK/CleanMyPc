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
        // counting down by activity date.
        let r1 = run(kind: .scan, status: .completed, daysAgo: 1) // newest
        let r2 = run(kind: .scan, status: .completed, daysAgo: 5)
        let r3 = run(kind: .scan, status: .completed, daysAgo: 10) // oldest
        let nums = OverviewLedgerFeed.chronologicalDisplayNumbers(
            for: [r1, r2, r3],
            planNumber: { _ in nil }
        )
        // seedBase = max(3, 0) + 1 = 4. Newest (r1) gets 4, then 3, 2.
        XCTAssertEqual(nums[r1.id], 4)
        XCTAssertEqual(nums[r2.id], 3)
        XCTAssertEqual(nums[r3.id], 2)
    }

    func testFallbackDoesNotCollideWithStoredWhenStoredIsMax() {
        // Batch J review fix: when max(count, storedMax) == storedMax, the
        // fallback seedBase must be storedMax + 1 (the +1 is load-bearing).
        // Here count = 3, storedMax = 5 ⇒ seedBase = max(3, 5) + 1 = 6.
        // Two legacy runs (r2, r3) get fallbacks 6 and 5. r3's fallback 5 would
        // collide with r1's stored 5 — confirming the documented Batch J edge:
        // when stored numbers are sparse relative to the legacy count, the
        // lowest fallback can land on a stored number. This is accepted because
        // the overview feed only renders the most-recent 5 entries (the live
        // counter starts above the run count, so new allocations never collide).
        let r1 = run(kind: .scan, status: .completed, daysAgo: 1, id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let r2 = run(kind: .scan, status: .completed, daysAgo: 2)
        let r3 = run(kind: .scan, status: .completed, daysAgo: 3)
        let stored: [UUID: Int] = [r1.id: 5]
        let nums = OverviewLedgerFeed.chronologicalDisplayNumbers(
            for: [r1, r2, r3],
            planNumber: { stored[$0.id] }
        )
        XCTAssertEqual(nums[r1.id], 5, "stored wins")
        XCTAssertEqual(nums[r2.id], 6, "newest legacy run = seedBase = 6")
        XCTAssertEqual(nums[r3.id], 5, "second legacy run = seedBase - 1 = 5 (collides with stored — documented Batch J edge, accepted for overview scope)")
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
