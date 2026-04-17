import XCTest
@testable import AtlasFeaturesOverview
import AtlasApplication
import AtlasDomain

@MainActor
final class OverviewFeatureViewTests: XCTestCase {

    // MARK: - View Initialization

    func testDefaultInitUsesFixtureData() {
        let view = OverviewFeatureView()
        XCTAssertNotNil(view, "OverviewFeatureView should initialize with default fixture data")
    }

    func testInitWithEmptySnapshot() {
        var snapshot = AtlasScaffoldWorkspace.snapshot()
        snapshot.findings = []
        snapshot.taskRuns = []
        snapshot.recoveryItems = []
        let view = OverviewFeatureView(snapshot: snapshot)
        XCTAssertNotNil(view)
    }

    func testInitWithRefreshingState() {
        let view = OverviewFeatureView(isRefreshingHealthSnapshot: true)
        XCTAssertNotNil(view)
    }

    // MARK: - Callbacks

    func testCallbackActionsCanBeStored() {
        var smartCleanTriggered = false
        var navigateToSmartCleanTriggered = false
        var navigateToHistoryTriggered = false
        var navigateToPermissionsTriggered = false

        let view = OverviewFeatureView(
            onStartSmartClean: { smartCleanTriggered = true },
            onNavigateToSmartClean: { navigateToSmartCleanTriggered = true },
            onNavigateToHistory: { navigateToHistoryTriggered = true },
            onNavigateToPermissions: { navigateToPermissionsTriggered = true }
        )
        XCTAssertNotNil(view)
        XCTAssertFalse(smartCleanTriggered)
        XCTAssertFalse(navigateToSmartCleanTriggered)
        XCTAssertFalse(navigateToHistoryTriggered)
        XCTAssertFalse(navigateToPermissionsTriggered)
    }

    // MARK: - Data Variations

    func testInitWithHealthSnapshot() {
        var snapshot = AtlasScaffoldWorkspace.snapshot()
        snapshot.healthSnapshot = AtlasHealthSnapshot(
            memoryUsedGB: 8,
            memoryTotalGB: 16,
            diskUsedGB: 200,
            diskTotalGB: 500,
            diskUsedPercent: 40,
            uptimeDays: 7,
            optimizations: []
        )
        let view = OverviewFeatureView(snapshot: snapshot)
        XCTAssertNotNil(view)
    }

    func testInitWithHighDiskUsage() {
        var snapshot = AtlasScaffoldWorkspace.snapshot()
        snapshot.healthSnapshot = AtlasHealthSnapshot(
            memoryUsedGB: 14,
            memoryTotalGB: 16,
            diskUsedGB: 450,
            diskTotalGB: 500,
            diskUsedPercent: 90,
            uptimeDays: 30,
            optimizations: []
        )
        let view = OverviewFeatureView(snapshot: snapshot)
        XCTAssertNotNil(view)
    }

    func testInitWithNoHealthSnapshot() {
        var snapshot = AtlasScaffoldWorkspace.snapshot()
        snapshot.healthSnapshot = nil
        let view = OverviewFeatureView(snapshot: snapshot, isRefreshingHealthSnapshot: true)
        XCTAssertNotNil(view)
    }

    func testInitWithFindingsAndNoHealthSnapshot() {
        var snapshot = AtlasScaffoldWorkspace.snapshot()
        snapshot.healthSnapshot = nil
        snapshot.findings = [
            Finding(id: UUID(), title: "Cache", detail: "100 MB", bytes: 100_000_000, risk: .safe, category: "System", targetPaths: []),
        ]
        let view = OverviewFeatureView(snapshot: snapshot)
        XCTAssertNotNil(view)
    }

    func testInitWithManyFindings() {
        var snapshot = AtlasScaffoldWorkspace.snapshot()
        snapshot.findings = (0..<10).map { i in
            Finding(id: UUID(), title: "Finding \(i)", detail: "\(i * 10) MB", bytes: Int64(i * 10_000_000), risk: .safe, category: "System", targetPaths: [])
        }
        let view = OverviewFeatureView(snapshot: snapshot, onNavigateToSmartClean: {})
        XCTAssertNotNil(view)
    }
}
