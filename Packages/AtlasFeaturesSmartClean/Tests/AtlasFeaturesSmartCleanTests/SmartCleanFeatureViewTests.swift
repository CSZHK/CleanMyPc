import XCTest
@testable import AtlasFeaturesSmartClean
import AtlasDesignSystem
import AtlasDomain

@MainActor
final class SmartCleanFeatureViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AtlasL10n.setCurrentLanguage(.zhHans)
    }

    // MARK: - Evidence builder: why text

    func testWhyTextPrefersExplanationFieldAndFallsBackToGenerated() {
        var finding = Self.finding(risk: .safe)
        finding.explanation = "缓存可自动重建。"
        XCTAssertEqual(SmartCleanEvidenceBuilder.whyText(for: finding), "缓存可自动重建。")

        finding.explanation = nil
        let generated = SmartCleanEvidenceBuilder.whyText(for: finding)
        XCTAssertFalse(generated.isEmpty, "missing explanation falls back to the generated category explanation")
    }

    // MARK: - Evidence builder: KV rows

    func testEvidenceItemsCarryPathSizeCategoryAndSource() {
        var finding = Self.finding(risk: .safe)
        finding.targetPaths = ["/Users/t/Library/Caches/a.bin", "/Users/t/Library/Caches/b.bin"]
        let items = SmartCleanEvidenceBuilder.evidenceItems(for: finding)
        let ids = items.map(\.id)

        XCTAssertEqual(items.first?.id, "path")
        XCTAssertEqual(items.first?.value, "/Users/t/Library/Caches/a.bin")
        XCTAssertTrue(ids.contains("path.more"), "extra paths surface as a count row")
        XCTAssertTrue(ids.contains("size"))
        XCTAssertTrue(ids.contains("category"))
        XCTAssertTrue(ids.contains("source"))

        // No real path ⇒ no path rows at all (fail-closed: nothing invented).
        finding.targetPaths = nil
        let withoutPath = SmartCleanEvidenceBuilder.evidenceItems(for: finding).map(\.id)
        XCTAssertFalse(withoutPath.contains("path"))
        XCTAssertFalse(withoutPath.contains("path.more"))
    }

    // MARK: - Evidence builder: recovery (fail-closed)

    func testRecoveryTextIsFailClosed() {
        XCTAssertNil(SmartCleanEvidenceBuilder.recoveryText(planItem: nil, retentionDays: 7),
                     "no plan item ⇒ no recovery sentence")
        let nonRecoverable = ActionItem(title: "t", detail: "d", kind: .reviewEvidence, recoverable: false)
        XCTAssertNil(SmartCleanEvidenceBuilder.recoveryText(planItem: nonRecoverable, retentionDays: 7))
        let recoverable = ActionItem(title: "t", detail: "d", kind: .removeCache, recoverable: true)
        let text = SmartCleanEvidenceBuilder.recoveryText(planItem: recoverable, retentionDays: 14)
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("14") == true, "retention days come from the real setting")
    }

    func testAggregateCommonRecoveryOnlyWhenAllSelectedRecoverable() {
        let findings = [Self.finding(risk: .safe), Self.finding(risk: .review)]
        let allRecoverable = ActionPlan(
            title: "p",
            items: findings.map { ActionItem(id: $0.id, title: $0.title, detail: $0.detail, kind: .removeCache, recoverable: true) },
            estimatedBytes: 0
        )
        XCTAssertNotNil(
            SmartCleanEvidenceBuilder.aggregate(selectedFindings: findings, plan: allRecoverable, retentionDays: 7).commonRecoveryText
        )

        let mixed = ActionPlan(
            title: "p",
            items: [
                ActionItem(id: findings[0].id, title: "a", detail: "d", kind: .removeCache, recoverable: true),
                ActionItem(id: findings[1].id, title: "b", detail: "d", kind: .reviewEvidence, recoverable: false),
            ],
            estimatedBytes: 0
        )
        XCTAssertNil(
            SmartCleanEvidenceBuilder.aggregate(selectedFindings: findings, plan: mixed, retentionDays: 7).commonRecoveryText,
            "a single non-recoverable selection suppresses the common promise (fail-closed)"
        )
    }

    // MARK: - Promise 三式 (§1.6)

    func testPromiseThreeForms() {
        // 全部可恢复 → full sentence with retention days.
        let full = SmartCleanEvidenceBuilder.promise(recoverableCount: 3, totalCount: 3, retentionDays: 7)
        XCTAssertEqual(full, AtlasL10n.string("smartclean.promise.full", 7))

        // 部分 → X/Y sentence.
        let partial = SmartCleanEvidenceBuilder.promise(recoverableCount: 2, totalCount: 5, retentionDays: 7)
        XCTAssertEqual(partial, AtlasL10n.string("smartclean.promise.partial", 2, 5, 7))

        // 无可恢复 / 无选择 → no ⛨ sentence at all.
        XCTAssertNil(SmartCleanEvidenceBuilder.promise(recoverableCount: 0, totalCount: 4, retentionDays: 7))
        XCTAssertNil(SmartCleanEvidenceBuilder.promise(recoverableCount: 0, totalCount: 0, retentionDays: 7))
    }

    func testRecoveryStatsJudgeAgainstPlanMetadata() {
        let findings = [Self.finding(risk: .safe), Self.finding(risk: .safe), Self.finding(risk: .advanced)]
        let plan = ActionPlan(
            title: "p",
            items: [
                ActionItem(id: findings[0].id, title: "a", detail: "d", kind: .removeCache, recoverable: true),
                ActionItem(id: findings[1].id, title: "b", detail: "d", kind: .removeCache, recoverable: false),
                // findings[2] has NO plan item → counts as not recoverable.
            ],
            estimatedBytes: 0
        )
        let ids = Set(findings.map(\.id.uuidString))
        let stats = SmartCleanEvidenceBuilder.recoveryStats(selectedFindingIDs: ids, plan: plan)
        XCTAssertEqual(stats.recoverable, 1)
        XCTAssertEqual(stats.total, 3)
    }

    // MARK: - Stage predicates (回看只读 / effective stage / decision A)

    func testReadOnlyPredicate() {
        XCTAssertTrue(SmartCleanEvidenceBuilder.isReadOnly(displayedStage: 0, currentStage: 2))
        XCTAssertFalse(SmartCleanEvidenceBuilder.isReadOnly(displayedStage: 2, currentStage: 2))
        XCTAssertFalse(SmartCleanEvidenceBuilder.isReadOnly(displayedStage: 3, currentStage: 2))
    }

    // MARK: - Look-back disables every completed stage (review fix C1)

    func testReadOnlyAppliesToScanStageLookBack() {
        // Looking back at ① scan from any later stage (②/③/④) is read-only — the
        // old gap let ①'s 「开始扫描 / 重新校验」 stay tappable and silently overwrite
        // № / ④ receipt via runSmartCleanScan(). The container now disables the
        // whole stageContent subtree whenever isReadOnly is true.
        for current in [SmartCleanStage.review, SmartCleanStage.execute, SmartCleanStage.receipt] {
            XCTAssertTrue(
                SmartCleanEvidenceBuilder.isReadOnly(displayedStage: SmartCleanStage.scan, currentStage: current),
                "scan look-back from stage \(current) must be read-only"
            )
        }
        // The live scan stage is NOT read-only (the user is actually on ①).
        XCTAssertFalse(SmartCleanEvidenceBuilder.isReadOnly(displayedStage: SmartCleanStage.scan, currentStage: SmartCleanStage.scan))
    }

    func testScanStageViewConstructsWithoutReadOnlyParameter() {
        // The scan-stage view stayed parameter-free on the read-only axis — the
        // container-level `.disabled(isReadOnly)` enforces look-back instead.
        // This construction smoke guards the view shape against regressions.
        let view = SmartCleanScanStageView(
            isScanning: false,
            scanSummary: "",
            scanProgress: 0,
            hasCachedFindings: false,
            planIssue: nil,
            onStartScan: {},
            onRefreshPreview: {}
        )
        XCTAssertNotNil(view.body)
    }

    func testEffectiveStageFollowsCurrentAndAllowsLookBack() {
        // Look-back: displayed below current renders read-only at displayed.
        XCTAssertEqual(SmartCleanEvidenceBuilder.effectiveStage(displayedStage: 1, currentStage: 3, hasReceipt: true), 1)
        // Following the live stage (resolve-on-render: current is the truth).
        XCTAssertEqual(SmartCleanEvidenceBuilder.effectiveStage(displayedStage: 2, currentStage: 2, hasReceipt: false), 2)
        // A stale displayed value above current never leads the render…
        XCTAssertEqual(SmartCleanEvidenceBuilder.effectiveStage(displayedStage: 3, currentStage: 1, hasReceipt: false), 1)
        // …except the explicit failure-receipt jump (③ error + recorded receipt).
        XCTAssertEqual(
            SmartCleanEvidenceBuilder.effectiveStage(
                displayedStage: SmartCleanStage.receipt,
                currentStage: SmartCleanStage.execute,
                hasReceipt: true
            ),
            SmartCleanStage.receipt
        )
        XCTAssertEqual(
            SmartCleanEvidenceBuilder.effectiveStage(
                displayedStage: SmartCleanStage.receipt,
                currentStage: SmartCleanStage.execute,
                hasReceipt: false
            ),
            SmartCleanStage.execute,
            "no recorded receipt ⇒ the jump is refused (fail-closed)"
        )
    }

    func testCompletedStagesAreEveryIndexBelowTheBarCurrent() {
        XCTAssertEqual(SmartCleanEvidenceBuilder.completedStages(currentStage: 2, effectiveStage: 2), [0, 1])
        // Failure-receipt view: ③ stays reachable to return to the error state.
        XCTAssertEqual(SmartCleanEvidenceBuilder.completedStages(currentStage: 2, effectiveStage: 3), [0, 1, 2])
        XCTAssertEqual(SmartCleanEvidenceBuilder.completedStages(currentStage: 0, effectiveStage: 0), [])
    }

    // MARK: - Metric + search

    func testMetricTextMonoSelectionTotal() {
        XCTAssertNil(SmartCleanEvidenceBuilder.metricText(selectedBytes: 0, selectedCount: 0))
        let text = SmartCleanEvidenceBuilder.metricText(selectedBytes: 1_024, selectedCount: 2)
        XCTAssertEqual(text, AtlasL10n.string("smartclean.stage.metric.selected", AtlasFormatters.byteCount(1_024), 2))
    }

    func testSearchFilterMatchesTitleDetailCategoryRisk() {
        let findings = [
            Finding(title: "Xcode DerivedData", detail: "build cache", bytes: 1, risk: .safe, category: "Developer"),
            Finding(title: "Old backup", detail: "superseded archive", bytes: 1, risk: .review, category: "System"),
        ]
        XCTAssertEqual(SmartCleanEvidenceBuilder.searchFiltered(findings, query: "").count, 2)
        XCTAssertEqual(SmartCleanEvidenceBuilder.searchFiltered(findings, query: "xcode").count, 1)
        XCTAssertEqual(SmartCleanEvidenceBuilder.searchFiltered(findings, query: "archive").count, 1)
        XCTAssertEqual(SmartCleanEvidenceBuilder.searchFiltered(findings, query: "nothing-matches").count, 0)
    }

    // MARK: - Evidence panel state machine

    func testPanelStateRoutesByStage() {
        let findings = [Self.finding(risk: .safe)]
        let plan = ActionPlan(
            title: "p",
            items: [ActionItem(id: findings[0].id, title: "a", detail: "d", kind: .removeCache, recoverable: true)],
            estimatedBytes: 0
        )

        let single = SmartCleanEvidenceBuilder.panelState(
            effectiveStage: SmartCleanStage.review, isExecutionError: false, executionIssue: nil,
            evidenceSelectionID: findings[0].id.uuidString,
            findings: findings, selectedFindings: findings, plan: plan, retentionDays: 7
        )
        XCTAssertEqual(single.kind, .single)
        XCTAssertTrue(single.showsRecoveryBox, "recoverable plan item ⇒ ⛨ box")

        let aggregate = SmartCleanEvidenceBuilder.panelState(
            effectiveStage: SmartCleanStage.review, isExecutionError: false, executionIssue: nil,
            evidenceSelectionID: nil,
            findings: findings, selectedFindings: findings, plan: plan, retentionDays: 7
        )
        XCTAssertEqual(aggregate.kind, .aggregate)

        let executing = SmartCleanEvidenceBuilder.panelState(
            effectiveStage: SmartCleanStage.execute, isExecutionError: true, executionIssue: "helper offline",
            evidenceSelectionID: nil,
            findings: findings, selectedFindings: [], plan: plan, retentionDays: 7
        )
        guard case let .executing(rows) = executing else {
            return XCTFail("execute stage maps to the executing row stream")
        }
        XCTAssertEqual(rows.first?.status, .danger, "the real failure reason leads the stream")
        XCTAssertEqual(rows.first?.detail, "helper offline")

        let empty = SmartCleanEvidenceBuilder.panelState(
            effectiveStage: SmartCleanStage.scan, isExecutionError: false, executionIssue: nil,
            evidenceSelectionID: nil, findings: findings, selectedFindings: [], plan: plan, retentionDays: 7
        )
        XCTAssertEqual(empty.kind, .empty)
    }

    // MARK: - Receipt fail-closed badge

    func testReceiptRestorePointBadgeIsFailClosed() {
        var receipt = Self.receipt(recoveryItemIDs: [], recoveryBytes: 0)
        XCTAssertFalse(receipt.hasRestorePoint, "no recovery items ⇒ no stamp badge")
        receipt = Self.receipt(recoveryItemIDs: [UUID()], recoveryBytes: 0)
        XCTAssertFalse(receipt.hasRestorePoint, "zero bytes ⇒ no stamp badge")
        receipt = Self.receipt(recoveryItemIDs: [UUID()], recoveryBytes: 512)
        XCTAssertTrue(receipt.hasRestorePoint)
    }

    // MARK: - Toast undo gate aligned with receipt stamp (review fix #5)

    func testUndoGateRequiresRestorePointNotJustNonEmptyIDs() {
        // The undo action must use the SAME predicate as the ④ stamp badge
        // (hasRestorePoint = IDs non-empty AND bytes > 0). A run that recorded
        // recovery entries but zero bytes can't meaningfully undo, so neither
        // the toast action nor the receipt stamp should appear.
        let zeroBytes = Self.receipt(recoveryItemIDs: [UUID(), UUID()], recoveryBytes: 0)
        XCTAssertFalse(zeroBytes.hasRestorePoint, "zero bytes ⇒ no undo action offered")

        let realRestorePoint = Self.receipt(recoveryItemIDs: [UUID()], recoveryBytes: 1_024)
        XCTAssertTrue(realRestorePoint.hasRestorePoint, "IDs + bytes ⇒ undo action offered")
    }

    // MARK: - Fact-only failure receipt (review fix #4)

    func testFailureReceiptHasNoRestorePointAndCarriesReason() {
        // The executeCurrentPlan catch path builds a failure receipt with empty
        // recovery IDs / zero bytes and a failureReason. hasRestorePoint must be
        // false so neither the stamp nor the undo action nor the freed-bytes row
        // is rendered from unverified plan figures.
        let failure = SmartCleanExecutionReceipt(
            planNumber: 5,
            receiptCode: "CD34",
            completedAt: Date(timeIntervalSince1970: 1_700_000_001),
            executedItemCount: 3,
            estimatedFreedBytes: 2_048,
            summary: "helper offline",
            recoveryItemIDs: [],
            recoveryBytes: 0,
            retentionDays: 7,
            failureReason: "helper offline"
        )
        XCTAssertFalse(failure.hasRestorePoint, "failure path ⇒ no restore-point claim")
        XCTAssertEqual(failure.failureReason, "helper offline")
        // The planned count is still carried (labelled 「计划项目」 on the receipt),
        // but the freed-bytes row is suppressed because execution did not succeed.
        XCTAssertEqual(failure.executedItemCount, 3)
    }

    // MARK: - View construction smoke (new init shape)

    func testViewConstructsAcrossStages() {
        let findings = [Self.finding(risk: .safe)]
        let plan = ActionPlan(
            title: "p",
            items: [ActionItem(id: findings[0].id, title: "a", detail: "d", kind: .removeCache, recoverable: true)],
            estimatedBytes: 64
        )
        for stage in [SmartCleanStage.scan, SmartCleanStage.review, SmartCleanStage.execute, SmartCleanStage.receipt] {
            let view = SmartCleanFeatureView(
                findings: findings,
                plan: plan,
                state: SmartCleanWorkflowState(currentStage: stage, displayedStage: stage, planNumber: 3, receiptCode: "AB12")
            )
            XCTAssertNotNil(view.body)
        }
    }

    // MARK: - Fixtures

    private static func finding(risk: RiskLevel) -> Finding {
        Finding(
            title: "Fixture finding",
            detail: "Fixture detail",
            bytes: 1_024,
            risk: risk,
            category: "Developer"
        )
    }

    private static func receipt(recoveryItemIDs: [UUID], recoveryBytes: Int64) -> SmartCleanExecutionReceipt {
        SmartCleanExecutionReceipt(
            planNumber: 1,
            receiptCode: "AB12",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            executedItemCount: 1,
            estimatedFreedBytes: 1_024,
            summary: "done",
            recoveryItemIDs: recoveryItemIDs,
            recoveryBytes: recoveryBytes,
            retentionDays: 7
        )
    }

}
