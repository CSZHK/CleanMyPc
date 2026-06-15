import XCTest
@testable import AtlasFeaturesHistory
import AtlasDesignSystem
import AtlasDomain

@MainActor
final class LedgerFeatureViewTests: XCTestCase {

    // MARK: - View initialization (mirrors the legacy smoke tests)

    func testDefaultInitUsesFixtureData() {
        let view = LedgerFeatureView()
        XCTAssertNotNil(view, "LedgerFeatureView should initialize with default fixture data")
    }

    func testInitWithEmptyTaskRunsAndRecoveryItems() {
        let view = LedgerFeatureView(taskRuns: [], recoveryItems: [])
        XCTAssertNotNil(view)
    }

    func testInitWithSingleTaskRun() {
        let run = TaskRun(kind: .scan, status: .completed, summary: "Cleaned 500 MB", startedAt: Date(), finishedAt: Date())
        let view = LedgerFeatureView(taskRuns: [run], recoveryItems: [])
        XCTAssertNotNil(view)
    }

    func testInitWithSingleRecoveryItem() {
        let item = RecoveryItem(title: "Test Cache", detail: "Recovered cache", originalPath: "/Users/test/Library/Caches/test", bytes: 1_000_000, deletedAt: Date())
        let view = LedgerFeatureView(taskRuns: [], recoveryItems: [item])
        XCTAssertNotNil(view)
    }

    func testInitWithRestoringItemID() {
        let item = RecoveryItem(title: "Restoring", detail: "In progress", originalPath: "/Users/test/Library/Caches/test", bytes: 500_000, deletedAt: Date())
        let view = LedgerFeatureView(taskRuns: [], recoveryItems: [item], restoringItemID: item.id)
        XCTAssertNotNil(view)
    }

    func testCallbackActionCanBeStored() {
        var restoreTriggered = false
        let view = LedgerFeatureView(onRestoreItem: { _ in restoreTriggered = true })
        XCTAssertNotNil(view)
        XCTAssertFalse(restoreTriggered)
    }

    func testInitWithMultipleTaskRuns() {
        let runs = (0..<5).map { i in
            TaskRun(kind: i % 2 == 0 ? .scan : .uninstallApp, status: .completed, summary: "Run \(i)", startedAt: Date().addingTimeInterval(-Double(i) * 3600), finishedAt: Date().addingTimeInterval(-Double(i) * 3600 + 60))
        }
        let view = LedgerFeatureView(taskRuns: runs, recoveryItems: [])
        XCTAssertNotNil(view)
    }

    func testInitWithMixedStatuses() {
        let runs = [
            TaskRun(kind: .scan, status: .completed, summary: "Done", startedAt: Date(), finishedAt: Date()),
            TaskRun(kind: .executePlan, status: .failed, summary: "Failed", startedAt: Date(), finishedAt: nil),
            TaskRun(kind: .uninstallApp, status: .running, summary: "Running", startedAt: Date(), finishedAt: nil),
        ]
        let view = LedgerFeatureView(taskRuns: runs, recoveryItems: [])
        XCTAssertNotNil(view)
    }

    func testInitWithMultipleRecoveryItems() {
        let items = (0..<3).map { i in
            RecoveryItem(title: "Item \(i)", detail: "Detail \(i)", originalPath: "/Users/test/Library/Caches/item\(i)", bytes: Int64(i) * 1_000_000, deletedAt: Date().addingTimeInterval(-Double(i) * 86400))
        }
        let view = LedgerFeatureView(taskRuns: [], recoveryItems: items)
        XCTAssertNotNil(view)
    }

    func testInitWithPlanNumberClosure() {
        let run = TaskRun(kind: .scan, status: .running, summary: "Scanning", startedAt: Date())
        let view = LedgerFeatureView(taskRuns: [run], planNumber: { _ in 42 })
        XCTAssertNotNil(view)
    }
}
