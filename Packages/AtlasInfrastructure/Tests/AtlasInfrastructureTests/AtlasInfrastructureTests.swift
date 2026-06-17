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

    func testRepositoryPersistsVersionedWorkspaceEnvelope() throws {
        let fileURL = temporaryStateFileURL()
        let repository = AtlasWorkspaceRepository(stateFileURL: fileURL)

        XCTAssertNoThrow(try repository.saveState(AtlasScaffoldWorkspace.state()))

        let data = try Data(contentsOf: fileURL)
        let persisted = try JSONDecoder().decode(AtlasPersistedWorkspaceState.self, from: data)

        XCTAssertEqual(persisted.schemaVersion, AtlasWorkspaceStateSchemaVersion.current)
        XCTAssertFalse(persisted.snapshot.apps.isEmpty)
    }

    func testRepositoryLoadsLegacyWorkspaceStateAndRewritesEnvelope() throws {
        let fileURL = temporaryStateFileURL()
        let legacyState = AtlasScaffoldWorkspace.state()
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(legacyState).write(to: fileURL)

        let repository = AtlasWorkspaceRepository(stateFileURL: fileURL)
        let loaded = repository.loadState()

        XCTAssertEqual(loaded.snapshot.apps.count, legacyState.snapshot.apps.count)

        let migratedData = try Data(contentsOf: fileURL)
        let persisted = try JSONDecoder().decode(AtlasPersistedWorkspaceState.self, from: migratedData)
        XCTAssertEqual(persisted.schemaVersion, AtlasWorkspaceStateSchemaVersion.current)
        XCTAssertEqual(persisted.snapshot.apps.count, legacyState.snapshot.apps.count)
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

    func testGradleCacheTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gradle/caches/modules-2/files-2.1/atlas-fixture.bin")
        let finding = Finding(
            id: UUID(),
            title: "Gradle cache",
            detail: targetURL.path,
            bytes: 1,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetURL.path]
        )

        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(targetURL))
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
    }

    func testSwiftPMCacheTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".swiftpm/cache/repositories/atlas-fixture.bin")
        let finding = Finding(
            id: UUID(),
            title: "SwiftPM cache",
            detail: targetURL.path,
            bytes: 1,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetURL.path]
        )

        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(targetURL))
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
    }

    func testPytestCacheTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".pytest_cache/v/cache/atlas-fixture")
        let finding = Finding(
            id: UUID(),
            title: "pytest cache",
            detail: targetURL.path,
            bytes: 1,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetURL.path]
        )

        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(targetURL))
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
    }

    func testAWSCLICacheTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aws/cli/cache/atlas-fixture.json")
        let finding = Finding(
            id: UUID(),
            title: "AWS CLI cache",
            detail: targetURL.path,
            bytes: 1,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetURL.path]
        )

        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(targetURL))
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
    }

    func testCoreSimulatorCacheTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Caches/atlas-fixture/device-cache.db")
        let finding = Finding(
            id: UUID(),
            title: "CoreSimulator cache",
            detail: targetURL.path,
            bytes: 1,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetURL.path]
        )

        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(targetURL))
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
    }

    func testContainerCacheTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.example.preview/Data/Library/Caches/cache.db")
        let finding = Finding(
            id: UUID(),
            title: "Container cache",
            detail: targetURL.path,
            bytes: 1,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetURL.path]
        )

        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(targetURL))
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
    }

    func testContainerLogsTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.example.preview/Data/Library/Logs/runtime.log")
        let finding = Finding(
            id: UUID(),
            title: "Container logs",
            detail: targetURL.path,
            bytes: 1,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [targetURL.path]
        )

        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(targetURL))
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding))
    }

    func testContainerTempTargetIsSupportedExecutionTarget() {
        let targetURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.example.preview/Data/tmp/runtime.tmp")
        let finding = Finding(
            id: UUID(),
            title: "Container temp",
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

    func testScanExecuteRescanRemovesExecutedGradleCacheTargetFromRealResults() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent(".gradle/caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("modules.bin")
        try Data("gradle-cache".utf8).write(to: targetFile)

        let provider = FileBackedSmartCleanProvider(targetFileURL: targetFile, title: "Gradle cache")
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

    func testScanExecuteRescanRemovesExecutedSwiftPMCacheTargetFromRealResults() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent(".swiftpm/cache/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("repositories.bin")
        try Data("swiftpm-cache".utf8).write(to: targetFile)

        let provider = FileBackedSmartCleanProvider(targetFileURL: targetFile, title: "SwiftPM cache")
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

    func testScanExecuteRescanRemovesExecutedContainerCacheTargetFromRealResults() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targetDirectory = home.appendingPathComponent("Library/Containers/com.example.atlas-fixture/Data/Library/Caches/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
        let targetFile = targetDirectory.appendingPathComponent("cache.db")
        try Data("container-cache".utf8).write(to: targetFile)

        let provider = FileBackedSmartCleanProvider(targetFileURL: targetFile, title: "com.example.atlas-fixture container cache")
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

    func testRestoreItemsKeepsStateUnchangedWhenLaterHelperRestoreFails() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        let directRoot = home.appendingPathComponent("Library/Caches/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directRoot, withIntermediateDirectories: true)
        let directTargetURL = directRoot.appendingPathComponent("restored.cache")
        try Data("restored".utf8).write(to: directTargetURL)
        var directTrashedURL: NSURL?
        try fileManager.trashItem(at: directTargetURL, resultingItemURL: &directTrashedURL)
        let directTrashedPath = try XCTUnwrap((directTrashedURL as URL?)?.path)

        let appRoot = home.appendingPathComponent("Applications/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        let appBundleURL = appRoot.appendingPathComponent("Atlas Restore Conflict.app", isDirectory: true)
        try fileManager.createDirectory(at: appBundleURL.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: appBundleURL.appendingPathComponent("Contents/MacOS/AtlasRestoreConflict"))
        var appTrashedURL: NSURL?
        try fileManager.trashItem(at: appBundleURL, resultingItemURL: &appTrashedURL)
        let appTrashedPath = try XCTUnwrap((appTrashedURL as URL?)?.path)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: directRoot)
            try? FileManager.default.removeItem(at: appRoot)
            if let directTrashedURL {
                try? FileManager.default.removeItem(at: directTrashedURL as URL)
            }
            if let appTrashedURL {
                try? FileManager.default.removeItem(at: appTrashedURL as URL)
            }
        }

        let directFinding = Finding(
            id: UUID(),
            title: "Direct restore fixture",
            detail: directTargetURL.path,
            bytes: 11,
            risk: .safe,
            category: "Developer tools",
            targetPaths: [directTargetURL.path]
        )
        let helperApp = AppFootprint(
            id: UUID(),
            name: "Atlas Restore Conflict",
            bundleIdentifier: "com.atlas.restore-conflict",
            bundlePath: appBundleURL.path,
            bytes: 17,
            leftoverItems: 1
        )
        let directRecoveryItem = RecoveryItem(
            id: UUID(),
            title: directFinding.title,
            detail: directFinding.detail,
            originalPath: directTargetURL.path,
            bytes: directFinding.bytes,
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            payload: .finding(directFinding),
            restoreMappings: [RecoveryPathMapping(originalPath: directTargetURL.path, trashedPath: directTrashedPath)]
        )
        let helperRecoveryItem = RecoveryItem(
            id: UUID(),
            title: helperApp.name,
            detail: helperApp.bundlePath,
            originalPath: helperApp.bundlePath,
            bytes: helperApp.bytes,
            deletedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            payload: .app(
                AtlasAppRecoveryPayload(
                    app: helperApp,
                    uninstallEvidence: AtlasAppUninstallEvidence(
                        bundlePath: helperApp.bundlePath,
                        bundleBytes: helperApp.bytes,
                        reviewOnlyGroups: []
                    )
                )
            ),
            restoreMappings: [RecoveryPathMapping(originalPath: helperApp.bundlePath, trashedPath: appTrashedPath)]
        )
        let state = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0,
                findings: [],
                apps: [],
                taskRuns: [],
                recoveryItems: [directRecoveryItem, helperRecoveryItem],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "Review 0 selected findings", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            helperExecutor: RestoreConflictPrivilegedHelperExecutor(),
            allowStateOnlyCleanExecution: false
        )

        let restore = try await worker.submit(
            AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [directRecoveryItem.id, helperRecoveryItem.id]))
        )

        guard case let .rejected(code, reason) = restore.response.response else {
            return XCTFail("Expected rejected restore response")
        }
        XCTAssertEqual(code, .restoreConflict)
        XCTAssertTrue(reason.contains(helperApp.bundlePath))

        XCTAssertTrue(fileManager.fileExists(atPath: directTargetURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: directTrashedPath))
        XCTAssertFalse(fileManager.fileExists(atPath: helperApp.bundlePath))
        XCTAssertTrue(fileManager.fileExists(atPath: appTrashedPath))

        XCTAssertFalse(restore.snapshot.findings.contains(where: { $0.id == directFinding.id }))
        XCTAssertFalse(restore.snapshot.apps.contains(where: { $0.id == helperApp.id }))
        XCTAssertEqual(restore.snapshot.recoveryItems.map(\.id), [directRecoveryItem.id, helperRecoveryItem.id])

        let persisted = repository.loadState()
        XCTAssertFalse(persisted.snapshot.findings.contains(where: { $0.id == directFinding.id }))
        XCTAssertFalse(persisted.snapshot.apps.contains(where: { $0.id == helperApp.id }))
        XCTAssertEqual(persisted.snapshot.recoveryItems.map(\.id), [directRecoveryItem.id, helperRecoveryItem.id])
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
        XCTAssertEqual(
            result.snapshot.taskRuns.first?.summary,
            AtlasL10n.string("infrastructure.apps.uninstall.summary", language: initialState.settings.language, app.name)
        )
    }

    func testExecuteAppUninstallSummaryMentionsReviewOnlyEvidenceGroupsWhenPresent() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let fileManager = FileManager.default
        let sandboxRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let homeRoot = sandboxRoot.appendingPathComponent("Home", isDirectory: true)
        let cacheURL = homeRoot.appendingPathComponent("Library/Caches/com.example.execute", isDirectory: true)
        let logsURL = homeRoot.appendingPathComponent("Library/Logs/Execute Preview", isDirectory: true)

        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 64).write(to: cacheURL.appendingPathComponent("cache.bin"))
        try Data(repeating: 0x2, count: 64).write(to: logsURL.appendingPathComponent("run.log"))

        addTeardownBlock {
            try? FileManager.default.removeItem(at: sandboxRoot)
        }

        let appRoot = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications/AtlasExecutionTests/" + UUID().uuidString, isDirectory: true)
        let appBundleURL = appRoot.appendingPathComponent("Execute Preview.app", isDirectory: true)
        try fileManager.createDirectory(at: appBundleURL, withIntermediateDirectories: true)
        let executableURL = appBundleURL.appendingPathComponent("Contents/MacOS/ExecutePreview")
        try fileManager.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: appRoot)
        }

        let app = AppFootprint(
            id: UUID(),
            name: "Execute Preview",
            bundleIdentifier: "com.example.execute",
            bundlePath: appBundleURL.path,
            bytes: 17,
            leftoverItems: 2
        )
        var settings = AtlasScaffoldWorkspace.state().settings
        settings.language = .en

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
            settings: settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            helperExecutor: StubPrivilegedHelperExecutor(),
            appUninstallEvidenceAnalyzer: AtlasAppUninstallEvidenceAnalyzer(homeDirectoryURL: homeRoot),
            allowStateOnlyCleanExecution: false
        )

        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .executeAppUninstall(appID: app.id))
        )

        XCTAssertEqual(
            result.snapshot.taskRuns.first?.summary,
            AtlasL10n.string("infrastructure.apps.uninstall.summary.review.other", language: .en, app.name, 2)
                + " "
                + AtlasL10n.string("infrastructure.apps.uninstall.reviewCategories", language: .en, "caches, logs")
        )
        XCTAssertEqual(
            result.snapshot.recoveryItems.first?.detail,
            AtlasL10n.string("infrastructure.recovery.app.detail.other", language: .en, 2)
                + " "
                + AtlasL10n.string("infrastructure.apps.uninstall.reviewCategories", language: .en, "caches, logs")
        )
    }

    func testPreviewAppUninstallBuildsReviewOnlyEvidenceItems() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let fileManager = FileManager.default
        let sandboxRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let homeRoot = sandboxRoot.appendingPathComponent("Home", isDirectory: true)
        let appSupportURL = homeRoot.appendingPathComponent("Library/Application Support/Atlas Preview", isDirectory: true)
        let cacheURL = homeRoot.appendingPathComponent("Library/Caches/com.example.preview", isDirectory: true)
        let launchAgentURL = homeRoot.appendingPathComponent("Library/LaunchAgents/com.example.preview.plist")

        try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: launchAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 256).write(to: appSupportURL.appendingPathComponent("state.db"))
        try Data(repeating: 0x2, count: 128).write(to: cacheURL.appendingPathComponent("cache.bin"))
        try Data("<?xml version=\"1.0\"?><plist></plist>".utf8).write(to: launchAgentURL)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: sandboxRoot)
        }

        let app = AppFootprint(
            id: UUID(),
            name: "Atlas Preview",
            bundleIdentifier: "com.example.preview",
            bundlePath: "/Applications/Atlas Preview.app",
            bytes: 2_048,
            leftoverItems: 3
        )

        var settings = AtlasScaffoldWorkspace.state().settings
        settings.language = .en

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
            settings: settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            appUninstallEvidenceAnalyzer: AtlasAppUninstallEvidenceAnalyzer(homeDirectoryURL: homeRoot),
            allowStateOnlyCleanExecution: true
        )

        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .previewAppUninstall(appID: app.id))
        )

        guard case let .preview(plan) = result.response.response else {
            return XCTFail("Expected preview response")
        }

        XCTAssertEqual(plan.estimatedBytes, app.bytes)
        XCTAssertEqual(plan.items.first?.kind, .removeApp)
        XCTAssertEqual(plan.items.first?.targetPaths, [app.bundlePath])
        XCTAssertEqual(plan.items.count, 4)
        let supportFilesItem = try XCTUnwrap(plan.items.first(where: { $0.title == "Review support files (1)" && !$0.recoverable }))
        let cachesItem = try XCTUnwrap(plan.items.first(where: { $0.title == "Review caches (1)" && !$0.recoverable }))
        let launchItemsItem = try XCTUnwrap(plan.items.first(where: { $0.title == "Review launch items (1)" && !$0.recoverable }))
        XCTAssertEqual(supportFilesItem.evidencePaths, [appSupportURL.path])
        XCTAssertEqual(cachesItem.evidencePaths, [cacheURL.path])
        XCTAssertEqual(launchItemsItem.evidencePaths, [launchAgentURL.path])
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

    func testRestoreAppUsesPersistedUninstallEvidenceCountWhenAvailable() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let app = AppFootprint(
            id: UUID(),
            name: "Atlas Restore Evidence",
            bundleIdentifier: "com.example.restore-evidence",
            bundlePath: "/Applications/Atlas Restore Evidence.app",
            bytes: 42,
            leftoverItems: 1
        )
        let recoveryItem = RecoveryItem(
            id: UUID(),
            title: app.name,
            detail: app.bundlePath,
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
                        reviewOnlyGroups: [
                            AtlasAppFootprintEvidenceGroup(
                                category: .caches,
                                items: [
                                    AtlasAppFootprintEvidenceItem(path: "/Users/test/Library/Caches/com.example.restore-evidence", bytes: 12),
                                    AtlasAppFootprintEvidenceItem(path: "/Users/test/Library/Caches/com.example.restore-evidence-2", bytes: 12),
                                ]
                            ),
                            AtlasAppFootprintEvidenceGroup(
                                category: .logs,
                                items: [
                                    AtlasAppFootprintEvidenceItem(path: "/Users/test/Library/Logs/Atlas Restore Evidence", bytes: 8)
                                ]
                            )
                        ]
                    )
                )
            ),
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
            allowStateOnlyCleanExecution: true
        )

        let restore = try await worker.submit(
            AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [recoveryItem.id]))
        )

        let restoredApp = try XCTUnwrap(restore.snapshot.apps.first(where: { $0.id == app.id }))
        XCTAssertEqual(restoredApp.leftoverItems, 3)
    }

    // MARK: - AtlasAuditStore

    func testAuditStoreAppendsAndRetrieves() async {
        let store = AtlasAuditStore()
        await store.append("first")
        await store.append("second")
        let entries = await store.allEntries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].message, "second")
        XCTAssertEqual(entries[1].message, "first")
    }

    func testAuditStoreTrimsOldEntriesWhenExceedingMaxEntries() async {
        let maxEntries = 5
        let store = AtlasAuditStore(maxEntries: maxEntries)
        for i in 0..<10 {
            await store.append("entry-\(i)")
        }
        let entries = await store.allEntries()
        XCTAssertEqual(entries.count, maxEntries)
        // Most recent entries should be kept (inserted at index 0)
        XCTAssertEqual(entries[0].message, "entry-9")
        XCTAssertEqual(entries[4].message, "entry-5")
    }

    func testAuditStoreRespectsCustomMaxEntries() async {
        let store = AtlasAuditStore(entries: [], maxEntries: 2)
        await store.append("a")
        await store.append("b")
        await store.append("c")
        let entries = await store.allEntries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].message, "c")
        XCTAssertEqual(entries[1].message, "b")
    }

    func testAuditStoreInitializesWithExistingEntries() async {
        let existing = [
            AuditEntry(id: UUID(), createdAt: Date(), message: "old-1"),
            AuditEntry(id: UUID(), createdAt: Date(), message: "old-2"),
        ]
        let store = AtlasAuditStore(entries: existing, maxEntries: 512)
        let entries = await store.allEntries()
        XCTAssertEqual(entries.count, 2)
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

private actor RestoreConflictPrivilegedHelperExecutor: AtlasPrivilegedActionExecuting {
    func perform(_ action: AtlasHelperAction) async throws -> AtlasHelperActionResult {
        AtlasHelperActionResult(
            action: action,
            success: false,
            message: "Restore destination already exists: \(action.destinationPath ?? "<missing>")"
        )
    }
}

// MARK: - File Organizer Use-Case Tests

extension AtlasInfrastructureTests {

    private func emptyWorkspaceState() -> AtlasWorkspaceState {
        AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: 0,
                findings: [],
                apps: [],
                taskRuns: [],
                recoveryItems: [],
                permissions: [],
                healthSnapshot: nil
            ),
            currentPlan: ActionPlan(title: "", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
    }

    func testFileOrganizerScanReturnsFixtureEntriesWhenNoProvider() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let worker = AtlasScaffoldWorkerService(repository: repository)

        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )

        if case let .fileOrganizerEntries(entries) = result.response.response {
            XCTAssertFalse(entries.isEmpty, "Should return fixture entries when no scan provider")
            XCTAssertEqual(result.snapshot.fileOrganizerEntries.count, entries.count)
        } else {
            XCTFail("Expected fileOrganizerEntries response")
        }
    }

    func testFileOrganizerScanUsesProviderWhenAvailable() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let stubEntries = [
            FileOrganizerEntry(path: "~/Desktop/test.png", fileName: "test.png", bytes: 1024, category: .images, proposedDestination: "~/Organized/Images/test.png")
        ]
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: stubEntries)
        )

        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )

        if case let .fileOrganizerEntries(entries) = result.response.response {
            XCTAssertEqual(entries.count, 1)
            XCTAssertEqual(entries.first?.fileName, "test.png")
        } else {
            XCTFail("Expected fileOrganizerEntries response")
        }
    }

    func testFileOrganizerScanRejectsOnProviderFailure() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: FailingFileOrganizerScanner()
        )

        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )

        if case let .rejected(code, _) = result.response.response {
            XCTAssertEqual(code, .executionUnavailable)
        } else {
            XCTFail("Expected rejected response for scan failure")
        }
    }

    func testFileOrganizerPreviewPlanGeneratesActionItems() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        _ = try repository.saveState(emptyWorkspaceState())

        let entries = [
            FileOrganizerEntry(id: UUID(uuidString: "a0000000-0000-0000-0000-000000000001")!, path: "~/Desktop/a.png", fileName: "a.png", bytes: 100, category: .images, proposedDestination: "~/Organized/Images/a.png"),
            FileOrganizerEntry(id: UUID(uuidString: "a0000000-0000-0000-0000-000000000002")!, path: "~/Desktop/b.pdf", fileName: "b.pdf", bytes: 200, category: .documents, proposedDestination: "~/Organized/Documents/b.pdf"),
        ]
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: entries)
        )
        _ = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )

        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerPreviewPlan(taskID: UUID(), entryIDs: []))
        )

        if case let .fileOrganizerPlan(plan) = result.response.response {
            XCTAssertEqual(plan.items.count, 2)
            XCTAssertEqual(plan.estimatedBytes, 300)
            XCTAssertTrue(plan.items.allSatisfy { $0.kind == .organizeFile })
            XCTAssertTrue(plan.items.allSatisfy { $0.recoverable })
        } else {
            XCTFail("Expected fileOrganizerPlan response")
        }
    }

    func testFileOrganizerExecutePlanMovesFilesAndCreatesRecoveryItem() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        _ = try repository.saveState(emptyWorkspaceState())
        let fm = FileManager.default

        // Create real temp file inside home directory so path traversal guard passes
        let homeDir = fm.homeDirectoryForCurrentUser.path
        let sourceDir = (homeDir as NSString).appendingPathComponent("Library/Caches/AtlasFOTest-\(UUID().uuidString)")
        try fm.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)
        let sourceFileURL = URL(fileURLWithPath: sourceDir).appendingPathComponent("sample.png")
        try Data("png-data".utf8).write(to: sourceFileURL)
        addTeardownBlock {
            try? fm.removeItem(atPath: sourceDir)
            try? fm.removeItem(atPath: (homeDir as NSString).appendingPathComponent("Organized"))
        }

        let displayPath = "~" + String(sourceFileURL.path.dropFirst(homeDir.count))
        let displayDest = "~/Organized/Images/sample.png"

        let entry = FileOrganizerEntry(
            path: displayPath,
            fileName: "sample.png",
            bytes: 8,
            category: .images,
            proposedDestination: displayDest
        )

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: [entry])
        )
        _ = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )

        let planResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerPreviewPlan(taskID: UUID(), entryIDs: []))
        )
        guard case let .fileOrganizerPlan(plan) = planResult.response.response else {
            XCTFail("Expected plan"); return
        }

        let executeResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerExecutePlan(planID: plan.id))
        )

        if case let .accepted(task) = executeResult.response.response {
            XCTAssertEqual(task.kind, TaskKind.organizeFiles)
        } else if case let .rejected(_, reason) = executeResult.response.response {
            XCTFail("Execute was rejected: \(reason)")
        } else {
            XCTFail("Expected accepted response, got \(executeResult.response.response)")
        }

        XCTAssertFalse(fm.fileExists(atPath: sourceFileURL.path))
        let destPath = (displayDest as NSString).expandingTildeInPath
        XCTAssertTrue(fm.fileExists(atPath: destPath))

        // Empty state had 0 recovery items, so after execute should have 1
        XCTAssertEqual(executeResult.snapshot.recoveryItems.count, 1)
        XCTAssertEqual(executeResult.snapshot.fileOrganizerEntries.count, 0)
    }

    func testFileOrganizerExecutePlanRejectsStalePlanID() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        _ = try repository.saveState(emptyWorkspaceState())

        let entries = [
            FileOrganizerEntry(path: "~/Desktop/test.png", fileName: "test.png", bytes: 100, category: .images, proposedDestination: "~/Organized/Images/test.png")
        ]
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: entries)
        )
        _ = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )

        let stalePlanID = UUID()
        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerExecutePlan(planID: stalePlanID))
        )

        if case let .rejected(code, _) = result.response.response {
            XCTAssertEqual(code, .invalidSelection)
        } else {
            XCTFail("Expected rejected response for stale plan ID")
        }
    }

    func testFileOrganizerDryRunValidatesPlanID() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        _ = try repository.saveState(emptyWorkspaceState())

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: [
                FileOrganizerEntry(path: "~/Desktop/test.png", fileName: "test.png", bytes: 100, category: .images, proposedDestination: "~/Organized/Images/test.png")
            ])
        )
        _ = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )

        let stalePlanID = UUID()
        let result = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerDryRun(planID: stalePlanID))
        )

        if case let .rejected(code, _) = result.response.response {
            XCTAssertEqual(code, .invalidSelection)
        } else {
            XCTFail("Expected rejected response for stale plan ID in dry run")
        }
    }

    func testFileOrganizerDryRunAcceptsCurrentPlanID() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        _ = try repository.saveState(emptyWorkspaceState())

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: [
                FileOrganizerEntry(path: "~/Desktop/test.png", fileName: "test.png", bytes: 100, category: .images, proposedDestination: "~/Organized/Images/test.png")
            ])
        )
        _ = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )

        let planResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerPreviewPlan(taskID: UUID(), entryIDs: []))
        )
        guard case let .fileOrganizerPlan(plan) = planResult.response.response else {
            XCTFail("Expected plan, got \(planResult.response.response)"); return
        }

        let dryRunResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerDryRun(planID: plan.id))
        )

        if case let .fileOrganizerPlan(dryRunPlan) = dryRunResult.response.response {
            XCTAssertEqual(dryRunPlan.items.count, plan.items.count)
        } else {
            XCTFail("Expected fileOrganizerPlan response from dry run, got \(dryRunResult.response.response)")
        }
    }

    func testFileOrganizerExecuteHandlesDuplicateFilenames() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        _ = try repository.saveState(emptyWorkspaceState())

        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser.path

        // Create two source directories with same-named file inside home
        let testBase = (homeDir as NSString).appendingPathComponent("Library/Caches/AtlasFODupTest-\(UUID().uuidString)")
        let sourceDir1 = (testBase as NSString).appendingPathComponent("dir1")
        let sourceDir2 = (testBase as NSString).appendingPathComponent("dir2")
        try fm.createDirectory(atPath: sourceDir1, withIntermediateDirectories: true)
        try fm.createDirectory(atPath: sourceDir2, withIntermediateDirectories: true)
        let file1 = (sourceDir1 as NSString).appendingPathComponent("dup.png")
        let file2 = (sourceDir2 as NSString).appendingPathComponent("dup.png")
        try Data("png1".utf8).write(to: URL(fileURLWithPath: file1))
        try Data("png2".utf8).write(to: URL(fileURLWithPath: file2))
        addTeardownBlock {
            try? fm.removeItem(atPath: testBase)
            try? fm.removeItem(atPath: (homeDir as NSString).appendingPathComponent("Organized"))
        }

        let displayPath1 = "~" + String(file1.dropFirst(homeDir.count))
        let displayPath2 = "~" + String(file2.dropFirst(homeDir.count))

        let entries = [
            FileOrganizerEntry(path: displayPath1, fileName: "dup.png", bytes: 4, category: .images, proposedDestination: "~/Organized/Images/dup.png"),
            FileOrganizerEntry(path: displayPath2, fileName: "dup.png", bytes: 4, category: .images, proposedDestination: "~/Organized/Images/dup.png"),
        ]

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: entries)
        )
        _ = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )

        let planResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerPreviewPlan(taskID: UUID(), entryIDs: []))
        )
        guard case let .fileOrganizerPlan(plan) = planResult.response.response else {
            XCTFail("Expected plan"); return
        }

        let executeResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerExecutePlan(planID: plan.id))
        )

        // Both files should be moved (second gets renamed with (1) suffix)
        XCTAssertEqual(executeResult.snapshot.recoveryItems.first?.restoreMappings?.count, 2)
        XCTAssertFalse(fm.fileExists(atPath: file1))
        XCTAssertFalse(fm.fileExists(atPath: file2))
    }

    func testFileOrganizerExecuteSkipsOutOfHomePath() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        _ = try repository.saveState(emptyWorkspaceState())

        let entry = FileOrganizerEntry(
            path: "/etc/hosts",
            fileName: "hosts",
            bytes: 200,
            category: .other,
            proposedDestination: "/etc/Organized/hosts"
        )

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: [entry])
        )
        _ = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["/etc"]))
        )

        let planResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerPreviewPlan(taskID: UUID(), entryIDs: []))
        )
        guard case let .fileOrganizerPlan(plan) = planResult.response.response else {
            XCTFail("Expected plan"); return
        }

        let executeResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerExecutePlan(planID: plan.id))
        )

        // Should complete but with 0 moves (out-of-scope paths skipped)
        XCTAssertEqual(executeResult.snapshot.recoveryItems.count, 0)
        // /etc/hosts should still exist (not moved)
        XCTAssertTrue(FileManager.default.fileExists(atPath: "/etc/hosts"))
    }

    func testFileOrganizerExecuteRejectsSystemDirDestinationViaHomeGuard() async throws {
        // audit security #22: a destination that PASSES AtlasPathValidator's
        // safeRoots (e.g. /Applications) but lies OUTSIDE the user's home must
        // be rejected by the worker's home guard — never written. The sibling
        // test above uses /etc, which safeRoots rejects upstream and so never
        // reaches the guard; this one targets the guard directly.
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        _ = try repository.saveState(emptyWorkspaceState())

        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser.path
        let source = (homeDir as NSString).appendingPathComponent("Library/Caches/AtlasFOHomeGuard-\(UUID().uuidString).png")
        try Data("x".utf8).write(to: URL(fileURLWithPath: source))
        addTeardownBlock { try? fm.removeItem(atPath: source) }

        let entry = FileOrganizerEntry(
            path: source, fileName: "x.png", bytes: 1, category: .images,
            proposedDestination: "/Applications/AtlasFOHomeGuard-\(UUID().uuidString)/x.png"
        )
        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: [entry])
        )
        _ = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~/Desktop"]))
        )
        let planResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerPreviewPlan(taskID: UUID(), entryIDs: []))
        )
        guard case let .fileOrganizerPlan(plan) = planResult.response.response else {
            XCTFail("Expected plan"); return
        }
        let executeResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerExecutePlan(planID: plan.id))
        )

        XCTAssertEqual(executeResult.snapshot.recoveryItems.count, 0, "must not create a recovery payload for a blocked move")
        XCTAssertEqual(executeResult.failedCount, 1, "the home-guard rejection must surface as a failed move")
        XCTAssertTrue(fm.fileExists(atPath: source), "source must be untouched (move blocked)")
    }

    // MARK: - File Organizer Undo/Restore Tests

    func testFileOrganizerUndoRestoresFilesToOriginalLocation() async throws {
        let repository = AtlasWorkspaceRepository(stateFileURL: temporaryStateFileURL())
        _ = try repository.saveState(emptyWorkspaceState())

        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser.path
        let testBase = (homeDir as NSString).appendingPathComponent("Library/Caches/AtlasFOUndoTest-\(UUID().uuidString)")
        try fm.createDirectory(atPath: testBase, withIntermediateDirectories: true)

        let file1 = (testBase as NSString).appendingPathComponent("report.pdf")
        let file2 = (testBase as NSString).appendingPathComponent("photo.png")
        try Data("pdf-content".utf8).write(to: URL(fileURLWithPath: file1))
        try Data("png-data".utf8).write(to: URL(fileURLWithPath: file2))
        addTeardownBlock {
            try? fm.removeItem(atPath: testBase)
            try? fm.removeItem(atPath: (homeDir as NSString).appendingPathComponent("Organized"))
        }

        let displayPath1 = "~" + String(file1.dropFirst(homeDir.count))
        let displayPath2 = "~" + String(file2.dropFirst(homeDir.count))
        let entries = [
            FileOrganizerEntry(path: displayPath1, fileName: "report.pdf", bytes: 11, category: .documents, proposedDestination: "~/Organized/Documents/report.pdf"),
            FileOrganizerEntry(path: displayPath2, fileName: "photo.png", bytes: 8, category: .images, proposedDestination: "~/Organized/Images/photo.png"),
        ]

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            fileOrganizerScanProvider: StubFileOrganizerScanner(entries: entries)
        )

        // Scan → Preview → Execute
        _ = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerScan(taskID: UUID(), folderPaths: ["~" + String(testBase.dropFirst(homeDir.count))]))
        )
        let planResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerPreviewPlan(taskID: UUID(), entryIDs: []))
        )
        guard case let .fileOrganizerPlan(plan) = planResult.response.response else {
            XCTFail("Expected plan"); return
        }
        let executeResult = try await worker.submit(
            AtlasRequestEnvelope(command: .fileOrganizerExecutePlan(planID: plan.id))
        )

        // Verify files moved away and recovery item created
        XCTAssertFalse(fm.fileExists(atPath: file1))
        XCTAssertFalse(fm.fileExists(atPath: file2))
        XCTAssertEqual(executeResult.snapshot.recoveryItems.count, 1)

        // Restore (undo)
        let recoveryItemID = try XCTUnwrap(executeResult.snapshot.recoveryItems.first?.id)
        let restoreResult = try await worker.submit(
            AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [recoveryItemID]))
        )

        // Verify files restored to original location
        XCTAssertTrue(fm.fileExists(atPath: file1), "file1 should be restored")
        XCTAssertTrue(fm.fileExists(atPath: file2), "file2 should be restored")
        XCTAssertEqual(restoreResult.snapshot.recoveryItems.count, 0, "recovery item should be removed")
        if case let .accepted(task) = restoreResult.response.response {
            XCTAssertEqual(task.kind, .restore)
        } else {
            XCTFail("Expected accepted restore response, got \(restoreResult.response.response)")
        }
    }

    func testFileOrganizerUndoRejectsExpiredRecoveryItem() async throws {
        let baseDate = Date(timeIntervalSince1970: 1_710_000_000)
        let clock = TestClock(now: baseDate)
        let repository = AtlasWorkspaceRepository(
            stateFileURL: temporaryStateFileURL(),
            nowProvider: { clock.now }
        )

        let recoveryItem = RecoveryItem(
            id: UUID(),
            title: "File Organizer",
            detail: "Expired undo",
            originalPath: "~/Desktop",
            bytes: 100,
            deletedAt: baseDate.addingTimeInterval(-60),
            expiresAt: baseDate.addingTimeInterval(-10),
            payload: .fileOrganizer(FileOrganizerRecoveryPayload(
                moveMappings: [FileOrganizerMoveMapping(originalPath: "~/Desktop/test.txt", destinationPath: "~/Organized/Documents/test.txt")],
                sourceFolder: "~/Desktop"
            )),
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
            currentPlan: ActionPlan(title: "", items: [], estimatedBytes: 0),
            settings: AtlasScaffoldWorkspace.state().settings
        )
        _ = try repository.saveState(state)

        let worker = AtlasScaffoldWorkerService(
            repository: repository,
            nowProvider: { clock.now },
            allowStateOnlyCleanExecution: false
        )

        let restore = try await worker.submit(
            AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [recoveryItem.id]))
        )

        guard case let .rejected(code, reason) = restore.response.response else {
            XCTFail("Expected rejected response for expired recovery item"); return
        }
        XCTAssertEqual(code, .invalidSelection)
        XCTAssertTrue(reason.contains("no longer available"), "reason should mention item unavailable, got: \(reason)")
        // Expired items are pruned during save/load, so the item no longer exists → invalidSelection
    }
}

// MARK: - File Organizer Test Stubs

private struct StubFileOrganizerScanner: AtlasFileOrganizerScanning {
    let entries: [FileOrganizerEntry]

    func scanFolders(_ paths: [String], destinationBasePath: String = "~/Organized", recursive: Bool = false) async throws -> FileOrganizerScanResult {
        FileOrganizerScanResult(
            entries: entries,
            totalFiles: entries.count,
            totalBytes: entries.map(\.bytes).reduce(0, +),
            categoryCounts: Dictionary(grouping: entries, by: \.category).mapValues(\.count)
        )
    }
}

private struct FailingFileOrganizerScanner: AtlasFileOrganizerScanning {
    func scanFolders(_ paths: [String], destinationBasePath: String = "~/Organized", recursive: Bool = false) async throws -> FileOrganizerScanResult {
        struct ScanError: LocalizedError { var errorDescription: String? { "simulated scan failure" } }
        throw ScanError()
    }
}

// MARK: - AtlasPathValidator Tests

final class AtlasPathValidatorTests: XCTestCase {
    private let homeURL = URL(fileURLWithPath: "/Users/testuser")

    // MARK: - Valid paths

    func testValidHomeSubdirectory() throws {
        let url = try AtlasPathValidator.validate("/Users/testuser/Library/Caches/test", homeDirectoryURL: homeURL)
        XCTAssertEqual(url.path, "/Users/testuser/Library/Caches/test")
    }

    func testValidApplicationsPath() throws {
        let url = try AtlasPathValidator.validate("/Applications/TestApp.app", homeDirectoryURL: homeURL)
        XCTAssertTrue(url.path.hasPrefix("/Applications/"))
    }

    func testValidLaunchAgentsPath() throws {
        let url = try AtlasPathValidator.validate("/Library/LaunchAgents/com.test.agent.plist", homeDirectoryURL: homeURL)
        XCTAssertTrue(url.path.hasPrefix("/Library/LaunchAgents/"))
    }

    func testValidLaunchDaemonsPath() throws {
        let url = try AtlasPathValidator.validate("/Library/LaunchDaemons/com.test.daemon.plist", homeDirectoryURL: homeURL)
        XCTAssertTrue(url.path.hasPrefix("/Library/LaunchDaemons/"))
    }

    func testHomeDirectoryItselfIsValid() throws {
        let url = try AtlasPathValidator.validate("/Users/testuser", homeDirectoryURL: homeURL)
        XCTAssertEqual(url.path, "/Users/testuser")
    }

    func testApplicationsRootItselfIsValid() throws {
        let url = try AtlasPathValidator.validate("/Applications", homeDirectoryURL: homeURL)
        XCTAssertEqual(url.path, "/Applications")
    }

    // MARK: - Invalid paths

    func testRelativePathRejected() {
        XCTAssertThrowsError(try AtlasPathValidator.validate("relative/path", homeDirectoryURL: homeURL)) { error in
            XCTAssertTrue(error is AtlasPathValidationError)
            if let pathError = error as? AtlasPathValidationError,
               case .relativePath = pathError { } else {
                XCTFail("Expected relativePath error")
            }
        }
    }

    func testNullByteRejected() {
        XCTAssertThrowsError(try AtlasPathValidator.validate("/Users/test\0user/test", homeDirectoryURL: homeURL)) { error in
            XCTAssertTrue(error is AtlasPathValidationError)
            if let pathError = error as? AtlasPathValidationError,
               case .nullByte = pathError { } else {
                XCTFail("Expected nullByte error")
            }
        }
    }

    func testPathTooLongRejected() {
        let longPath = "/Users/testuser/" + String(repeating: "a", count: 1200)
        XCTAssertThrowsError(try AtlasPathValidator.validate(longPath, homeDirectoryURL: homeURL)) { error in
            XCTAssertTrue(error is AtlasPathValidationError)
            if let pathError = error as? AtlasPathValidationError,
               case .pathTooLong = pathError { } else {
                XCTFail("Expected pathTooLong error")
            }
        }
    }

    func testOutsideSafeRootsRejected() {
        XCTAssertThrowsError(try AtlasPathValidator.validate("/etc/passwd", homeDirectoryURL: homeURL)) { error in
            XCTAssertTrue(error is AtlasPathValidationError)
            if let pathError = error as? AtlasPathValidationError,
               case .outsideSafeRoots = pathError { } else {
                XCTFail("Expected outsideSafeRoots error")
            }
        }
    }

    func testSystemPrivateDirRejected() {
        XCTAssertThrowsError(try AtlasPathValidator.validate("/private/var/log/test.log", homeDirectoryURL: homeURL)) { error in
            XCTAssertTrue(error is AtlasPathValidationError)
        }
    }

    func testRootPathRejected() {
        XCTAssertThrowsError(try AtlasPathValidator.validate("/", homeDirectoryURL: homeURL)) { error in
            XCTAssertTrue(error is AtlasPathValidationError)
        }
    }

    // MARK: - validateAll

    func testValidateAllSucceedsForValidPaths() throws {
        let paths = [
            "/Users/testuser/Library/Caches/a",
            "/Applications/Test.app",
        ]
        let urls = try AtlasPathValidator.validateAll(paths, homeDirectoryURL: homeURL)
        XCTAssertEqual(urls.count, 2)
    }

    func testValidateAllThrowsOnFirstInvalid() {
        let paths = [
            "/Users/testuser/Library/Caches/ok",
            "relative/bad",
        ]
        XCTAssertThrowsError(try AtlasPathValidator.validateAll(paths, homeDirectoryURL: homeURL))
    }

    func testValidateAllEmptyArray() throws {
        let urls = try AtlasPathValidator.validateAll([], homeDirectoryURL: homeURL)
        XCTAssertTrue(urls.isEmpty)
    }
}

private final class TestClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}
