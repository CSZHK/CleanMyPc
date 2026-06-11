import XCTest
@testable import AtlasFeaturesSmartClean
import AtlasDesignSystem
import AtlasDomain

@MainActor
final class SmartCleanActionBarModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AtlasL10n.setCurrentLanguage(.zhHans)
    }

    // MARK: - Action bar resolution (spec §2.3 right column)

    func testActionBarResolution() {
        // ① scanning → progress capsule, no primary intent.
        let scanning = SmartCleanActionBarModel.resolve(Self.inputs(isScanning: true, scanProgress: 0.4))
        XCTAssertEqual(scanning.intent, .none)
        XCTAssertEqual(scanning.progress, 0.4)

        // ② live → execute intent with promise + metric.
        let review = SmartCleanActionBarModel.resolve(Self.inputs(
            effectiveStage: SmartCleanStage.review,
            canExecutePlan: true, selectedCount: 3, selectedBytes: 2_048, recoverableCount: 3
        ))
        XCTAssertEqual(review.intent, .execute)
        XCTAssertTrue(review.isEnabled)
        XCTAssertEqual(review.promise, AtlasL10n.string("smartclean.promise.full", 7))
        XCTAssertNotNil(review.metricText)

        // ② live with empty selection → disabled primary, no ⛨ sentence.
        let noneSelected = SmartCleanActionBarModel.resolve(Self.inputs(
            effectiveStage: SmartCleanStage.review, canExecutePlan: true, selectedCount: 0
        ))
        XCTAssertFalse(noneSelected.isEnabled)
        XCTAssertNil(noneSelected.promise, "no selection ⇒ no ⛨ sentence")

        // Read-only look-back → single return action.
        let readOnly = SmartCleanActionBarModel.resolve(Self.inputs(effectiveStage: 0, isReadOnly: true))
        XCTAssertEqual(readOnly.intent, .returnToCurrent)

        // ③ error → view receipt, disabled until a receipt exists.
        let errorNoReceipt = SmartCleanActionBarModel.resolve(Self.inputs(effectiveStage: SmartCleanStage.execute))
        XCTAssertEqual(errorNoReceipt.intent, .viewReceipt)
        XCTAssertFalse(errorNoReceipt.isEnabled)

        // ④ → new scan via the rescan confirmation path; freed metric is real-valued.
        let receipt = SmartCleanActionBarModel.resolve(Self.inputs(
            effectiveStage: SmartCleanStage.receipt, hasReceipt: true, receiptFreedBytes: 4_096, hasPlanNumber: true
        ))
        XCTAssertEqual(receipt.intent, .rescan)
        XCTAssertEqual(receipt.metricText, AtlasFormatters.byteCount(4_096))

        // ① idle: scan without №, rescan (confirm path) with №.
        XCTAssertEqual(
            SmartCleanActionBarModel.resolve(Self.inputs(effectiveStage: 0)).title,
            AtlasL10n.string("smartclean.action.runScan")
        )
        XCTAssertEqual(
            SmartCleanActionBarModel.resolve(Self.inputs(effectiveStage: 0, hasPlanNumber: true)).title,
            AtlasL10n.string("smartclean.stage.actionbar.rescan")
        )
    }

    // MARK: - Fixtures

    private static func inputs(
        effectiveStage: Int = 0,
        isReadOnly: Bool = false,
        isScanning: Bool = false,
        isExecuting: Bool = false,
        isReviewZero: Bool = false,
        canExecutePlan: Bool = false,
        scanProgress: Double = 0,
        selectedCount: Int = 0,
        selectedBytes: Int64 = 0,
        recoverableCount: Int = 0,
        retentionDays: Int = 7,
        hasReceipt: Bool = false,
        receiptFreedBytes: Int64 = 0,
        hasPlanNumber: Bool = false
    ) -> SmartCleanActionBarModel.Inputs {
        SmartCleanActionBarModel.Inputs(
            effectiveStage: effectiveStage,
            isReadOnly: isReadOnly,
            isScanning: isScanning,
            isExecuting: isExecuting,
            isReviewZero: isReviewZero,
            canExecutePlan: canExecutePlan,
            scanProgress: scanProgress,
            selectedCount: selectedCount,
            selectedBytes: selectedBytes,
            recoverableCount: recoverableCount,
            retentionDays: retentionDays,
            hasReceipt: hasReceipt,
            receiptFreedBytes: receiptFreedBytes,
            hasPlanNumber: hasPlanNumber
        )
    }
}
