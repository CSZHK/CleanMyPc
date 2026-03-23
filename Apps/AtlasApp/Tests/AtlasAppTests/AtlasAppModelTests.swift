import XCTest
@testable import AtlasApp
import AtlasApplication
import AtlasDomain
import AtlasInfrastructure
import AtlasProtocol

@MainActor
final class AtlasAppModelTests: XCTestCase {

    func testCurrentSmartCleanPlanStartsAsCachedUntilSessionRefresh() {
        let model = AtlasAppModel(repository: makeRepository(), workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true))

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
        let model = AtlasAppModel(repository: repository, workerService: worker)

        await model.runSmartCleanScan()

        XCTAssertFalse(model.isCurrentSmartCleanPlanFresh)
        XCTAssertFalse(model.canExecuteCurrentSmartCleanPlan)
        XCTAssertNotNil(model.smartCleanPlanIssue)
        XCTAssertTrue(model.latestScanSummary.contains("Smart Clean scan is unavailable"))
    }

    func testRefreshPlanPreviewKeepsPlanNonExecutableWhenFindingsLackTargets() async {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let model = AtlasAppModel(repository: repository, workerService: worker)

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
        let model = AtlasAppModel(repository: repository, workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true))

        XCTAssertFalse(model.currentSmartCleanPlanHasExecutableTargets)
        XCTAssertFalse(model.canExecuteCurrentSmartCleanPlan)
    }

    func testRunSmartCleanScanMarksPlanAsFreshForCurrentSession() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            smartCleanScanProvider: FakeSmartCleanProvider(),
            allowStateOnlyCleanExecution: true
        )
        let model = AtlasAppModel(repository: repository, workerService: worker)

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
        let model = AtlasAppModel(repository: repository, workerService: worker)

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
        let model = AtlasAppModel(repository: repository, workerService: worker)
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
            workerService: RejectingWorker(code: .executionUnavailable, reason: "XPC worker offline")
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
            xpcRequestExecutor: { _ in responseData }
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
        let model = AtlasAppModel(repository: repository, workerService: worker)

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
        settings.acknowledgementText = AtlasL10n.acknowledgement(language: .en)
        settings.thirdPartyNoticesText = AtlasL10n.thirdPartyNotices(language: .en)

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
        let model = AtlasAppModel(repository: repository, workerService: worker)

        await model.previewAppUninstall(appID: app.id)

        XCTAssertEqual(model.currentPreviewedAppID, app.id)
        XCTAssertEqual(model.currentAppPreview?.items.count, 3)
        XCTAssertTrue(model.currentAppPreview?.items.dropFirst().allSatisfy { !$0.recoverable } == true)
        XCTAssertEqual(model.latestAppsSummary, AtlasL10n.string("application.apps.previewUpdated", "Uninstall Sample App"))
    }

    func testRestoreRecoveryItemReturnsFindingToWorkspace() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let model = AtlasAppModel(repository: repository, workerService: worker)

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
            )
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
        let model = AtlasAppModel(repository: repository, workerService: worker)

        await model.previewAppUninstall(appID: app.id)
        XCTAssertNotNil(model.currentAppPreview)
        XCTAssertEqual(model.currentPreviewedAppID, app.id)

        model.navigate(to: .history)
        await model.restoreRecoveryItem(recoveryItem.id)

        XCTAssertEqual(model.selection, .history)
        XCTAssertNil(model.currentAppPreview)
        XCTAssertNil(model.currentPreviewedAppID)
        XCTAssertEqual(model.snapshot.apps.first?.leftoverItems, 1)
        XCTAssertEqual(model.latestAppsSummary, AtlasL10n.string("application.apps.loaded.one"))
        XCTAssertFalse(model.snapshot.recoveryItems.contains(where: { $0.id == recoveryItem.id }))
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
        let model = AtlasAppModel(repository: repository, workerService: worker)
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
            notificationPermissionRequester: { true }
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
        let model = AtlasAppModel(repository: repository, workerService: worker)

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
            notificationPermissionRequester: { await recorder.request() }
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
        let model = AtlasAppModel(repository: repository, workerService: worker)

        await model.refreshPermissionsIfNeeded()

        XCTAssertEqual(model.snapshot.permissions.first(where: { $0.kind == .fullDiskAccess })?.isGranted, true)
        XCTAssertEqual(model.snapshot.permissions.first(where: { $0.kind == .accessibility })?.isGranted, true)
        XCTAssertEqual(model.snapshot.permissions.first(where: { $0.kind == .notifications })?.isGranted, false)
    }

    func testToggleTaskCenterFlipsPresentationState() {
        let model = AtlasAppModel(repository: makeRepository(), workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true))

        XCTAssertFalse(model.isTaskCenterPresented)
        model.toggleTaskCenter()
        XCTAssertTrue(model.isTaskCenterPresented)
        model.toggleTaskCenter()
        XCTAssertFalse(model.isTaskCenterPresented)
    }


    func testSetLanguagePersistsThroughWorkerAndUpdatesLocalization() async throws {
        let repository = makeRepository()
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let model = AtlasAppModel(repository: repository, workerService: worker)

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

private final class TestClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
