import Foundation

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
    private let maxEntries: Int

    public init(entries: [AuditEntry] = [], maxEntries: Int = 512) {
        self.entries = entries
        self.maxEntries = maxEntries
    }

    public func append(_ message: String) {
        entries.insert(AuditEntry(message: message), at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    public func allEntries() -> [AuditEntry] {
        entries
    }
}
