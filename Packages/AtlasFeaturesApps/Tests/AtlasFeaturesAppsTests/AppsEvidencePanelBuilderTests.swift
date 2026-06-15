import XCTest
@testable import AtlasFeaturesApps
import AtlasDesignSystem
import AtlasDomain

@MainActor
final class AppsEvidencePanelBuilderTests: XCTestCase {

    // MARK: - Fixtures

    private func makeApp(
        evidenceSummary: [AtlasAppEvidenceCategory: Int]? = nil,
        leftoverItems: Int = 6
    ) -> AppFootprint {
        AppFootprint(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000aa")!,
            name: "Atlas Test App",
            bundleIdentifier: "com.atlas.test",
            bundlePath: "/Applications/Atlas Test.app",
            bytes: 1_200_000_000,
            leftoverItems: leftoverItems,
            evidenceSummary: evidenceSummary
        )
    }

    private func makePlan(recoverable: Bool, items: Int = 3, reviewOnlyBytes: Int64? = nil) -> ActionPlan {
        ActionPlan(
            title: "Atlas Test Plan",
            items: (0..<items).map { idx in
                ActionItem(
                    title: "item-\(idx)",
                    detail: "detail",
                    kind: .removeApp,
                    recoverable: recoverable,
                    targetPaths: ["/tmp/\(idx)"]
                )
            },
            estimatedBytes: 800_000_000,
            evidencePlanID: nil,
            estimatedReviewOnlyBytes: reviewOnlyBytes
        )
    }

    // MARK: - panelState

    func testPanelStateNilAppIsEmpty() {
        let state = AppsEvidencePanelBuilder.panelState(app: nil, previewPlan: nil, retentionDays: 14)
        XCTAssertEqual(state.kind, .empty)
    }

    func testPanelStateAppIsSingle() {
        let app = makeApp()
        let state = AppsEvidencePanelBuilder.panelState(app: app, previewPlan: nil, retentionDays: 14)
        XCTAssertEqual(state.kind, .single)
    }

    // MARK: - Fail-closed recovery

    func testRecoveryNilWhenNoPlan() {
        let app = makeApp()
        XCTAssertNil(AppsEvidencePanelBuilder.recoveryText(app: app, previewPlan: nil, retentionDays: 14))
    }

    func testRecoveryNilWhenNoRecoverableItems() {
        let app = makeApp()
        let plan = makePlan(recoverable: false)
        XCTAssertNil(AppsEvidencePanelBuilder.recoveryText(app: app, previewPlan: plan, retentionDays: 14))
    }

    func testRecoveryPresentWhenPlanHasRecoverable() {
        let app = makeApp()
        let plan = makePlan(recoverable: true, items: 2)
        let text = AppsEvidencePanelBuilder.recoveryText(app: app, previewPlan: plan, retentionDays: 14)
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("2"))
    }

    // MARK: - Footprint 10-category mapping

    func testFootprintCategoryItemsOmitsZeroAndAbsent() {
        let app = makeApp(evidenceSummary: [
            .appBundle: 1,
            .caches: 0,            // zero → omitted
            .logs: 3,
            // remaining 7 categories absent → omitted
        ])
        let items = AppsEvidencePanelBuilder.footprintCategoryItems(for: app)
        let labels = items.map(\.label)
        XCTAssertEqual(items.count, 2, "only the two non-zero categories render")
        XCTAssertEqual(labels, [AtlasAppEvidenceCategory.appBundle.title, AtlasAppEvidenceCategory.logs.title])
    }

    func testFootprintCategoryItemsEmptyWhenNoSummary() {
        let app = makeApp(evidenceSummary: nil)
        XCTAssertTrue(AppsEvidencePanelBuilder.footprintCategoryItems(for: app).isEmpty)
    }

    // MARK: - Leftover / residual estimates

    func testLeftoverEstimatePrefersFootprintTotal() {
        let app = makeApp(evidenceSummary: [.logs: 4, .caches: 2], leftoverItems: 1)
        XCTAssertEqual(AppsEvidencePanelBuilder.leftoverEstimate(app: app), 6)
    }

    func testLeftoverEstimateFallsBackToScalar() {
        let app = makeApp(evidenceSummary: nil, leftoverItems: 9)
        XCTAssertEqual(AppsEvidencePanelBuilder.leftoverEstimate(app: app), 9)
    }

    func testResidualEstimateNilWhenNoPlan() {
        XCTAssertNil(AppsEvidencePanelBuilder.residualEstimate(plan: nil))
    }

    func testResidualEstimateReclaimableOnly() {
        let plan = makePlan(recoverable: true, reviewOnlyBytes: nil)
        let text = AppsEvidencePanelBuilder.residualEstimate(plan: plan)
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("800"))
    }

    func testResidualEstimateWithReviewBytes() {
        let plan = makePlan(recoverable: true, reviewOnlyBytes: 120_000_000)
        let text = AppsEvidencePanelBuilder.residualEstimate(plan: plan)
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("120"))
    }

    // MARK: - Evidence items ordering (bundle leads)

    func testEvidenceItemsBundleLeads() {
        let app = makeApp(evidenceSummary: [.logs: 2])
        let items = AppsEvidencePanelBuilder.evidenceItems(for: app, previewPlan: nil)
        XCTAssertEqual(items.first?.id, "bundlePath")
        XCTAssertEqual(items.count, 4, "bundlePath + bundleBytes + leftoverItems + logs")
    }

    // MARK: - Action-bar gating

    func testActionBarHiddenWhenNoApp() {
        XCTAssertFalse(AppsEvidencePanelBuilder.shouldShowActionBar(
            selectedApp: nil, previewPlan: makePlan(recoverable: true), currentPreviewedAppID: nil))
    }

    func testActionBarHiddenWhenNoPlan() {
        let app = makeApp()
        XCTAssertFalse(AppsEvidencePanelBuilder.shouldShowActionBar(
            selectedApp: app, previewPlan: nil, currentPreviewedAppID: app.id))
    }

    func testActionBarHiddenWhenIDMismatch() {
        let app = makeApp()
        let otherID = UUID()
        XCTAssertFalse(AppsEvidencePanelBuilder.shouldShowActionBar(
            selectedApp: app, previewPlan: makePlan(recoverable: true), currentPreviewedAppID: otherID))
    }

    func testActionBarShownWhenAppSelectedAndPlanReadyAndIDMatches() {
        let app = makeApp()
        XCTAssertTrue(AppsEvidencePanelBuilder.shouldShowActionBar(
            selectedApp: app, previewPlan: makePlan(recoverable: true), currentPreviewedAppID: app.id))
    }

    // MARK: - Action-bar promise (three-form, fail-closed)

    func testPromiseNilWhenNoPlan() {
        XCTAssertNil(AppsEvidencePanelBuilder.actionBarPromise(plan: nil, retentionDays: 14))
    }

    func testPromiseNilWhenNoRecoverable() {
        let plan = makePlan(recoverable: false)
        XCTAssertNil(AppsEvidencePanelBuilder.actionBarPromise(plan: plan, retentionDays: 14))
    }

    func testPromiseFullWhenAllRecoverable() {
        let plan = makePlan(recoverable: true, items: 3)
        let text = AppsEvidencePanelBuilder.actionBarPromise(plan: plan, retentionDays: 14)
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("14"))
    }

    func testPromisePartialWhenMixed() {
        var items: [ActionItem] = [
            ActionItem(title: "r", detail: "", kind: .removeApp, recoverable: true, targetPaths: []),
            ActionItem(title: "n", detail: "", kind: .removeApp, recoverable: false, targetPaths: []),
        ]
        let plan = ActionPlan(title: "mixed", items: items, estimatedBytes: 100)
        _ = items
        let text = AppsEvidencePanelBuilder.actionBarPromise(plan: plan, retentionDays: 14)
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("1"))
        XCTAssertTrue(text!.contains("2"))
    }

    func testActionBarMetricNilWhenNoApp() {
        XCTAssertNil(AppsEvidencePanelBuilder.actionBarMetric(selectedApp: nil))
    }

    func testActionBarMetricFormatsBytes() {
        let app = makeApp()
        let text = AppsEvidencePanelBuilder.actionBarMetric(selectedApp: app)
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("1.2"))
    }

    // MARK: - whyText

    func testWhyTextIdleWithoutPlan() {
        let app = makeApp()
        let text = AppsEvidencePanelBuilder.whyText(for: app, previewPlan: nil)
        XCTAssertTrue(text.contains("Atlas Test App"))
    }

    func testWhyTextReadyWithPlan() {
        let app = makeApp()
        let text = AppsEvidencePanelBuilder.whyText(for: app, previewPlan: makePlan(recoverable: true))
        XCTAssertTrue(text.contains("Atlas Test App"))
        XCTAssertNotEqual(text, AppsEvidencePanelBuilder.whyText(for: app, previewPlan: nil))
    }
}
