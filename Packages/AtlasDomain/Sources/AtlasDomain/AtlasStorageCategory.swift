import Foundation

public enum AtlasStorageCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case systemCache
    case appCache
    case developerArtifact
    case browserData
    case logFile
    case downloadArtifact
    case mailAttachment
    case oldBackup
    case unknown

    public var title: String {
        switch self {
        case .systemCache:
            return AtlasL10n.string("storageCategory.systemCache")
        case .appCache:
            return AtlasL10n.string("storageCategory.appCache")
        case .developerArtifact:
            return AtlasL10n.string("storageCategory.developerArtifact")
        case .browserData:
            return AtlasL10n.string("storageCategory.browserData")
        case .logFile:
            return AtlasL10n.string("storageCategory.logFile")
        case .downloadArtifact:
            return AtlasL10n.string("storageCategory.downloadArtifact")
        case .mailAttachment:
            return AtlasL10n.string("storageCategory.mailAttachment")
        case .oldBackup:
            return AtlasL10n.string("storageCategory.oldBackup")
        case .unknown:
            return AtlasL10n.string("storageCategory.unknown")
        }
    }

    public var systemImage: String {
        switch self {
        case .systemCache:
            return "gearshape.2"
        case .appCache:
            return "square.grid.2x2"
        case .developerArtifact:
            return "hammer"
        case .browserData:
            return "globe"
        case .logFile:
            return "doc.text"
        case .downloadArtifact:
            return "arrow.down.circle"
        case .mailAttachment:
            return "envelope"
        case .oldBackup:
            return "externaldrive"
        case .unknown:
            return "questionmark.folder"
        }
    }
}
