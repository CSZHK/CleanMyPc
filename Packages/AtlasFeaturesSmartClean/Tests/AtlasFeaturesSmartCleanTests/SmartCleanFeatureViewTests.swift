import XCTest
@testable import AtlasFeaturesSmartClean
import AtlasDomain

@MainActor
final class SmartCleanFeatureViewTests: XCTestCase {

    // MARK: - View Initialization

    func testDefaultInitUsesFixtureData() {
        let view = SmartCleanFeatureView()
        XCTAssertNotNil(view, "SmartCleanFeatureView should initialize with default fixture data")
    }

    func testInitWithEmptyFindings() {
        let view = SmartCleanFeatureView(
            findings: [],
            plan: ActionPlan(title: "Empty", items: [], estimatedBytes: 0),
            isScanning: false,
            isExecutingPlan: false,
            isCurrentPlanFresh: false,
            canExecutePlan: false
        )
        XCTAssertNotNil(view)
    }

    func testInitWithScanRunning() {
        let view = SmartCleanFeatureView(
            findings: AtlasScaffoldFixtures.findings,
            plan: AtlasScaffoldFixtures.actionPlan,
            scanProgress: 0.5,
            isScanning: true,
            isExecutingPlan: false,
            isCurrentPlanFresh: false,
            canExecutePlan: false
        )
        XCTAssertNotNil(view)
    }

    func testInitWithExecutionRunning() {
        let view = SmartCleanFeatureView(
            findings: AtlasScaffoldFixtures.findings,
            plan: AtlasScaffoldFixtures.actionPlan,
            scanProgress: 0.75,
            isScanning: false,
            isExecutingPlan: true,
            isCurrentPlanFresh: true,
            canExecutePlan: false
        )
        XCTAssertNotNil(view)
    }

    func testInitWithPlanReadyToExecute() {
        let view = SmartCleanFeatureView(
            findings: AtlasScaffoldFixtures.findings,
            plan: AtlasScaffoldFixtures.actionPlan,
            isScanning: false,
            isExecutingPlan: false,
            isCurrentPlanFresh: true,
            canExecutePlan: true
        )
        XCTAssertNotNil(view)
    }

    func testInitWithPlanIssue() {
        let view = SmartCleanFeatureView(
            findings: [],
            plan: ActionPlan(title: "Error", items: [], estimatedBytes: 0),
            isScanning: false,
            isExecutingPlan: false,
            isCurrentPlanFresh: false,
            canExecutePlan: false,
            planIssue: "Scan unavailable"
        )
        XCTAssertNotNil(view)
    }

    func testInitWithExecutionIssue() {
        let view = SmartCleanFeatureView(
            findings: AtlasScaffoldFixtures.findings,
            plan: AtlasScaffoldFixtures.actionPlan,
            isScanning: false,
            isExecutingPlan: false,
            isCurrentPlanFresh: true,
            canExecutePlan: false,
            executionIssue: "Helper unavailable"
        )
        XCTAssertNotNil(view)
    }

    // MARK: - Callbacks

    func testCallbackActionsCanBeStored() async {
        var scanTriggered = false
        var refreshTriggered = false
        var executeTriggered = false

        let view = SmartCleanFeatureView(
            onStartScan: { scanTriggered = true },
            onRefreshPreview: { refreshTriggered = true },
            onExecutePlan: { executeTriggered = true }
        )

        XCTAssertNotNil(view)
        XCTAssertFalse(scanTriggered)
        XCTAssertFalse(refreshTriggered)
        XCTAssertFalse(executeTriggered)
    }

    // MARK: - Data Variations

    func testInitWithSingleFinding() {
        let finding = Finding(
            id: UUID(),
            title: "Test Cache",
            detail: "12 MB in test cache",
            bytes: 12_000_000,
            risk: .safe,
            category: "Developer tools",
            targetPaths: ["/Users/test/.cache/test"]
        )
        let plan = ActionPlan(
            title: "Clean 1 item",
            items: [
                ActionItem(
                    id: finding.id,
                    title: "Remove test cache",
                    detail: finding.detail,
                    kind: .removeCache,
                    recoverable: true,
                    targetPaths: ["/Users/test/.cache/test"]
                )
            ],
            estimatedBytes: finding.bytes
        )

        let view = SmartCleanFeatureView(
            findings: [finding],
            plan: plan,
            isScanning: false,
            isExecutingPlan: false,
            isCurrentPlanFresh: true,
            canExecutePlan: true
        )
        XCTAssertNotNil(view)
    }

    func testInitWithMultipleRiskLevels() {
        let findings = [
            Finding(id: UUID(), title: "Safe", detail: "Safe cache", bytes: 100, risk: .safe, category: "System"),
            Finding(id: UUID(), title: "Review", detail: "Review item", bytes: 200, risk: .review, category: "System"),
            Finding(id: UUID(), title: "Advanced", detail: "Advanced item", bytes: 300, risk: .advanced, category: "System"),
        ]
        let plan = ActionPlan(
            title: "Mixed plan",
            items: findings.map { ActionItem(id: $0.id, title: $0.title, detail: $0.detail, kind: .removeCache, recoverable: $0.risk != .advanced) },
            estimatedBytes: 600
        )

        let view = SmartCleanFeatureView(
            findings: findings,
            plan: plan,
            isCurrentPlanFresh: true,
            canExecutePlan: true
        )
        XCTAssertNotNil(view)
    }

    func testInitWithProgressStates() {
        for progress: Double in [0, 0.25, 0.5, 0.75, 1.0] {
            let view = SmartCleanFeatureView(
                scanProgress: progress,
                isScanning: progress > 0 && progress < 1
            )
            XCTAssertNotNil(view, "View should initialize with progress \(progress)")
        }
    }
}
