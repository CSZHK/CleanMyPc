import XCTest
@testable import AtlasApp
import AtlasApplication
import AtlasDomain
import AtlasInfrastructure

@MainActor
final class AtlasWorkflowViewStateTests: XCTestCase {

    // MARK: - 1. Stage mapping (spec §2.3 table, row by row)

    func testStageMapNoPlanIsScanStage() {
        let r = AtlasWorkflowStageMap.resolve(.init())
        XCTAssertEqual(r, .init(current: AtlasWorkflowStageMap.scanStage))
    }

    func testStageMapScanningIsScanStageInProgress() {
        let r = AtlasWorkflowStageMap.resolve(.init(isScanning: true))
        XCTAssertEqual(r.current, AtlasWorkflowStageMap.scanStage)
        XCTAssertTrue(r.isScanInProgress)
    }

    func testStageMapFreshPlanIsReviewStage() {
        let r = AtlasWorkflowStageMap.resolve(.init(isPlanFresh: true, findingsCount: 3))
        XCTAssertEqual(r, .init(current: AtlasWorkflowStageMap.reviewStage))
    }

    func testStageMapExecutingIsExecuteStage() {
        let r = AtlasWorkflowStageMap.resolve(.init(isExecuting: true, isPlanFresh: true, findingsCount: 3))
        XCTAssertEqual(r, .init(current: AtlasWorkflowStageMap.executeStage))
    }

    func testStageMapExecutionCompletedIsReceiptStage() {
        let r = AtlasWorkflowStageMap.resolve(.init(executionCompleted: true))
        XCTAssertEqual(r, .init(current: AtlasWorkflowStageMap.receiptStage))
    }

    func testStageMapZeroFindingsIsEmptyReviewStage() {
        let r = AtlasWorkflowStageMap.resolve(.init(isPlanFresh: true, findingsCount: 0))
        XCTAssertEqual(r.current, AtlasWorkflowStageMap.reviewStage)
        XCTAssertTrue(r.isReviewEmpty)
    }

    func testStageMapExecutionFailureIsExecuteErrorStage() {
        let r = AtlasWorkflowStageMap.resolve(.init(executionFailed: true, isPlanFresh: true, findingsCount: 2))
        XCTAssertEqual(r.current, AtlasWorkflowStageMap.executeStage)
        XCTAssertTrue(r.isExecutionError)
    }

    func testStageMapPrecedenceLiveStatesWin() {
        // Executing beats everything else.
        let executing = AtlasWorkflowStageMap.resolve(
            .init(isScanning: true, isExecuting: true, executionFailed: true, executionCompleted: true)
        )
        XCTAssertEqual(executing.current, AtlasWorkflowStageMap.executeStage)
        XCTAssertFalse(executing.isExecutionError)

        // A new scan cycle supersedes stale completion/failure.
        let rescanning = AtlasWorkflowStageMap.resolve(
            .init(isScanning: true, executionFailed: true, executionCompleted: true)
        )
        XCTAssertEqual(rescanning.current, AtlasWorkflowStageMap.scanStage)
        XCTAssertTrue(rescanning.isScanInProgress)

        // Failure (fail-closed) beats completed.
        let failed = AtlasWorkflowStageMap.resolve(.init(executionFailed: true, executionCompleted: true))
        XCTAssertTrue(failed.isExecutionError)
    }

    // MARK: - 2. № increment, supersede, counter seeding

    func testAssignPlanNumberIncrementsAndSupersedeVoids() {
        let store = InMemoryLedgerNumberStore()
        let model = makeModel(ledgerNumberStore: store)

        model.assignPlanNumber(for: .smartClean, scanDate: Date(timeIntervalSince1970: 100))
        let first = model.workflowState(for: .smartClean)
        XCTAssertNotNil(first.planNumber)
        XCTAssertNotNil(first.receiptCode)
        XCTAssertEqual(first.currentStage, AtlasWorkflowStageMap.reviewStage)

        model.assignPlanNumber(for: .smartClean, scanDate: Date(timeIntervalSince1970: 200))
        let second = model.workflowState(for: .smartClean)
        XCTAssertEqual(second.planNumber, first.planNumber! + 1)

        model.supersedePlan(for: .smartClean)
        let superseded = model.workflowState(for: .smartClean)
        XCTAssertNil(superseded.planNumber)
        XCTAssertNil(superseded.receiptCode)
        XCTAssertEqual(superseded.currentStage, AtlasWorkflowStageMap.scanStage)
        XCTAssertEqual(superseded.displayedStage, AtlasWorkflowStageMap.scanStage)

        // The counter does NOT rewind on supersede — the next plan gets a fresh №.
        model.assignPlanNumber(for: .smartClean, scanDate: Date(timeIntervalSince1970: 300))
        XCTAssertEqual(model.workflowState(for: .smartClean).planNumber, first.planNumber! + 2)
    }

    func testLedgerCounterSeedsFromTaskRunCountPlusOne() {
        let store = InMemoryLedgerNumberStore()
        let model = makeModel(ledgerNumberStore: store)
        let expectedBase = model.snapshot.taskRuns.count + 1

        model.assignPlanNumber(for: .smartClean)

        XCTAssertEqual(store.recordedFallbackBases, [expectedBase])
        XCTAssertEqual(model.workflowState(for: .smartClean).planNumber, expectedBase)
    }

    func testUserDefaultsStoreSeedsPersistsAndAdvances() throws {
        let suiteName = "AtlasWorkflowViewStateTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AtlasUserDefaultsLedgerNumberStore(defaults: defaults)

        // First use: counter empty → seeds from fallbackBase, persists base+1.
        XCTAssertEqual(store.next(fallbackBase: 7), 7)
        XCTAssertEqual(defaults.integer(forKey: AtlasUserDefaultsLedgerNumberStore.defaultsKey), 8)

        // Subsequent uses ignore fallbackBase and advance monotonically.
        XCTAssertEqual(store.next(fallbackBase: 99), 8)
        XCTAssertEqual(store.next(fallbackBase: 1), 9)

        // Degenerate fallback never yields № < 1.
        let freshSuite = "AtlasWorkflowViewStateTests-\(UUID().uuidString)"
        let freshDefaults = try XCTUnwrap(UserDefaults(suiteName: freshSuite))
        defer { freshDefaults.removePersistentDomain(forName: freshSuite) }
        XCTAssertEqual(AtlasUserDefaultsLedgerNumberStore(defaults: freshDefaults).next(fallbackBase: 0), 1)
    }

    func testSmartCleanScanCompletionAssignsNumberAndReceipt() async throws {
        let store = InMemoryLedgerNumberStore()
        let model = makeModel(
            workerService: AtlasScaffoldWorkerService(
                repository: makeRepository(),
                smartCleanScanProvider: ScanFixtureProvider(),
                allowStateOnlyCleanExecution: true
            ),
            ledgerNumberStore: store
        )

        await model.runSmartCleanScan()

        let state = model.workflowState(for: .smartClean)
        XCTAssertTrue(model.isCurrentSmartCleanPlanFresh)
        XCTAssertNotNil(state.planNumber)
        let receipt = try XCTUnwrap(state.receiptCode)
        XCTAssertNotNil(receipt.range(of: "^[0-9A-F]{4}$", options: .regularExpression))
    }

    // MARK: - 3. Receipt determinism

    func testReceiptCodeIsDeterministicAndOrderInvariant() {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let findings = Self.fixtureFindings()

        let a = AtlasLedgerReceipt.code(findings: findings, scanDate: date)
        let b = AtlasLedgerReceipt.code(findings: findings.reversed(), scanDate: date)
        XCTAssertEqual(a, b, "same findings in any order + same timestamp ⇒ same receipt")
        XCTAssertTrue(a.range(of: "^[0-9A-F]{4}$", options: .regularExpression) != nil)

        let differentDate = AtlasLedgerReceipt.code(findings: findings, scanDate: date.addingTimeInterval(1))
        XCTAssertNotEqual(a, differentDate, "timestamp participates in the digest")

        var changedSize = findings
        changedSize[0] = Finding(
            id: changedSize[0].id,
            title: changedSize[0].title,
            detail: changedSize[0].detail,
            bytes: changedSize[0].bytes + 1,
            risk: changedSize[0].risk,
            category: changedSize[0].category
        )
        XCTAssertNotEqual(a, AtlasLedgerReceipt.code(findings: changedSize, scanDate: date), "size participates in the digest")
    }

    // MARK: - 4. ViewState survives route round-trips

    func testWorkflowStateSurvivesRouteRoundTrip() {
        let model = makeModel(ledgerNumberStore: InMemoryLedgerNumberStore())

        model.updateWorkflowState(for: .smartClean) { state in
            state.selectedIDs = ["a", "b"]
            state.riskFilter = "safe"
            state.displayedStage = 1
            state.evidenceSelectionID = "a"
        }

        model.navigate(to: .overview)
        model.navigate(to: .smartClean)

        let restored = model.workflowState(for: .smartClean)
        XCTAssertEqual(restored.selectedIDs, ["a", "b"])
        XCTAssertEqual(restored.riskFilter, "safe")
        XCTAssertEqual(restored.displayedStage, 1)
        XCTAssertEqual(restored.evidenceSelectionID, "a")

        // Routes are independently keyed — other routes stay pristine.
        XCTAssertEqual(model.workflowState(for: .fileOrganizer), AtlasWorkflowViewState())
    }

    // MARK: - 5. № change clears plan-scoped selection; rescan flag

    func testPlanNumberChangeClearsSelectionAndFilter() {
        let model = makeModel(ledgerNumberStore: InMemoryLedgerNumberStore())

        model.assignPlanNumber(for: .smartClean)
        model.updateWorkflowState(for: .smartClean) { state in
            state.selectedIDs = ["x", "y"]
            state.riskFilter = "review"
        }

        model.assignPlanNumber(for: .smartClean)

        let state = model.workflowState(for: .smartClean)
        XCTAssertTrue(state.selectedIDs.isEmpty, "№ change clears checked rows (spec §2.3)")
        XCTAssertNil(state.riskFilter, "№ change clears the plan-scoped filter")
    }

    func testRescanConfirmationFlagRaisesAndClearsOnSupersede() {
        let model = makeModel(ledgerNumberStore: InMemoryLedgerNumberStore())
        model.assignPlanNumber(for: .smartClean)

        model.requestRescanConfirmation(for: .smartClean)
        XCTAssertTrue(model.workflowState(for: .smartClean).rescanConfirmationPending)

        model.supersedePlan(for: .smartClean)
        XCTAssertFalse(model.workflowState(for: .smartClean).rescanConfirmationPending)

        // A completed assignment also clears a stale pending flag.
        model.requestRescanConfirmation(for: .smartClean)
        model.assignPlanNumber(for: .smartClean)
        XCTAssertFalse(model.workflowState(for: .smartClean).rescanConfirmationPending)
    }

    // MARK: - Helpers

    private func makeModel(
        workerService: (any AtlasWorkerServing)? = nil,
        ledgerNumberStore: any AtlasLedgerNumberStoring
    ) -> AtlasAppModel {
        AtlasAppModel(
            repository: makeRepository(),
            workerService: workerService ?? AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true),
            ledgerNumberStore: ledgerNumberStore
        )
    }

    private func makeRepository() -> AtlasWorkspaceRepository {
        AtlasWorkspaceRepository(
            stateFileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
                .appendingPathComponent("workspace-state.json")
        )
    }

    private static func fixtureFindings() -> [Finding] {
        [
            Finding(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                title: "Build cache",
                detail: "Derived data",
                bytes: 512_000,
                risk: .safe,
                category: "Developer"
            ),
            Finding(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                title: "Browser cache",
                detail: "Safari caches",
                bytes: 64_000,
                risk: .safe,
                category: "System"
            ),
            Finding(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                title: "Old runtime",
                detail: "Unused simulator runtime",
                bytes: 2_048_000,
                risk: .review,
                category: "Developer"
            ),
        ]
    }
}

// MARK: - Test doubles
// (InMemoryLedgerNumberStore moved to the shared test helper file so the
// legacy AtlasAppModelTests can inject it too — Batch H review fix.)

private struct ScanFixtureProvider: AtlasSmartCleanScanProviding {
    func collectSmartCleanScan() async throws -> AtlasSmartCleanScanResult {
        AtlasSmartCleanScanResult(
            findings: [
                Finding(
                    title: "Fixture cache",
                    detail: "Workflow fixture",
                    bytes: 1_024,
                    risk: .safe,
                    category: "Developer",
                    targetPaths: [
                        FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Library/Caches/AtlasWorkflowFixture.bin").path
                    ]
                )
            ],
            summary: "Workflow fixture scan found 1 reclaimable item."
        )
    }
}
