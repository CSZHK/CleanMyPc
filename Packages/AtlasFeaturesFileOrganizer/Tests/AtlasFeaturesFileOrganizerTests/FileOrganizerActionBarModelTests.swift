@testable import AtlasFeaturesFileOrganizer
import AtlasDesignSystem
import AtlasDomain
import XCTest

/// FileOrganizerActionBarModel.resolve — pure action-bar mapping (spec §2.3
/// five-segment table, right column). Every stage's primary intent + gating.
final class FileOrganizerActionBarModelTests: XCTestCase {

    private func inputs(
        effectiveStage: Int = FileOrganizerStage.scan,
        isReadOnly: Bool = false,
        isScanning: Bool = false,
        isClassifying: Bool = false,
        isExecuting: Bool = false,
        isRulesEmpty: Bool = false,
        canDryRun: Bool = true,
        canExecutePlan: Bool = true,
        scanProgress: Double = 0,
        selectedCount: Int = 0,
        selectedBytes: Int64 = 0,
        hasReceipt: Bool = false,
        receiptMovedCount: Int = 0,
        hasPlanNumber: Bool = false
    ) -> FileOrganizerActionBarModel.Inputs {
        .init(
            effectiveStage: effectiveStage, isReadOnly: isReadOnly,
            isScanning: isScanning, isClassifying: isClassifying, isExecuting: isExecuting,
            isRulesEmpty: isRulesEmpty, canDryRun: canDryRun, canExecutePlan: canExecutePlan,
            scanProgress: scanProgress, selectedCount: selectedCount, selectedBytes: selectedBytes,
            hasReceipt: hasReceipt, receiptMovedCount: receiptMovedCount, hasPlanNumber: hasPlanNumber
        )
    }

    // MARK: - Live task modes beat everything (progress capsule)

    func testScanningShowsProgressNoneIntent() {
        let m = FileOrganizerActionBarModel.resolve(inputs(isScanning: true, scanProgress: 0.42))
        XCTAssertEqual(m.intent, .none)
        XCTAssertFalse(m.isEnabled)
        XCTAssertEqual(m.progress, 0.42)
    }

    func testClassifyingShowsProgressNoneIntent() {
        let m = FileOrganizerActionBarModel.resolve(inputs(isClassifying: true))
        XCTAssertEqual(m.intent, .none)
        XCTAssertFalse(m.isEnabled)
    }

    func testExecutingShowsProgressNoneIntent() {
        let m = FileOrganizerActionBarModel.resolve(inputs(isExecuting: true, scanProgress: 0.7))
        XCTAssertEqual(m.intent, .none)
        XCTAssertEqual(m.progress, 0.7)
    }

    // MARK: - Read-only look-back

    func testReadOnlyReturnsToCurrent() {
        let m = FileOrganizerActionBarModel.resolve(inputs(isReadOnly: true))
        XCTAssertEqual(m.intent, .returnToCurrent)
        XCTAssertTrue(m.isEnabled)
    }

    // MARK: - Per-stage primary intents

    func testRulesStageDryRunIntentGatedBySelection() {
        // ② rules, selection present, can dry-run ⇒ dryRun intent, enabled.
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.rules, selectedCount: 3, selectedBytes: 1024))
        XCTAssertEqual(m.intent, .dryRun)
        XCTAssertTrue(m.isEnabled)
        XCTAssertNotNil(m.metricText)
        XCTAssertNotNil(m.promise)
    }

    func testRulesStageDryRunDisabledWhenNoSelection() {
        // ② rules, no selection ⇒ dryRun intent but disabled.
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.rules, selectedCount: 0))
        XCTAssertEqual(m.intent, .dryRun)
        XCTAssertFalse(m.isEnabled)
    }

    func testRulesStageEmptyDoesNotOfferDryRun() {
        // ② rules empty (isRulesEmpty) ⇒ falls through to default (rescan/scan).
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.rules, isRulesEmpty: true, hasPlanNumber: true))
        XCTAssertEqual(m.intent, .rescan)
        XCTAssertTrue(m.isEnabled)
    }

    func testPreviewStageExecuteIntent() {
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.preview, canExecutePlan: true))
        XCTAssertEqual(m.intent, .execute)
        XCTAssertTrue(m.isEnabled)
    }

    func testPreviewStageExecuteDisabledWhenPlanNotExecutable() {
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.preview, canExecutePlan: false))
        XCTAssertEqual(m.intent, .execute)
        XCTAssertFalse(m.isEnabled)
    }

    func testExecuteErrorStageViewReceiptGatedByReceipt() {
        // ④ error (settled) ⇒ viewReceipt, enabled only when a receipt exists.
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.execute, hasReceipt: true))
        XCTAssertEqual(m.intent, .viewReceipt)
        XCTAssertTrue(m.isEnabled)
    }

    func testExecuteErrorStageViewReceiptDisabledWithoutReceipt() {
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.execute, hasReceipt: false))
        XCTAssertEqual(m.intent, .viewReceipt)
        XCTAssertFalse(m.isEnabled)
    }

    func testReceiptStageRescanIntentWithMovedMetric() {
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.receipt, receiptMovedCount: 12, hasPlanNumber: true))
        XCTAssertEqual(m.intent, .rescan)
        XCTAssertTrue(m.isEnabled)
        XCTAssertNotNil(m.metricText)
    }

    func testScanIdleStageRescanWhenPlanNumberExists() {
        // ① idle with a prior plan № ⇒ "Rescan" (numbered), intent rescan.
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.scan, hasPlanNumber: true))
        XCTAssertEqual(m.intent, .rescan)
        XCTAssertTrue(m.isEnabled)
    }

    func testScanIdleStageScanWhenNoPlanNumber() {
        // ① idle, no prior plan ⇒ "Scan", intent rescan (same effect, different copy).
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.scan, hasPlanNumber: false))
        XCTAssertEqual(m.intent, .rescan)
        XCTAssertTrue(m.isEnabled)
    }

    // MARK: - metricText (mono selection metric, fail-closed)

    func testMetricTextNilForNoSelection() {
        XCTAssertNil(FileOrganizerActionBarModel.metricText(selectedBytes: 0, selectedCount: 0))
    }

    func testMetricTextFormatsBytesAndCount() {
        let text = FileOrganizerActionBarModel.metricText(selectedBytes: 1_048_576, selectedCount: 3)
        XCTAssertNotNil(text)
        XCTAssertTrue(text?.contains("3") == true)
    }
}
