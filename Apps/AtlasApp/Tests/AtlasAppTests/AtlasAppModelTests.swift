import XCTest
@testable import AtlasApp
import AtlasApplication
import AtlasDomain
import AtlasFeaturesSmartClean
import AtlasInfrastructure
import AtlasProtocol

@MainActor
final class AtlasAppModelTests: XCTestCase {

    func testCurrentSmartCleanPlanStartsAsCachedUntilSessionRefresh() {
        let model = AtlasAppModel(repository: makeRepository(), workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true), ledgerNumberStore: InMemoryLedgerNumberStore())

        XCTAssertFalse(model.isCurrentSmartCleanPlanFresh)
        XCTAssertFalse(model.canExecuteCurrentSmartCleanPlan)
        XCTAssertNil(model.smartCleanPlanOutcome)
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
        XCTAssertNotNil(model.smartCleanPlanOutcome)
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
        XCTAssertNil(model.smartCleanPlanOutcome)
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

        // Round-7: pin the fail-closed receipt shape via the REAL catch path
        // (not just a hand-built fixture). A failed execute must produce a
        // receipt that carries the reason and asserts nothing it can't verify.
        let receipt = model.smartCleanExecutionReceipt
        XCTAssertNotNil(receipt, "a failed execute must build a receipt")
        XCTAssertNotNil(receipt?.failureReason, "failure receipt must carry the reason")
        XCTAssertTrue(receipt?.recoveryItemIDs.isEmpty == true, "failure receipt must not claim recovery items")
        XCTAssertEqual(receipt?.recoveryBytes, 0, "failure receipt must not claim recovery bytes")
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
        XCTAssertEqual(model.smartCleanPlanOutcome?.message, AtlasL10n.string("application.error.executionUnavailable", "simulated packaged worker failure"))
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
        // P0-1 之前，这条断言钉的是**缺陷本身**：台账恢复失败被写进
        // `latestScanSummary`（Smart Clean 的状态行），台账屏零呈现。
        // 契约一改为写进**台账自己的 source 槽位**（`I-1`）。
        XCTAssertEqual(model.ledgerOutcome?.source, .ledger)
        XCTAssertEqual(model.ledgerOutcome?.kind, .failed)
        XCTAssertEqual(
            model.ledgerOutcome?.message,
            AtlasL10n.string("application.error.restoreExpired", "One or more selected recovery items have expired and can no longer be restored.")
        )
    }

    /// `I-11` —— **本规格最重要的一条**：每个路由至少两条可达路径
    /// （菜单/键盘至少其一 + UI）。
    ///
    /// 断言对象是 `AtlasRoute.sidebarRoutes`（`AtlasDomain.swift:132`），**不是**
    /// `CommandMenu` —— 后者是 SwiftUI View body，不可枚举（设计评审 F3）。
    /// `.about` 由 app 菜单「关于 Atlas」承载，该事实经 `AtlasRoute.appMenuRoutes`
    /// 变成可枚举的；这是产品负责人 2026-09-14 的裁定。
    ///
    /// **落点固定在 `Apps/AtlasApp/Tests/AtlasAppTests/`**：`shortcutKey` 定义在
    /// `Apps/AtlasApp/`，放错包会让 Wave 2 的验证命令（`swift test --package-path Apps`）
    /// 漏跑它。
    ///
    /// 本守卫兜住的是 `iterations/REQ-ui-ux-overhaul` P1-3「把 ⌘, 打开 Settings 标为
    /// 已完成却未交付」那类欠账 —— 写成不变量才不会再重蹈覆辙。
    func testEveryRouteHasAtLeastTwoReachablePaths() {
        for route in AtlasRoute.allCases {
            let inSidebar = AtlasRoute.sidebarRoutes.contains(route)
            let hasShortcut = route.shortcutKey != nil
            let inAppMenu = AtlasRoute.appMenuRoutes.contains(route)

            // 半支 A：**菜单/键盘至少其一**。
            //
            // 原实现是一条析取式 `inSidebar || hasShortcut || inAppMenu`，对 6 条
            // sidebar 路由被 `inSidebar` **恒真短路** —— 把它们的快捷键整体删掉、
            // 让用户只剩鼠标一条路径，守卫照样绿。变异检验实证：`.permissions` 的
            // `shortcutKey` 置 `nil` 后原断言仍 passed。故必须**单独**断言这一支。
            XCTAssertTrue(
                hasShortcut || inAppMenu,
                "I-11(菜单/键盘半支): \(route) 既没有快捷键、也不在 appMenuRoutes —— 只剩鼠标一条路径"
            )

            // 保留原析取式作为「至少有一条路径」的兜底（对非 sidebar 路由仍是有效判据）。
            XCTAssertTrue(
                inSidebar || hasShortcut || inAppMenu,
                "I-11(兜底): \(route) 无任何已登记入口"
            )
        }

        // 判据面的**已知边界，不是遗漏**：不变量还要求「+ UI」一条路径，但静态可枚举的
        // 落点只有 `sidebarRoutes` / `appMenuRoutes`，而 `.settings` 既不在前者
        // （`isSidebarRoute` 显式排除它）、也不在后者 —— 尽管 `AppShellView.swift:39`
        // 确实渲染了它的 sidebar 行、`CommandGroup(replacing: .appSettings)` 也给了
        // app 菜单入口。`CommandMenu` 是 View body、不可枚举（设计评审 F3），
        // 故 UI 半支无法在此断言，由 `testSettingsMenuEntryOpensSettings`（XCUITest
        // 点击端到端）覆盖。**不要**为此把 `.settings` 塞进 `appMenuRoutes` 充数 ——
        // 那只会让判据看起来更全，实际仍不检验 UI 路径。
    }

    /// `P1-18`（CONTRACT）：⌘, 必须真的绑到设置上。
    func testSettingsRouteHasCommaShortcut() {
        XCTAssertEqual(AtlasRoute.settings.shortcutKey, ",")
    }

    /// 守卫基座自检：`review-executable` fixture 必须真的产出「可执行的复核页」，
    /// 否则 `I-4` 的 UI 断言会在 `execute.isEnabled` 上假失败。
    /// 逐项断言判据链，把排查从每次 ~60s 的 UI 运行降回秒级。
    func testReviewExecutableFixtureProducesExecutablePlan() {
        let model = AtlasAppModel(
            repository: makeRepository(),
            workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true),
            ledgerNumberStore: InMemoryLedgerNumberStore()
        )
        model.applyUITestFixture("review-executable")

        XCTAssertFalse(model.currentPlan.items.isEmpty, "① 计划非空")
        XCTAssertTrue(model.isCurrentSmartCleanPlanFresh, "② 计划新鲜")
        XCTAssertTrue(model.currentSmartCleanPlanHasExecutableTargets, "③ 有可执行目标")
        XCTAssertTrue(model.canExecuteCurrentSmartCleanPlan, "④ 因而可执行")

        let selected = model.workflowState(for: .smartClean).selectedIDs
        XCTAssertFalse(selected.isEmpty, "⑤ 有一项被选中")
        let findingIDs = Set(model.snapshot.findings.map(\.id.uuidString))
        XCTAssertFalse(
            selected.intersection(findingIDs).isEmpty,
            "⑥ 选中的 id 必须能在 snapshot.findings 里解析（否则 selectedCount 归零）"
        )
        XCTAssertEqual(model.workflowState(for: .smartClean).displayedStage, SmartCleanStage.review, "⑦ 落在②复核")

        // ⑧ **本轮踩到的真坑**：AppShellView.task 启动后会调
        // `refreshHealthSnapshotIfNeeded()` / `refreshPermissionsIfNeeded()`，
        // 两者都 `snapshot = output.snapshot` —— 只改内存态的 fixture 会在首帧后被
        // 冲掉，findings 消失 ⇒ selectedCount 归零 ⇒ 执行按钮置灰。
        // 断言 fixture **经受得住 reload**：注入必须落在真相源（repository）上。
    }

    /// fixture 注入必须落在真相源：reload 之后 findings 仍在。
    func testReviewExecutableFixtureSurvivesSnapshotReload() async {
        let repository = makeRepository()
        let model = AtlasAppModel(
            repository: repository,
            workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true),
            ledgerNumberStore: InMemoryLedgerNumberStore()
        )
        model.applyUITestFixture("review-executable")

        // 只跑 health 那条：`refreshPermissionsIfNeeded()` 依赖
        // `bundleProxyForCurrentProcess`，在非 bundle 的单测进程里会崩
        // （`AtlasPermissionInspector.swift:84`），属环境阻塞、不是被测行为。
        // 两者都与 `snapshot = output.snapshot` 同构，health 这条已能代表该路径。
        await model.refreshHealthSnapshotIfNeeded()

        XCTAssertFalse(
            model.snapshot.findings.isEmpty,
            "reload 后 findings 被冲掉了 —— fixture 只改了内存态，没落到 repository"
        )
        XCTAssertTrue(
            model.canExecuteCurrentSmartCleanPlan,
            "reload 之后仍须是可执行的复核页，否则 I-4 会假失败"
        )
    }

    /// `P1-16` 的**反面**：「不见了」≠「被清理了」。
    ///
    /// 会话间 id 差分无法区分「被 prune」与「被用户恢复」—— 两者都会让恢复项从
    /// `recoveryItems` 消失。若不补偿，用户恢复一条记录后重启，会看到
    /// 「N 条过期记录已被清理」这种与事实相反的提示。
    ///
    /// **测试要点（第一版在这里写错过两次，留档）**：
    /// ① 必须显式构造「上次会话见过它」—— 否则集合为空，`disappeared` 永远为空，
    ///    用例空转（变异检验把它抓了出来）；
    /// ② 必须断言 **plan 通道** —— `ledgerOutcome` 是 `execution ?? plan`，
    ///    恢复成功写的是 execution，断言它会永远看不见这条 advisory。
    ///
    /// **`F-03` 修复（第三处错误）**：本用例此前把种子写进 `UserDefaults.standard`，
    /// 而 SPM 测试进程的 standard 域就是 `com.apple.dt.xctest.tool` —— **仓库外的
    /// 持久 OS 状态**。后果：`init` 内先跑一次 `surfaceExpiredRecoveryPruneIfNeeded()`
    /// 读到的基线是**别的用例/别的跑次留下的**，用例的绿取决于跑没跑过别的测试；
    /// 且种子写在模型构造**之后**，对 `init` 那一次已经太晚。实测污染后隔离跑必红。
    ///
    /// 现改用**本次专有 suite**，并在**构造模型之前**写种子，`addTeardownBlock` 清理。
    func testRestoredItemIsNotReportedAsPruned() async throws {
        let repository = makeRepository()
        let defaults = makeIsolatedDefaults()
        let item = RecoveryItem(
            id: UUID(),
            title: "Restorable",
            detail: "d",
            originalPath: "~/Library/Caches/restorable",
            bytes: 10,
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(86_400),
            payload: .finding(Finding(title: "f", detail: "d", bytes: 10, risk: .safe, category: "Caches"))
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0, findings: [], apps: [], taskRuns: [],
                recoveryItems: [item], permissions: [], healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)

        // ① 显式构造「上次会话见过它」—— **必须在构造模型之前**：
        //    `init` 本身就会跑一次差分（`surfaceExpiredRecoveryPruneIfNeeded`），
        //    构造后再写只影响"下一轮"，`init` 那一轮读到的是别人的基线。
        defaults.set([item.id.uuidString], forKey: AtlasAppModel.seenRecoveryItemIDsKey)

        let model = AtlasAppModel(
            repository: repository,
            workerService: worker,
            ledgerNumberStore: InMemoryLedgerNumberStore(),
            userDefaults: defaults
        )

        // 本轮：它还在，不该报。
        model.surfaceExpiredRecoveryPruneIfNeeded()
        XCTAssertNil(model.sourceOutcomes[.ledger]?.plan, "项目还在时不得报「已被清理」")

        // 用户主动恢复它 —— 它同样会从 `recoveryItems` 消失。
        await model.restoreRecoveryItem(item.id)
        XCTAssertFalse(model.snapshot.recoveryItems.contains { $0.id == item.id }, "恢复后该项应当消失")

        // ② 下一轮：不得把它报成「已被清理」（断言 plan 通道）。
        model.surfaceExpiredRecoveryPruneIfNeeded()
        XCTAssertNil(
            model.sourceOutcomes[.ledger]?.plan,
            "**不见了 ≠ 被清理了**：用户主动恢复的项不得被误报为已清理"
        )
    }

    /// `F-08`：「写入 → 出清」必须成对。
    ///
    /// 复审发现：`surfaceExpiredRecoveryPruneIfNeeded` 写 `.ledger` 的 plan 槽之后，
    /// 全仓 `clearPlan(.ledger)` / `clearExecution(.ledger)` **零命中** —— 用户进过
    /// 一次台账，那条「N 条过期记录已被清理」会永远挂在屏上（粘性横幅）。
    ///
    /// 守卫同时钉住**两侧**：① 写入确实发生（否则下面的出清断言会空转通过 ——
    /// 这正是本仓库守卫反复栽的那个坑）；② 已读后确实出清；③ 出清**不得**误伤
    /// 同一槽位上的 `.failed` —— 那是另一个（更新的）结果。
    func testLedgerPruneAdvisoryIsWrittenAndThenClearedOnAcknowledge() async throws {
        let repository = makeRepository()
        let defaults = makeIsolatedDefaults()

        // 上一次会话见过两条，本次快照里都不在 ⇒ 差分判定「被清理了」。
        let vanished = [UUID(), UUID()]
        defaults.set(vanished.map(\.uuidString), forKey: AtlasAppModel.seenRecoveryItemIDsKey)

        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0, findings: [], apps: [], taskRuns: [],
                recoveryItems: [], permissions: [], healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let model = AtlasAppModel(
            repository: repository,
            workerService: worker,
            ledgerNumberStore: InMemoryLedgerNumberStore(),
            userDefaults: defaults
        )

        // ① 写入侧：`init` 已经跑过一次差分，advisory 必须在场。
        let written = try XCTUnwrap(
            model.sourceOutcomes[.ledger]?.plan,
            "差分判定有 2 条恢复项消失 ⇒ 必须写入 advisory（否则本用例的绿是空转）"
        )
        XCTAssertTrue(written.isAdvisory)
        XCTAssertFalse(written.isError)

        // ② 出清侧：用户进到台账屏「看到过」之后必须清掉。
        model.acknowledgeLedgerPruneNotice()
        XCTAssertNil(
            model.sourceOutcomes[.ledger]?.plan,
            "已读后必须出清 —— 否则横幅粘在台账屏上永不消失（F-08）"
        )

        // ③ 不误伤：同一槽位若是 `.failed`（更新的结果），acknowledge 不得抹掉它。
        await model.restoreRecoveryItem(UUID())   // 找不到恢复项 ⇒ 失败结果写进 .ledger
        let failed = try XCTUnwrap(model.sourceOutcomes[.ledger]?.execution)
        XCTAssertTrue(failed.isError, "前提：失败结果确实写进了 .ledger 的执行槽")
        model.acknowledgeLedgerPruneNotice()
        XCTAssertNotNil(
            model.sourceOutcomes[.ledger]?.execution,
            "acknowledge 只清 advisory 的 plan 槽，不得连 .failed 的执行槽一起抹掉"
        )
    }

    /// `TS-01`：`I-1` 的**清除方向**。`I-1` 原文只钉了写入方向
    /// （「失败结果不得写入非本 source 的槽位」），清除方向无人守 ——
    /// `restoreRecoveryItemCore` 的成功分支里曾有一条**无条件**
    /// `clearExecution(.smartClean)`：从**台账**恢复一条记录，也会顺手抹掉
    /// Smart Clean 自己那条执行结果。清除必须与写入同口径：只清**本 source**。
    ///
    /// 用例构造的态：`.smartClean` 的执行槽已写实（Smart Clean 刚跑完一次执行），
    /// 随后用户发起一次**台账**恢复。台账这条不得动 Smart Clean 的槽。
    ///
    /// **构造注意（第一版写错过，留档）**：恢复的是**带 `app` 载荷**的恢复项。
    /// 只有这条分支走 `reloadAppsInventory`；走 `.finding` 载荷的话
    /// `restoreRecoveryItemCore` 末尾会调 `refreshPlanPreview()`，而它首行就是
    /// `clearExecution(.smartClean)`（HEAD 既有语义，非本 CHG 引入）——
    /// 那样 `.smartClean` 槽**必然**为空，断言与 `clearExecution(.smartClean)`
    /// 那条被测语句就脱钩了：无论被测语句在不在，用例都会红/绿一致 → 空转。
    func testLedgerRestoreDoesNotClearSmartCleanOutcomeSlot() async throws {
        let repository = makeRepository()
        let defaults = makeIsolatedDefaults()

        let appFootprint = AppFootprint(
            name: "Sample App", bundleIdentifier: "com.example.sample",
            bundlePath: "/Applications/Sample App.app", bytes: 2_048_000_000, leftoverItems: 3
        )
        let appItem = RecoveryItem(
            id: UUID(),
            title: "Sample App",
            detail: "d",
            originalPath: "/Applications/Sample App.app",
            bytes: 2_048_000_000,
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(86_400),
            payload: .app(
                AtlasAppRecoveryPayload(
                    app: appFootprint,
                    uninstallEvidence: AtlasAppUninstallEvidence(
                        bundlePath: appFootprint.bundlePath,
                        bundleBytes: appFootprint.bytes,
                        reviewOnlyGroups: []
                    )
                )
            )
        )
        // 前置素材：把 `.smartClean` 执行槽写实 —— 用**同一批 app 载荷项**里的
        // 另一条走 Smart Clean 入口。app 载荷 ⇒ 末尾走 `reloadAppsInventory`，
        // 不会撞上 `refreshPlanPreview()` 的 `clearExecution(.smartClean)`。
        let baselineApp = AppFootprint(
            name: "Baseline App", bundleIdentifier: "com.example.baseline",
            bundlePath: "/Applications/Baseline App.app", bytes: 1_024_000_000, leftoverItems: 1
        )
        let baselineItem = RecoveryItem(
            id: UUID(),
            title: "Baseline App",
            detail: "d",
            originalPath: "/Applications/Baseline App.app",
            bytes: 1_024_000_000,
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(86_400),
            payload: .app(
                AtlasAppRecoveryPayload(
                    app: baselineApp,
                    uninstallEvidence: AtlasAppUninstallEvidence(
                        bundlePath: baselineApp.bundlePath,
                        bundleBytes: baselineApp.bytes,
                        reviewOnlyGroups: []
                    )
                )
            )
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0, findings: [], apps: [appFootprint], taskRuns: [],
                recoveryItems: [appItem, baselineItem], permissions: [], healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let model = AtlasAppModel(
            repository: repository,
            workerService: worker,
            ledgerNumberStore: InMemoryLedgerNumberStore(),
            userDefaults: defaults
        )

        _ = await model.restoreRecoveryItemReportingSuccess(baselineItem.id)
        let pre = try XCTUnwrap(
            model.sourceOutcomes[.smartClean]?.execution,
            "前置：本用例必须先把 .smartClean 执行槽写实，否则断言会空转通过"
        )
        XCTAssertTrue(pre.isSuccess)

        // 被测：**台账**恢复一条（app 载荷 ⇒ 走 reloadAppsInventory，不经过
        // 会清 `.smartClean` 的 `refreshPlanPreview`）。
        await model.restoreRecoveryItem(appItem.id)

        XCTAssertNotNil(
            model.sourceOutcomes[.smartClean]?.execution,
            "从**台账**恢复不得清除 Smart Clean 自己的执行结果 —— 清除必须与写入同 source（TS-01）"
        )
        XCTAssertEqual(
            model.sourceOutcomes[.ledger]?.execution?.source,
            .ledger,
            "台账恢复的结果必须写进台账自己的槽"
        )
    }

    /// `I-5`（降级形式，规格 §7.1 的可自动化那一半）：
    /// **凡是能发起扫描的调用路径，必然先写入 preamble 状态。**
    ///
    /// **守卫口径 = 时序，不是赋值存在性**。此前本用例只断言
    /// `model.fileOrganizerScanPreambleShown == true` —— 那与赋值**位置**无关：
    /// 把 `fileOrganizerScanPreambleShown = true` 挪到扫描调用**之后**（甚至挪进
    /// `defer`），守卫照旧通过（复审 `TS-03` 的实证）。
    ///
    /// 现用记录时序的扫描器桩（`RecordingFileOrganizerScanner`）钉住顺序：
    /// preamble 必须在**扫描被发起之前**就已置位。断言顺序而非存在性，
    /// 才真正守住「说明先于触发 TCC 的调用」这一语义。
    ///
    /// 不可自动化的那一半（TCC 弹窗出现时 app 内已渲染作用域说明）是
    /// `macos-gui-acceptance` 的人工验收项 —— 此处不冒充自动化覆盖。
    func testFileOrganizerScanWritesPreambleState() async {
        let repository = makeRepository()
        let scanner = RecordingFileOrganizerScanner(entries: [])
        let worker = AtlasScaffoldWorkerService(repository: repository, fileOrganizerScanProvider: scanner)
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())
        // 桩在「扫描被发起时」回调读模型的 preamble —— 采样点即断言点。
        scanner.preambleProbe = { [weak model] in model?.fileOrganizerScanPreambleShown ?? false }

        // 首扫前：仍应渲染作用域说明。
        XCTAssertFalse(model.fileOrganizerScanPreambleShown)

        await model.runFileOrganizerScan(folderPaths: ["~/Desktop"])

        // ① 扫描确实被发起（否则下面的时序断言会因「从未扫描」而空转）。
        XCTAssertEqual(scanner.scanCallCount, 1, "I-5：本路径必须真的发起过一次扫描")

        // ② 时序：发起扫描的那一刻，preamble **已经**置位。
        //    `scanner.preambleShownAtScanTime` 由桩在 `scanFolders` 内读取，
        //    因此它记录的是「扫描被发起时」的真实取值 —— 与赋值位置强相关。
        XCTAssertTrue(
            scanner.preambleShownAtScanTime,
            "I-5：preamble 必须**先于**扫描调用被发起而置位（把赋值挪到扫描之后即失败）"
        )
    }

    /// `I-1`：失败结果不得写入非本 source 的槽位。
    ///
    /// 守卫载体：`AtlasAppModelTests`（规格 §7 I-1）。触发一次**台账**恢复失败，
    /// 断言①台账槽非空且为 `.failed`；②Smart Clean 槽**逐字节未变**
    /// （状态行与计划层结果都比对失败前后的值）。
    func testLedgerRestoreFailureNeverWritesAnotherSourceSlot() async throws {
        let repository = makeRepository()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = TestClock(now: baseDate)
        let recoveryItem = RecoveryItem(
            id: UUID(),
            title: "Expired item",
            detail: "detail",
            originalPath: "~/Library/Caches/expired",
            bytes: 1_024,
            deletedAt: baseDate.addingTimeInterval(-86_400),
            expiresAt: baseDate.addingTimeInterval(-60),
            payload: .finding(
                Finding(title: "f", detail: "d", bytes: 1_024, risk: .safe, category: "Caches")
            )
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

        // 失败前：记下 Smart Clean 槽的逐字节快照。
        let smartCleanSummaryBefore = model.latestScanSummary
        let smartCleanPlanBefore = model.smartCleanPlanOutcome
        let smartCleanExecutionBefore = model.smartCleanExecutionIssue

        clock.now = baseDate.addingTimeInterval(60)
        await model.restoreRecoveryItem(recoveryItem.id)

        // ① 台账槽非空，且带自己的 source。
        let ledgerOutcome = try XCTUnwrap(model.ledgerOutcome)
        XCTAssertEqual(ledgerOutcome.source, .ledger)
        XCTAssertEqual(ledgerOutcome.kind, .failed)
        XCTAssertFalse(ledgerOutcome.message.isEmpty)

        // ② Smart Clean 槽未被写入（这正是 `P0-1` 的形状）。
        XCTAssertEqual(model.latestScanSummary, smartCleanSummaryBefore)
        XCTAssertEqual(model.smartCleanPlanOutcome, smartCleanPlanBefore)
        XCTAssertEqual(model.smartCleanExecutionIssue, smartCleanExecutionBefore)
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

    /// 本次用例专有的 `UserDefaults` 域，**随用例销毁**。
    ///
    /// `F-03` 的根因：`UserDefaults.standard` 在 SPM 测试进程里是
    /// `com.apple.dt.xctest.tool` —— 一个**跨用例、跨跑次持久**的 OS 状态。
    /// 任何依赖它的用例，其结论都取决于「之前跑过什么」，这是不可接受的测试确定性缺陷。
    private func makeIsolatedDefaults(function: String = #function) -> UserDefaults {
        let suiteName = "atlas.app.tests.\(function).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("UserDefaults(suiteName:) returned nil for \(suiteName)")
        }
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
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

        // Step 1: Scan — now auto-runs classify → preview so the workflow
        // advances off ①scan (audit P0 #7 + P1 #19; previously the plan was
        // never generated here and the stage was stranded on scan).
        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])

        XCTAssertEqual(model.fileOrganizerEntries.count, 2)
        XCTAssertFalse(model.isFileOrganizerScanning)
        XCTAssertTrue(model.isFileOrganizerPlanFresh)
        XCTAssertEqual(model.currentFileOrganizerPlan.items.count, 2)

        // Step 2: Re-preview is idempotent and keeps the plan fresh.
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

    /// Regression (audit P0 #7 + P1 #19): `runFileOrganizerScan` must itself
    /// classify the fresh entries and generate the plan. The Calm Ledger
    /// refactor (commit 62f30d7) dropped the only call sites of
    /// `onRefreshPreview`/`onClassify`, so the plan was never built
    /// (`isFileOrganizerPlanFresh` stayed false), the stage was stranded on
    /// ①scan, and execute/dry-run were permanently disabled. This pins that
    /// scan alone leaves a fresh, executable plan.
    func testFileOrganizerScanGeneratesFreshPlanWithoutManualPreview() async throws {
        let repository = makeRepository()
        let fm = FileManager.default
        let sourceDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/AtlasFO-Stage-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let file = sourceDir.appendingPathComponent("photo.png")
        try Data(repeating: 0x1, count: 100).write(to: file)
        addTeardownBlock { try? fm.removeItem(at: sourceDir) }

        let entries = [
            FileOrganizerEntry(
                id: UUID(), path: file.path, fileName: "photo.png",
                bytes: 100, category: .images,
                proposedDestination: "~/Organized/Images/photo.png"
            )
        ]
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: E2EFileOrganizerScanner(entries: entries)
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])

        XCTAssertTrue(model.isFileOrganizerPlanFresh, "scan must generate a fresh plan (was stranded on ①scan)")
        XCTAssertTrue(model.canExecuteFileOrganizerPlan, "execute must be reachable after scan")
        XCTAssertEqual(model.currentFileOrganizerPlan.items.count, 1)
    }

    /// Regression (audit #8): when every move fails (e.g. sources gone),
    /// execute must surface a failure and retain entries for retry — never a
    /// silent "0 files organized" success.
    func testFileOrganizerExecuteAllFailedSurfacesFailureNotSilentSuccess() async throws {
        let repository = makeRepository()
        let ghostPath = "~/Library/Caches/AtlasFO-Ghost-\(UUID().uuidString)/missing.png"
        let entries = [
            FileOrganizerEntry(
                id: UUID(), path: ghostPath, fileName: "missing.png",
                bytes: 10, category: .images,
                proposedDestination: "~/Organized/Images/missing.png"
            )
        ]
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: E2EFileOrganizerScanner(entries: entries)
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.runFileOrganizerScan(folderPaths: ["~/Desktop"])
        await model.executeFileOrganizerPlan()

        XCTAssertFalse(model.fileOrganizerExecutionCompleted, "all-failed execute must not report success")
        XCTAssertNotNil(model.fileOrganizerExecutionIssue)
        XCTAssertNotNil(model.fileOrganizerExecutionReceipt?.failureReason)
        // Core #8 contract (final-audit): failed entries are retained for retry.
        XCTAssertGreaterThan(model.fileOrganizerEntries.count, 0, "failed entries must be retained for retry")
    }

    /// Regression (audit #8 display): a partial run (some moved, some failed)
    /// must surface failedItemCount on the receipt, not display as a clean
    /// success.
    func testFileOrganizerExecutePartialFailureSurfacesFailedItemCount() async throws {
        let repository = makeRepository()
        let fm = FileManager.default
        let sourceDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/AtlasFO-Partial-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let goodFile = sourceDir.appendingPathComponent("real.png")
        try Data("ok".utf8).write(to: goodFile)
        addTeardownBlock { try? fm.removeItem(at: sourceDir) }

        let entries = [
            FileOrganizerEntry(
                id: UUID(), path: goodFile.path, fileName: "real.png",
                bytes: 2, category: .images, proposedDestination: "~/Organized/Images/real.png"
            ),
            FileOrganizerEntry(
                id: UUID(), path: "~/Library/Caches/AtlasFO-Ghost-\(UUID().uuidString)/missing.png",
                fileName: "missing.png", bytes: 1, category: .images,
                proposedDestination: "~/Organized/Images/missing.png"
            ),
        ]
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: E2EFileOrganizerScanner(entries: entries)
        )
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        await model.runFileOrganizerScan(folderPaths: [sourceDir.path])
        await model.executeFileOrganizerPlan()

        XCTAssertTrue(model.fileOrganizerExecutionCompleted, "partial success is still completed")
        XCTAssertEqual(model.fileOrganizerExecutionReceipt?.movedItemCount, 1)
        XCTAssertEqual(model.fileOrganizerExecutionReceipt?.failedItemCount, 1, "partial failure must surface failedItemCount")
        XCTAssertNil(model.fileOrganizerExecutionReceipt?.failureReason)
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
        XCTAssertNotNil(model.fileOrganizerPlanOutcome)
    }

    /// `CT-04`：`.unavailable(reason:)` 的生产/消费成对。
    ///
    /// 契约一 §1.2(2)：**「条件不满足」≠「控件不适用」** —— 凡「动作可恢复但本次
    /// 无可恢复项」一律落 `.unavailable(reason)`（禁用 + 理由），**不得隐藏**。
    ///
    /// 文件整理的撤销此前是**裸 `return`**：点一下，画面毫无变化，用户无从知道
    /// 为什么。本用例钉住「必须写入 `.unavailable` 且理由非空」。
    ///
    /// 反向守卫：若把该分支改回裸 `return`（或用 `.available` / 不写槽），
    /// 本用例必红。
    func testFileOrganizerUndoWithNoRecoveryItemWritesUnavailableOutcome() async {
        let repository = makeRepository()
        // 快照里**没有** fileOrganizer 恢复项 ⇒ 撤销动作本次无可恢复项。
        _ = try? repository.saveState(
            AtlasWorkspaceState(
                snapshot: AtlasWorkspaceSnapshot(
                    reclaimableSpaceBytes: 0, findings: [], apps: [], taskRuns: [],
                    recoveryItems: [], permissions: [], healthSnapshot: nil
                ),
                currentPlan: ActionPlan(title: "", items: [], estimatedBytes: 0),
                settings: AtlasScaffoldWorkspace.state().settings
            )
        )
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let model = AtlasAppModel(repository: repository, workerService: worker, ledgerNumberStore: InMemoryLedgerNumberStore())

        XCTAssertTrue(
            model.snapshot.recoveryItems.isEmpty,
            "前提：本用例要求快照里没有恢复项，否则落不到 .unavailable 分支"
        )

        await model.undoFileOrganizerExecution()

        let outcome = model.fileOrganizerPlanOutcome
        XCTAssertNotNil(outcome, "无可恢复项时撤销必须留下可读的结果，不得静默 return（契约一 §1.2(2)）")
        XCTAssertNotNil(
            outcome?.unavailableReason,
            "必须落 `.unavailable(reason)` 且理由非空 —— 「条件不满足」要给出可读的为什么"
        )
        XCTAssertFalse(
            outcome?.isError == true,
            "「本次没有可恢复项」不是错误态，不得走 AtlasErrorState"
        )
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

/// `I-5` 的**时序**探针：在扫描被发起的那一刻读一次模型的 preamble 标志。
///
/// 关键在「读的时机」：`preambleShownAtScanTime` 是在 `scanFolders` **内部**采样的，
/// 因此它记录的是「扫描真正开始时」的状态。把
/// `fileOrganizerScanPreambleShown = true` 挪到扫描调用**之后**，
/// 采样点读到 false ⇒ 守卫变红（复审 `TS-03` 要求的正是这种相关性）。
///
/// `@unchecked Sendable`：`AtlasFileOrganizerScanning` 要求 `Sendable`，
/// 而这里要记录可变状态。测试内单线程驱动（`await model.runFileOrganizerScan`
/// 串行 await），不存在并发访问。
private final class RecordingFileOrganizerScanner: AtlasFileOrganizerScanning, @unchecked Sendable {
    let entries: [FileOrganizerEntry]
    private(set) var scanCallCount = 0
    private(set) var preambleShownAtScanTime = false
    /// 由测试在 `runFileOrganizerScan` 之前注入 —— 每次扫描时调用，返回当时的 preamble 状态。
    var preambleProbe: (() -> Bool)?

    init(entries: [FileOrganizerEntry]) {
        self.entries = entries
    }

    func scanFolders(_ paths: [String], destinationBasePath: String = "~/Organized", recursive: Bool = false) async throws -> FileOrganizerScanResult {
        scanCallCount += 1
        // 采样点：扫描被发起的那一刻。
        preambleShownAtScanTime = preambleProbe?() ?? false
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
