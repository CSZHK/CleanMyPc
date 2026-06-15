import AtlasDesignSystem
import AtlasDomain
import Foundation

// MARK: - Apps restore-refresh UI mapping

/// Shared localization/tone mapping for `AtlasAppPostRestoreRefreshState`, used
/// by the apps screen callout and the evidence-panel restore section. Lifted
/// out of the feature coordinator to keep the view file under the 350-line
/// feature-view discipline (the mapping is pure presentation logic, not a View).
extension AtlasAppPostRestoreRefreshState {
    var calloutTitle: String {
        switch self {
        case .refreshing: return AtlasL10n.string("apps.restore.refresh.pending.title")
        case .refreshed:  return AtlasL10n.string("apps.restore.refresh.refreshed.title")
        case .stale:      return AtlasL10n.string("apps.restore.refresh.stale.title")
        }
    }

    func calloutDetail(status: AtlasAppPostRestoreRefreshStatus) -> String {
        switch self {
        case .refreshing:
            return AtlasL10n.string("apps.restore.refresh.pending.detail", status.appName)
        case .refreshed:
            return AtlasL10n.string(
                "apps.restore.refresh.refreshed.detail",
                status.appName,
                status.refreshedLeftoverItems ?? 0,
                status.recordedLeftoverItems
            )
        case .stale:
            return AtlasL10n.string(
                "apps.restore.refresh.stale.detail",
                status.appName,
                status.recordedLeftoverItems
            )
        }
    }

    var tone: AtlasTone {
        switch self {
        case .refreshing: return .neutral
        case .refreshed:  return .success
        case .stale:      return .warning
        }
    }

    var systemImage: String {
        switch self {
        case .refreshing: return "arrow.triangle.2.circlepath"
        case .refreshed:  return "checkmark.arrow.trianglehead.clockwise"
        case .stale:      return "exclamationmark.arrow.trianglehead.clockwise"
        }
    }
}
