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
        // counting down — and all sit below seedBase = taskRuns.count.
        let now = Date()
        let newest = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!, kind: .scan, status: .completed, summary: "newest", startedAt: now, finishedAt: now)
        let mid = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!, kind: .scan, status: .completed, summary: "mid", startedAt: now.addingTimeInterval(-3600), finishedAt: now.addingTimeInterval(-3500))
        let oldest = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!, kind: .scan, status: .completed, summary: "oldest", startedAt: now.addingTimeInterval(-7200), finishedAt: now.addingTimeInterval(-7100))
        let runs = [mid, newest, oldest] // shuffled input order
        let nums = LedgerEntryMapping.chronologicalDisplayNumbers(for: runs) { _ in nil }

        // seedBase = taskRuns.count = 3; newest = 3, mid = 2, oldest = 1.
        XCTAssertEqual(nums[newest.id], 3)
        XCTAssertEqual(nums[mid.id], 2)
        XCTAssertEqual(nums[oldest.id], 1)

        // No collisions: all distinct.
        let values = Array(nums.values)
        XCTAssertEqual(Set(values).count, values.count)
    }

    func testChronologicalMixedStoredAndFallback() {
        let now = Date()
        let numbered = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!, kind: .scan, status: .running, summary: "stored", startedAt: now)
        let legacy = TaskRun(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!, kind: .scan, status: .completed, summary: "legacy", startedAt: now.addingTimeInterval(-3600), finishedAt: now.addingTimeInterval(-3500))
        let runs = [numbered, legacy]
        // max(taskRuns.count=2, stored max=5) = 5; legacy fallback = 5.
        let nums = LedgerEntryMapping.chronologicalDisplayNumbers(for: runs) { run in
            run.id == numbered.id ? 5 : nil
        }
        XCTAssertEqual(nums[numbered.id], 5)
        XCTAssertEqual(nums[legacy.id], 5, "fallback seeds above stored max; no collision risk with fresh allocations")
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
