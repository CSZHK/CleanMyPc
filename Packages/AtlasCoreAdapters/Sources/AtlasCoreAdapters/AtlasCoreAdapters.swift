import AtlasProtocol
import Foundation

public struct AtlasLegacyAdapterDescriptor: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var capability: String
    public var status: AtlasCapabilityStatus

    public init(name: String, capability: String, status: AtlasCapabilityStatus) {
        self.name = name
        self.capability = capability
        self.status = status
    }
}

public enum AtlasCoreAdapterCatalog {
    public static func defaultDescriptors(
        status: AtlasCapabilityStatus = AtlasCapabilityStatus()
    ) -> [AtlasLegacyAdapterDescriptor] {
        [
            AtlasLegacyAdapterDescriptor(
                name: "MoleScanAdapter",
                capability: "Structured Smart Clean scanning bridge",
                status: status
            ),
            AtlasLegacyAdapterDescriptor(
                name: "MoleAppsAdapter",
                capability: "Installed apps and leftovers inspection bridge",
                status: status
            ),
            AtlasLegacyAdapterDescriptor(
                name: "MoleStatusAdapter",
                capability: "Overview health and diagnostics bridge",
                status: status
            ),
        ]
    }

    public static func bootstrapEvent(taskID: UUID = UUID()) -> AtlasEventEnvelope {
        AtlasEventEnvelope(event: .taskProgress(taskID: taskID, completed: 0, total: 1))
    }
}
