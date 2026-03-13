import XCTest
@testable import AtlasInfrastructure
import AtlasApplication
import AtlasDomain
import AtlasProtocol

final class AtlasInfrastructureTests: XCTestCase {
    func testRepositoryPersistsWorkspaceState() {
        let fileURL = temporaryStateFileURL()
        let repository = AtlasWorkspaceRepository(stateFileURL: fileURL)
        var state = AtlasScaffoldWorkspace.state()
        state.settings.recoveryRetentionDays = 21

        XCTAssertNoThrow(try repository.saveState(state))
        let loaded = repository.loadState()

        XCTAssertEqual(loaded.settings.recoveryRetentionDays, 21)
        XCTAssertEqual(loaded.snapshot.apps.count, state.snapshot.apps.count)
    }


    func testRepositorySaveStateThrowsForInvalidParentURL() {
        let repository = AtlasWorkspaceRepository(
            stateFileURL: URL(fileURLWithPath: "/dev/null/workspace-state.json")
        )

        XCTAssertThrowsError(try repository.saveState(AtlasScaffoldWorkspace.state()))
    }

    func testRepositorySaveStatePrunesExpiredRecoveryItems() throws {
        let baseDate = Date(timeIntervalSince1970: 1_710_000_000)
        let clock = TestClock(now: baseDate)
        let repository = AtlasWorkspaceRepository(
            stateFileURL: temporaryStateFileURL(),
            nowProvider: { clock.now }
        )
        let activeItem = RecoveryItem(
            id: UUID(),
            title: "Active recovery",
            detail: "Still valid",
            originalPath: "~/Library/Caches/Active",
            bytes: 5,
            deletedAt: baseDate.addingTimeInterval(-120),
            expiresAt: baseDate.addingTimeInterval(3600),
            payload: nil,
            restoreMappings: nil
        )
        let expiredItem = RecoveryItem(
            id: UUID(),
            title: "Expired recovery",
            detail: "Expired",
            originalPath: "~/Library/Caches/Expired",
            bytes: 7,
            deletedAt: baseDate.addingTimeInterval(-7200),
            expiresAt: baseDate.addingTimeInterval(-1),
            payload: nil,
            restoreMappings: nil
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0,
                findings: [],
                apps: [],
                taskRuns: [],
                recoveryItems: [activeItem, expiredItem],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 0 selected findings", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )

        let saved = try repository.saveState(state)

        XCTAssertEqual(saved.snapshot.recoveryItems.map(\.id), [activeItem.id])
        XCTAssertEqual(repository.loadState().snapshot.recoveryItems.map(\.id), [activeItem.id])
    }

    func testExecutePlanMovesSupportedFindingsIntoRecoveryWhileKeepingInspectionOnlyItems() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("sample.cache")
        try Data("cache".utf8).write(to: targetFile)

        let supportedFinding = Finding(
            id: UUID(),
            title: "Sample cache",
            detail: targetFile.path,
            bytes: 5,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetFile.path]
        )
        let unsupportedPath = home.appendingPathComponent("Documents/AtlasUnsupported/" + UUID().uuidString).path
        let unsupportedFinding = Finding(
            id: UUID(),
            title: "Unsupported cache",
            detail: unsupportedPath,
            bytes: 7,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [unsupportedPath]
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 12,
                findings: [supportedFinding, unsupportedFinding],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(
                title: "Review 2 selected findings",
                items: [
                    ActionItem(id: supportedFinding.id, title: "Move Sample cache to Trash", detail: supportedFinding.detail, kind: .removeCache, recoverable: true),
                    ActionItem(id: unsupportedFinding.id, title: "Inspect Unsupported cache", detail: unsupportedFinding.detail, kind: .inspectPermission, recoverable: false),
                ],
                estimatedBytes: 12
            ),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let executeResult = try await worker.submit(
            AtlasRequestEnvelope(command: .executePlan(planID: state.currentPlan.id))
        )

        if case let .accepted(task) = executeResult.response.response {
            XCTAssertEqual(task.kind, .executePlan)
        } else {
            XCTFail("Expected accepted execute-plan response")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetFile.path))
        XCTAssertEqual(executeResult.snapshot.findings.count, 1)
        XCTAssertEqual(executeResult.snapshot.findings.first?.id, unsupportedFinding.id)
        XCTAssertEqual(executeResult.snapshot.recoveryItems.count, 1)

        let restoredItemID = try XCTUnwrap(executeResult.snapshot.recoveryItems.first?.id)
        let restoreTaskID = UUID()
        let restoreResult = try await worker.submit(
            AtlasRequestEnvelope(command: .restoreItems(taskID: restoreTaskID, itemIDs: [restoredItemID]))
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path))
        XCTAssertEqual(Set(restoreResult.snapshot.findings.map(\.id)), Set([supportedFinding.id, unsupportedFinding.id]))
        XCTAssertEqual(restoreResult.snapshot.recoveryItems.count, 0)
    }

    func testExecutePlanPreservesCompletedRecoveryEntriesWhenLaterFindingFailsInStateOnlyMode() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        let cacheDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        let cacheFile = cacheDirectory.appendingPathComponent("sample.cache")
        try Data("cache".utf8).write(to: cacheFile)

        let helperDirectory = home.appendingPathComponent("Applications/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: helperDirectory, withIntermediateDirectories: true)
        let helperFile = helperDirectory.appendingPathComponent("HelperRequired.app")
        try Data("helper".utf8).write(to: helperFile)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: helperDirectory)
        }

        let supportedFinding = Finding(
            id: UUID(),
            title: "Sample cache",
            detail: cacheFile.path,
            bytes: 5,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [cacheFile.path]
        )
        let helperRequiredFinding = Finding(
            id: UUID(),
            title: "Helper required cleanup",
            detail: helperFile.path,
            bytes: 7,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [helperFile.path]
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 12,
                findings: [supportedFinding, helperRequiredFinding],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(
                title: "Review 2 selected findings",
                items: [
                    ActionItem(id: supportedFinding.id, title: "Move Sample cache to Trash", detail: supportedFinding.detail, kind: .removeCache, recoverable: true),
                    ActionItem(id: helperRequiredFinding.id, title: "Move Helper required cleanup to Trash", detail: helperRequiredFinding.detail, kind: .removeCache, recoverable: true),
                ],
                estimatedBytes: 12
            ),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let result = try await worker.submit(AtlasRequestEnvelope(command: .executePlan(planID: state.currentPlan.id)))

        if case let .accepted(task) = result.response.response {
            XCTAssertEqual(task.kind, .executePlan)
        } else {
            XCTFail("Expected accepted execute-plan response")
        }
        XCTAssertFalse(fileManager.fileExists(atPath: cacheFile.path))
        XCTAssertTrue(fileManager.fileExists(atPath: helperFile.path))
        XCTAssertEqual(result.snapshot.recoveryItems.count, 1)
        XCTAssertEqual(result.snapshot.recoveryItems.first?.title, supportedFinding.title)
        XCTAssertEqual(result.snapshot.findings.map(\.id), [helperRequiredFinding.id])
        XCTAssertEqual(result.snapshot.taskRuns.first?.status, .failed)
        XCTAssertEqual(
            result.snapshot.taskRuns.first?.summary,
            [
                AtlasL10n.string("infrastructure.execute.summary.clean.one", language: state.settings.language, 1),
                AtlasL10n.string("infrastructure.execute.summary.clean.failed.one", language: state.settings.language, 1),
            ].joined(separator: " ")
        )
    }

    func testStartScanRejectsWhenProviderFailsWithoutFallback() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            smartCleanScanProvider: FailingSmartCleanProvider(),
            allowProviderFailureFallback: false
        )

        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .startScan(taskID: UUID()))
        )

        guard case let .rejected(code, reason) = result.response.response else {
            return XCTFail("Expected rejected scan response")
        }
        XCTAssertEqual(code, .executionUnavailable)
        XCTAssertTrue(reason.contains("Smart Clean scan is unavailable"))
    }

    func testPermissionInspectorMarksFullDiskAccessGrantedWhenAnyProbeIsReadable() async {
        let probeURLs = [
            URL(fileURLWithPath: "/tmp/unreadable"),
            URL(fileURLWithPath: "/tmp/readable"),
        ]
        let inspector = AtlasPermissionInspector(
            homeDirectoryURL: URL(fileURLWithPath: "/tmp"),
            fullDiskAccessProbeURLs: probeURLs,
            protectedLocationReader: { url in url.path == "/tmp/readable" },
            accessibilityStatusProvider: { false },
            notificationsAuthorizationProvider: { false }
        )

        let permissions = await inspector.snapshot()
        let fullDiskAccess = permissions.first(where: { $0.kind == .fullDiskAccess })

        XCTAssertEqual(fullDiskAccess?.isGranted, true)
    }

    func testPermissionInspectorMarksFullDiskAccessMissingWhenAllProbesFail() async {
        let probeURLs = [
            URL(fileURLWithPath: "/tmp/probe-a"),
            URL(fileURLWithPath: "/tmp/probe-b"),
        ]
        let inspector = AtlasPermissionInspector(
            homeDirectoryURL: URL(fileURLWithPath: "/tmp"),
            fullDiskAccessProbeURLs: probeURLs,
            protectedLocationReader: { _ in false },
            accessibilityStatusProvider: { false },
            notificationsAuthorizationProvider: { false }
        )

        let permissions = await inspector.snapshot()
        let fullDiskAccess = permissions.first(where: { $0.kind == .fullDiskAccess })

        XCTAssertEqual(fullDiskAccess?.isGranted, false)
        XCTAssertTrue(fullDiskAccess?.rationale.contains("重新打开") == true || fullDiskAccess?.rationale.contains("reopen Atlas") == true)
    }

    func testUnsupportedTargetIsDowngradedToInspectionAndDoesNotFailExecution() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let unsupportedPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/AtlasUnsupported/" + UUID().uuidString).path
        let finding = Finding(
            id: UUID(),
            title: "Unsupported cache",
            detail: unsupportedPath,
            bytes: 5,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [unsupportedPath]
        )
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 5,
                findings: [finding],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(
                title: "Review 1 selected finding",
                items: [ActionItem(id: finding.id, title: "Inspect Unsupported cache", detail: finding.detail, kind: .inspectPermission, recoverable: false)],
                estimatedBytes: 5
            ),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let result = try await worker.submit(AtlasRequestEnvelope(command: .executePlan(planID: state.currentPlan.id)))

        if case let .accepted(task) = result.response.response {
            XCTAssertEqual(task.kind, .executePlan)
        } else {
            XCTFail("Expected accepted execute-plan response")
        }
        XCTAssertEqual(result.snapshot.findings.count, 1)
        XCTAssertEqual(result.snapshot.recoveryItems.count, 0)
    }

    func testInspectionOnlyPlanIsAcceptedWithoutMutatingState() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let initialState = repository.loadState()

        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .executePlan(planID: initialState.currentPlan.id))
        )

        if case let .accepted(task) = result.response.response {
            XCTAssertEqual(task.kind, .executePlan)
        } else {
            XCTFail("Expected accepted execute-plan response")
        }
        XCTAssertEqual(result.snapshot.findings.count, initialState.snapshot.findings.count)
        XCTAssertEqual(result.snapshot.recoveryItems.count, initialState.snapshot.recoveryItems.count)
    }

    func testExecutePlanRejectsWhenFailClosedExecutionFailsBeforeAnySideEffect() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let fileManager = FileManager.default
        let helperDirectory = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: helperDirectory, withIntermediateDirectories: true)
        let helperFile = helperDirectory.appendingPathComponent("HelperRequired.app")
        try Data("helper".utf8).write(to: helperFile)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: helperDirectory)
        }

        let finding = Finding(
            id: UUID(),
            title: "Helper required cleanup",
            detail: helperFile.path,
            bytes: 7,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [helperFile.path]
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 7,
                findings: [finding],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(
                title: "Review 1 selected finding",
                items: [ActionItem(id: finding.id, title: "Move Helper required cleanup to Trash", detail: finding.detail, kind: .removeCache, recoverable: true)],
                estimatedBytes: 7
            ),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let result = try await worker.submit(AtlasRequestEnvelope(command: .executePlan(planID: state.currentPlan.id)))

        guard case let .rejected(code, reason) = result.response.response else {
            return XCTFail("Expected rejected execute-plan response")
        }
        XCTAssertEqual(code, .executionUnavailable)
        XCTAssertTrue(reason.contains("Bundled helper unavailable"))
        XCTAssertTrue(fileManager.fileExists(atPath: helperFile.path))
        XCTAssertEqual(result.snapshot.findings.map(\.id), [finding.id])
        XCTAssertEqual(result.snapshot.recoveryItems.count, 0)
    }

    func testZcompdumpTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zcompdump")
        let finding = Finding(
            id: UUID(),
            title: "Zsh completion cache",
            detail: targetURL.path,
            bytes: 1,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetURL.path]
        )

        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(targetURL))
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
    }

    func testPnpmStoreTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/pnpm/store/v3/files/atlas-fixture/package.tgz")
        let finding = Finding(
            id: UUID(),
            title: "pnpm store",
            detail: targetURL.path,
            bytes: 1,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetURL.path]
        )

        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(targetURL))
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
    }

    func testExecutePlanTrashesRealTargetsWhenAvailable() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("sample.cache")
        try Data("cache".utf8).write(to: targetFile)

        let finding = Finding(
            id: UUID(),
            title: "Sample cache",
            detail: targetFile.path,
            bytes: 5,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetFile.path]
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 5,
                findings: [finding],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 1 selected finding", items: [ActionItem(id: finding.id, title: "Move Sample cache to Trash", detail: finding.detail, kind: .removeCache, recoverable: true)], estimatedBytes: 5),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let result = try await worker.submit(AtlasRequestEnvelope(command: .executePlan(planID: state.currentPlan.id)))

        if case let .accepted(task) = result.response.response {
            XCTAssertEqual(task.kind, .executePlan)
        } else {
            XCTFail("Expected accepted execute-plan response")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetFile.path))
        XCTAssertEqual(result.snapshot.findings.count, 0)
    }

    func testExecutePlanUsesStructuredTargetPathsCarriedByCurrentPlan() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("plan-target.cache")
        try Data("cache".utf8).write(to: targetFile)

        let finding = Finding(
            id: UUID(),
            title: "Plan-backed cache",
            detail: targetFile.path,
            bytes: 5,
            risk: .safe,
            category: "Developer tools",
            targetPaths: nil
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 5,
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
                        title: "Move Plan-backed cache to Trash",
                        detail: finding.detail,
                        kind: .removeCache,
                        recoverable: true,
                        targetPaths: [targetFile.path]
                    )
                ],
                estimatedBytes: 5
            ),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let result = try await worker.submit(AtlasRequestEnvelope(command: .executePlan(planID: state.currentPlan.id)))

        if case let .accepted(task) = result.response.response {
            XCTAssertEqual(task.kind, .executePlan)
        } else {
            XCTFail("Expected accepted execute-plan response")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetFile.path))
        XCTAssertEqual(result.snapshot.findings.count, 0)
        XCTAssertEqual(result.snapshot.recoveryItems.first?.originalPath, targetFile.path)
    }

    func testScanExecuteRescanRemovesExecutedTargetFromRealResults() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("sample.cache")
        try Data("cache".utf8).write(to: targetFile)

        let provider = FileBackedSmartCleanProvider(targetFileURL: targetFile)
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            smartCleanScanProvider: provider,
            allowProviderFailureFallback: false,
            allowStateOnlyCleanExecution: false
        )

        let firstScan = try await worker.submit(AtlasRequestEnvelope(command: .startScan(taskID: UUID())))
        XCTAssertEqual(firstScan.snapshot.findings.count, 1)
        let planID = try XCTUnwrap(firstScan.previewPlan?.id)

        let execute = try await worker.submit(AtlasRequestEnvelope(command: .executePlan(planID: planID)))
        if case let .accepted(task) = execute.response.response {
            XCTAssertEqual(task.kind, .executePlan)
        } else {
            XCTFail("Expected accepted execute-plan response")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetFile.path))

        let secondScan = try await worker.submit(AtlasRequestEnvelope(command: .startScan(taskID: UUID())))
        XCTAssertEqual(secondScan.snapshot.findings.count, 0)
        XCTAssertEqual(secondScan.snapshot.reclaimableSpaceBytes, 0)
    }

    func testScanExecuteRescanRemovesExecutedPnpmStoreTargetFromRealResults() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent("Library/pnpm/store/v3/files/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("package.tgz")
        try Data("pnpm-cache".utf8).write(to: targetFile)

        let provider = FileBackedSmartCleanProvider(targetFileURL: targetFile, title: "pnpm store")
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            smartCleanScanProvider: provider,
            allowProviderFailureFallback: false,
            allowStateOnlyCleanExecution: false
        )

        let firstScan = try await worker.submit(AtlasRequestEnvelope(command: .startScan(taskID: UUID())))
        XCTAssertEqual(firstScan.snapshot.findings.count, 1)
        let planID = try XCTUnwrap(firstScan.previewPlan?.id)
        let initialRecoveryCount = firstScan.snapshot.recoveryItems.count

        let execute = try await worker.submit(AtlasRequestEnvelope(command: .executePlan(planID: planID)))
        if case let .accepted(task) = execute.response.response {
            XCTAssertEqual(task.kind, .executePlan)
        } else {
            XCTFail("Expected accepted execute-plan response")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetFile.path))
        XCTAssertEqual(execute.snapshot.recoveryItems.count, initialRecoveryCount + 1)
        XCTAssertTrue(execute.snapshot.recoveryItems.contains(where: { $0.title == "pnpm store" }))

        let secondScan = try await worker.submit(AtlasRequestEnvelope(command: .startScan(taskID: UUID())))
        XCTAssertEqual(secondScan.snapshot.findings.count, 0)
        XCTAssertEqual(secondScan.snapshot.reclaimableSpaceBytes, 0)
    }

    func testExecutePlanDoesNotCreateRecoveryEntryWhenTargetIsAlreadyGone() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("sample.cache")

        let finding = Finding(
            id: UUID(),
            title: "Stale cache",
            detail: targetFile.path,
            bytes: 5,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetFile.path]
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 5,
                findings: [finding],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 1 selected finding", items: [ActionItem(id: finding.id, title: "Move Stale cache to Trash", detail: finding.detail, kind: .removeCache, recoverable: true)], estimatedBytes: 5),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let result = try await worker.submit(AtlasRequestEnvelope(command: .executePlan(planID: state.currentPlan.id)))

        if case let .accepted(task) = result.response.response {
            XCTAssertEqual(task.kind, .executePlan)
        } else {
            XCTFail("Expected accepted execute-plan response")
        }
        XCTAssertEqual(result.snapshot.recoveryItems.count, 0)
        XCTAssertEqual(result.snapshot.findings.count, 0)
        XCTAssertEqual(
            result.snapshot.taskRuns.first?.summary,
            AtlasL10n.string("infrastructure.execute.summary.clean.stale.one", language: state.settings.language)
        )
    }

    func testRestoreRecoveryItemPhysicallyRestoresRealTargets() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("sample.cache")
        try Data("cache".utf8).write(to: targetFile)

        let finding = Finding(
            id: UUID(),
            title: "Sample cache",
            detail: targetFile.path,
            bytes: 5,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetFile.path]
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 5,
                findings: [finding],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 1 selected finding", items: [ActionItem(id: finding.id, title: "Move Sample cache to Trash", detail: finding.detail, kind: .removeCache, recoverable: true)], estimatedBytes: 5),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let execute = try await worker.submit(AtlasRequestEnvelope(command: .executePlan(planID: state.currentPlan.id)))
        let recoveryItemID = try XCTUnwrap(execute.snapshot.recoveryItems.first?.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetFile.path))

        let restore = try await worker.submit(AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [recoveryItemID])))

        if case let .accepted(task) = restore.response.response {
            XCTAssertEqual(task.kind, .restore)
        } else {
            XCTFail("Expected accepted restore response")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path))
        XCTAssertEqual(
            restore.snapshot.taskRuns.first?.summary,
            AtlasL10n.string("infrastructure.restore.summary.disk.one", language: state.settings.language)
        )
    }

    func testRestoreItemsStateOnlySummaryDoesNotClaimOnDiskRestore() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let finding = Finding(
            id: UUID(),
            title: "Atlas-only fixture",
            detail: "State-only recovery item",
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
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
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

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let restore = try await worker.submit(AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [recoveryItem.id])))

        if case let .accepted(task) = restore.response.response {
            XCTAssertEqual(task.kind, .restore)
        } else {
            XCTFail("Expected accepted restore response")
        }
        XCTAssertEqual(
            restore.snapshot.taskRuns.first?.summary,
            AtlasL10n.string("infrastructure.restore.summary.state.one", language: state.settings.language)
        )
    }

    func testRestoreItemsRejectsExpiredRecoveryItemsAndPrunesThem() async throws {
        let baseDate = Date(timeIntervalSince1970: 1_710_000_000)
        let clock = TestClock(now: baseDate)
        let repository = AtlasWorkspaceRepository(
            stateFileURL: temporaryStateFileURL(),
            nowProvider: { clock.now }
        )
        let finding = Finding(
            id: UUID(),
            title: "Atlas-only fixture",
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
            allowStateOnlyCleanExecution: false
        )
        clock.now = baseDate.addingTimeInterval(60)

        let restore = try await worker.submit(
            AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [recoveryItem.id]))
        )

        guard case let .rejected(code, reason) = restore.response.response else {
            return XCTFail("Expected rejected restore response")
        }
        XCTAssertEqual(code, .restoreExpired)
        XCTAssertTrue(reason.contains("expired"))
        XCTAssertFalse(restore.snapshot.recoveryItems.contains(where: { $0.id == recoveryItem.id }))
        XCTAssertFalse(repository.loadState().snapshot.recoveryItems.contains(where: { $0.id == recoveryItem.id }))
    }

    func testRestoreItemsMixedSummaryIncludesDiskAndStateOnlyClauses() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("sample.cache")
        try Data("cache".utf8).write(to: targetFile)

        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: targetFile, resultingItemURL: &trashedURL)
        let trashedPath = try XCTUnwrap((trashedURL as URL?)?.path)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: targetDirectory)
            if let trashedURL {
                try? FileManager.default.removeItem(at: trashedURL as URL)
            }
        }

        let fileBackedFinding = Finding(
            id: UUID(),
            title: "Disk-backed fixture",
            detail: targetFile.path,
            bytes: 5,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetFile.path]
        )
        let stateOnlyFinding = Finding(
            id: UUID(),
            title: "Atlas-only fixture",
            detail: "State-only recovery item",
            bytes: 7,
            risk: .safe,
            category: "Developer tools"
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0,
                findings: [],
                apps: [],
                taskRuns: [],
                recoveryItems: [
                    RecoveryItem(
                        id: UUID(),
                        title: fileBackedFinding.title,
                        detail: fileBackedFinding.detail,
                        originalPath: targetFile.path,
                        bytes: fileBackedFinding.bytes,
                        deletedAt: Date(),
                        expiresAt: Date().addingTimeInterval(3600),
                        payload: .finding(fileBackedFinding),
                        restoreMappings: [RecoveryPathMapping(originalPath: targetFile.path, trashedPath: trashedPath)]
                    ),
                    RecoveryItem(
                        id: UUID(),
                        title: stateOnlyFinding.title,
                        detail: stateOnlyFinding.detail,
                        originalPath: "~/Library/Caches/AtlasOnly",
                        bytes: stateOnlyFinding.bytes,
                        deletedAt: Date(),
                        expiresAt: Date().addingTimeInterval(3600),
                        payload: .finding(stateOnlyFinding),
                        restoreMappings: nil
                    ),
                ],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 0 selected findings", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let restoreItemIDs = state.snapshot.recoveryItems.map(\.id)
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let restore = try await worker.submit(AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: restoreItemIDs)))

        if case let .accepted(task) = restore.response.response {
            XCTAssertEqual(task.kind, .restore)
        } else {
            XCTFail("Expected accepted restore response")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetFile.path))
        XCTAssertTrue(restore.snapshot.findings.contains(where: { $0.id == fileBackedFinding.id }))
        XCTAssertTrue(restore.snapshot.findings.contains(where: { $0.id == stateOnlyFinding.id }))
        XCTAssertEqual(
            restore.snapshot.taskRuns.first?.summary,
            [
                AtlasL10n.string("infrastructure.restore.summary.disk.one", language: state.settings.language),
                AtlasL10n.string("infrastructure.restore.summary.state.one", language: state.settings.language),
            ].joined(separator: " ")
        )
    }

    func testRestoreItemsRejectsWhenDestinationAlreadyExists() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let sourceDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        let destinationDirectory = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let trashedCandidate = sourceDirectory.appendingPathComponent("trashed.cache")
        try Data("trashed".utf8).write(to: trashedCandidate)
        var trashedURL: NSURL?
        try fileManager.trashItem(at: trashedCandidate, resultingItemURL: &trashedURL)
        let trashedPath = try XCTUnwrap((trashedURL as URL?)?.path)

        let destinationURL = destinationDirectory.appendingPathComponent("trashed.cache")
        try Data("existing".utf8).write(to: destinationURL)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
            if let trashedURL {
                try? FileManager.default.removeItem(at: trashedURL as URL)
            }
        }

        let finding = Finding(
            id: UUID(),
            title: "Conflicting restore",
            detail: destinationURL.path,
            bytes: 7,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [destinationURL.path]
        )
        let recoveryItem = RecoveryItem(
            id: UUID(),
            title: finding.title,
            detail: finding.detail,
            originalPath: destinationURL.path,
            bytes: 7,
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            payload: .finding(finding),
            restoreMappings: [RecoveryPathMapping(originalPath: destinationURL.path, trashedPath: trashedPath)]
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

        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: false)
        let restore = try await worker.submit(
            AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [recoveryItem.id]))
        )

        guard case let .rejected(code, reason) = restore.response.response else {
            return XCTFail("Expected rejected restore response")
        }
        XCTAssertEqual(code, .restoreConflict)
        XCTAssertTrue(reason.contains(destinationURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: destinationURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: trashedPath))
    }

    func testExecuteAppUninstallRemovesAppAndCreatesRecoveryEntry() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let worker = AtlasScaffoldWorkerService(repository: repository, allowStateOnlyCleanExecution: true)
        let initialState = repository.loadState()
        let app = try XCTUnwrap(initialState.snapshot.apps.first)

        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .executeAppUninstall(appID: app.id))
        )

        XCTAssertFalse(result.snapshot.apps.contains(where: { $0.id == app.id }))
        XCTAssertTrue(result.snapshot.recoveryItems.contains(where: { $0.title == app.name }))
        XCTAssertEqual(result.snapshot.taskRuns.first?.kind, .uninstallApp)
    }

    func testExecuteAppUninstallRestorePhysicallyRestoresAppBundle() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let fileManager = FileManager.default
        let appRoot = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        let appBundleURL = appRoot.appendingPathComponent("Atlas Restore Test.app", isDirectory: true)
        try fileManager.createDirectory(at: appBundleURL, withIntermediateDirectories: true)
        let executableURL = appBundleURL.appendingPathComponent("Contents/MacOS/AtlasRestoreTest")
        try fileManager.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: appRoot)
        }

        let app = AppFootprint(
            id: UUID(),
            name: "Atlas Restore Test",
            bundleIdentifier: "com.atlas.restore-test",
            bundlePath: appBundleURL.path,
            bytes: 17,
            leftoverItems: 1
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: app.bytes,
                findings: [],
                apps: [app],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 0 selected findings", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            helperExecutor: StubPrivilegedHelperExecutor(),
            allowStateOnlyCleanExecution: false
        )

        let execute = try await worker.submit(
            AtlasRequestEnvelope(command: .executeAppUninstall(appID: app.id))
        )

        if case let .accepted(task) = execute.response.response {
            XCTAssertEqual(task.kind, .uninstallApp)
        } else {
            XCTFail("Expected accepted uninstall response")
        }

        XCTAssertFalse(fileManager.fileExists(atPath: appBundleURL.path))
        XCTAssertFalse(execute.snapshot.apps.contains(where: { $0.id == app.id }))

        let recoveryItem = try XCTUnwrap(execute.snapshot.recoveryItems.first)
        XCTAssertEqual(recoveryItem.restoreMappings?.first?.originalPath, appBundleURL.path)
        XCTAssertNotNil(recoveryItem.restoreMappings?.first?.trashedPath)

        let restore = try await worker.submit(
            AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [recoveryItem.id]))
        )

        if case let .accepted(task) = restore.response.response {
            XCTAssertEqual(task.kind, .restore)
        } else {
            XCTFail("Expected accepted restore response")
        }

        XCTAssertTrue(fileManager.fileExists(atPath: appBundleURL.path))
        XCTAssertTrue(restore.snapshot.apps.contains(where: { $0.id == app.id }))
        XCTAssertEqual(
            restore.snapshot.taskRuns.first?.summary,
            AtlasL10n.string("infrastructure.restore.summary.disk.one", language: state.settings.language)
        )
    }

    private func temporaryStateFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("workspace-state.json")
    }

}

private struct FailingSmartCleanProvider: AtlasSmartCleanScanProviding {
    func collectSmartCleanScan() async throws -> AtlasSmartCleanScanResult {
        struct SampleError: LocalizedError { var errorDescription: String? { "simulated scan failure" } }
        throw SampleError()
    }
}

private struct FileBackedSmartCleanProvider: AtlasSmartCleanScanProviding {
    let targetFileURL: URL
    var title: String = "Sample cache"
    var category: String = "Developer tools"

    func collectSmartCleanScan() async throws -> AtlasSmartCleanScanResult {
        guard FileManager.default.fileExists(atPath: targetFileURL.path) else {
            return AtlasSmartCleanScanResult(findings: [], summary: "No reclaimable items remain.")
        }
        let size = Int64((try? FileManager.default.attributesOfItem(atPath: targetFileURL.path)[.size] as? NSNumber)?.int64Value ?? 0)
        let finding = Finding(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000001") ?? UUID(),
            title: title,
            detail: targetFileURL.path,
            bytes: size,
            risk: .safe,
            category: category,
            targetPaths: [targetFileURL.path]
        )
        return AtlasSmartCleanScanResult(findings: [finding], summary: "Found 1 reclaimable item.")
    }
}

private actor StubPrivilegedHelperExecutor: AtlasPrivilegedActionExecuting {
    func perform(_ action: AtlasHelperAction) async throws -> AtlasHelperActionResult {
        let fileManager = FileManager.default
        let targetURL = URL(fileURLWithPath: action.targetPath)

        switch action.kind {
        case .trashItems:
            var trashedURL: NSURL?
            try fileManager.trashItem(at: targetURL, resultingItemURL: &trashedURL)
            return AtlasHelperActionResult(
                action: action,
                success: true,
                message: "Moved item to Trash.",
                resolvedPath: (trashedURL as URL?)?.path
            )
        case .restoreItem:
            let destinationPath = try XCTUnwrap(action.destinationPath)
            let destinationURL = URL(fileURLWithPath: destinationPath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: targetURL, to: destinationURL)
            return AtlasHelperActionResult(
                action: action,
                success: true,
                message: "Restored item from Trash.",
                resolvedPath: destinationURL.path
            )
        case .removeLaunchService, .repairOwnership:
            throw NSError(domain: "StubPrivilegedHelperExecutor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported test helper action: \(action.kind)"])
        }
    }
}

private final class TestClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
