import AtlasDomain
import AtlasProtocol
import Foundation

public struct AtlasWorkspaceSnapshot: Codable, Hashable, Sendable {
    public var reclaimableSpaceBytes: Int64
    public var findings: [Finding]
    public var apps: [AppFootprint]
    public var taskRuns: [TaskRun]
    public var recoveryItems: [RecoveryItem]
    public var permissions: [PermissionState]
    public var healthSnapshot: AtlasHealthSnapshot?

    public init(
        reclaimableSpaceBytes: Int64,
        findings: [Finding],
        apps: [AppFootprint],
        taskRuns: [TaskRun],
        recoveryItems: [RecoveryItem],
        permissions: [PermissionState],
        healthSnapshot: AtlasHealthSnapshot? = nil
    ) {
        self.reclaimableSpaceBytes = reclaimableSpaceBytes
        self.findings = findings
        self.apps = apps
        self.taskRuns = taskRuns
        self.recoveryItems = recoveryItems
        self.permissions = permissions
        self.healthSnapshot = healthSnapshot
    }
}

public struct AtlasWorkspaceState: Codable, Hashable, Sendable {
    public var snapshot: AtlasWorkspaceSnapshot
    public var currentPlan: ActionPlan
    public var settings: AtlasSettings

    public init(snapshot: AtlasWorkspaceSnapshot, currentPlan: ActionPlan, settings: AtlasSettings) {
        self.snapshot = snapshot
        self.currentPlan = currentPlan
        self.settings = settings
    }
}

public enum AtlasScaffoldWorkspace {
    public static func state(language: AtlasLanguage = AtlasL10n.currentLanguage) -> AtlasWorkspaceState {
        let snapshot = AtlasWorkspaceSnapshot(
            reclaimableSpaceBytes: AtlasScaffoldFixtures.findings(language: language).map(\.bytes).reduce(0, +),
            findings: AtlasScaffoldFixtures.findings(language: language),
            apps: AtlasScaffoldFixtures.apps,
            taskRuns: AtlasScaffoldFixtures.taskRuns(language: language),
            recoveryItems: AtlasScaffoldFixtures.recoveryItems(language: language),
            permissions: AtlasScaffoldFixtures.permissions(language: language),
            healthSnapshot: AtlasScaffoldFixtures.healthSnapshot(language: language)
        )

        return AtlasWorkspaceState(
            snapshot: snapshot,
            currentPlan: makeInitialPlan(from: snapshot.findings),
            settings: AtlasScaffoldFixtures.settings(language: language)
        )
    }

    public static func snapshot(language: AtlasLanguage = AtlasL10n.currentLanguage) -> AtlasWorkspaceSnapshot {
        state(language: language).snapshot
    }

    private static func makeInitialPlan(from findings: [Finding]) -> ActionPlan {
        let items = findings.map { finding in
            let hasExecutableTargets = !((finding.targetPaths ?? []).isEmpty)
            let kind: ActionItem.Kind
            if !hasExecutableTargets || finding.risk == .advanced {
                kind = .inspectPermission
            } else if finding.category == "Apps" {
                kind = .removeApp
            } else if finding.risk == .review {
                kind = .archiveFile
            } else {
                kind = .removeCache
            }

            return ActionItem(
                id: finding.id,
                title: finding.risk == .advanced
                    ? AtlasL10n.string("application.plan.inspectPrivileged", finding.title)
                    : AtlasL10n.string("application.plan.reviewFinding", finding.title),
                detail: finding.detail,
                kind: kind,
                recoverable: finding.risk != .advanced,
                targetPaths: finding.targetPaths
            )
        }

        let titleKey = findings.count == 1 ? "application.plan.reviewSelected.one" : "application.plan.reviewSelected.other"
        return ActionPlan(
            title: AtlasL10n.string(titleKey, findings.count),
            items: items,
            estimatedBytes: findings.map(\.bytes).reduce(0, +)
        )
    }
}

public protocol AtlasHealthSnapshotProviding: Sendable {
    func collectHealthSnapshot() async throws -> AtlasHealthSnapshot
}

public struct AtlasSmartCleanScanResult: Codable, Hashable, Sendable {
    public var findings: [Finding]
    public var summary: String

    public init(findings: [Finding], summary: String) {
        self.findings = findings
        self.summary = summary
    }
}

public protocol AtlasSmartCleanScanProviding: Sendable {
    func collectSmartCleanScan() async throws -> AtlasSmartCleanScanResult
}


public protocol AtlasAppInventoryProviding: Sendable {
    func collectInstalledApps() async throws -> [AppFootprint]
}

public struct AtlasWorkerCommandResult: Codable, Hashable, Sendable {
    public var request: AtlasRequestEnvelope
    public var response: AtlasResponseEnvelope
    public var events: [AtlasEventEnvelope]
    public var snapshot: AtlasWorkspaceSnapshot
    public var previewPlan: ActionPlan?

    public init(
        request: AtlasRequestEnvelope,
        response: AtlasResponseEnvelope,
        events: [AtlasEventEnvelope],
        snapshot: AtlasWorkspaceSnapshot,
        previewPlan: ActionPlan? = nil
    ) {
        self.request = request
        self.response = response
        self.events = events
        self.snapshot = snapshot
        self.previewPlan = previewPlan
    }
}

public protocol AtlasWorkerServing: Sendable {
    func submit(_ request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult
}

public enum AtlasWorkspaceControllerError: LocalizedError, Sendable {
    case rejected(code: AtlasProtocolErrorCode, reason: String)
    case unexpectedResponse(String)

    public var errorDescription: String? {
        switch self {
        case let .rejected(code, reason):
            switch code {
            case .executionUnavailable:
                return AtlasL10n.string("application.error.executionUnavailable", reason)
            case .helperUnavailable:
                return AtlasL10n.string("application.error.helperUnavailable", reason)
            case .restoreExpired:
                return AtlasL10n.string("application.error.restoreExpired", reason)
            case .restoreConflict:
                return AtlasL10n.string("application.error.restoreConflict", reason)
            default:
                return AtlasL10n.string("application.error.workerRejected", code.rawValue, reason)
            }
        case let .unexpectedResponse(reason):
            return reason
        }
    }
}

public struct AtlasPermissionInspectionOutput: Sendable {
    public var snapshot: AtlasWorkspaceSnapshot
    public var events: [AtlasEventEnvelope]

    public init(snapshot: AtlasWorkspaceSnapshot, events: [AtlasEventEnvelope]) {
        self.snapshot = snapshot
        self.events = events
    }
}

public struct AtlasHealthSnapshotOutput: Sendable {
    public var snapshot: AtlasWorkspaceSnapshot
    public var healthSnapshot: AtlasHealthSnapshot

    public init(snapshot: AtlasWorkspaceSnapshot, healthSnapshot: AtlasHealthSnapshot) {
        self.snapshot = snapshot
        self.healthSnapshot = healthSnapshot
    }
}

public struct AtlasPlanPreviewOutput: Sendable {
    public var snapshot: AtlasWorkspaceSnapshot
    public var actionPlan: ActionPlan
    public var summary: String

    public init(snapshot: AtlasWorkspaceSnapshot, actionPlan: ActionPlan, summary: String) {
        self.snapshot = snapshot
        self.actionPlan = actionPlan
        self.summary = summary
    }
}

public struct AtlasScanOutput: Sendable {
    public var snapshot: AtlasWorkspaceSnapshot
    public var actionPlan: ActionPlan?
    public var events: [AtlasEventEnvelope]
    public var progressFraction: Double
    public var summary: String

    public init(
        snapshot: AtlasWorkspaceSnapshot,
        actionPlan: ActionPlan?,
        events: [AtlasEventEnvelope],
        progressFraction: Double,
        summary: String
    ) {
        self.snapshot = snapshot
        self.actionPlan = actionPlan
        self.events = events
        self.progressFraction = progressFraction
        self.summary = summary
    }
}

public struct AtlasTaskActionOutput: Sendable {
    public var snapshot: AtlasWorkspaceSnapshot
    public var events: [AtlasEventEnvelope]
    public var progressFraction: Double
    public var summary: String

    public init(
        snapshot: AtlasWorkspaceSnapshot,
        events: [AtlasEventEnvelope],
        progressFraction: Double,
        summary: String
    ) {
        self.snapshot = snapshot
        self.events = events
        self.progressFraction = progressFraction
        self.summary = summary
    }
}

public struct AtlasAppsOutput: Sendable {
    public var snapshot: AtlasWorkspaceSnapshot
    public var apps: [AppFootprint]
    public var summary: String

    public init(snapshot: AtlasWorkspaceSnapshot, apps: [AppFootprint], summary: String) {
        self.snapshot = snapshot
        self.apps = apps
        self.summary = summary
    }
}

public struct AtlasSettingsOutput: Sendable {
    public var settings: AtlasSettings

    public init(settings: AtlasSettings) {
        self.settings = settings
    }
}

public struct AtlasWorkspaceController: Sendable {
    private let worker: any AtlasWorkerServing

    public init(worker: any AtlasWorkerServing) {
        self.worker = worker
    }

    public func healthSnapshot() async throws -> AtlasHealthSnapshotOutput {
        let request = HealthSnapshotUseCase().makeRequest()
        let result = try await worker.submit(request)

        switch result.response.response {
        case let .health(healthSnapshot):
            return AtlasHealthSnapshotOutput(snapshot: result.snapshot, healthSnapshot: healthSnapshot)
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected health response for healthSnapshot.")
        }
    }

    public func inspectPermissions() async throws -> AtlasPermissionInspectionOutput {
        let request = InspectPermissionsUseCase().makeRequest()
        let result = try await worker.submit(request)

        switch result.response.response {
        case .permissions:
            return AtlasPermissionInspectionOutput(snapshot: result.snapshot, events: result.events)
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected permissions response for inspectPermissions.")
        }
    }

    public func startScan(taskID: UUID = UUID()) async throws -> AtlasScanOutput {
        let request = StartScanUseCase().makeRequest(taskID: taskID)
        let result = try await worker.submit(request)

        switch result.response.response {
        case .accepted:
            return AtlasScanOutput(
                snapshot: result.snapshot,
                actionPlan: result.previewPlan,
                events: result.events,
                progressFraction: progressFraction(from: result.events),
                summary: summary(from: result.events, fallback: AtlasL10n.string("application.scan.completed"))
            )
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected accepted response for startScan.")
        }
    }

    public func previewPlan(findingIDs: [UUID]) async throws -> AtlasPlanPreviewOutput {
        let request = PreviewPlanUseCase().makeRequest(findingIDs: findingIDs)
        let result = try await worker.submit(request)

        switch result.response.response {
        case let .preview(plan):
            return AtlasPlanPreviewOutput(
                snapshot: result.snapshot,
                actionPlan: plan,
                summary: AtlasL10n.string(plan.items.count == 1 ? "application.preview.updated.one" : "application.preview.updated.other", plan.items.count)
            )
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected preview response for previewPlan.")
        }
    }

    public func executePlan(planID: UUID) async throws -> AtlasTaskActionOutput {
        let request = ExecutePlanUseCase().makeRequest(planID: planID)
        let result = try await worker.submit(request)

        switch result.response.response {
        case .accepted:
            return AtlasTaskActionOutput(
                snapshot: result.snapshot,
                events: result.events,
                progressFraction: progressFraction(from: result.events),
                summary: summary(from: result.events, fallback: AtlasL10n.string("application.plan.executed"))
            )
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected accepted response for executePlan.")
        }
    }

    public func restoreItems(taskID: UUID = UUID(), itemIDs: [UUID]) async throws -> AtlasTaskActionOutput {
        let request = RestoreItemsUseCase().makeRequest(taskID: taskID, itemIDs: itemIDs)
        let result = try await worker.submit(request)

        switch result.response.response {
        case .accepted:
            return AtlasTaskActionOutput(
                snapshot: result.snapshot,
                events: result.events,
                progressFraction: progressFraction(from: result.events),
                summary: summary(from: result.events, fallback: AtlasL10n.string("application.recovery.completed"))
            )
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected accepted response for restoreItems.")
        }
    }

    public func listApps() async throws -> AtlasAppsOutput {
        let request = AppsListUseCase().makeRequest()
        let result = try await worker.submit(request)

        switch result.response.response {
        case let .apps(apps):
            return AtlasAppsOutput(
                snapshot: result.snapshot,
                apps: apps,
                summary: AtlasL10n.string(apps.count == 1 ? "application.apps.loaded.one" : "application.apps.loaded.other", apps.count)
            )
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected apps response for listApps.")
        }
    }

    public func previewAppUninstall(appID: UUID) async throws -> AtlasPlanPreviewOutput {
        let request = PreviewAppUninstallUseCase().makeRequest(appID: appID)
        let result = try await worker.submit(request)

        switch result.response.response {
        case let .preview(plan):
            return AtlasPlanPreviewOutput(
                snapshot: result.snapshot,
                actionPlan: plan,
                summary: AtlasL10n.string("application.apps.previewUpdated", plan.title)
            )
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected preview response for previewAppUninstall.")
        }
    }

    public func executeAppUninstall(appID: UUID) async throws -> AtlasTaskActionOutput {
        let request = ExecuteAppUninstallUseCase().makeRequest(appID: appID)
        let result = try await worker.submit(request)

        switch result.response.response {
        case .accepted:
            return AtlasTaskActionOutput(
                snapshot: result.snapshot,
                events: result.events,
                progressFraction: progressFraction(from: result.events),
                summary: summary(from: result.events, fallback: AtlasL10n.string("application.apps.uninstallCompleted"))
            )
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected accepted response for executeAppUninstall.")
        }
    }

    public func settings() async throws -> AtlasSettingsOutput {
        let request = SettingsGetUseCase().makeRequest()
        let result = try await worker.submit(request)

        switch result.response.response {
        case let .settings(settings):
            return AtlasSettingsOutput(settings: settings)
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected settings response for settings.")
        }
    }

    public func updateSettings(_ settings: AtlasSettings) async throws -> AtlasSettingsOutput {
        let request = SettingsSetUseCase().makeRequest(settings: settings)
        let result = try await worker.submit(request)

        switch result.response.response {
        case let .settings(settings):
            return AtlasSettingsOutput(settings: settings)
        case let .rejected(code, reason):
            throw AtlasWorkspaceControllerError.rejected(code: code, reason: reason)
        default:
            throw AtlasWorkspaceControllerError.unexpectedResponse("Expected settings response for updateSettings.")
        }
    }

    private func progressFraction(from events: [AtlasEventEnvelope]) -> Double {
        let fractions = events.compactMap { event -> Double? in
            guard case let .taskProgress(_, completed, total) = event.event, total > 0 else {
                return nil
            }

            return Double(completed) / Double(total)
        }

        return fractions.last ?? 0
    }

    private func summary(from events: [AtlasEventEnvelope], fallback: String) -> String {
        for event in events.reversed() {
            if case let .taskFinished(taskRun) = event.event {
                return taskRun.summary
            }
        }

        return fallback
    }
}

public struct HealthSnapshotUseCase: Sendable {
    public init() {}

    public func makeRequest() -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .healthSnapshot)
    }
}

public struct StartScanUseCase: Sendable {
    public init() {}

    public func makeRequest(taskID: UUID = UUID()) -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .startScan(taskID: taskID))
    }
}

public struct InspectPermissionsUseCase: Sendable {
    public init() {}

    public func makeRequest() -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .inspectPermissions)
    }
}

public struct PreviewPlanUseCase: Sendable {
    public init() {}

    public func makeRequest(taskID: UUID = UUID(), findingIDs: [UUID]) -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .previewPlan(taskID: taskID, findingIDs: findingIDs))
    }
}

public struct ExecutePlanUseCase: Sendable {
    public init() {}

    public func makeRequest(planID: UUID) -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .executePlan(planID: planID))
    }
}

public struct RestoreItemsUseCase: Sendable {
    public init() {}

    public func makeRequest(taskID: UUID = UUID(), itemIDs: [UUID]) -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .restoreItems(taskID: taskID, itemIDs: itemIDs))
    }
}

public struct AppsListUseCase: Sendable {
    public init() {}

    public func makeRequest() -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .appsList)
    }
}

public struct PreviewAppUninstallUseCase: Sendable {
    public init() {}

    public func makeRequest(appID: UUID) -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .previewAppUninstall(appID: appID))
    }
}

public struct ExecuteAppUninstallUseCase: Sendable {
    public init() {}

    public func makeRequest(appID: UUID) -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .executeAppUninstall(appID: appID))
    }
}

public struct SettingsGetUseCase: Sendable {
    public init() {}

    public func makeRequest() -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .settingsGet)
    }
}

public struct SettingsSetUseCase: Sendable {
    public init() {}

    public func makeRequest(settings: AtlasSettings) -> AtlasRequestEnvelope {
        AtlasRequestEnvelope(command: .settingsSet(settings))
    }
}
