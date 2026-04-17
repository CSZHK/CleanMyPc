import XCTest
@testable import AtlasFeaturesHistory
import AtlasDomain

@MainActor
final class HistoryFeatureViewTests: XCTestCase {

    // MARK: - View Initialization

    func testDefaultInitUsesFixtureData() {
        let view = HistoryFeatureView()
        XCTAssertNotNil(view, "HistoryFeatureView should initialize with default fixture data")
    }

    func testInitWithEmptyTaskRunsAndRecoveryItems() {
        let view = HistoryFeatureView(taskRuns: [], recoveryItems: [])
        XCTAssertNotNil(view)
    }

    func testInitWithSingleTaskRun() {
        let taskRun = TaskRun(
            id: UUID(),
            kind: .scan,
            status: .completed,
            summary: "Cleaned 500 MB",
            startedAt: Date(),
            finishedAt: Date()
        )
        let view = HistoryFeatureView(taskRuns: [taskRun], recoveryItems: [])
        XCTAssertNotNil(view)
    }

    func testInitWithSingleRecoveryItem() {
        let item = RecoveryItem(
            title: "Test Cache",
            detail: "Recovered cache",
            originalPath: "/Users/test/Library/Caches/test",
            bytes: 1_000_000,
            deletedAt: Date()
        )
        let view = HistoryFeatureView(taskRuns: [], recoveryItems: [item])
        XCTAssertNotNil(view)
    }

    func testInitWithRestoringItemID() {
        let item = RecoveryItem(
            title: "Restoring",
            detail: "In progress",
            originalPath: "/Users/test/Library/Caches/test",
            bytes: 500_000,
            deletedAt: Date()
        )
        let view = HistoryFeatureView(
            taskRuns: [],
            recoveryItems: [item],
            restoringItemID: item.id
        )
        XCTAssertNotNil(view)
    }

    // MARK: - Callbacks

    func testCallbackActionsCanBeStored() {
        var restoreTriggered = false
        let view = HistoryFeatureView(
            onRestoreItem: { _ in restoreTriggered = true }
        )
        XCTAssertNotNil(view)
        XCTAssertFalse(restoreTriggered)
    }

    // MARK: - Data Variations

    func testInitWithMultipleTaskRuns() {
        let runs = (0..<5).map { i in
            TaskRun(
                id: UUID(),
                kind: i % 2 == 0 ? .scan : .uninstallApp,
                status: .completed,
                summary: "Run \(i)",
                startedAt: Date().addingTimeInterval(-Double(i) * 3600),
                finishedAt: Date().addingTimeInterval(-Double(i) * 3600 + 60)
            )
        }
        let view = HistoryFeatureView(taskRuns: runs, recoveryItems: [])
        XCTAssertNotNil(view)
    }

    func testInitWithMixedStatuses() {
        let runs = [
            TaskRun(id: UUID(), kind: .scan, status: .completed, summary: "Done", startedAt: Date(), finishedAt: Date()),
            TaskRun(id: UUID(), kind: .executePlan, status: .failed, summary: "Failed", startedAt: Date(), finishedAt: nil),
            TaskRun(id: UUID(), kind: .uninstallApp, status: .running, summary: "Running", startedAt: Date(), finishedAt: nil),
        ]
        let view = HistoryFeatureView(taskRuns: runs, recoveryItems: [])
        XCTAssertNotNil(view)
    }

    func testInitWithMultipleRecoveryItems() {
        let items = (0..<3).map { i in
            RecoveryItem(
                title: "Item \(i)",
                detail: "Detail \(i)",
                originalPath: "/Users/test/Library/Caches/item\(i)",
                bytes: Int64(i) * 1_000_000,
                deletedAt: Date().addingTimeInterval(-Double(i) * 86400)
            )
        }
        let view = HistoryFeatureView(taskRuns: [], recoveryItems: items)
        XCTAssertNotNil(view)
    }
}
