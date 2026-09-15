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
        // Round-14: the execute stage is indeterminate — scanProgress is the
        // stale value from the prior scan (the worker reports progress only on
        // completion), so resolve must NOT echo it as a determinate value.
        XCTAssertNil(m.progress)
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

    /// 契约一 §1.2(3)（`P1-14`，与 `P1-11` 同构）：无可达回执时**不得渲染一个
    /// 点了不动的控件**。改为真实出口 + 「本次未生成回执」+ 最少可用信息。
    func testExecuteErrorStageWithoutReceiptOffersRealExit() {
        let m = FileOrganizerActionBarModel.resolve(inputs(
            effectiveStage: FileOrganizerStage.execute, hasReceipt: false))
        XCTAssertEqual(m.intent, .rescan)
        XCTAssertTrue(m.isEnabled, "failure path must not render a dead control (P1-14)")
        XCTAssertEqual(m.promise, AtlasL10n.string("action.receipt.missing.title"))
        XCTAssertNotNil(m.metricText, "minimum usable facts must be present")
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


/// `I-12`：任何渲染出的徽章/标签必须有对应动作，**或明确说明其只是分类**。
///
/// 载体（规格 §7）：`AtlasAppUITests` + **strings 文案断言**。这里是后半 ——
/// 断言这两个此前会**读成待办动作**的分类标签，用的是分类语。
/// （前半的动作侧由 `testReviewScreenHasNoConflictingInteractiveLabels` 覆盖。）
final class ClassificationLabelTests: XCTestCase {
    func testDuplicateBadgeDescribesTheActualCriterion() {
        // 判据只是「同名 + 同大小」，**不比对内容**。此前叫「重复文件」——
        // 用户直觉是「这些该处理掉」，而界面上既无法把它们聚到一起，
        // 也无法区分真重复与同名同大小的不同文件。
        let zh = AtlasL10n.string("fileorganizer.insight.duplicate.badge", language: .zhHans)
        XCTAssertEqual(zh, "同名同大小", "徽章必须如实描述判据，而不是断言「重复」")
        XCTAssertFalse(zh.contains("重复"), "「重复」隐含内容相同 —— 本仓库不比对内容")
    }

    func testConditionalSafetyLabelIsACategoryNotAnAction() {
        // en 是形容词风险等级（`Conditional`）；zh 曾译成动作「需确认」，
        // 用户会去找「确认」按钮，而这个 chip 只是分类标签、没有对应动作。
        XCTAssertEqual(AtlasL10n.string("evidence.safety.conditional", language: .zhHans), "有条件")
        XCTAssertEqual(AtlasL10n.string("evidence.safety.conditional", language: .en), "Conditional")
    }

    func testRiskChipDoesNotCollideWithTheReviewStageName() {
        // `P2-2`：阶段条（术语表的 `Review`）与风险 chip 同屏。两者不得同名 ——
        // 用户点阶段条是切步骤、点 chip 是筛风险。
        let stage = AtlasL10n.string("smartclean.stage.review", language: .zhHans)
        let chip = AtlasL10n.string("risk.review", language: .zhHans)
        XCTAssertNotEqual(stage, chip, "同屏两个不同动作的控件不得共用同一可见标签（I-7/I-12）")
    }
}
