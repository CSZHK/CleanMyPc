import AtlasApplication
import AtlasDomain
import AtlasProtocol
import Foundation
import ApplicationServices
import UserNotifications

public struct AuditEntry: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var message: String

    public init(id: UUID = UUID(), createdAt: Date = Date(), message: String) {
        self.id = id
        self.createdAt = createdAt
        self.message = message
    }
}

public actor AtlasAuditStore {
    private var entries: [AuditEntry]

    public init(entries: [AuditEntry] = []) {
        self.entries = entries
    }

    public func append(_ message: String) {
        entries.insert(AuditEntry(message: message), at: 0)
    }

    public func allEntries() -> [AuditEntry] {
        entries
    }
}

public struct AtlasPermissionInspector: Sendable {
    private let fullDiskAccessProbeURLs: [URL]
    private let protectedLocationReader: @Sendable (URL) -> Bool
    private let accessibilityStatusProvider: @Sendable () -> Bool
    private let notificationsAuthorizationProvider: @Sendable () async -> Bool

    public init(
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        fullDiskAccessProbeURLs: [URL]? = nil,
        protectedLocationReader: (@Sendable (URL) -> Bool)? = nil,
        accessibilityStatusProvider: (@Sendable () -> Bool)? = nil,
        notificationsAuthorizationProvider: (@Sendable () async -> Bool)? = nil
    ) {
        self.fullDiskAccessProbeURLs = fullDiskAccessProbeURLs ?? Self.defaultFullDiskAccessProbeURLs(homeDirectoryURL: homeDirectoryURL)
        self.protectedLocationReader = protectedLocationReader ?? { url in
            Self.defaultProtectedLocationReader(url)
        }
        self.accessibilityStatusProvider = accessibilityStatusProvider ?? {
            Self.defaultAccessibilityStatusProvider()
        }
        self.notificationsAuthorizationProvider = notificationsAuthorizationProvider ?? {
            await Self.defaultNotificationsAuthorizationProvider()
        }
    }

    public func snapshot() async -> [PermissionState] {
        [
            fullDiskAccessState(),
            accessibilityState(),
            await notificationsState(),
        ]
    }

    private static func defaultFullDiskAccessProbeURLs(homeDirectoryURL: URL) -> [URL] {
        [
            homeDirectoryURL.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            homeDirectoryURL.appendingPathComponent("Library/Mail", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Safari", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Messages", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Calendars", isDirectory: true),
        ]
    }

    private static func defaultProtectedLocationReader(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }

        if isDirectory.boolValue {
            return (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) != nil
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return false
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            try handle.close()
            return true
        } catch {
            return false
        }
    }

    private static func defaultAccessibilityStatusProvider() -> Bool {
        AXIsProcessTrusted()
    }

    private static func defaultNotificationsAuthorizationProvider() async -> Bool {
        let settings = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    private func fullDiskAccessState() -> PermissionState {
        let accessibleProtectedPath = fullDiskAccessProbeURLs.first(where: protectedLocationReader)
        let isGranted = accessibleProtectedPath != nil
        let rationale = isGranted
            ? AtlasL10n.string("infrastructure.permission.fullDiskAccess.granted")
            : AtlasL10n.string("infrastructure.permission.fullDiskAccess.needed")

        return PermissionState(kind: .fullDiskAccess, isGranted: isGranted, rationale: rationale)
    }

    private func accessibilityState() -> PermissionState {
        let isGranted = accessibilityStatusProvider()
        let rationale = isGranted
            ? AtlasL10n.string("infrastructure.permission.accessibility.granted")
            : AtlasL10n.string("infrastructure.permission.accessibility.needed")
        return PermissionState(kind: .accessibility, isGranted: isGranted, rationale: rationale)
    }

    private func notificationsState() async -> PermissionState {
        let isGranted = await notificationsAuthorizationProvider()
        let rationale = isGranted
            ? AtlasL10n.string("infrastructure.permission.notifications.granted")
            : AtlasL10n.string("infrastructure.permission.notifications.needed")
        return PermissionState(kind: .notifications, isGranted: isGranted, rationale: rationale)
    }
}

public enum AtlasWorkspaceRepositoryError: LocalizedError, Sendable, Equatable {
    case readFailed(String)
    case decodeFailed(String)
    case createDirectoryFailed(String)
    case encodeFailed(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .readFailed(reason):
            return "Failed to read workspace state: \(reason)"
        case let .decodeFailed(reason):
            return "Failed to decode workspace state: \(reason)"
        case let .createDirectoryFailed(reason):
            return "Failed to prepare workspace state directory: \(reason)"
        case let .encodeFailed(reason):
            return "Failed to encode workspace state: \(reason)"
        case let .writeFailed(reason):
            return "Failed to write workspace state: \(reason)"
        }
    }
}

public enum AtlasSmartCleanExecutionSupport {
    public static func requiresHelper(for targetURL: URL, homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let helperRoots = [
            "/Applications",
            homeDirectoryURL.appendingPathComponent("Applications", isDirectory: true).path,
            homeDirectoryURL.appendingPathComponent("Library/LaunchAgents", isDirectory: true).path,
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
        ]
        let path = targetURL.path
        return helperRoots.contains { root in
            path == root || path.hasPrefix(root + "/")
        }
    }

    public static func isDirectlyTrashable(_ targetURL: URL, homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let path = targetURL.path
        let home = homeDirectoryURL.path
        guard path.hasPrefix(home + "/") else { return false }
        if path == home || path == home + "/Library" { return false }

        let safePrefixes = [
            home + "/Library/Caches",
            home + "/Library/Logs",
            home + "/Library/Suggestions",
            home + "/Library/Messages/Caches",
            home + "/Library/Developer/CoreSimulator/Caches",
            home + "/Library/Developer/CoreSimulator/tmp",
            home + "/Library/Developer/Xcode/DerivedData",
            home + "/Library/pnpm/store",
            home + "/.npm",
            home + "/.npm_cache",
            home + "/.gradle/caches",
            home + "/.ivy2/cache",
            home + "/.oh-my-zsh/cache",
            home + "/.cache",
            home + "/.pytest_cache",
            home + "/.jupyter/runtime",
            home + "/.tnpm/_cacache",
            home + "/.tnpm/_logs",
            home + "/.yarn/cache",
            home + "/.bun/install/cache",
            home + "/.pyenv/cache",
            home + "/.conda/pkgs",
            home + "/anaconda3/pkgs",
            home + "/.cargo/registry/cache",
            home + "/.cargo/git",
            home + "/.rustup/downloads",
            home + "/.docker/buildx/cache",
            home + "/.kube/cache",
            home + "/.local/share/containers/storage/tmp",
            home + "/.aws/cli/cache",
            home + "/.config/gcloud/logs",
            home + "/.azure/logs",
            home + "/.node-gyp",
            home + "/.turbo/cache",
            home + "/.vite/cache",
            home + "/.parcel-cache",
            home + "/.android/build-cache",
            home + "/.android/cache",
            home + "/.cache/swift-package-manager",
            home + "/.swiftpm/cache",
            home + "/.expo/expo-go",
            home + "/.expo/android-apk-cache",
            home + "/.expo/ios-simulator-app-cache",
            home + "/.expo/native-modules-cache",
            home + "/.expo/schema-cache",
            home + "/.expo/template-cache",
            home + "/.expo/versions-cache",
            home + "/.vagrant.d/tmp",
        ]
        if safePrefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }

        if isSupportedContainerCleanupPath(path, homeDirectoryURL: homeDirectoryURL) {
            return true
        }

        let safeFragments = [
            "/__pycache__",
            "/.next/cache",
            "/component_crx_cache",
            "/GoogleUpdater",
            "/CoreSimulator.log",
            "/Application Cache",
            "/GPUCache",
            "/cache2",
            "/extensions_crx_cache",
            "/GraphiteDawnCache",
            "/GrShaderCache",
            "/ShaderCache",
        ]
        if safeFragments.contains(where: { path.contains($0) }) {
            return true
        }

        let basename = targetURL.lastPathComponent.lowercased()
        if basename.hasSuffix(".pyc") {
            return true
        }

        let safeBasenamePrefixes = [
            ".zcompdump",
            ".zsh_history.bak",
        ]
        return safeBasenamePrefixes.contains(where: { basename.hasPrefix($0) })
    }

    private static func isSupportedContainerCleanupPath(_ path: String, homeDirectoryURL: URL) -> Bool {
        let containerRoot = homeDirectoryURL.appendingPathComponent("Library/Containers", isDirectory: true).path
        guard path == containerRoot || path.hasPrefix(containerRoot + "/") else {
            return false
        }

        let allowedContainerFragments = [
            "/Data/Library/Caches",
            "/Data/Library/Logs",
            "/Data/tmp",
            "/Data/Library/tmp",
        ]

        return allowedContainerFragments.contains(where: { fragment in
            path == containerRoot + fragment || path.contains(fragment + "/") || path.hasSuffix(fragment)
        })
    }

    public static func isSupportedExecutionTarget(_ targetURL: URL, homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        requiresHelper(for: targetURL, homeDirectoryURL: homeDirectoryURL)
            || isDirectlyTrashable(targetURL, homeDirectoryURL: homeDirectoryURL)
    }

    public static func isFindingExecutionSupported(_ finding: Finding, homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        guard let targetPaths = finding.targetPaths, !targetPaths.isEmpty else {
            return false
        }
        return targetPaths.allSatisfy { rawPath in
            let url = URL(fileURLWithPath: rawPath).resolvingSymlinksInPath()
            return isSupportedExecutionTarget(url, homeDirectoryURL: homeDirectoryURL)
        }
    }
}

public struct AtlasWorkspaceRepository: Sendable {
    private let stateFileURL: URL
    private let nowProvider: @Sendable () -> Date

    public init(
        stateFileURL: URL? = nil,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.stateFileURL = stateFileURL ?? Self.defaultStateFileURL
        self.nowProvider = nowProvider
    }

    public func loadState() -> AtlasWorkspaceState {
        let decoder = JSONDecoder()

        if FileManager.default.fileExists(atPath: stateFileURL.path) {
            do {
                let data = try Data(contentsOf: stateFileURL)
                let decodedResult = try decodePersistedState(from: data, using: decoder)
                let decoded = decodedResult.state
                let normalized = normalizedState(decoded)
                if decodedResult.usedLegacyShape || normalized != decoded {
                    _ = try? saveState(normalized)
                }
                return normalized
            } catch let repositoryError as AtlasWorkspaceRepositoryError {
                reportFailure(repositoryError, operation: "load existing workspace state from \(stateFileURL.path)")
            } catch {
                reportFailure(
                    AtlasWorkspaceRepositoryError.decodeFailed(error.localizedDescription),
                    operation: "decode workspace state from \(stateFileURL.path)"
                )
            }
        }

        let state = AtlasScaffoldWorkspace.state()
        do {
            _ = try saveState(state)
        } catch {
            reportFailure(error, operation: "seed initial workspace state at \(stateFileURL.path)")
        }
        return state
    }

    @discardableResult
    public func saveState(_ state: AtlasWorkspaceState) throws -> AtlasWorkspaceState {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let normalizedState = normalizedState(state)

        do {
            try FileManager.default.createDirectory(
                at: stateFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw AtlasWorkspaceRepositoryError.createDirectoryFailed(error.localizedDescription)
        }

        let data: Data
        do {
            data = try encoder.encode(
                AtlasPersistedWorkspaceState(
                    savedAt: nowProvider(),
                    state: normalizedState
                )
            )
        } catch {
            throw AtlasWorkspaceRepositoryError.encodeFailed(error.localizedDescription)
        }

        do {
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            throw AtlasWorkspaceRepositoryError.writeFailed(error.localizedDescription)
        }

        return normalizedState
    }

    public func loadScaffoldSnapshot() -> AtlasWorkspaceSnapshot {
        loadState().snapshot
    }

    public func loadCurrentPlan() -> ActionPlan {
        loadState().currentPlan
    }

    public func loadSettings() -> AtlasSettings {
        loadState().settings
    }

    private func reportFailure(_ error: Error, operation: String) {
        let message = "[AtlasWorkspaceRepository] Failed to \(operation): \(error.localizedDescription)\n"
        if let data = message.data(using: .utf8) {
            try? FileHandle.standardError.write(contentsOf: data)
        }
    }

    private func normalizedState(_ state: AtlasWorkspaceState) -> AtlasWorkspaceState {
        var normalized = state
        let now = nowProvider()
        normalized.snapshot.recoveryItems.removeAll { item in
            item.isExpired(asOf: now)
        }
        return normalized
    }

    private func decodePersistedState(from data: Data, using decoder: JSONDecoder) throws -> (state: AtlasWorkspaceState, usedLegacyShape: Bool) {
        if let persisted = try? decoder.decode(AtlasPersistedWorkspaceState.self, from: data) {
            return (persisted.workspaceState, false)
        }

        return (try decoder.decode(AtlasWorkspaceState.self, from: data), true)
    }

    private static var defaultStateFileURL: URL {
        if let explicit = ProcessInfo.processInfo.environment["ATLAS_STATE_FILE"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit)
        }

        let baseDirectory: URL
        if let explicitDirectory = ProcessInfo.processInfo.environment["ATLAS_STATE_DIR"], !explicitDirectory.isEmpty {
            baseDirectory = URL(fileURLWithPath: explicitDirectory, isDirectory: true)
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
            baseDirectory = applicationSupport.appendingPathComponent("AtlasForMac", isDirectory: true)
        }

        return baseDirectory.appendingPathComponent("workspace-state.json")
    }
}

public actor AtlasScaffoldWorkerService: AtlasWorkerServing {
    private let repository: AtlasWorkspaceRepository
    private let auditStore: AtlasAuditStore
    private let permissionInspector: AtlasPermissionInspector
    private let healthSnapshotProvider: (any AtlasHealthSnapshotProviding)?
    private let smartCleanScanProvider: (any AtlasSmartCleanScanProviding)?
    private let appsInventoryProvider: (any AtlasAppInventoryProviding)?
    private let helperExecutor: (any AtlasPrivilegedActionExecuting)?
    private let appUninstallEvidenceAnalyzer: AtlasAppUninstallEvidenceAnalyzer
    private let nowProvider: @Sendable () -> Date
    private let allowProviderFailureFallback: Bool
    private let allowStateOnlyCleanExecution: Bool
    private var state: AtlasWorkspaceState

    public init(
        repository: AtlasWorkspaceRepository = AtlasWorkspaceRepository(),
        permissionInspector: AtlasPermissionInspector = AtlasPermissionInspector(),
        healthSnapshotProvider: (any AtlasHealthSnapshotProviding)? = nil,
        smartCleanScanProvider: (any AtlasSmartCleanScanProviding)? = nil,
        appsInventoryProvider: (any AtlasAppInventoryProviding)? = nil,
        helperExecutor: (any AtlasPrivilegedActionExecuting)? = nil,
        appUninstallEvidenceAnalyzer: AtlasAppUninstallEvidenceAnalyzer = AtlasAppUninstallEvidenceAnalyzer(),
        auditStore: AtlasAuditStore = AtlasAuditStore(),
        nowProvider: @escaping @Sendable () -> Date = { Date() },
        allowProviderFailureFallback: Bool = ProcessInfo.processInfo.environment["ATLAS_ALLOW_PROVIDER_FAILURE_FALLBACK"] == "1",
        allowStateOnlyCleanExecution: Bool = ProcessInfo.processInfo.environment["ATLAS_ALLOW_STATE_ONLY_CLEAN_EXECUTION"] == "1"
    ) {
        self.repository = repository
        self.auditStore = auditStore
        self.permissionInspector = permissionInspector
        self.healthSnapshotProvider = healthSnapshotProvider
        self.smartCleanScanProvider = smartCleanScanProvider
        self.appsInventoryProvider = appsInventoryProvider
        self.helperExecutor = helperExecutor
        self.appUninstallEvidenceAnalyzer = appUninstallEvidenceAnalyzer
        self.nowProvider = nowProvider
        self.allowProviderFailureFallback = allowProviderFailureFallback
        self.allowStateOnlyCleanExecution = allowStateOnlyCleanExecution
        self.state = repository.loadState()
        AtlasL10n.setCurrentLanguage(self.state.settings.language)
    }

    public func submit(_ request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult {
        AtlasL10n.setCurrentLanguage(state.settings.language)
        if case .restoreItems = request.command {
            // Restore needs selected-item expiry reporting before the general prune.
        } else {
            await pruneExpiredRecoveryItemsIfNeeded(context: "process request \(request.id.uuidString)")
        }
        switch request.command {
        case .healthSnapshot:
            return try await healthSnapshot(using: request)
        case .inspectPermissions:
            return await inspectPermissions(using: request)
        case let .startScan(taskID):
            return await startScan(using: request, taskID: taskID)
        case let .previewPlan(_, findingIDs):
            return await previewPlan(using: request, findingIDs: findingIDs)
        case let .executePlan(planID):
            return await executePlan(using: request, planID: planID)
        case let .restoreItems(taskID, itemIDs):
            return await restoreItems(using: request, taskID: taskID, itemIDs: itemIDs)
        case .appsList:
            return await listApps(using: request)
        case let .previewAppUninstall(appID):
            return await previewAppUninstall(using: request, appID: appID)
        case let .executeAppUninstall(appID):
            return await executeAppUninstall(using: request, appID: appID)
        case .settingsGet:
            return await settingsGet(using: request)
        case let .settingsSet(settings):
            return await settingsSet(using: request, settings: settings)
        }
    }

    private func healthSnapshot(using request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult {
        let healthSnapshot: AtlasHealthSnapshot

        if let healthSnapshotProvider {
            healthSnapshot = try await healthSnapshotProvider.collectHealthSnapshot()
        } else {
            healthSnapshot = AtlasScaffoldFixtures.healthSnapshot
        }

        state.snapshot.healthSnapshot = healthSnapshot
        await persistState(context: "health snapshot")
        let response = AtlasResponseEnvelope(requestID: request.id, response: .health(healthSnapshot))
        await auditStore.append("Collected health snapshot for request \(request.id.uuidString)")
        return AtlasWorkerCommandResult(request: request, response: response, events: [], snapshot: state.snapshot)
    }

    private func inspectPermissions(using request: AtlasRequestEnvelope) async -> AtlasWorkerCommandResult {
        let permissions = await permissionInspector.snapshot()
        state.snapshot.permissions = permissions
        await persistState(context: "permission inspection")
        let events = permissions.map { permission in
            AtlasEventEnvelope(event: .permissionUpdated(permission))
        }
        let response = AtlasResponseEnvelope(requestID: request.id, response: .permissions(permissions))
        await auditStore.append("Inspected permissions for request \(request.id.uuidString)")
        return AtlasWorkerCommandResult(request: request, response: response, events: events, snapshot: state.snapshot)
    }

    private func startScan(using request: AtlasRequestEnvelope, taskID: UUID) async -> AtlasWorkerCommandResult {
        let scanSummary: String
        if let smartCleanScanProvider {
            do {
                let scanResult = try await smartCleanScanProvider.collectSmartCleanScan()
                state.snapshot.findings = scanResult.findings
                scanSummary = scanResult.summary
            } catch {
                guard allowProviderFailureFallback else {
                    return rejectedResult(
                        for: request,
                        code: .executionUnavailable,
                        reason: "Smart Clean scan is unavailable because the upstream clean workflow could not complete: \(error.localizedDescription)"
                    )
                }
                state.snapshot.findings = AtlasScaffoldFixtures.findings(language: state.settings.language)
                scanSummary = AtlasL10n.string(
                    state.snapshot.findings.count == 1 ? "infrastructure.scan.completed.one" : "infrastructure.scan.completed.other",
                    language: state.settings.language,
                    state.snapshot.findings.count
                )
            }
        } else {
            state.snapshot.findings = AtlasScaffoldFixtures.findings(language: state.settings.language)
            scanSummary = AtlasL10n.string(
                state.snapshot.findings.count == 1 ? "infrastructure.scan.completed.one" : "infrastructure.scan.completed.other",
                language: state.settings.language,
                state.snapshot.findings.count
            )
        }
        recalculateReclaimableSpace()

        let response = AtlasResponseEnvelope(
            requestID: request.id,
            response: .accepted(task: AtlasTaskDescriptor(taskID: taskID, kind: .scan))
        )

        let progressEvents = (1 ... 4).map { step in
            AtlasEventEnvelope(event: .taskProgress(taskID: taskID, completed: step, total: 4))
        }

        let completedRun = TaskRun(
            id: taskID,
            kind: .scan,
            status: .completed,
            summary: scanSummary,
            startedAt: request.issuedAt,
            finishedAt: Date()
        )

        state.snapshot.taskRuns.removeAll { $0.id == taskID }
        state.snapshot.taskRuns.insert(completedRun, at: 0)
        let previewPlan = makePreviewPlan(findingIDs: state.snapshot.findings.map(\.id))
        state.currentPlan = previewPlan
        await persistState(context: "smart clean scan")
        let events = progressEvents + [AtlasEventEnvelope(event: .taskFinished(completedRun))]
        await auditStore.append("Completed Smart Clean scan \(taskID.uuidString)")
        return AtlasWorkerCommandResult(
            request: request,
            response: response,
            events: events,
            snapshot: state.snapshot,
            previewPlan: previewPlan
        )
    }

    private func previewPlan(using request: AtlasRequestEnvelope, findingIDs: [UUID]) async -> AtlasWorkerCommandResult {
        let plan = makePreviewPlan(findingIDs: findingIDs)
        state.currentPlan = plan
        await persistState(context: "preview plan refresh")
        let response = AtlasResponseEnvelope(requestID: request.id, response: .preview(plan))
        await auditStore.append("Prepared preview plan \(plan.id.uuidString) for request \(request.id.uuidString)")
        return AtlasWorkerCommandResult(
            request: request,
            response: response,
            events: [],
            snapshot: state.snapshot,
            previewPlan: plan
        )
    }

    private func executePlan(using request: AtlasRequestEnvelope, planID: UUID) async -> AtlasWorkerCommandResult {
        guard state.currentPlan.id == planID else {
            return rejectedResult(
                for: request,
                code: .invalidSelection,
                reason: "The requested Smart Clean plan is no longer current. Refresh the preview and try again."
            )
        }

        let selectedItems = state.currentPlan.items
        let findingsByID = Dictionary(uniqueKeysWithValues: state.snapshot.findings.map { ($0.id, $0) })
        let missingFindingIDs = selectedItems.compactMap { item in
            findingsByID[item.id] == nil ? item.id : nil
        }

        if !missingFindingIDs.isEmpty {
            return rejectedResult(
                for: request,
                code: .invalidSelection,
                reason: "The requested Smart Clean items are no longer available. Refresh the preview and try again."
            )
        }

        let selectedFindings = selectedItems.compactMap { item in
            findingsByID[item.id]
        }

        guard !selectedFindings.isEmpty else {
            return rejectedResult(
                for: request,
                code: .invalidSelection,
                reason: "The requested Smart Clean items are no longer available. Refresh the preview and try again."
            )
        }

        let executableSelections = selectedItems.compactMap { item -> SmartCleanExecutableSelection? in
            guard item.kind != .inspectPermission, item.kind != .reviewEvidence, let finding = findingsByID[item.id] else {
                return nil
            }
            return SmartCleanExecutableSelection(
                finding: finding,
                targetPaths: resolvedTargetPaths(for: item, finding: finding)
            )
        }
        let missingExecutableTargets = executableSelections.filter { $0.targetPaths.isEmpty }

        if !missingExecutableTargets.isEmpty && !allowStateOnlyCleanExecution {
            return rejectedResult(
                for: request,
                code: .executionUnavailable,
                reason: "Smart Clean execution is unavailable because one or more plan items do not include executable cleanup targets in this build."
            )
        }
        let skippedCount = selectedItems.count - executableSelections.count
        let taskID = UUID()

        let response = AtlasResponseEnvelope(
            requestID: request.id,
            response: .accepted(task: AtlasTaskDescriptor(taskID: taskID, kind: .executePlan))
        )

        var executionResult = SmartCleanExecutionResult()
        if !executableSelections.isEmpty {
            do {
                executionResult = try await executeSmartCleanSelections(executableSelections)
            } catch let failure as SmartCleanExecutionFailure {
                executionResult = failure.result
                if !allowStateOnlyCleanExecution && !executionResult.hasRecordedOutcome {
                    return rejectedResult(
                        for: request,
                        code: .executionUnavailable,
                        reason: failure.localizedDescription
                    )
                }
            } catch {
                if !allowStateOnlyCleanExecution {
                    return rejectedResult(
                        for: request,
                        code: .executionUnavailable,
                        reason: error.localizedDescription
                    )
                }
            }
        }

        let executedFindings = executableSelections.map(\.finding)
        let physicallyExecutedFindings = executedFindings.filter {
            !(executionResult.restoreMappingsByFindingID[$0.id] ?? []).isEmpty
        }
        let staleFindings = executedFindings.filter { executionResult.staleFindingIDs.contains($0.id) }
        let failedFindings = executedFindings.filter { executionResult.failedFindingIDs.contains($0.id) }
        let recoveryItems = physicallyExecutedFindings.map {
            makeRecoveryItem(for: $0, deletedAt: Date(), restoreMappings: executionResult.restoreMappingsByFindingID[$0.id])
        }
        let removedFindingIDs = Set(physicallyExecutedFindings.map(\.id)).union(staleFindings.map(\.id))
        state.snapshot.findings.removeAll { removedFindingIDs.contains($0.id) }
        state.snapshot.recoveryItems.insert(contentsOf: recoveryItems, at: 0)
        recalculateReclaimableSpace()
        state.currentPlan = makePreviewPlan(findingIDs: state.snapshot.findings.map(\.id))

        let summary = smartCleanExecutionSummary(
            executedCount: physicallyExecutedFindings.count,
            staleCount: staleFindings.count,
            reviewOnlyCount: skippedCount,
            failedCount: failedFindings.count
        )

        let completedRun = TaskRun(
            id: taskID,
            kind: .executePlan,
            status: failedFindings.isEmpty ? .completed : .failed,
            summary: summary,
            startedAt: request.issuedAt,
            finishedAt: Date()
        )
        state.snapshot.taskRuns.removeAll { $0.id == taskID }
        state.snapshot.taskRuns.insert(completedRun, at: 0)
        await persistState(context: "execute Smart Clean plan")
        let events = progressEvents(taskID: taskID, total: 3) + [AtlasEventEnvelope(event: .taskFinished(completedRun))]
        if let failureReason = executionResult.failureReason {
            await auditStore.append("Smart Clean execution recorded partial failure: \(failureReason)")
        }
        await auditStore.append("Executed Smart Clean plan \(planID.uuidString)")
        return AtlasWorkerCommandResult(request: request, response: response, events: events, snapshot: state.snapshot)
    }

    private func restoreItems(using request: AtlasRequestEnvelope, taskID: UUID, itemIDs: [UUID]) async -> AtlasWorkerCommandResult {
        let requestedItemIDs = Set(itemIDs)
        let expiredSelectionIDs = requestedItemIDs.intersection(expiredRecoveryItemIDs())

        if !expiredSelectionIDs.isEmpty {
            await pruneExpiredRecoveryItemsIfNeeded(context: "prune expired recovery items before rejected restore")
            return rejectedResult(
                for: request,
                code: .restoreExpired,
                reason: "One or more selected recovery items have expired and can no longer be restored."
            )
        }

        await pruneExpiredRecoveryItemsIfNeeded(context: "refresh recovery retention before restore")
        let itemsToRestore = state.snapshot.recoveryItems.filter { requestedItemIDs.contains($0.id) }

        guard !itemsToRestore.isEmpty else {
            return rejectedResult(
                for: request,
                code: .invalidSelection,
                reason: "The selected recovery item is no longer available."
            )
        }

        do {
            try validateRestoreItems(itemsToRestore)
        } catch let failure as RecoveryRestoreFailure {
            return rejectedResult(
                for: request,
                code: failure.code,
                reason: failure.localizedDescription
            )
        } catch {
            return rejectedResult(
                for: request,
                code: .executionUnavailable,
                reason: error.localizedDescription
            )
        }

        var physicalRestoreCount = 0
        var atlasOnlyRestoreCount = 0

        for item in itemsToRestore {
            if let restoreMappings = item.restoreMappings, !restoreMappings.isEmpty {
                do {
                    try await restoreRecoveryMappings(restoreMappings)
                    physicalRestoreCount += 1
                } catch let failure as RecoveryRestoreFailure {
                    return rejectedResult(
                        for: request,
                        code: failure.code,
                        reason: failure.localizedDescription
                    )
                } catch {
                    return rejectedResult(
                        for: request,
                        code: .executionUnavailable,
                        reason: error.localizedDescription
                    )
                }
            } else {
                atlasOnlyRestoreCount += 1
            }
        }

        for item in itemsToRestore {
            switch item.payload {
            case let .finding(finding):
                if !state.snapshot.findings.contains(where: { $0.id == finding.id }) {
                    state.snapshot.findings.insert(finding, at: 0)
                }
            case let .app(payload):
                var restoredApp = payload.app
                if payload.uninstallEvidence.reviewOnlyItemCount > 0 {
                    restoredApp.leftoverItems = payload.uninstallEvidence.reviewOnlyItemCount
                }
                if !state.snapshot.apps.contains(where: { $0.id == restoredApp.id }) {
                    state.snapshot.apps.insert(restoredApp, at: 0)
                }
            case nil:
                break
            }
        }

        state.snapshot.recoveryItems.removeAll { requestedItemIDs.contains($0.id) }
        recalculateReclaimableSpace()
        state.currentPlan = makePreviewPlan(findingIDs: state.snapshot.findings.map(\.id))

        let completedRun = TaskRun(
            id: taskID,
            kind: .restore,
            status: .completed,
            summary: restoreSummary(physicalRestoreCount: physicalRestoreCount, atlasOnlyRestoreCount: atlasOnlyRestoreCount),
            startedAt: request.issuedAt,
            finishedAt: Date()
        )
        state.snapshot.taskRuns.removeAll { $0.id == taskID }
        state.snapshot.taskRuns.insert(completedRun, at: 0)
        await persistState(context: "restore recovery items")
        let response = AtlasResponseEnvelope(
            requestID: request.id,
            response: .accepted(task: AtlasTaskDescriptor(taskID: taskID, kind: .restore))
        )
        let events = progressEvents(taskID: taskID, total: 2) + [AtlasEventEnvelope(event: .taskFinished(completedRun))]
        await auditStore.append("Restored \(itemsToRestore.count) item(s) for task \(taskID.uuidString)")
        return AtlasWorkerCommandResult(request: request, response: response, events: events, snapshot: state.snapshot)
    }

    private func listApps(using request: AtlasRequestEnvelope) async -> AtlasWorkerCommandResult {
        if let appsInventoryProvider, let apps = try? await appsInventoryProvider.collectInstalledApps(), !apps.isEmpty {
            state.snapshot.apps = apps
            await persistState(context: "refresh app inventory")
        }

        let apps = state.snapshot.apps.sorted { lhs, rhs in
            if lhs.bytes == rhs.bytes {
                return lhs.name < rhs.name
            }
            return lhs.bytes > rhs.bytes
        }
        let response = AtlasResponseEnvelope(requestID: request.id, response: .apps(apps))
        await auditStore.append("Listed \(apps.count) apps for request \(request.id.uuidString)")
        return AtlasWorkerCommandResult(request: request, response: response, events: [], snapshot: state.snapshot)
    }

    private func previewAppUninstall(using request: AtlasRequestEnvelope, appID: UUID) async -> AtlasWorkerCommandResult {
        guard let app = state.snapshot.apps.first(where: { $0.id == appID }) else {
            return rejectedResult(
                for: request,
                code: .invalidSelection,
                reason: "The selected app is no longer available for uninstall preview."
            )
        }

        let preview = makeAppUninstallPreview(for: app)
        let response = AtlasResponseEnvelope(requestID: request.id, response: .preview(preview))
        await auditStore.append("Prepared uninstall preview for \(app.name)")
        return AtlasWorkerCommandResult(
            request: request,
            response: response,
            events: [],
            snapshot: state.snapshot,
            previewPlan: preview
        )
    }

    private func executeAppUninstall(using request: AtlasRequestEnvelope, appID: UUID) async -> AtlasWorkerCommandResult {
        guard let app = state.snapshot.apps.first(where: { $0.id == appID }) else {
            return rejectedResult(
                for: request,
                code: .invalidSelection,
                reason: "The selected app is no longer available to uninstall."
            )
        }

        let uninstallEvidence = appUninstallEvidenceAnalyzer.analyze(
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            bundlePath: app.bundlePath,
            bundleBytes: app.bytes
        )

        var appRestoreMappings: [RecoveryPathMapping]?
        if !app.bundlePath.isEmpty, FileManager.default.fileExists(atPath: app.bundlePath) {
            guard let helperExecutor else {
                return rejectedResult(
                    for: request,
                    code: .helperUnavailable,
                    reason: "Bundled helper unavailable for app uninstall. Build or package the helper and try again."
                )
            }

            do {
                let result = try await helperExecutor.perform(
                    AtlasHelperAction(kind: .trashItems, targetPath: app.bundlePath)
                )
                guard result.success else {
                    return rejectedResult(for: request, code: .helperUnavailable, reason: result.message)
                }
                if let trashedPath = result.resolvedPath {
                    appRestoreMappings = [RecoveryPathMapping(originalPath: app.bundlePath, trashedPath: trashedPath)]
                }
            } catch {
                return rejectedResult(for: request, code: .helperUnavailable, reason: error.localizedDescription)
            }
        }

        let taskID = UUID()
        state.snapshot.apps.removeAll { $0.id == appID }
        state.snapshot.recoveryItems.insert(
            makeRecoveryItem(for: app, uninstallEvidence: uninstallEvidence, deletedAt: Date(), restoreMappings: appRestoreMappings),
            at: 0
        )

        let completedRun = TaskRun(
            id: taskID,
            kind: .uninstallApp,
            status: .completed,
            summary: appUninstallSummary(for: app, uninstallEvidence: uninstallEvidence),
            startedAt: request.issuedAt,
            finishedAt: Date()
        )
        state.snapshot.taskRuns.removeAll { $0.id == taskID }
        state.snapshot.taskRuns.insert(completedRun, at: 0)
        await persistState(context: "execute app uninstall")

        let response = AtlasResponseEnvelope(
            requestID: request.id,
            response: .accepted(task: AtlasTaskDescriptor(taskID: taskID, kind: .uninstallApp))
        )
        let events = progressEvents(taskID: taskID, total: 3) + [AtlasEventEnvelope(event: .taskFinished(completedRun))]
        await auditStore.append("Executed uninstall preview for \(app.name)")
        return AtlasWorkerCommandResult(request: request, response: response, events: events, snapshot: state.snapshot)
    }

    private func settingsGet(using request: AtlasRequestEnvelope) async -> AtlasWorkerCommandResult {
        let response = AtlasResponseEnvelope(requestID: request.id, response: .settings(state.settings))
        return AtlasWorkerCommandResult(request: request, response: response, events: [], snapshot: state.snapshot)
    }

    private func settingsSet(using request: AtlasRequestEnvelope, settings: AtlasSettings) async -> AtlasWorkerCommandResult {
        state.settings = sanitized(settings: settings)
        await persistState(context: "restore recovery items")
        let response = AtlasResponseEnvelope(requestID: request.id, response: .settings(state.settings))
        await auditStore.append("Updated settings for request \(request.id.uuidString)")
        return AtlasWorkerCommandResult(request: request, response: response, events: [], snapshot: state.snapshot)
    }

    private func rejectedResult(
        for request: AtlasRequestEnvelope,
        code: AtlasProtocolErrorCode,
        reason: String
    ) -> AtlasWorkerCommandResult {
        AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(requestID: request.id, response: .rejected(code: code, reason: reason)),
            events: [],
            snapshot: state.snapshot
        )
    }

    private func validateRestoreItems(_ items: [RecoveryItem]) throws {
        for item in items {
            guard let restoreMappings = item.restoreMappings, !restoreMappings.isEmpty else {
                continue
            }
            try validateRestoreMappings(restoreMappings)
        }
    }

    private func validateRestoreMappings(_ restoreMappings: [RecoveryPathMapping]) throws {
        for mapping in restoreMappings {
            try validateRestoreTarget(mapping)
        }
    }

    private func expiredRecoveryItemIDs(asOf now: Date? = nil) -> Set<UUID> {
        let cutoff = now ?? nowProvider()
        return Set(state.snapshot.recoveryItems.compactMap { item in
            item.isExpired(asOf: cutoff) ? item.id : nil
        })
    }

    private func pruneExpiredRecoveryItemsIfNeeded(context: String, now: Date? = nil) async {
        let cutoff = now ?? nowProvider()
        let expiredIDs = expiredRecoveryItemIDs(asOf: cutoff)
        guard !expiredIDs.isEmpty else {
            return
        }

        state.snapshot.recoveryItems.removeAll { expiredIDs.contains($0.id) }
        await persistState(context: context)
        await auditStore.append("Pruned \(expiredIDs.count) expired recovery item(s)")
    }

    private func persistState(context: String) async {
        do {
            _ = try repository.saveState(state)
        } catch {
            await auditStore.append("Failed to persist state after \(context): \(error.localizedDescription)")
            let message = "[AtlasScaffoldWorkerService] Failed to persist state after \(context): \(error.localizedDescription)\n"
            if let data = message.data(using: .utf8) {
                try? FileHandle.standardError.write(contentsOf: data)
            }
        }
    }

    private func recalculateReclaimableSpace() {
        state.snapshot.reclaimableSpaceBytes = state.snapshot.findings.map(\.bytes).reduce(0, +)
    }

    private func progressEvents(taskID: UUID, total: Int) -> [AtlasEventEnvelope] {
        (1 ... total).map { step in
            AtlasEventEnvelope(event: .taskProgress(taskID: taskID, completed: step, total: total))
        }
    }

    private func executeSmartCleanSelections(_ selections: [SmartCleanExecutableSelection]) async throws -> SmartCleanExecutionResult {
        var result = SmartCleanExecutionResult()
        for selection in selections {
            let targetPaths = Array(Set(selection.targetPaths)).sorted()
            guard !targetPaths.isEmpty else {
                result.failedFindingIDs.insert(selection.finding.id)
                result.failureReason = result.failureReason ?? "Smart Clean finding is missing executable targets."
                throw SmartCleanExecutionFailure(result: result)
            }
            do {
                let preparedTargetPaths = try prepareSmartCleanTargetPaths(targetPaths)
                var mappings: [RecoveryPathMapping] = []
                for targetPath in preparedTargetPaths {
                    if let mapping = try await trashSmartCleanTarget(at: targetPath) {
                        mappings.append(mapping)
                    }
                }
                if mappings.isEmpty {
                    result.staleFindingIDs.insert(selection.finding.id)
                } else {
                    result.restoreMappingsByFindingID[selection.finding.id] = mappings
                }
            } catch {
                result.failedFindingIDs.insert(selection.finding.id)
                result.failureReason = result.failureReason ?? error.localizedDescription
                throw SmartCleanExecutionFailure(result: result)
            }
        }
        return result
    }

    private func resolvedTargetPaths(for item: ActionItem, finding: Finding) -> [String] {
        Array(Set(item.targetPaths ?? finding.targetPaths ?? [])).sorted()
    }

    private func prepareSmartCleanTargetPaths(_ targetPaths: [String]) throws -> [String] {
        var preparedTargetPaths: [String] = []
        for targetPath in targetPaths {
            let targetURL = URL(fileURLWithPath: targetPath).resolvingSymlinksInPath()
            guard FileManager.default.fileExists(atPath: targetURL.path) else {
                continue
            }
            if shouldUseHelperForSmartCleanTarget(targetURL) {
                guard helperExecutor != nil else {
                    throw AtlasWorkspaceRepositoryError.writeFailed("Bundled helper unavailable for Smart Clean target: \(targetURL.path)")
                }
            } else if !isDirectlyTrashableSmartCleanTarget(targetURL) {
                throw AtlasWorkspaceRepositoryError.writeFailed("Smart Clean target is outside the supported execution allowlist: \(targetURL.path)")
            }
            preparedTargetPaths.append(targetURL.path)
        }
        return preparedTargetPaths
    }

    private func trashSmartCleanTarget(at targetPath: String) async throws -> RecoveryPathMapping? {
        let targetURL = URL(fileURLWithPath: targetPath).resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            return nil
        }

        if shouldUseHelperForSmartCleanTarget(targetURL) {
            guard let helperExecutor else {
                throw AtlasWorkspaceRepositoryError.writeFailed("Bundled helper unavailable for Smart Clean target: \(targetURL.path)")
            }
            let result = try await helperExecutor.perform(AtlasHelperAction(kind: .trashItems, targetPath: targetURL.path))
            guard result.success else {
                throw AtlasWorkspaceRepositoryError.writeFailed(result.message)
            }
            guard let trashedPath = result.resolvedPath else {
                throw AtlasWorkspaceRepositoryError.writeFailed("Smart Clean target was trashed but no recovery path was returned.")
            }
            return RecoveryPathMapping(originalPath: targetURL.path, trashedPath: trashedPath)
        }

        guard isDirectlyTrashableSmartCleanTarget(targetURL) else {
            throw AtlasWorkspaceRepositoryError.writeFailed("Smart Clean target is outside the supported execution allowlist: \(targetURL.path)")
        }

        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: targetURL, resultingItemURL: &trashedURL)
        guard let trashedPath = (trashedURL as URL?)?.path else {
            throw AtlasWorkspaceRepositoryError.writeFailed("Smart Clean target was trashed but no recovery path was returned.")
        }
        return RecoveryPathMapping(originalPath: targetURL.path, trashedPath: trashedPath)
    }

    private func restoreRecoveryMappings(_ restoreMappings: [RecoveryPathMapping]) async throws {
        for mapping in restoreMappings {
            try await restoreRecoveryTarget(mapping)
        }
    }

    private func validateRestoreTarget(_ mapping: RecoveryPathMapping) throws {
        let sourceURL = URL(fileURLWithPath: mapping.trashedPath).resolvingSymlinksInPath()
        let destinationURL = URL(fileURLWithPath: mapping.originalPath).resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw RecoveryRestoreFailure.executionUnavailable("Recovery source is no longer available on disk: \(sourceURL.path)")
        }
        if shouldUseHelperForSmartCleanTarget(destinationURL) {
            guard helperExecutor != nil else {
                throw RecoveryRestoreFailure.helperUnavailable("Bundled helper unavailable for recovery target: \(destinationURL.path)")
            }
        } else if !isDirectlyTrashableSmartCleanTarget(destinationURL) {
            throw RecoveryRestoreFailure.executionUnavailable("Recovery target is outside the supported execution allowlist: \(destinationURL.path)")
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            throw RecoveryRestoreFailure.restoreConflict("Recovery target already exists: \(destinationURL.path)")
        }
    }

    private func restoreRecoveryTarget(_ mapping: RecoveryPathMapping) async throws {
        try validateRestoreTarget(mapping)
        let sourceURL = URL(fileURLWithPath: mapping.trashedPath).resolvingSymlinksInPath()
        let destinationURL = URL(fileURLWithPath: mapping.originalPath).resolvingSymlinksInPath()
        if shouldUseHelperForSmartCleanTarget(destinationURL) {
            guard let helperExecutor else {
                throw RecoveryRestoreFailure.helperUnavailable("Bundled helper unavailable for recovery target: \(destinationURL.path)")
            }
            do {
                let result = try await helperExecutor.perform(
                    AtlasHelperAction(kind: .restoreItem, targetPath: sourceURL.path, destinationPath: destinationURL.path)
                )
                guard result.success else {
                    throw recoveryRestoreFailure(fromHelperMessage: result.message)
                }
            } catch let failure as RecoveryRestoreFailure {
                throw failure
            } catch let clientError as AtlasHelperClientError {
                switch clientError {
                case .helperUnavailable:
                    throw RecoveryRestoreFailure.helperUnavailable(clientError.localizedDescription)
                case .encodingFailed, .decodingFailed, .invocationFailed:
                    throw RecoveryRestoreFailure.executionUnavailable(clientError.localizedDescription)
                }
            } catch {
                throw RecoveryRestoreFailure.executionUnavailable(error.localizedDescription)
            }
            return
        }
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    private func recoveryRestoreFailure(fromHelperMessage message: String) -> RecoveryRestoreFailure {
        if message.hasPrefix("Restore destination already exists:") {
            return .restoreConflict(message)
        }
        return .executionUnavailable(message)
    }

    private func shouldUseHelperForSmartCleanTarget(_ targetURL: URL) -> Bool {
        AtlasSmartCleanExecutionSupport.requiresHelper(for: targetURL)
    }

    private func isDirectlyTrashableSmartCleanTarget(_ targetURL: URL) -> Bool {
        AtlasSmartCleanExecutionSupport.isDirectlyTrashable(targetURL)
    }

    private func smartCleanExecutionSummary(executedCount: Int, staleCount: Int, reviewOnlyCount: Int, failedCount: Int) -> String {
        var clauses: [String] = []

        if executedCount > 0 {
            clauses.append(
                AtlasL10n.string(
                    executedCount == 1 ? "infrastructure.execute.summary.clean.one" : "infrastructure.execute.summary.clean.other",
                    language: state.settings.language,
                    executedCount
                )
            )
        }

        if staleCount > 0 {
            clauses.append(
                AtlasL10n.string(
                    staleCount == 1 ? "infrastructure.execute.summary.clean.stale.one" : "infrastructure.execute.summary.clean.stale.other",
                    language: state.settings.language,
                    staleCount
                )
            )
        }

        if reviewOnlyCount > 0 {
            clauses.append(
                AtlasL10n.string(
                    reviewOnlyCount == 1 ? "infrastructure.execute.summary.clean.review.one" : "infrastructure.execute.summary.clean.review.other",
                    language: state.settings.language,
                    reviewOnlyCount
                )
            )
        }

        if failedCount > 0 {
            clauses.append(
                AtlasL10n.string(
                    failedCount == 1 ? "infrastructure.execute.summary.clean.failed.one" : "infrastructure.execute.summary.clean.failed.other",
                    language: state.settings.language,
                    failedCount
                )
            )
        }

        guard !clauses.isEmpty else {
            return AtlasL10n.string("infrastructure.execute.summary.clean.none", language: state.settings.language)
        }

        return clauses.joined(separator: " ")
    }

    private func restoreSummary(physicalRestoreCount: Int, atlasOnlyRestoreCount: Int) -> String {
        var clauses: [String] = []

        if physicalRestoreCount > 0 {
            clauses.append(
                AtlasL10n.string(
                    physicalRestoreCount == 1 ? "infrastructure.restore.summary.disk.one" : "infrastructure.restore.summary.disk.other",
                    language: state.settings.language,
                    physicalRestoreCount
                )
            )
        }

        if atlasOnlyRestoreCount > 0 {
            clauses.append(
                AtlasL10n.string(
                    atlasOnlyRestoreCount == 1 ? "infrastructure.restore.summary.state.one" : "infrastructure.restore.summary.state.other",
                    language: state.settings.language,
                    atlasOnlyRestoreCount
                )
            )
        }

        guard !clauses.isEmpty else {
            return AtlasL10n.string("infrastructure.restore.summary.none", language: state.settings.language)
        }

        return clauses.joined(separator: " ")
    }


    private func recoveryExpiryDate(from deletedAt: Date) -> Date {
        deletedAt.addingTimeInterval(TimeInterval(state.settings.recoveryRetentionDays * 86_400))
    }

    private func makeRecoveryItem(for finding: Finding, deletedAt: Date, restoreMappings: [RecoveryPathMapping]? = nil) -> RecoveryItem {
        RecoveryItem(
            title: finding.title,
            detail: finding.detail,
            originalPath: restoreMappings?.first?.originalPath ?? inferredPath(for: finding),
            bytes: finding.bytes,
            deletedAt: deletedAt,
            expiresAt: recoveryExpiryDate(from: deletedAt),
            payload: .finding(finding),
            restoreMappings: restoreMappings
        )
    }

    private func makeRecoveryItem(for app: AppFootprint, deletedAt: Date, restoreMappings: [RecoveryPathMapping]? = nil) -> RecoveryItem {
        makeRecoveryItem(
            for: app,
            uninstallEvidence: AtlasAppUninstallEvidence(bundlePath: app.bundlePath, bundleBytes: app.bytes, reviewOnlyGroups: []),
            deletedAt: deletedAt,
            restoreMappings: restoreMappings
        )
    }

    private func makeRecoveryItem(
        for app: AppFootprint,
        uninstallEvidence: AtlasAppUninstallEvidence,
        deletedAt: Date,
        restoreMappings: [RecoveryPathMapping]? = nil
    ) -> RecoveryItem {
        let reviewOnlyItemCount = uninstallEvidence.reviewOnlyItemCount > 0 ? uninstallEvidence.reviewOnlyItemCount : app.leftoverItems
        let baseDetail = AtlasL10n.string(
            reviewOnlyItemCount == 1 ? "infrastructure.recovery.app.detail.one" : "infrastructure.recovery.app.detail.other",
            language: state.settings.language,
            reviewOnlyItemCount
        )
        return RecoveryItem(
            title: app.name,
            detail: appReviewOnlyEvidenceDetail(baseDetail: baseDetail, uninstallEvidence: uninstallEvidence),
            originalPath: app.bundlePath,
            bytes: app.bytes,
            deletedAt: deletedAt,
            expiresAt: recoveryExpiryDate(from: deletedAt),
            payload: .app(AtlasAppRecoveryPayload(app: app, uninstallEvidence: uninstallEvidence)),
            restoreMappings: restoreMappings
        )
    }

    private func appUninstallSummary(for app: AppFootprint, uninstallEvidence: AtlasAppUninstallEvidence) -> String {
        let reviewOnlyGroupCount = uninstallEvidence.reviewOnlyGroupCount
        guard reviewOnlyGroupCount > 0 else {
            return AtlasL10n.string("infrastructure.apps.uninstall.summary", language: state.settings.language, app.name)
        }

        let baseSummary = AtlasL10n.string(
            reviewOnlyGroupCount == 1 ? "infrastructure.apps.uninstall.summary.review.one" : "infrastructure.apps.uninstall.summary.review.other",
            language: state.settings.language,
            app.name,
            reviewOnlyGroupCount
        )
        return appReviewOnlyEvidenceDetail(baseDetail: baseSummary, uninstallEvidence: uninstallEvidence)
    }

    private func appReviewOnlyEvidenceDetail(baseDetail: String, uninstallEvidence: AtlasAppUninstallEvidence) -> String {
        let categorySummary = appReviewOnlyEvidenceCategorySummary(for: uninstallEvidence.reviewOnlyGroups)
        guard !categorySummary.isEmpty else {
            return baseDetail
        }
        return baseDetail + " " + AtlasL10n.string(
            "infrastructure.apps.uninstall.reviewCategories",
            language: state.settings.language,
            categorySummary
        )
    }

    private func appReviewOnlyEvidenceCategorySummary(for groups: [AtlasAppFootprintEvidenceGroup]) -> String {
        groups.map { appReviewOnlyEvidenceLabel(for: $0.category) }.joined(separator: ", ")
    }

    private func inferredPath(for finding: Finding) -> String {
        if let firstTargetPath = finding.targetPaths?.first {
            return firstTargetPath
        }
        switch finding.category.lowercased() {
        case "developer":
            return "~/Library/Developer"
        case "system":
            return "~/Library/Caches"
        case "apps":
            return "~/Library/Application Support"
        case "browsers":
            return "~/Library/Caches"
        default:
            return "~/Library"
        }
    }

    private func makePreviewPlan(findingIDs: [UUID]) -> ActionPlan {
        let selectedFindings: [Finding]

        if findingIDs.isEmpty {
            selectedFindings = state.snapshot.findings
        } else {
            let selected = state.snapshot.findings.filter { findingIDs.contains($0.id) }
            selectedFindings = selected.isEmpty ? state.snapshot.findings : selected
        }

        let items = selectedFindings.map { finding in
            ActionItem(
                id: finding.id,
                title: actionTitle(for: finding),
                detail: finding.detail,
                kind: actionKind(for: finding),
                recoverable: finding.risk != .advanced,
                targetPaths: Array(Set(finding.targetPaths ?? [])).sorted()
            )
        }

        let estimatedBytes = selectedFindings.map(\.bytes).reduce(0, +)

        return ActionPlan(
            title: AtlasL10n.string(selectedFindings.count == 1 ? "infrastructure.plan.review.one" : "infrastructure.plan.review.other", language: state.settings.language, selectedFindings.count),
            items: items,
            estimatedBytes: estimatedBytes
        )
    }

    private func makeAppUninstallPreview(for app: AppFootprint) -> ActionPlan {
        let uninstallEvidence = appUninstallEvidenceAnalyzer.analyze(
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            bundlePath: app.bundlePath,
            bundleBytes: app.bytes
        )

        var items: [ActionItem] = [
            ActionItem(
                id: app.id,
                title: AtlasL10n.string("infrastructure.plan.uninstall.moveBundle.title", language: state.settings.language, app.name),
                detail: AtlasL10n.string("infrastructure.plan.uninstall.moveBundle.detail", language: state.settings.language, app.bundlePath),
                kind: .removeApp,
                recoverable: true,
                targetPaths: [app.bundlePath]
            ),
        ]

        items.append(contentsOf: uninstallEvidence.reviewOnlyGroups.map { group in
            ActionItem(
                title: appReviewOnlyEvidenceTitle(for: group),
                detail: AtlasL10n.string(
                    "infrastructure.plan.uninstall.review.detail",
                    language: state.settings.language,
                    formattedByteCount(group.totalBytes),
                    group.items.count
                ),
                kind: .reviewEvidence,
                recoverable: false,
                evidencePaths: group.items.map(\.path)
            )
        })

        return ActionPlan(
            title: AtlasL10n.string("infrastructure.plan.uninstall.title", language: state.settings.language, app.name),
            items: items,
            estimatedBytes: app.bytes
        )
    }

    private func appReviewOnlyEvidenceTitle(for group: AtlasAppFootprintEvidenceGroup) -> String {
        AtlasL10n.string(
            "infrastructure.plan.uninstall.review.title",
            language: state.settings.language,
            appReviewOnlyEvidenceLabel(for: group.category),
            group.items.count
        )
    }

    private func appReviewOnlyEvidenceLabel(for category: AtlasAppFootprintEvidenceCategory) -> String {
        switch category {
        case .supportFiles:
            return AtlasL10n.string("infrastructure.plan.uninstall.review.supportFiles", language: state.settings.language)
        case .caches:
            return AtlasL10n.string("infrastructure.plan.uninstall.review.caches", language: state.settings.language)
        case .preferences:
            return AtlasL10n.string("infrastructure.plan.uninstall.review.preferences", language: state.settings.language)
        case .logs:
            return AtlasL10n.string("infrastructure.plan.uninstall.review.logs", language: state.settings.language)
        case .launchItems:
            return AtlasL10n.string("infrastructure.plan.uninstall.review.launchItems", language: state.settings.language)
        }
    }

    private func formattedByteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func actionTitle(for finding: Finding) -> String {
        switch actionKind(for: finding) {
        case .removeApp:
            return AtlasL10n.string("infrastructure.action.reviewUninstall", language: state.settings.language, finding.title)
        case .inspectPermission:
            return AtlasL10n.string("infrastructure.action.inspectPrivileged", language: state.settings.language, finding.title)
        case .reviewEvidence:
            return AtlasL10n.string("infrastructure.action.inspectPrivileged", language: state.settings.language, finding.title)
        case .archiveFile:
            return AtlasL10n.string("infrastructure.action.archiveRecovery", language: state.settings.language, finding.title)
        case .removeCache:
            return AtlasL10n.string("infrastructure.action.moveToTrash", language: state.settings.language, finding.title)
        }
    }

    private func actionKind(for finding: Finding) -> ActionItem.Kind {
        if finding.risk == .advanced {
            return .inspectPermission
        }

        if !AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding) {
            return .inspectPermission
        }

        if finding.category == "Apps" {
            return .removeApp
        }

        if finding.risk == .review {
            return .archiveFile
        }

        return .removeCache
    }

    private func sanitized(settings: AtlasSettings) -> AtlasSettings {
        AtlasSettings(
            recoveryRetentionDays: min(max(settings.recoveryRetentionDays, 1), 30),
            notificationsEnabled: settings.notificationsEnabled,
            excludedPaths: Array(Set(settings.excludedPaths.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })).sorted(),
            language: settings.language,
            acknowledgementText: AtlasL10n.acknowledgement(language: settings.language),
            thirdPartyNoticesText: AtlasL10n.thirdPartyNotices(language: settings.language)
        )
    }
}

private struct SmartCleanExecutionResult {
    var restoreMappingsByFindingID: [UUID: [RecoveryPathMapping]] = [:]
    var staleFindingIDs: Set<UUID> = []
    var failedFindingIDs: Set<UUID> = []
    var failureReason: String?

    var hasRecordedOutcome: Bool {
        !restoreMappingsByFindingID.isEmpty || !staleFindingIDs.isEmpty
    }
}

private struct SmartCleanExecutableSelection {
    let finding: Finding
    let targetPaths: [String]
}

private struct SmartCleanExecutionFailure: LocalizedError {
    let result: SmartCleanExecutionResult

    var errorDescription: String? {
        result.failureReason
    }
}

private enum RecoveryRestoreFailure: LocalizedError {
    case helperUnavailable(String)
    case restoreConflict(String)
    case executionUnavailable(String)

    var code: AtlasProtocolErrorCode {
        switch self {
        case .helperUnavailable:
            return .helperUnavailable
        case .restoreConflict:
            return .restoreConflict
        case .executionUnavailable:
            return .executionUnavailable
        }
    }

    var errorDescription: String? {
        switch self {
        case let .helperUnavailable(reason),
             let .restoreConflict(reason),
             let .executionUnavailable(reason):
            return reason
        }
    }
}

private extension RecoveryItem {
    func isExpired(asOf date: Date) -> Bool {
        guard let expiresAt else {
            return false
        }
        return expiresAt <= date
    }
}

import AtlasProtocol
import Foundation

public protocol AtlasPrivilegedActionExecuting: Sendable {
    func perform(_ action: AtlasHelperAction) async throws -> AtlasHelperActionResult
}

public enum AtlasHelperClientError: LocalizedError, Sendable {
    case helperUnavailable(attemptedPaths: [String])
    case encodingFailed(String)
    case decodingFailed(String)
    case invocationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .helperUnavailable(attemptedPaths):
            let joined = attemptedPaths.isEmpty ? "<no candidate paths recorded>" : attemptedPaths.joined(separator: ", ")
            return "Bundled privileged helper is unavailable. Attempted: \(joined)"
        case let .encodingFailed(reason):
            return "Failed to encode helper action: \(reason)"
        case let .decodingFailed(reason):
            return "Failed to decode helper response: \(reason)"
        case let .invocationFailed(reason):
            return "Privileged helper failed: \(reason)"
        }
    }
}

public actor AtlasPrivilegedHelperClient: AtlasPrivilegedActionExecuting {
    private let explicitExecutableURL: URL?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(executableURL: URL? = nil) {
        self.explicitExecutableURL = executableURL
    }

    public func perform(_ action: AtlasHelperAction) async throws -> AtlasHelperActionResult {
        let resolution = resolveExecutableURL()
        guard let executableURL = resolution.url else {
            throw AtlasHelperClientError.helperUnavailable(attemptedPaths: resolution.attemptedPaths)
        }

        let requestData: Data
        do {
            requestData = try encoder.encode(action)
        } catch {
            throw AtlasHelperClientError.encodingFailed(error.localizedDescription)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--action-json"]

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        stdin.fileHandleForWriting.write(requestData)
        stdin.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "unknown helper error"
            throw AtlasHelperClientError.invocationFailed(errorMessage)
        }

        do {
            return try decoder.decode(AtlasHelperActionResult.self, from: outputData)
        } catch {
            let raw = String(data: outputData, encoding: .utf8) ?? "<empty>"
            throw AtlasHelperClientError.decodingFailed("\(error.localizedDescription). Output: \(raw)")
        }
    }

    private func resolveExecutableURL() -> (url: URL?, attemptedPaths: [String]) {
        var attemptedPaths: [String] = []

        if let explicitExecutableURL {
            attemptedPaths.append(explicitExecutableURL.path)
            if FileManager.default.isExecutableFile(atPath: explicitExecutableURL.path) {
                return (explicitExecutableURL, attemptedPaths)
            }
        }

        if let environmentPath = ProcessInfo.processInfo.environment["ATLAS_HELPER_EXECUTABLE"] {
            attemptedPaths.append(environmentPath)
            if FileManager.default.isExecutableFile(atPath: environmentPath) {
                return (URL(fileURLWithPath: environmentPath), attemptedPaths)
            }
        }

        let bundleCandidates = bundledHelperCandidates()
        attemptedPaths.append(contentsOf: bundleCandidates.map(\.path))
        for candidate in bundleCandidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return (candidate, attemptedPaths)
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
        let repoRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let devCandidates = [
            repoRoot.appendingPathComponent("Helpers/.build/debug/AtlasPrivilegedHelper"),
            repoRoot.appendingPathComponent("Helpers/.build/release/AtlasPrivilegedHelper"),
        ]
        attemptedPaths.append(contentsOf: devCandidates.map(\.path))

        for candidate in devCandidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return (candidate, attemptedPaths)
        }

        return (nil, attemptedPaths)
    }

    private func bundledHelperCandidates() -> [URL] {
        let mainBundleURL = Bundle.main.bundleURL
        let appHelper = mainBundleURL.appendingPathComponent("Contents/Helpers/AtlasPrivilegedHelper")
        let xpcHelper = mainBundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Helpers/AtlasPrivilegedHelper")
        return [appHelper, xpcHelper]
    }
}
