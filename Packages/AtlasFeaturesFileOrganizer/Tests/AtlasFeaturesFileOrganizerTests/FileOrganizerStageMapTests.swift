@testable import AtlasFeaturesFileOrganizer
import AtlasDesignSystem
import AtlasDomain
import XCTest

/// FileOrganizerStageMap / StagePredicates — pure stage resolution (decision A,
/// resolve-on-render). Spec §2.3 five-segment mapping table, every row.
final class FileOrganizerStageMapTests: XCTestCase {

    // MARK: - Stage ordinals (spec §2.3 — five segments)

    func testStageOrdinalsAreFiveSegmentsContiguous() {
        XCTAssertEqual(FileOrganizerStage.count, 5)
        XCTAssertEqual(FileOrganizerStage.scan, 0)       // ① 扫描
        XCTAssertEqual(FileOrganizerStage.rules, 1)      // ② 规则
        XCTAssertEqual(FileOrganizerStage.preview, 2)    // ③ 预演
        XCTAssertEqual(FileOrganizerStage.execute, 3)    // ④ 执行
        XCTAssertEqual(FileOrganizerStage.receipt, 4)    // ⑤ 回执
    }

    // MARK: - resolve — precedence table (spec §2.3, every row)

    func testResolveNoPlanDefaultsToScan() {
        // No flags, no plan → ① scan (idle).
        let r = FileOrganizerStageMap.resolve(.init())
        XCTAssertEqual(r.current, FileOrganizerStage.scan)
        XCTAssertFalse(r.isScanInProgress)
        XCTAssertFalse(r.isRulesEmpty)
        XCTAssertFalse(r.isExecutionError)
    }

    func testResolveScanningInProgress() {
        // isScanning → ① scan, in-progress flag set.
        let r = FileOrganizerStageMap.resolve(.init(isScanning: true))
        XCTAssertEqual(r.current, FileOrganizerStage.scan)
        XCTAssertTrue(r.isScanInProgress)
    }

    func testResolveClassifyingInProgress() {
        // isClassifying → ① scan, in-progress flag set (classify is part of ①).
        let r = FileOrganizerStageMap.resolve(.init(isClassifying: true))
        XCTAssertEqual(r.current, FileOrganizerStage.scan)
        XCTAssertTrue(r.isScanInProgress)
    }

    func testResolvePlanFreshWithEntriesToRules() {
        // plan fresh, entries > 0 → ② rules.
        let r = FileOrganizerStageMap.resolve(.init(isPlanFresh: true, entriesCount: 3))
        XCTAssertEqual(r.current, FileOrganizerStage.rules)
        XCTAssertFalse(r.isRulesEmpty)
    }

    func testResolvePlanFreshZeroEntriesToRulesEmpty() {
        // plan fresh, 0 entries → ② rules, empty state.
        let r = FileOrganizerStageMap.resolve(.init(isPlanFresh: true, entriesCount: 0))
        XCTAssertEqual(r.current, FileOrganizerStage.rules)
        XCTAssertTrue(r.isRulesEmpty)
    }

    func testResolvePreviewResultsToPreview() {
        // dry-run results available → ③ preview.
        let r = FileOrganizerStageMap.resolve(.init(hasPreviewResults: true))
        XCTAssertEqual(r.current, FileOrganizerStage.preview)
    }

    func testResolveExecutingToExecute() {
        // live execution → ④ execute (running, not error).
        let r = FileOrganizerStageMap.resolve(.init(isExecuting: true))
        XCTAssertEqual(r.current, FileOrganizerStage.execute)
        XCTAssertFalse(r.isExecutionError)
    }

    func testResolveExecutionFailedToExecuteError() {
        // execution issue → ④ execute, error state.
        let r = FileOrganizerStageMap.resolve(.init(executionFailed: true))
        XCTAssertEqual(r.current, FileOrganizerStage.execute)
        XCTAssertTrue(r.isExecutionError)
    }

    func testResolveExecutionCompletedToReceipt() {
        // execution completed → ⑤ receipt.
        let r = FileOrganizerStageMap.resolve(.init(executionCompleted: true))
        XCTAssertEqual(r.current, FileOrganizerStage.receipt)
    }

    // MARK: - Precedence ordering (most live state wins)

    func testPrecedenceExecutingBeatsEverything() {
        // executing supersedes scanning, failed, completed, preview, plan.
        let r = FileOrganizerStageMap.resolve(.init(
            isScanning: true,
            isClassifying: true,
            isExecuting: true,
            executionFailed: true,
            executionCompleted: true,
            isPlanFresh: true,
            hasPreviewResults: true,
            entriesCount: 5
        ))
        XCTAssertEqual(r.current, FileOrganizerStage.execute)
        XCTAssertFalse(r.isExecutionError) // running, not error
    }

    func testPrecedenceScanningBeatsCompletedAndPlan() {
        // A new scan cycle supersedes a stale completion/plan.
        let r = FileOrganizerStageMap.resolve(.init(
            isScanning: true,
            executionCompleted: true,
            isPlanFresh: true,
            entriesCount: 5
        ))
        XCTAssertEqual(r.current, FileOrganizerStage.scan)
        XCTAssertTrue(r.isScanInProgress)
    }

    func testPrecedenceFailedBeatsCompletedAndPreview() {
        // failure (with no live scan/exec) surfaces the ④ error state over
        // a prior completion — the user sees what went wrong first.
        let r = FileOrganizerStageMap.resolve(.init(
            executionFailed: true,
            executionCompleted: true,
            hasPreviewResults: true
        ))
        XCTAssertEqual(r.current, FileOrganizerStage.execute)
        XCTAssertTrue(r.isExecutionError)
    }

    func testPrecedenceCompletedBeatsPreviewAndPlan() {
        // completed → ⑤ receipt beats a lingering preview/plan.
        let r = FileOrganizerStageMap.resolve(.init(
            executionCompleted: true,
            isPlanFresh: true,
            hasPreviewResults: true
        ))
        XCTAssertEqual(r.current, FileOrganizerStage.receipt)
    }

    func testPrecedencePreviewBeatsPlanFresh() {
        // dry-run results advance ② → ③ while the plan is still fresh.
        let r = FileOrganizerStageMap.resolve(.init(
            isPlanFresh: true,
            hasPreviewResults: true,
            entriesCount: 5
        ))
        XCTAssertEqual(r.current, FileOrganizerStage.preview)
    }

    // MARK: - Resolve consistency (determinism)

    func testResolveIsDeterministicAndEquatable() {
        // Same inputs ⇒ same resolution; resolution is Equatable.
        let inputs = FileOrganizerStageMap.Inputs(isPlanFresh: true, entriesCount: 2)
        let r1 = FileOrganizerStageMap.resolve(inputs)
        let r2 = FileOrganizerStageMap.resolve(inputs)
        XCTAssertEqual(r1, r2)
    }

    func testResolveScanAndClassifyBothProduceInProgress() {
        // Either scanning or classifying raises the in-progress flag.
        let a = FileOrganizerStageMap.resolve(.init(isScanning: true))
        let b = FileOrganizerStageMap.resolve(.init(isClassifying: true))
        XCTAssertEqual(a.current, b.current)
        XCTAssertEqual(a.isScanInProgress, b.isScanInProgress)
    }

    // MARK: - StagePredicates

    func testIsReadOnlyTrueWhenLookingBack() {
        // displayed < current ⇒ read-only look-back.
        XCTAssertTrue(FileOrganizerStagePredicates.isReadOnly(
            displayedStage: FileOrganizerStage.scan, currentStage: FileOrganizerStage.rules))
        XCTAssertTrue(FileOrganizerStagePredicates.isReadOnly(
            displayedStage: FileOrganizerStage.rules, currentStage: FileOrganizerStage.receipt))
    }

    func testIsReadOnlyFalseAtOrAheadOfCurrent() {
        XCTAssertFalse(FileOrganizerStagePredicates.isReadOnly(
            displayedStage: FileOrganizerStage.rules, currentStage: FileOrganizerStage.rules))
        XCTAssertFalse(FileOrganizerStagePredicates.isReadOnly(
            displayedStage: FileOrganizerStage.receipt, currentStage: FileOrganizerStage.rules))
    }

    func testEffectiveStageLookBackReturnsDisplayed() {
        // Look-back shows the displayed stage (clamped to ≥ scan).
        let s = FileOrganizerStagePredicates.effectiveStage(
            displayedStage: FileOrganizerStage.scan, currentStage: FileOrganizerStage.receipt, hasReceipt: true)
        XCTAssertEqual(s, FileOrganizerStage.scan)
    }

    func testEffectiveStageReceiptReachableFromExecuteErrorWhenReceiptExists() {
        // ④ error state → 「查看回执」 reaches ⑤ when a (partial) receipt exists.
        let s = FileOrganizerStagePredicates.effectiveStage(
            displayedStage: FileOrganizerStage.receipt,
            currentStage: FileOrganizerStage.execute,
            hasReceipt: true)
        XCTAssertEqual(s, FileOrganizerStage.receipt)
    }

    func testEffectiveStageReceiptNotReachableWithoutReceipt() {
        // No receipt record ⇒ cannot view ⑤ from ④ error (fail-closed).
        let s = FileOrganizerStagePredicates.effectiveStage(
            displayedStage: FileOrganizerStage.receipt,
            currentStage: FileOrganizerStage.execute,
            hasReceipt: false)
        XCTAssertEqual(s, FileOrganizerStage.execute)
    }

    func testEffectiveStageDefaultsToCurrent() {
        // displayed >= current (and not the receipt-from-execute case) ⇒ the
        // resolved current stage wins (not a look-back).
        let s = FileOrganizerStagePredicates.effectiveStage(
            displayedStage: FileOrganizerStage.preview,
            currentStage: FileOrganizerStage.rules,
            hasReceipt: false)
        XCTAssertEqual(s, FileOrganizerStage.rules)
    }

    func testCompletedStagesBeforeCurrent() {
        let stages = FileOrganizerStagePredicates.completedStages(
            currentStage: FileOrganizerStage.preview, effectiveStage: FileOrganizerStage.preview)
        XCTAssertEqual(stages, Set([FileOrganizerStage.scan, FileOrganizerStage.rules]))
    }
}
