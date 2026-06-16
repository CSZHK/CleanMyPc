import XCTest
@testable import AtlasFeaturesHistory
import AtlasDesignSystem
import AtlasDomain

@MainActor
final class LedgerModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AtlasL10n.setCurrentLanguage(.zhHans)
    }

    // MARK: - Entry mapping: task run → entry (pure function)

    func testEntryMappingTaskRunWithStoredNumber() {
        let run = TaskRun(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A0")!,
            kind: .executePlan,
            status: .completed,
            summary: "Cleaned 1.2 GB",
            startedAt: Date(),
            finishedAt: Date()
        )
        let entry = LedgerEntryMapping.entry(for: run, displayNumber: 7)
        XCTAssertEqual(entry.id, "run.\(run.id.uuidString)")
        XCTAssertEqual(entry.number, 7)
        XCTAssertEqual(entry.title, run.kind.title)
        XCTAssertEqual(entry.detail, run.summary)
        XCTAssertEqual(entry.status, .verified)
        XCTAssertNotNil(entry.metricText)
    }

    func testEntryMappingTaskRunInProgressStatus() {
        let run = TaskRun(kind: .scan, status: .running, summary: "Scanning", startedAt: Date())
        let entry = LedgerEntryMapping.entry(for: run, displayNumber: 1)
        XCTAssertEqual(entry.status, .inProgress, "in-progress runs must pin to the timeline top")
    }

    func testEntryMappingTaskRunFailedStatusArchived() {
        let run = TaskRun(kind: .executePlan, status: .failed, summary: "Failed", startedAt: Date(), finishedAt: nil)
        let entry = LedgerEntryMapping.entry(for: run, displayNumber: 3)
        XCTAssertEqual(entry.status, .archived)
    }

    // MARK: - Entry mapping: recovery item → entry (pure function)

    func testEntryMappingRecoveryItemRecoverable() {
        let item = RecoveryItem(
            title: "Chrome Cache",
            detail: "Deleted cache",
            originalPath: "~/Library/Caches/Google/Chrome",
            bytes: 1_200_000_000,
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(6 * 86400) // ~6 days out
        )
        let entry = LedgerEntryMapping.entry(for: item, retentionDays: 7)
        XCTAssertEqual(entry.id, "recovery.\(item.id.uuidString)")
        XCTAssertEqual(entry.number, 0, "recovery items are not plan-numbered")
        XCTAssertEqual(entry.title, item.title)
        XCTAssertEqual(entry.detail, item.detail)

        if case .recoverable(let days) = entry.status {
            // 6 * 86400s truncates to 5 or 6 whole days depending on wall-clock
            // second at run time; assert the band rather than an exact value.
            XCTAssertTrue((5...6).contains(days), "days-left should be ~6, got \(days)")
        } else {
            XCTFail("expected .recoverable status, got \(entry.status)")
        }
    }

    func testEntryMappingRecoveryItemExpiredArchived() {
        let item = RecoveryItem(
            title: "Old Cache",
            detail: "Expired",
            originalPath: "~/Library/Caches/old",
            bytes: 1_000,
            deletedAt: Date().addingTimeInterval(-30 * 86400),
            expiresAt: Date().addingTimeInterval(-86400) // already expired
        )
        let entry = LedgerEntryMapping.entry(for: item, retentionDays: 7)
        XCTAssertEqual(entry.status, .archived)
    }

    func testEntryMappingRecoveryItemNoExpiryVerified() {
        let item = RecoveryItem(
            title: "Permanent",
            detail: "No expiry",
            originalPath: "~/Library/permanent",
            bytes: 500,
            deletedAt: Date(),
            expiresAt: nil
        )
        let entry = LedgerEntryMapping.entry(for: item, retentionDays: 7)
        XCTAssertEqual(entry.status, .verified, "no expiry ⇒ permanently recoverable record")
    }

    // MARK: - Selection resolution (non-clobbering invariant — round-9/15)

    /// A recovery item stays resolvable against the FULL set even when a filter
    /// chip (e.g. .archive) narrows it out of the rendered timeline. syncSelection
    /// keys off resolveSelection == .none, so this is what keeps an active
    /// selection from being silently clobbered on a filter change.
    func testResolveSelectionRecoveryItemSurvivesFilterNarrowing() {
        let item = RecoveryItem(
            title: "Chrome Cache", detail: "Deleted cache",
            originalPath: "~/Library/Caches/Google/Chrome",
            bytes: 1_200_000, deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(6 * 86400) // non-expired ⇒ filtered out by .archive
        )
        let id = LedgerEntryMapping.entryID(for: item)
        let resolved = LedgerEntryMapping.resolveSelection(id: id, taskRuns: [], recoveryItems: [item])
        guard case .recoveryItem(let found) = resolved else {
            return XCTFail("expected .recoveryItem — a valid recovery id must resolve against the full set")
        }
        XCTAssertEqual(found.id, item.id)
    }

    func testResolveSelectionTaskRun() {
        let run = TaskRun(id: UUID(), kind: .scan, status: .completed, summary: "s", startedAt: Date(), finishedAt: Date())
        let resolved = LedgerEntryMapping.resolveSelection(id: LedgerEntryMapping.entryID(for: run), taskRuns: [run], recoveryItems: [])
        guard case .taskRun(let found) = resolved else { return XCTFail("expected .taskRun") }
        XCTAssertEqual(found.id, run.id)
    }

    func testResolveSelectionNilAndStaleIDsAreNone() {
        XCTAssertEqual(LedgerEntryMapping.resolveSelection(id: nil, taskRuns: [], recoveryItems: []), .none)
        XCTAssertEqual(LedgerEntryMapping.resolveSelection(id: "run.deadbeef", taskRuns: [], recoveryItems: []), .none)
        XCTAssertEqual(LedgerEntryMapping.resolveSelection(id: "recovery.unknown", taskRuns: [], recoveryItems: []), .none)
    }

    // MARK: - Numbering rule (PER Decision Log 2026-06-10 / spec §1.6)

    func testChronologicalNumbersUseStoredWhenPresent() {
        let r1 = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!, kind: .scan, status: .running, summary: "1", startedAt: Date())
        let r2 = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!, kind: .scan, status: .completed, summary: "2", startedAt: Date().addingTimeInterval(-3600), finishedAt: Date().addingTimeInterval(-3500))
        let stored: [UUID: Int] = [r1.id: 42]
        let nums = LedgerEntryMapping.chronologicalDisplayNumbers(for: [r1, r2]) { run in stored[run.id] }
        XCTAssertEqual(nums[r1.id], 42, "stored counter number wins")
    }

    func testChronologicalFallbackNeverCollidesWithCounter() {
        // Three legacy runs (no stored №). Newest gets the highest fallback,
        // counting down. storedMax = 0, fallbackCount = 3, so the band is
        // [1, 3]: newest = 3, mid = 2, oldest = 1. Every fallback sits strictly
        // above the stored max (0 here) and all are distinct.
        let now = Date()
        let newest = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!, kind: .scan, status: .completed, summary: "newest", startedAt: now, finishedAt: now)
        let mid = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!, kind: .scan, status: .completed, summary: "mid", startedAt: now.addingTimeInterval(-3600), finishedAt: now.addingTimeInterval(-3500))
        let oldest = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!, kind: .scan, status: .completed, summary: "oldest", startedAt: now.addingTimeInterval(-7200), finishedAt: now.addingTimeInterval(-7100))
        let runs = [mid, newest, oldest] // shuffled input order
        let nums = LedgerEntryMapping.chronologicalDisplayNumbers(for: runs) { _ in nil }

        // newest = 3, mid = 2, oldest = 1 (newest highest, counting down).
        XCTAssertEqual(nums[newest.id], 3)
        XCTAssertEqual(nums[mid.id], 2)
        XCTAssertEqual(nums[oldest.id], 1)

        // No collisions: all distinct.
        let values = Array(nums.values)
        XCTAssertEqual(Set(values).count, values.count)
    }

    /// Multi-fallback regression (review round-1 fix): when several legacy runs
    /// coexist with a stored №, the OLD `max(count, storedMax) + 1` seed let
    /// lower-index fallbacks count DOWN into the stored band — e.g. stored 5 +
    /// 3 legacy runs yielded fallbacks 6/5/4, with 5 colliding with the stored 5.
    /// The strictly-above-storedMax band guarantees disjointness for any count.
    func testChronologicalFallbackManyRunsNeverCollideWithStored() {
        let now = Date()
        // One stored run (№5) + three pre-counter legacy runs.
        let stored = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000F1")!, kind: .scan, status: .running, summary: "stored", startedAt: now)
        let legacyNewest = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000F2")!, kind: .scan, status: .completed, summary: "legacy1", startedAt: now.addingTimeInterval(-3600), finishedAt: now.addingTimeInterval(-3500))
        let legacyMid = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000F3")!, kind: .scan, status: .completed, summary: "legacy2", startedAt: now.addingTimeInterval(-7200), finishedAt: now.addingTimeInterval(-7100))
        let legacyOldest = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000F4")!, kind: .scan, status: .completed, summary: "legacy3", startedAt: now.addingTimeInterval(-10800), finishedAt: now.addingTimeInterval(-10700))
        let runs = [stored, legacyNewest, legacyMid, legacyOldest]
        let nums = LedgerEntryMapping.chronologicalDisplayNumbers(for: runs) { run in
            run.id == stored.id ? 5 : nil
        }

        // storedMax = 5, fallbackCount = 3 ⇒ band = [6, 8]: 8 / 7 / 6.
        XCTAssertEqual(nums[stored.id], 5)
        XCTAssertEqual(nums[legacyNewest.id], 8, "newest legacy = storedMax + count = 8")
        XCTAssertEqual(nums[legacyMid.id], 7)
        XCTAssertEqual(nums[legacyOldest.id], 6)

        // Hard invariant: every fallback strictly above storedMax, and all
        // values distinct (no collision, any number of legacy runs).
        let allValues = Array(nums.values)
        XCTAssertEqual(Set(allValues).count, allValues.count, "no two runs share a №")
        let fallbackValues = [nums[legacyNewest.id]!, nums[legacyMid.id]!, nums[legacyOldest.id]!]
        XCTAssertTrue(fallbackValues.allSatisfy { $0 > 5 }, "every fallback strictly above stored max (5)")
    }

    /// Mixed stored + fallback: the `+ 1` on seedBase is load-bearing. Before
    /// the fix, when `max(count, storedMax) == storedMax` the index-0 fallback
    /// run landed on `seedBase - 0 == storedMax`, colliding with the stored
    /// entry at that №. With `+ 1` the fallback is `storedMax + 1` — strictly
    /// greater, genuinely no collision. (Renamed from
    /// `testChronologicalMixedStoredAndFallback` to make the non-collision
    /// invariant the test's name. Review fix I-1.)
    func testChronologicalMixedStoredAndFallbackStrictlyAboveStored() {
        let now = Date()
        let numbered = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!, kind: .scan, status: .running, summary: "stored", startedAt: now)
        let legacy = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!, kind: .scan, status: .completed, summary: "legacy", startedAt: now.addingTimeInterval(-3600), finishedAt: now.addingTimeInterval(-3500))
        let runs = [numbered, legacy]
        // seedBase = max(count=2, storedMax=5) + 1 = 6; legacy fallback (index 0) = 6.
        let nums = LedgerEntryMapping.chronologicalDisplayNumbers(for: runs) { run in
            run.id == numbered.id ? 5 : nil
        }
        XCTAssertEqual(nums[numbered.id], 5)
        XCTAssertEqual(nums[legacy.id], 6, "fallback must be strictly greater than the stored max (5); pre-fix this was 5 and collided")

        // The invariant the `+ 1` exists to enforce: no fallback № equals any
        // stored №. Pre-fix this would fail (5 == 5).
        let storedValues = Set([5])
        let fallbackValues = Set(nums.values).subtracting(storedValues)
        let allValues = Set(nums.values)
        XCTAssertEqual(fallbackValues.count + storedValues.intersection(allValues).count, allValues.count, "stored and fallback № sets must be disjoint")
        XCTAssertTrue(nums[legacy.id]! > 5, "fallback strictly above stored max")
    }

    /// Boundary lock for the `+ 1`: when the stored max equals `count - 1`
    /// (i.e. the stored band exactly fills the run indices below `count`), the
    /// fallback must still clear it. Without `+ 1`, seedBase would equal
    /// storedMax and the index-0 fallback would collide. This pins the fix so
    /// a future "tidy up the +1" cannot silently regress it. (Review fix I-1.)
    func testChronologicalFallbackClearsStoredMaxEqualsCountMinusOneBoundary() {
        let now = Date()
        // count = 3, stored max = 2 (= count - 1). One legacy run fills index 0.
        let stored1 = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000E1")!, kind: .scan, status: .completed, summary: "stored1", startedAt: now.addingTimeInterval(-100), finishedAt: now)
        let stored2 = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000E2")!, kind: .scan, status: .completed, summary: "stored2", startedAt: now.addingTimeInterval(-200), finishedAt: now.addingTimeInterval(-50))
        let legacy = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000E3")!, kind: .scan, status: .completed, summary: "legacy", startedAt: now.addingTimeInterval(-3600), finishedAt: now.addingTimeInterval(-3500))
        let runs = [stored1, stored2, legacy]
        let nums = LedgerEntryMapping.chronologicalDisplayNumbers(for: runs) { run in
            // stored1 → 1, stored2 → 2 (max = 2 = count - 1); legacy → fallback.
            switch run.id {
            case stored1.id: return 1
            case stored2.id: return 2
            default: return nil
            }
        }
        // storedMax = 2, fallbackCount = 1 ⇒ legacy = storedMax + 1 = 3. The
        // band floor is storedMax + 1, so legacy is strictly above every stored
        // № (1, 2) — never collides, at the exact count-1 boundary.
        XCTAssertEqual(nums[stored1.id], 1)
        XCTAssertEqual(nums[stored2.id], 2)
        XCTAssertEqual(nums[legacy.id], 3, "boundary: stored max == count-1; fallback = storedMax + 1 = 3 (strictly above the stored band)")

        // Hard lock: every fallback № strictly greater than every stored №.
        let storedValues = Set([1, 2])
        let legacyValue = nums[legacy.id]!
        XCTAssertTrue(storedValues.allSatisfy { legacyValue > $0 }, "fallback must exceed every stored № at the count-1 boundary")
    }

    // MARK: - Export builder (pure function)

    func testExportBuilderRendersFooterAndEntries() {
        let entry = LedgerExportBuilder.ExportEntry(
            id: "test-1",
            displayNumber: 7,
            kind: "智能清理扫描",
            status: "已完成",
            summary: "Cleaned 1.2 GB",
            startedAt: Date(),
            finishedAt: Date(),
            recoveryBytes: nil
        )
        let input = LedgerExportBuilder.Input(
            title: "维护台账报告",
            generatedAt: Date(),
            retentionDays: 7,
            entries: [entry],
            summary: LedgerExportBuilder.ExportSummary(taskRunCount: 1, recoveryItemCount: 0, totalRecoveryBytes: 0, activeTaskCount: 0)
        )
        let markdown = LedgerExportBuilder.render(input)

        XCTAssertTrue(markdown.contains("# 维护台账报告"), "report title heading")
        XCTAssertTrue(markdown.contains("№7"), "entry display number")
        XCTAssertTrue(markdown.contains("Cleaned 1.2 GB"), "entry summary as blockquote")
        XCTAssertTrue(markdown.contains("本报告由 Atlas 在本机生成"), "mandated footer disclaimer (zh)")
    }

    func testExportBuilderEmptyEntriesShowsPlaceholder() {
        let input = LedgerExportBuilder.Input(
            title: "Report",
            generatedAt: Date(),
            retentionDays: 7,
            entries: [],
            summary: LedgerExportBuilder.ExportSummary(taskRunCount: 0, recoveryItemCount: 0, totalRecoveryBytes: 0, activeTaskCount: 0)
        )
        let markdown = LedgerExportBuilder.render(input)
        XCTAssertTrue(markdown.contains("当前没有可见的台账条目"), "empty entries placeholder")
        XCTAssertTrue(markdown.contains("本报告由 Atlas"), "footer still present on empty report")
    }

    // MARK: - Filter chip mapping (legacy fields preserved)

    func testFilterAllMatchesEverything() {
        let item = RecoveryItem(title: "x", detail: "y", originalPath: "/p", bytes: 1, deletedAt: Date(), expiresAt: nil)
        XCTAssertTrue(LedgerFilter.all.matches(recovery: item))
    }

    func testFilterRecoverableExcludesExpired() {
        let live = RecoveryItem(title: "live", detail: "d", originalPath: "/p", bytes: 1, deletedAt: Date(), expiresAt: Date().addingTimeInterval(86400))
        let expired = RecoveryItem(title: "exp", detail: "d", originalPath: "/p", bytes: 1, deletedAt: Date(), expiresAt: Date().addingTimeInterval(-86400))
        XCTAssertTrue(LedgerFilter.recoverable.matches(recovery: live))
        XCTAssertFalse(LedgerFilter.recoverable.matches(recovery: expired))
    }

    func testFilterArchiveMatchesOnlyExpired() {
        let live = RecoveryItem(title: "live", detail: "d", originalPath: "/p", bytes: 1, deletedAt: Date(), expiresAt: Date().addingTimeInterval(86400))
        let expired = RecoveryItem(title: "exp", detail: "d", originalPath: "/p", bytes: 1, deletedAt: Date(), expiresAt: Date().addingTimeInterval(-86400))
        XCTAssertFalse(LedgerFilter.archive.matches(recovery: live))
        XCTAssertTrue(LedgerFilter.archive.matches(recovery: expired))
    }

    func testFilterCasesCoverLegacyFields() {
        // Legacy history screen had: all / expiring / apps / developer / browsers / system.
        // New ledger filter simplifies to all/recoverable/archive (spec §3 台账).
        XCTAssertEqual(LedgerFilter.allCases.count, 3)
    }
}
