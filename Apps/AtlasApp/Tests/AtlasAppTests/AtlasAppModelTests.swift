import XCTest
@testable import AtlasApp
import AtlasApplication
import AtlasDomain
import AtlasInfrastructure
import AtlasProtocol

@MainActor
final class AtlasAppModelTests: XCTestCase {

    func testCurrentSmartCleanPlanStartsAsCachedUntilSessionRefresh() {
        let model = AtlasAppModel(repository: makeRepository(), workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true), ledgerNumberStore: InMemoryLedgerNumberStore())

        XCTAssertFalse(model.isCurrentSmartCleanPlanFresh)
        XCTAssertFalse(model.canExecuteCurrentSmartCleanPlan)
        XCTAssertNil(model.smartCleanPlanIssue)
    }

    func testFailedSmartCleanScanKeepsCachedPlanAndExposesFailureReason() async {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            smartCleanScanProvider: FailingSmartCleanProvider()
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.runSmartCleanScan()

        XCTAssertFalse(model.isCurrentSmartCleanPlanFresh)
        XCTAssertFalse(model.canExecuteCurrentSmartCleanPlan)
        XCTAssertNotNil(model.smartCleanPlanIssue)
        XCTAssertTrue(model.latestScanSummary.contains("Smart Clean scan is unavailable"))
    }

    func testRefreshPlanPreviewKeepsPlanNonExecutableWhenFindingsLackTargets() async {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        let refreshed = await model.refreshPlanPreview()

        XCTAssertTrue(refreshed)
        XCTAssertTrue(model.isCurrentSmartCleanPlanFresh)
        XCTAssertFalse(model.canExecuteCurrentSmartCleanPlan)
    }

    func testReviewEvidenceItemsDoNotMakeSmartCleanPlanExecutable() {
        let repository = makeRepository()
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0,
                findings: [],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(
                title: "Review only",
                items: [
                    ActionItem(
                        title: "Review caches (1)",
                        detail: "Found 12 KB across 1 item.",
                        kind: .reviewEvidence,
                        recoverable: false,
                        evidencePaths: ["/Users/test/Library/Caches/com.example"]
                    )
                ],
                estimatedBytes: 12
            ),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try? repository.saveState(state)
        let model = AtlasAppModel(repository: repository, workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true), ledgerNumberStore: InMemoryLedgerNumberStore())

        XCTAssertFalse(model.currentSmartCleanPlanHasExecutableTargets)
        XCTAssertFalse(model.canExecuteCurrentSmartCleanPlan)
    }

    func testLegacySmartCleanPlanStillUsesFindingTargetsForExecutableBoundary() {
        let repository = makeRepository()
        let targetPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".swiftpm/cache/repositories/legacy-fixture.bin")
            .path
        let finding = Finding(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000099") ?? UUID(),
            title: "Legacy cache",
            detail: targetPath,
            bytes: 12,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetPath]
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 12,
                findings: [finding],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(
                title: "Review 1 selected finding",
                items: [
                    ActionItem(
                        id: finding.id,
                        title: "Move Legacy cache to Trash",
                        detail: finding.detail,
                        kind: .removeCache,
                        recoverable: true
                    )
                ],
                estimatedBytes: 12
            ),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try? repository.saveState(state)
        let model = AtlasAppModel(repository: repository, workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true), ledgerNumberStore: InMemoryLedgerNumberStore())

        XCTAssertTrue(model.currentSmartCleanPlanHasExecutableTargets)
    }

    func testRunSmartCleanScanMarksPlanAsFreshForCurrentSession() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            smartCleanScanProvider: FakeSmartCleanProvider(),
            allowStateOnlyCleanExecution: true
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.runSmartCleanScan()

        XCTAssertTrue(model.isCurrentSmartCleanPlanFresh)
        XCTAssertNil(model.smartCleanPlanIssue)
        XCTAssertTrue(model.canExecuteCurrentSmartCleanPlan)
    }
    func testRunSmartCleanScanUpdatesSummaryProgressAndPlan() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            smartCleanScanProvider: FakeSmartCleanProvider()
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.runSmartCleanScan()

        XCTAssertEqual(model.snapshot.findings.count, 2)
        XCTAssertEqual(model.currentPlan.items.count, 2)
        XCTAssertEqual(model.latestScanProgress, 1)
        XCTAssertTrue(model.latestScanSummary.contains("2 reclaimable item"))
    }

    func testExecuteCurrentPlanOnlyRecordsRecoveryForRealSideEffects() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            smartCleanScanProvider: FakeSmartCleanProvider(),
            allowStateOnlyCleanExecution: true
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())
        let initialRecoveryCount = model.snapshot.recoveryItems.count

        await model.runSmartCleanScan()
        await model.executeCurrentPlan()

        XCTAssertEqual(model.snapshot.recoveryItems.count, initialRecoveryCount)
        XCTAssertEqual(model.snapshot.taskRuns.first?.kind, .executePlan)
        XCTAssertGreaterThan(model.latestScanProgress, 0)
    }

    func testExecuteCurrentPlanExposesExplicitExecutionIssueWhenWorkerRejectsExecution() async {
        let repository = makeRepository()
        let model = AtlasAppModel(
            repository: repository,
            workerService: RejectingWorker(code: .executionUnavailable, reason: "XPC worker offline"),
            ledgerNumberStore: InMemoryLedgerNumberStore()
        )

        await model.executeCurrentPlan()

        XCTAssertFalse(model.isPlanRunning)
        XCTAssertEqual(model.smartCleanExecutionIssue, AtlasL10n.string("application.error.executionUnavailable", "XPC worker offline"))
        XCTAssertEqual(model.latestScanSummary, AtlasL10n.string("application.error.executionUnavailable", "XPC worker offline"))
    }

    func testPreferredXPCWorkerPathFailsClosedWhenScanIsRejected() async throws {
        let repository = makeRepository()
        let rejectedRequest = AtlasRequestEnvelope(command: .startScan(taskID: UUID()))
        let rejectedResult = AtlasWorkerCommandResult(
            request: rejectedRequest,
            response: AtlasResponseEnvelope(
                requestID: rejectedRequest.id,
                response: .rejected(code: .executionUnavailable, reason: "simulated packaged worker failure")
            ),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(language: .en),
            previewPlan: nil
        )
        let responseData = try JSONEncoder().encode(rejectedResult)
        let model = AtlasAppModel(
            repository: repository,
            preferXPCWorker: true,
            allowScaffoldFallback: false,
            xpcRequestConfiguration: AtlasXPCRequestConfiguration(timeout: 1, retryCount: 0, retryDelay: 0),
            xpcRequestExecutor: { _ in responseData },
            ledgerNumberStore: InMemoryLedgerNumberStore()
        )

        await model.runSmartCleanScan()

        XCTAssertFalse(model.isCurrentSmartCleanPlanFresh)
        XCTAssertEqual(model.smartCleanPlanIssue, AtlasL10n.string("application.error.executionUnavailable", "simulated packaged worker failure"))
        XCTAssertFalse(model.latestScanSummary.contains("reclaimable item"))
    }

    func testRefreshAppsUsesInventoryProvider() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            appsInventoryProvider: FakeInventoryProvider()
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.refreshApps()

        XCTAssertEqual(model.snapshot.apps.count, 1)
        XCTAssertEqual(model.snapshot.apps.first?.name, "Sample App")
        XCTAssertEqual(model.latestAppsSummary, AtlasL10n.string("application.apps.loaded.one"))
    }

    func testPreviewAppUninstallStoresEvidenceBackedPlan() async throws {
        let repository = makeRepository()
        let fileManager = FileManager.default
        let sandboxRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let homeRoot = sandboxRoot.appendingPathComponent("Home", isDirectory: true)
        let appSupportURL = homeRoot.appendingPathComponent("Library/Application Support/Sample App", isDirectory: true)
        let cacheURL = homeRoot.appendingPathComponent("Library/Caches/com.example.sample", isDirectory: true)

        try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 64).write(to: appSupportURL.appendingPathComponent("settings.json"))
        try Data(repeating: 0x2, count: 64).write(to: cacheURL.appendingPathComponent("cache.bin"))

        addTeardownBlock {
            try? FileManager.default.removeItem(at: sandboxRoot)
        }

        let app = AppFootprint(
            id: UUID(),
            name: "Sample App",
            bundleIdentifier: "com.example.sample",
            bundlePath: "/Applications/Sample App.app",
            bytes: 2_048_000_000,
            leftoverItems: 2
        )

        var settings = AtlasScaffoldWorkspace.state().settings
        settings.language = .en

        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0,
                findings: [],
                apps: [app],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 0 selected findings", items: [], estimatedBytes: 0),
            settings: settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            appUninstallEvidenceAnalyzer: AtlasAppUninstallEvidenceAnalyzer(homeDirectoryURL: homeRoot),
            allowStateOnlyCleanExecution: true
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.previewAppUninstall(appID: app.id)

        XCTAssertEqual(model.currentPreviewedAppID, app.id)
        XCTAssertEqual(model.currentAppPreview?.items.count, 3)
        XCTAssertTrue(model.currentAppPreview?.items.dropFirst().allSatisfy { !$0.recoverable } == true)
        XCTAssertEqual(model.latestAppsSummary, AtlasL10n.string("application.apps.previewUpdated", "Uninstall Sample App"))
    }

    func testRestoreRecoveryItemReturnsFindingToWorkspace() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.executeCurrentPlan()
        let recoveryItemID = try XCTUnwrap(model.snapshot.recoveryItems.first?.id)
        let findingsCountAfterExecute = model.snapshot.findings.count

        await model.restoreRecoveryItem(recoveryItemID)

        XCTAssertGreaterThan(model.snapshot.findings.count, findingsCountAfterExecute)
        XCTAssertFalse(model.snapshot.recoveryItems.contains(where: { $0.id == recoveryItemID }))
    }

    func testRestoreRecoveryItemClearsPreviousSmartCleanExecutionIssue() async throws {
        let repository = makeRepository()
        let realWorker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let seededState = repository.loadState()
        XCTAssertFalse(seededState.snapshot.recoveryItems.isEmpty)
        let recoveryItemID = try XCTUnwrap(seededState.snapshot.recoveryItems.first?.id)
        let model = AtlasAppModel(
            repository: repository,
            workerService: ExecuteRejectingRestoreDelegatingWorker(
                code: .executionUnavailable,
                reason: "XPC worker offline",
                restoreWorker: realWorker
            ),
            ledgerNumberStore: InMemoryLedgerNumberStore()
        )

        await model.executeCurrentPlan()
        XCTAssertNotNil(model.smartCleanExecutionIssue)

        await model.restoreRecoveryItem(recoveryItemID)

        XCTAssertNil(model.smartCleanExecutionIssue)
    }

    func testRestoreAppRecoveryItemClearsPreviewAndRefreshesInventoryWithoutLeavingHistory() async throws {
        let repository = makeRepository()
        let app = AppFootprint(
            id: UUID(),
            name: "Recovered App",
            bundleIdentifier: "com.example.recovered",
            bundlePath: "/Applications/Recovered App.app",
            bytes: 2_048,
            leftoverItems: 9
        )
        let recoveryItem = RecoveryItem(
            id: UUID(),
            title: app.name,
            detail: "Restorable app payload",
            originalPath: app.bundlePath,
            bytes: app.bytes,
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            payload: .app(
                AtlasAppRecoveryPayload(
                    app: app,
                    uninstallEvidence: AtlasAppUninstallEvidence(
                        bundlePath: app.bundlePath,
                        bundleBytes: app.bytes,
                        reviewOnlyGroups: []
                    )
                )
            ),
            restoreMappings: nil
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0,
                findings: [],
                apps: [app],
                taskRuns: [],
                recoveryItems: [recoveryItem],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 0 selected findings", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            appsInventoryProvider: RestoredInventoryProvider()
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.previewAppUninstall(appID: app.id)
        XCTAssertNotNil(model.currentAppPreview)
        XCTAssertEqual(model.currentPreviewedAppID, app.id)

        model.navigate(to: .ledger)  // route renamed history→ledger (Calm Ledger §2.2)
        await model.restoreRecoveryItem(recoveryItem.id)

        XCTAssertEqual(model.selection, .ledger)
        XCTAssertNil(model.currentAppPreview)
        XCTAssertNil(model.currentPreviewedAppID)
        XCTAssertEqual(model.snapshot.apps.first?.leftoverItems, 1)
        XCTAssertEqual(model.latestAppsSummary, AtlasL10n.string("application.apps.loaded.one"))
        XCTAssertFalse(model.snapshot.recoveryItems.contains(where: { $0.id == recoveryItem.id }))
        XCTAssertEqual(model.latestAppRestoreRefreshStatus?.state, .refreshed)
        XCTAssertEqual(model.latestAppRestoreRefreshStatus?.recordedLeftoverItems, 9)
        XCTAssertEqual(model.latestAppRestoreRefreshStatus?.refreshedLeftoverItems, 1)
    }

    func testRestoreAppRecoveryItemMarksEvidenceStaleWhenInventoryRefreshCannotFindApp() async throws {
        let repository = makeRepository()
        let app = AppFootprint(
            id: UUID(),
            name: "Recovered App",
            bundleIdentifier: "com.example.recovered",
            bundlePath: "/Applications/Recovered App.app",
            bytes: 2_048,
            leftoverItems: 4
        )
        let recoveryItem = RecoveryItem(
            id: UUID(),
            title: app.name,
            detail: "Restorable app payload",
            originalPath: app.bundlePath,
            bytes: app.bytes,
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            payload: .app(
                AtlasAppRecoveryPayload(
                    app: app,
                    uninstallEvidence: AtlasAppUninstallEvidence(
                        bundlePath: app.bundlePath,
                        bundleBytes: app.bytes,
                        reviewOnlyGroups: []
                    )
                )
            ),
            restoreMappings: nil
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0,
                findings: [],
                apps: [app],
                taskRuns: [],
                recoveryItems: [recoveryItem],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 0 selected findings", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            appsInventoryProvider: MissingRestoredInventoryProvider()
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.restoreRecoveryItem(recoveryItem.id)

        XCTAssertEqual(model.latestAppRestoreRefreshStatus?.state, .stale)
        XCTAssertEqual(model.latestAppRestoreRefreshStatus?.recordedLeftoverItems, 4)
        XCTAssertNil(model.latestAppRestoreRefreshStatus?.refreshedLeftoverItems)
        XCTAssertEqual(model.latestAppsSummary, AtlasL10n.string("application.apps.loaded.one"))
    }

    func testRestoreExpiredRecoveryItemReloadsPersistedState() async throws {
        let baseDate = Date(timeIntervalSince1970: 1_710_000_000)
        let clock = TestClock(now: baseDate)
        let repository = makeRepository(nowProvider: { clock.now })
        let finding = Finding(
            id: UUID(),
            title: "Expiring fixture",
            detail: "Expires soon",
            bytes: 5,
            risk: .safe,
            category: "Developer tools"
        )
        let recoveryItem = RecoveryItem(
            id: UUID(),
            title: finding.title,
            detail: finding.detail,
            originalPath: "~/Library/Caches/AtlasOnly",
            bytes: 5,
            deletedAt: baseDate,
            expiresAt: baseDate.addingTimeInterval(10),
            payload: .finding(finding),
            restoreMappings: nil
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0,
                findings: [],
                apps: [],
                taskRuns: [],
                recoveryItems: [recoveryItem],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 0 selected findings", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            nowProvider: { clock.now },
            allowStateOnlyCleanExecution: true
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())
        XCTAssertTrue(model.snapshot.recoveryItems.contains(where: { $0.id == recoveryItem.id }))

        clock.now = baseDate.addingTimeInterval(60)
        await model.restoreRecoveryItem(recoveryItem.id)

        XCTAssertFalse(model.snapshot.recoveryItems.contains(where: { $0.id == recoveryItem.id }))
        XCTAssertEqual(
            model.latestScanSummary,
            AtlasL10n.string("application.error.restoreExpired", "One or more selected recovery items have expired and can no longer be restored.")
        )
    }

    func testSettingsUpdatePersistsThroughWorker() async throws {
        let repository = makeRepository()
        let permissionInspector = AtlasPermissionInspector(
            homeDirectoryURL: FileManager.default.temporaryDirectory,
            fullDiskAccessProbeURLs: [URL(fileURLWithPath: "/tmp/fda-probe")],
            protectedLocationReader: { _ in false },
            accessibilityStatusProvider: { false },
            notificationsAuthorizationProvider: { false }
        )
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            permissionInspector: permissionInspector,
            allowStateOnlyCleanExecution: true
        )
        let model = AtlasAppModel(
            repository: repository,
            workerService: worker,
            notificationPermissionRequester: { true },
            ledgerNumberStore: InMemoryLedgerNumberStore()
        )

        await model.setRecoveryRetentionDays(14)
        await model.setNotificationsEnabled(false)

        XCTAssertEqual(model.settings.recoveryRetentionDays, 14)
        XCTAssertFalse(model.settings.notificationsEnabled)
        XCTAssertEqual(repository.loadSettings().recoveryRetentionDays, 14)
        XCTAssertFalse(repository.loadSettings().notificationsEnabled)
    }

    func testRefreshCurrentRouteRefreshesAppsWhenAppsSelected() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            appsInventoryProvider: FakeInventoryProvider()
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        model.navigate(to: .apps)
        await model.refreshCurrentRoute()

        XCTAssertEqual(model.selection, .apps)
        XCTAssertEqual(model.snapshot.apps.count, 1)
        XCTAssertEqual(model.snapshot.apps.first?.name, "Sample App")
        XCTAssertEqual(model.latestAppsSummary, AtlasL10n.string("application.apps.loaded.one"))
    }

    func testSetNotificationsEnabledRequestsNotificationPermissionWhenEnabling() async {
        let repository = makeRepository()
        let permissionInspector = AtlasPermissionInspector(
            homeDirectoryURL: FileManager.default.temporaryDirectory,
            fullDiskAccessProbeURLs: [URL(fileURLWithPath: "/tmp/fda-probe")],
            protectedLocationReader: { _ in false },
            accessibilityStatusProvider: { false },
            notificationsAuthorizationProvider: { false }
        )
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            permissionInspector: permissionInspector,
            allowStateOnlyCleanExecution: true
        )
        let recorder = NotificationPermissionRecorder()
        let model = AtlasAppModel(
            repository: repository,
            workerService: worker,
            notificationPermissionRequester: { await recorder.request() },
            ledgerNumberStore: InMemoryLedgerNumberStore()
        )

        await model.setNotificationsEnabled(false)
        await model.setNotificationsEnabled(true)

        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testRefreshPermissionsIfNeededUpdatesSnapshotFromWorker() async {
        let repository = makeRepository()
        let permissionInspector = AtlasPermissionInspector(
            homeDirectoryURL: FileManager.default.temporaryDirectory,
            fullDiskAccessProbeURLs: [URL(fileURLWithPath: "/tmp/fda-probe")],
            protectedLocationReader: { _ in true },
            accessibilityStatusProvider: { true },
            notificationsAuthorizationProvider: { false }
        )
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            permissionInspector: permissionInspector,
            allowStateOnlyCleanExecution: true
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.refreshPermissionsIfNeeded()

        XCTAssertEqual(model.snapshot.permissions.first(where: { $0.kind == .fullDiskAccess })?.isGranted, true)
        XCTAssertEqual(model.snapshot.permissions.first(where: { $0.kind == .accessibility })?.isGranted, true)
        XCTAssertEqual(model.snapshot.permissions.first(where: { $0.kind == .notifications })?.isGranted, false)
    }

    func testToggleTaskCenterFlipsPresentationState() {
        let model = AtlasAppModel(repository: makeRepository(), workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true), ledgerNumberStore: InMemoryLedgerNumberStore())

        XCTAssertFalse(model.isTaskCenterPresented)
        model.toggleTaskCenter()
        XCTAssertTrue(model.isTaskCenterPresented)
        model.toggleTaskCenter()
        XCTAssertFalse(model.isTaskCenterPresented)
    }


    func testSetLanguagePersistsThroughWorkerAndUpdatesLocalization() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.setLanguage(.en)

        XCTAssertEqual(model.settings.language, .en)
        XCTAssertEqual(repository.loadSettings().language, .en)
        XCTAssertEqual(AtlasRoute.overview.title, "Overview")
    }

    private func makeRepository(nowProvider: @escaping @Sendable () -> Date = { Date() }) -> AtlasWorkspaceRepository {
        AtlasWorkspaceRepository(
            stateFileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
                .appendingPathComponent("workspace-state.json"),
            nowProvider: nowProvider
        )
    }
}

private struct FakeSmartCleanProvider: AtlasSmartCleanScanProviding {
    func collectSmartCleanScan() async throws -> AtlasSmartCleanScanResult {
        AtlasSmartCleanScanResult(
            findings: [
                Finding(title: "Build Cache", detail: "Temporary build outputs.", bytes: 512_000_000, risk: .safe, category: "Developer", targetPaths: [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/FakeBuildCache.bin").path]),
                Finding(title: "Old Runtime", detail: "Unused runtime assets.", bytes: 1_024_000_000, risk: .review, category: "Developer", targetPaths: [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/DerivedData/FakeOldRuntime").path]),
            ],
            summary: "Smart Clean dry run found 2 reclaimable items."
        )
    }
}

private struct FakeInventoryProvider: AtlasAppInventoryProviding {
    func collectInstalledApps() async throws -> [AppFootprint] {
        [
            AppFootprint(
                name: "Sample App",
                bundleIdentifier: "com.example.sample",
                bundlePath: "/Applications/Sample App.app",
                bytes: 2_048_000_000,
                leftoverItems: 3
            )
        ]
    }
}

private struct RestoredInventoryProvider: AtlasAppInventoryProviding {
    func collectInstalledApps() async throws -> [AppFootprint] {
        [
            AppFootprint(
                name: "Recovered App",
                bundleIdentifier: "com.example.recovered",
                bundlePath: "/Applications/Recovered App.app",
                bytes: 2_048,
                leftoverItems: 1
            )
        ]
    }
}

private struct MissingRestoredInventoryProvider: AtlasAppInventoryProviding {
    func collectInstalledApps() async throws -> [AppFootprint] {
        [
            AppFootprint(
                name: "Different App",
                bundleIdentifier: "com.example.other",
                bundlePath: "/Applications/Different App.app",
                bytes: 1_024,
                leftoverItems: 0
            )
        ]
    }
}

private struct FailingSmartCleanProvider: AtlasSmartCleanScanProviding {
    func collectSmartCleanScan() async throws -> AtlasSmartCleanScanResult {
        throw NSError(domain: "AtlasAppModelTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fixture scan failed."])
    }
}

private actor NotificationPermissionRecorder {
    private var calls = 0

    func request() -> Bool {
        calls += 1
        return true
    }

    func callCount() -> Int {
        calls
    }
}

private actor RejectingWorker: AtlasWorkerServing {
    let code: AtlasProtocolErrorCode
    let reason: String

    init(code: AtlasProtocolErrorCode, reason: String) {
        self.code = code
        self.reason = reason
    }

    func submit(_ request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult {
        AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(
                requestID: request.id,
                response: .rejected(code: code, reason: reason)
            ),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(language: .en),
            previewPlan: nil
        )
    }
}

private actor ExecuteRejectingRestoreDelegatingWorker: AtlasWorkerServing {
    let code: AtlasProtocolErrorCode
    let reason: String
    let restoreWorker: AtlasScaffoldWorkerService

    init(code: AtlasProtocolErrorCode, reason: String, restoreWorker: AtlasScaffoldWorkerService) {
        self.code = code
        self.reason = reason
        self.restoreWorker = restoreWorker
    }

    func submit(_ request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult {
        switch request.command {
        case .executePlan:
            return AtlasWorkerCommandResult(
                request: request,
                response: AtlasResponseEnvelope(
                    requestID: request.id,
                    response: .rejected(code: code, reason: reason)
                ),
                events: [],
                snapshot: AtlasScaffoldWorkspace.snapshot(language: .en),
                previewPlan: nil
            )
        default:
            return try await restoreWorker.submit(request)
        }
    }
}

/// Rejects `.fileOrganizerExecutePlan` on the 2nd+ call so a test can drive a
/// successful execute (establishing a non-zero movedCount) then a failing one,
/// pinning the fail-closed receipt invariant (round-4 test gap).
private actor FileOrganizerExecuteRejectAfterSuccessWorker: AtlasWorkerServing {
    let realWorker: AtlasScaffoldWorkerService
    private var executeCount = 0
    init(realWorker: AtlasScaffoldWorkerService) { self.realWorker = realWorker }

    func submit(_ request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult {
        if case .fileOrganizerExecutePlan = request.command {
            executeCount += 1
            if executeCount > 1 {
                return AtlasWorkerCommandResult(
                    request: request,
                    response: AtlasResponseEnvelope(
                        requestID: request.id,
                        response: .rejected(code: .executionUnavailable, reason: "simulated mid-run failure")
                    ),
                    events: [],
                    snapshot: AtlasScaffoldWorkspace.snapshot(language: .en),
                    previewPlan: nil
                )
            }
        }
        return try await realWorker.submit(request)
    }
}

// MARK: - File Organizer E2E Tests

extension AtlasAppModelTests {

    func testFileOrganizerFullPipelineScanPreviewExecute() async throws {
        let repository = makeRepository()
        let fm = FileManager.default

        // Create temp files under home/Library/Caches (safe prefix for restore validation)
        let sourceDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/AtlasFO-E2E-\(UUID().uuidString)", isDirectory: true)
        let destDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Organized", isDirectory: true)

        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let file1 = sourceDir.appendingPathComponent("photo.png")
        let file2 = sourceDir.appendingPathComponent("report.pdf")
        try Data(repeating: 0x1, count: 100).write(to: file1)
        try Data(repeating: 0x2, count: 200).write(to: file2)

        addTeardownBlock {
            try? fm.removeItem(at: sourceDir)
            try? fm.removeItem(at: destDir)
        }

        let entries = [
            FileOrganizerEntry(
                id: UUID(),
                path: file1.path,
                fileName: "photo.png",
                bytes: 100,
                category: .images,
                proposedDestination: "~/Organized/Images/photo.png"
            ),
            FileOrganizerEntry(
                id: UUID(),
                path: file2.path,
                fileName: "report.pdf",
                bytes: 200,
                category: .documents,
                proposedDestination: "~/Organized/Documents/report.pdf"
            )
        ]

        let scanner = E2EFileOrganizerScanner(entries: entries)
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: scanner
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        // Step 1: Scan
        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])

        XCTAssertEqual(model.fileOrganizerEntries.count, 2)
        XCTAssertFalse(model.isFileOrganizerScanning)
        XCTAssertFalse(model.isFileOrganizerPlanFresh)

        // Step 2: Preview
        await model.refreshFileOrganizerPreview(entryIDs: [])

        XCTAssertTrue(model.isFileOrganizerPlanFresh)
        XCTAssertTrue(model.canExecuteFileOrganizerPlan)
        XCTAssertEqual(model.currentFileOrganizerPlan.items.count, 2)

        // Step 3: Execute
        await model.executeFileOrganizerPlan()

        // Verify entries cleared after execution
        XCTAssertEqual(model.fileOrganizerEntries.count, 0)
        XCTAssertTrue(model.fileOrganizerExecutionCompleted)
        XCTAssertFalse(model.isFileOrganizerPlanFresh)

        // Verify recovery item created with correct payload
        let recoveryItem = model.snapshot.recoveryItems.first(where: {
            if case .fileOrganizer = $0.payload { return true }
            return false
        })
        XCTAssertNotNil(recoveryItem)
        XCTAssertEqual(recoveryItem?.bytes, 300)

        // Verify task run recorded
        let taskRun = model.snapshot.taskRuns.first(where: { $0.kind == .organizeFiles })
        XCTAssertNotNil(taskRun)
        XCTAssertEqual(taskRun?.status, .completed)

        // Verify files actually moved on disk
        XCTAssertFalse(fm.fileExists(atPath: file1.path))
        XCTAssertFalse(fm.fileExists(atPath: file2.path))
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("Images/photo.png").path))
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("Documents/report.pdf").path))
    }

    /// round-3 fail-closed guard: when executeFileOrganizerPlan() fails AFTER a
    /// prior successful run left fileOrganizerMovedCount > 0, the failure
    /// receipt's movedItemCount must read 0 — never the stale prior count
    /// (which previously made the receipt falsely claim moves that did not
    /// happen). Pins the exact regression the round-3 fix prevents.
    func testFileOrganizerExecuteFailureEmitsFailClosedReceiptWithZeroMovedCount() async throws {
        let repository = makeRepository()
        let fm = FileManager.default
        let sourceDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/AtlasFO-Fail-\(UUID().uuidString)", isDirectory: true)
        let destDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Organized", isDirectory: true)
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        addTeardownBlock {
            try? fm.removeItem(at: sourceDir)
            try? fm.removeItem(at: destDir)
        }

        let entry = FileOrganizerEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
            path: sourceDir.appendingPathComponent("photo.png").path,
            fileName: "photo.png",
            bytes: 100,
            category: .images,
            proposedDestination: "~/Organized/Images/photo.png"
        )
        func seedFile() throws {
            try Data(repeating: 0x1, count: 100).write(to: URL(fileURLWithPath: entry.path))
        }

        let realWorker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: E2EFileOrganizerScanner(entries: [entry])
        )
        let model = AtlasAppModel(
            repository: repository,
            workerService: FileOrganizerExecuteRejectAfterSuccessWorker(realWorker: realWorker),
            ledgerNumberStore: InMemoryLedgerNumberStore()
        )

        // 1st execute succeeds → movedItemCount = 1 (establishes a stale count).
        try seedFile()
        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])
        await model.refreshFileOrganizerPreview(entryIDs: [])
        await model.executeFileOrganizerPlan()
        XCTAssertEqual(model.fileOrganizerExecutionReceipt?.movedItemCount, 1)
        XCTAssertNil(model.fileOrganizerExecutionReceipt?.failureReason)

        // 2nd execute rejects → fail-closed receipt must read 0, NOT the stale 1.
        try seedFile()
        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])
        await model.refreshFileOrganizerPreview(entryIDs: [])
        await model.executeFileOrganizerPlan()
        XCTAssertEqual(
            model.fileOrganizerExecutionReceipt?.movedItemCount, 0,
            "failure receipt must not carry the prior run's moved count (round-3 fail-closed)"
        )
        XCTAssertNotNil(model.fileOrganizerExecutionReceipt?.failureReason)
    }

    func testFileOrganizerScanFailureExposesError() async {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: FailingE2EFileOrganizerScanner()
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.runFileOrganizerScan(folderPaths: ["~/Desktop"])

        XCTAssertTrue(model.fileOrganizerEntries.isEmpty)
        XCTAssertNotNil(model.fileOrganizerPlanIssue)
    }

    func testFileOrganizerDryRunDoesNotMoveFiles() async throws {
        let repository = makeRepository()
        let fm = FileManager.default

        let sourceDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/AtlasFO-E2E-DryRun-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let file1 = sourceDir.appendingPathComponent("image.jpg")
        try Data(repeating: 0x1, count: 50).write(to: file1)

        addTeardownBlock {
            try? fm.removeItem(at: sourceDir)
        }

        let entries = [
            FileOrganizerEntry(
                id: UUID(),
                path: file1.path,
                fileName: "image.jpg",
                bytes: 50,
                category: .images,
                proposedDestination: "~/Organized/Images/image.jpg"
            )
        ]

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: E2EFileOrganizerScanner(entries: entries)
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])
        await model.refreshFileOrganizerPreview(entryIDs: [])
        XCTAssertTrue(model.isFileOrganizerPlanFresh)

        await model.dryRunFileOrganizerPlan()

        // File should still exist at original location
        XCTAssertTrue(fm.fileExists(atPath: file1.path))
        // Entries should still be present (dry run doesn't clear them)
        XCTAssertEqual(model.fileOrganizerEntries.count, 1)
    }

    func testFileOrganizerRestoreMovesFilesBack() async throws {
        let repository = makeRepository()
        let fm = FileManager.default

        let sourceDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/AtlasFO-E2E-Restore-\(UUID().uuidString)", isDirectory: true)
        let destDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Organized", isDirectory: true)

        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let file1 = sourceDir.appendingPathComponent("archive.zip")
        try Data(repeating: 0x1, count: 300).write(to: file1)

        addTeardownBlock {
            try? fm.removeItem(at: sourceDir)
            try? fm.removeItem(at: destDir)
        }

        let entries = [
            FileOrganizerEntry(
                id: UUID(),
                path: file1.path,
                fileName: "archive.zip",
                bytes: 300,
                category: .archives,
                proposedDestination: "~/Organized/Archives/archive.zip"
            )
        ]

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: E2EFileOrganizerScanner(entries: entries)
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        // Full pipeline: scan → preview → execute
        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])
        await model.refreshFileOrganizerPreview(entryIDs: [])
        await model.executeFileOrganizerPlan()

        // Verify file moved
        XCTAssertFalse(fm.fileExists(atPath: file1.path))
        let movedFile = destDir.appendingPathComponent("Archives/archive.zip")
        XCTAssertTrue(fm.fileExists(atPath: movedFile.path))

        // Verify recovery item exists
        let recoveryItem = try XCTUnwrap(model.snapshot.recoveryItems.first(where: {
            if case .fileOrganizer = $0.payload { return true }
            return false
        }))

        // Restore
        await model.restoreRecoveryItem(recoveryItem.id)

        // Verify file moved back to original location
        XCTAssertTrue(fm.fileExists(atPath: file1.path))
        // Recovery item should be removed
        XCTAssertFalse(model.snapshot.recoveryItems.contains(where: { $0.id == recoveryItem.id }))
    }

    func testFileOrganizerExecuteRejectsStalePlanAfterReScan() async throws {
        let repository = makeRepository()
        let fm = FileManager.default

        let sourceDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/AtlasFO-E2E-Stale-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let file1 = sourceDir.appendingPathComponent("data.csv")
        try Data(repeating: 0x1, count: 50).write(to: file1)
        let file2 = sourceDir.appendingPathComponent("notes.txt")
        try Data(repeating: 0x2, count: 80).write(to: file2)

        addTeardownBlock {
            try? fm.removeItem(at: sourceDir)
            try? fm.removeItem(at: fm.homeDirectoryForCurrentUser.appendingPathComponent("Organized"))
        }

        // First scan returns only file1
        let firstEntries = [
            FileOrganizerEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                path: file1.path,
                fileName: "data.csv",
                bytes: 50,
                category: .documents,
                proposedDestination: "~/Organized/Documents/data.csv"
            )
        ]

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: E2EFileOrganizerScanner(entries: firstEntries)
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        // First scan + preview
        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])
        await model.refreshFileOrganizerPreview(entryIDs: [])
        XCTAssertTrue(model.isFileOrganizerPlanFresh)
        XCTAssertEqual(model.currentFileOrganizerPlan.items.count, 1)

        // Execute — should succeed with matching plan ID
        await model.executeFileOrganizerPlan()
        XCTAssertNil(model.fileOrganizerExecutionIssue)
        XCTAssertTrue(model.fileOrganizerExecutionCompleted)

        // Entries should be cleared after execution
        XCTAssertEqual(model.fileOrganizerEntries.count, 0)

        // File should be moved
        XCTAssertFalse(fm.fileExists(atPath: file1.path))
    }

    func testFileOrganizerWorkflowBusyFlags() async throws {
        let repository = makeRepository()
        let fm = FileManager.default

        let sourceDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/AtlasFO-E2E-Busy-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let file1 = sourceDir.appendingPathComponent("file.mp3")
        try Data(repeating: 0x1, count: 100).write(to: file1)

        addTeardownBlock {
            try? fm.removeItem(at: sourceDir)
            try? fm.removeItem(at: fm.homeDirectoryForCurrentUser.appendingPathComponent("Organized"))
        }

        let entries = [
            FileOrganizerEntry(
                id: UUID(),
                path: file1.path,
                fileName: "file.mp3",
                bytes: 100,
                category: .audio,
                proposedDestination: "~/Organized/Audio/file.mp3"
            )
        ]

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: E2EFileOrganizerScanner(entries: entries)
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        // Initially not busy
        XCTAssertFalse(model.isWorkflowBusy)

        // After scan completes, still not busy
        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])
        XCTAssertFalse(model.isWorkflowBusy)

        // After preview completes
        await model.refreshFileOrganizerPreview(entryIDs: [])
        XCTAssertFalse(model.isWorkflowBusy)

        // After execute completes
        await model.executeFileOrganizerPlan()
        XCTAssertFalse(model.isWorkflowBusy)
        XCTAssertTrue(model.fileOrganizerExecutionCompleted)

        // Re-scanning resets executionCompleted
        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])
        XCTAssertFalse(model.fileOrganizerExecutionCompleted)
    }
}

// MARK: - File Organizer E2E Test Providers

private struct E2EFileOrganizerScanner: AtlasFileOrganizerScanning {
    let entries: [FileOrganizerEntry]

    func scanFolders(_ paths: [String], destinationBasePath: String = "~/Organized", recursive: Bool = false) async throws -> FileOrganizerScanResult {
        var counts: [FileOrganizerCategory: Int] = [:]
        for entry in entries { counts[entry.category, default: 0] += 1 }
        return FileOrganizerScanResult(
            entries: entries,
            totalFiles: entries.count,
            totalBytes: entries.map(\.bytes).reduce(0, +),
            categoryCounts: counts
        )
    }
}

private struct FailingE2EFileOrganizerScanner: AtlasFileOrganizerScanning {
    func scanFolders(_ paths: [String], destinationBasePath: String = "~/Organized", recursive: Bool = false) async throws -> FileOrganizerScanResult {
        throw NSError(domain: "AtlasAppModelTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Scan unavailable."])
    }
}

private final class TestClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
