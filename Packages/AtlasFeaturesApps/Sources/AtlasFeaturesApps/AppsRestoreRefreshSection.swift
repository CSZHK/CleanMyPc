import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Restore-refresh auxiliary section (evidence-panel action slot)

/// Post-restore refresh card + divergence rescan, rendered as the apps
/// evidence-panel's action slot. Both pieces are fail-closed on real backing
/// data: the card only renders when a matching `AtlasAppPostRestoreRefreshStatus`
/// exists for the selected app, and the divergence block only when
/// `evidenceDivergenceDetected` is true.
struct AppsRestoreRefreshSection: View {
    let status: AtlasAppPostRestoreRefreshStatus
    let isRunning: Bool
    let onRescanLeftovers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            cardBody
            if status.evidenceDivergenceDetected {
                divergenceBody
            }
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            AtlasKeyValueRow(
                title: AtlasL10n.string("apps.restore.refresh.recorded.title"),
                value: "\(status.recordedLeftoverItems)",
                detail: AtlasL10n.string("apps.restore.refresh.recorded.detail")
            )
            if let refreshed = status.refreshedLeftoverItems {
                AtlasKeyValueRow(
                    title: AtlasL10n.string("apps.restore.refresh.current.title"),
                    value: "\(refreshed)",
                    detail: AtlasL10n.string("apps.restore.refresh.current.detail")
                )
            }
        }
        .padding(AtlasSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous).fill(AtlasColor.surface))
        .overlay(RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous).strokeBorder(AtlasColor.border, lineWidth: 1))
    }

    private var divergenceBody: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            AtlasCallout(
                title: AtlasL10n.string("apps.restore.divergence.title"),
                detail: AtlasL10n.string(
                    "apps.restore.divergence.detail",
                    status.appName,
                    status.divergentCategories.map(\.title).joined(separator: ", ")
                ),
                tone: .warning,
                systemImage: "exclamationmark.arrow.triangle.2.circlepath"
            )
            Button(action: onRescanLeftovers) {
                Label(AtlasL10n.string("apps.restore.divergence.rescan"), systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.atlasPrimary)
            .disabled(isRunning)
            .accessibilityIdentifier("apps.restore.divergence.rescan")
        }
    }
}
