import AtlasDomain
import Foundation

public enum AtlasProtocolVersion {
    public static let current = "0.3.2"
}

public struct AtlasCapabilityStatus: Codable, Hashable, Sendable {
    public var workerConnected: Bool
    public var helperInstalled: Bool
    public var protocolVersion: String

    public init(
        workerConnected: Bool = false,
        helperInstalled: Bool = false,
        protocolVersion: String = AtlasProtocolVersion.current
    ) {
        self.workerConnected = workerConnected
        self.helperInstalled = helperInstalled
        self.protocolVersion = protocolVersion
    }
}

public enum AtlasCommand: Codable, Hashable, Sendable {
    case healthSnapshot
    case inspectPermissions
    case startScan(taskID: UUID)
    case previewPlan(taskID: UUID, findingIDs: [UUID])
    case executePlan(planID: UUID)
    case restoreItems(taskID: UUID, itemIDs: [UUID])
    case appsList
    case previewAppUninstall(appID: UUID)
    case executeAppUninstall(appID: UUID)
    case settingsGet
    case settingsSet(AtlasSettings)
}

public struct AtlasRequestEnvelope: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var issuedAt: Date
    public var command: AtlasCommand

    public init(id: UUID = UUID(), issuedAt: Date = Date(), command: AtlasCommand) {
        self.id = id
        self.issuedAt = issuedAt
        self.command = command
    }
}

public struct AtlasTaskDescriptor: Codable, Hashable, Sendable {
    public var taskID: UUID
    public var kind: TaskKind

    public init(taskID: UUID, kind: TaskKind) {
        self.taskID = taskID
        self.kind = kind
    }
}

public enum AtlasProtocolErrorCode: String, Codable, CaseIterable, Hashable, Sendable {
    case unsupportedCommand
    case permissionRequired
    case helperUnavailable
    case executionUnavailable
    case restoreExpired
    case restoreConflict
    case invalidSelection
}

public enum AtlasResponse: Codable, Hashable, Sendable {
    case accepted(task: AtlasTaskDescriptor)
    case health(AtlasHealthSnapshot)
    case permissions([PermissionState])
    case apps([AppFootprint])
    case preview(ActionPlan)
    case settings(AtlasSettings)
    case rejected(code: AtlasProtocolErrorCode, reason: String)
}

public struct AtlasResponseEnvelope: Codable, Hashable, Sendable {
    public var requestID: UUID
    public var sentAt: Date
    public var response: AtlasResponse

    public init(requestID: UUID, sentAt: Date = Date(), response: AtlasResponse) {
        self.requestID = requestID
        self.sentAt = sentAt
        self.response = response
    }
}

public enum AtlasEvent: Codable, Hashable, Sendable {
    case taskProgress(taskID: UUID, completed: Int, total: Int)
    case taskFinished(TaskRun)
    case permissionUpdated(PermissionState)
}

public struct AtlasEventEnvelope: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var emittedAt: Date
    public var event: AtlasEvent

    public init(id: UUID = UUID(), emittedAt: Date = Date(), event: AtlasEvent) {
        self.id = id
        self.emittedAt = emittedAt
        self.event = event
    }
}

public enum AtlasPrivilegedActionKind: String, Codable, CaseIterable, Hashable, Sendable {
    case trashItems
    case restoreItem
    case removeLaunchService
    case repairOwnership
}

public struct AtlasHelperAction: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var kind: AtlasPrivilegedActionKind
    public var targetPath: String
    public var destinationPath: String?

    public init(id: UUID = UUID(), kind: AtlasPrivilegedActionKind, targetPath: String, destinationPath: String? = nil) {
        self.id = id
        self.kind = kind
        self.targetPath = targetPath
        self.destinationPath = destinationPath
    }
}


public struct AtlasHelperActionResult: Codable, Hashable, Sendable {
    public var action: AtlasHelperAction
    public var success: Bool
    public var message: String
    public var resolvedPath: String?

    public init(action: AtlasHelperAction, success: Bool, message: String, resolvedPath: String? = nil) {
        self.action = action
        self.success = success
        self.message = message
        self.resolvedPath = resolvedPath
    }
}
