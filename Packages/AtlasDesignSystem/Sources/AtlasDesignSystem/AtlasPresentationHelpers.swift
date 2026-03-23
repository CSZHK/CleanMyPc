import AtlasDomain
import SwiftUI

// MARK: - Shared Domain → UI Mappings
//
// These public extensions centralise the mapping from domain enums
// to AtlasTone and SF Symbol strings so every feature module shares
// the same visual language without duplicating private extensions.

public extension TaskStatus {
    var atlasTone: AtlasTone {
        switch self {
        case .queued:
            return .neutral
        case .running:
            return .warning
        case .completed:
            return .success
        case .failed, .cancelled:
            return .danger
        }
    }
}

public extension RiskLevel {
    var atlasTone: AtlasTone {
        switch self {
        case .safe:
            return .success
        case .review:
            return .warning
        case .advanced:
            return .danger
        }
    }
}

public extension TaskKind {
    var atlasSystemImage: String {
        switch self {
        case .scan:
            return "sparkles"
        case .executePlan:
            return "play.circle"
        case .uninstallApp:
            return "trash"
        case .restore:
            return "arrow.uturn.backward.circle"
        case .inspectPermissions:
            return "lock.shield"
        }
    }
}

public extension ActionItem.Kind {
    var atlasSystemImage: String {
        switch self {
        case .removeCache:
            return "trash"
        case .removeApp:
            return "app.badge.minus"
        case .archiveFile:
            return "archivebox"
        case .inspectPermission:
            return "lock.shield"
        case .reviewEvidence:
            return "doc.text.magnifyingglass"
        }
    }
}

public enum AtlasCategoryIcon {
    public static func systemImage(for category: String) -> String {
        switch category.lowercased() {
        case "developer":
            return "hammer"
        case "system":
            return "gearshape.2"
        case "apps":
            return "square.stack.3d.up"
        case "browsers":
            return "globe"
        default:
            return "sparkles"
        }
    }
}
