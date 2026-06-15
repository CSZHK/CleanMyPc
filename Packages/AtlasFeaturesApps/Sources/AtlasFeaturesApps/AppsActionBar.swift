import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Apps action bar

/// Pinned action bar for the apps screen (spec §2.3 Apps 段 — single select,
/// no batch). Renders only when `shouldShowActionBar` is true (selected app +
/// ready preview plan + matching currentPreviewedAppID).
struct AppsActionBar: View {
    let selectedApp: AppFootprint?
    let previewPlan: ActionPlan?
    let isRunning: Bool
    let activePreviewAppID: UUID?
    let activeUninstallAppID: UUID?
    let retentionDays: Int
    let onPrimary: () -> Void

    var body: some View {
        AtlasActionBar(
            primaryTitle: primaryTitle,
            primaryEnabled: !isRunning,
            onPrimary: onPrimary,
            promise: AppsEvidencePanelBuilder.actionBarPromise(plan: previewPlan, retentionDays: retentionDays),
            metricText: AppsEvidencePanelBuilder.actionBarMetric(selectedApp: selectedApp),
            progress: activeUninstallAppID == selectedApp?.id ? 0.0 : nil,
            primaryIdentifier: primaryIdentifier
        )
        .padding(.horizontal, AtlasSpacing.lg)
        .padding(.top, AtlasSpacing.sm)
    }

    private var primaryTitle: String {
        if activePreviewAppID == selectedApp?.id { return AtlasL10n.string("apps.preview.running") }
        if activeUninstallAppID == selectedApp?.id { return AtlasL10n.string("apps.uninstall.running") }
        return previewPlan != nil
            ? AtlasL10n.string("apps.uninstall.action")
            : AtlasL10n.string("apps.preview.action")
    }

    /// Stable UI-test contract: mirror the legacy per-app identifiers.
    private var primaryIdentifier: String {
        guard let id = selectedApp?.id else { return "apps.primary" }
        return previewPlan != nil
            ? "apps.uninstall.\(id.uuidString)"
            : "apps.preview.\(id.uuidString)"
    }
}
