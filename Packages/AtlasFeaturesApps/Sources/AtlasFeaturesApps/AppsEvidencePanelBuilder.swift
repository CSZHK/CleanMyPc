import AtlasDesignSystem
import AtlasDomain
import Foundation

// MARK: - Apps evidence builder (pure)

/// Pure mapping from a single selected `AppFootprint` (and the matching
/// `ActionPlan?`, if a preview has been generated for that app) to the
/// `AtlasEvidencePanel` single-selection state machine (spec §3 Apps row).
///
/// The 10-category evidence footprint (spec §3) maps as follows:
/// - `AppFootprint.evidenceSummary: [AtlasAppEvidenceCategory: Int]?` holds the
///   per-category item counts for the 10 footprint categories (appBundle,
///   supportFiles, caches, preferences, logs, launchItems, savedState,
///   containers, groupContainers, miscLeftovers).
/// - Each non-zero category becomes one mono KV row in the `evidence` segment.
/// - The app bundle path/bytes render as the leading KV rows.
///
/// Fail-closed (spec §1.6): no recovery ⛨ sentence without a real `ActionPlan`
/// whose `recoverable` items back the recovery promise. No plan ⇒ `recoveryText`
/// is nil and the recovery box is suppressed by `AtlasEvidenceState`.
public enum AppsEvidencePanelBuilder {

    // MARK: Whole-panel state

    /// Maps the apps-screen selection to the evidence-panel state machine.
    ///
    /// - `selectedApp == nil` → `.empty` ("select an app" hint).
    /// - `selectedApp != nil` → `.single` three-segment content built from the
    ///   footprint's 10-category evidence summary + the matching `ActionPlan?`
    ///   (plan preview / residual estimate / recovery promise).
    public static func panelState(
        app: AppFootprint?,
        previewPlan: ActionPlan?,
        retentionDays: Int
    ) -> AtlasEvidenceState {
        guard let app else {
            return .empty
        }
        return .single(content(for: app, previewPlan: previewPlan, retentionDays: retentionDays))
    }

    // MARK: Three-segment content (why / evidence KV / recovery)

    public static func content(
        for app: AppFootprint,
        previewPlan: ActionPlan?,
        retentionDays: Int
    ) -> AtlasEvidenceContent {
        AtlasEvidenceContent(
            title: app.name,
            whyText: whyText(for: app, previewPlan: previewPlan),
            evidence: evidenceItems(for: app, previewPlan: previewPlan),
            recoveryText: recoveryText(app: app, previewPlan: previewPlan, retentionDays: retentionDays)
        )
    }

    /// Why-safe explanation for the selected app.
    public static func whyText(for app: AppFootprint, previewPlan: ActionPlan?) -> String {
        if previewPlan != nil {
            return AtlasL10n.string("apps.evidence.why.ready", app.name)
        }
        return AtlasL10n.string("apps.evidence.why.idle", app.name)
    }

    /// Mono KV rows. Bundle path/bytes lead, then the 10-category footprint
    /// (only non-zero categories render), then the uninstall-plan residual
    /// estimate when a preview plan exists.
    public static func evidenceItems(for app: AppFootprint, previewPlan: ActionPlan?) -> [AtlasEvidenceItem] {
        var items: [AtlasEvidenceItem] = []
        items.append(AtlasEvidenceItem(
            id: "bundlePath",
            label: AtlasL10n.string("apps.evidence.bundlePath"),
            value: app.bundlePath
        ))
        items.append(AtlasEvidenceItem(
            id: "bundleBytes",
            label: AtlasL10n.string("apps.evidence.bundleBytes"),
            value: AtlasFormatters.byteCount(app.bytes)
        ))
        if let leftoverItems = leftoverEstimate(app: app) {
            items.append(AtlasEvidenceItem(
                id: "leftoverItems",
                label: AtlasL10n.string("apps.evidence.leftoverItems"),
                value: "\(leftoverItems)"
            ))
        }
        items.append(contentsOf: footprintCategoryItems(for: app))
        if let residual = residualEstimate(plan: previewPlan) {
            items.append(AtlasEvidenceItem(
                id: "residualEstimate",
                label: AtlasL10n.string("apps.evidence.residualEstimate"),
                value: residual
            ))
        }
        return items
    }

    /// Recovery sentence only when a real preview plan exists AND at least one
    /// plan item is recoverable; nil suppresses the ⛨ box entirely (fail-closed
    /// §1.6). Apps recovery = bundle moved to the recovery area + retentionDays
    /// window before final purge (same model as the legacy detail card).
    public static func recoveryText(app: AppFootprint, previewPlan: ActionPlan?, retentionDays: Int) -> String? {
        guard let previewPlan else { return nil }
        let recoverableCount = previewPlan.items.filter(\.recoverable).count
        guard recoverableCount > 0 else { return nil }
        return AtlasL10n.string("apps.evidence.recovery", recoverableCount, retentionDays)
    }

    // MARK: Footprint 10-category mapping

    /// One KV row per non-zero evidence-summary category, in the stable
    /// `AtlasAppEvidenceCategory.allCases` order. Categories absent from the
    /// summary (or zero counts) are omitted — only real backing data renders.
    public static func footprintCategoryItems(for app: AppFootprint) -> [AtlasEvidenceItem] {
        guard let summary = app.evidenceSummary, !summary.isEmpty else {
            return []
        }
        return AtlasAppEvidenceCategory.allCases.compactMap { category in
            guard let count = summary[category], count > 0 else { return nil }
            return AtlasEvidenceItem(
                id: "footprint.\(category.rawValue)",
                label: category.title,
                value: "\(count)"
            )
        }
    }

    // MARK: Residual / leftover estimates (pure)

    /// Total leftover item count across the 10-category footprint, when the
    /// summary is present. Falls back to the legacy `leftoverItems` scalar when
    /// the per-category summary is unavailable (older scan output).
    public static func leftoverEstimate(app: AppFootprint) -> Int? {
        if let summary = app.evidenceSummary, !summary.isEmpty {
            let footprintTotal = summary.values.reduce(0, +)
            return max(footprintTotal, app.leftoverItems)
        }
        return app.leftoverItems > 0 ? app.leftoverItems : nil
    }

    /// Uninstall-plan residual estimate (spec §3 残留估计): the bytes Atlas will
    /// move to the recovery area (recoverable items) plus any review-only bytes
    /// the plan flags for manual attention. nil when no plan is ready.
    public static func residualEstimate(plan: ActionPlan?) -> String? {
        guard let plan else { return nil }
        let reclaimable = plan.estimatedBytes
        let reviewOnly = plan.estimatedReviewOnlyBytes ?? 0
        if reviewOnly > 0 {
            return AtlasL10n.string(
                "apps.evidence.residual.withReview",
                AtlasFormatters.byteCount(reclaimable),
                AtlasFormatters.byteCount(reviewOnly)
            )
        }
        return AtlasL10n.string("apps.evidence.residual.reclaimable", AtlasFormatters.byteCount(reclaimable))
    }

    // MARK: Action-bar gating predicate

    /// The action bar appears only when an app is selected AND its uninstall
    /// preview plan is ready (spec §2.3 Apps 段 — single select, no batch).
    public static func shouldShowActionBar(selectedApp: AppFootprint?, previewPlan: ActionPlan?, currentPreviewedAppID: UUID?) -> Bool {
        guard let selectedApp, let previewPlan, currentPreviewedAppID == selectedApp.id else {
            return false
        }
        // previewPlan's presence is the gate; its contents are surfaced via the
        // promise/metric accessors. Touching it here keeps the contract explicit.
        _ = previewPlan
        return true
    }

    /// Action-bar promise (state-driven, fail-closed §1.6): mirrors the
    /// SmartClean three-form copy, judged against the preview plan's real
    /// recovery metadata. nil ⇒ no ⛨ sentence.
    public static func actionBarPromise(plan: ActionPlan?, retentionDays: Int) -> String? {
        guard let plan, !plan.items.isEmpty else { return nil }
        let recoverableCount = plan.items.filter(\.recoverable).count
        let totalCount = plan.items.count
        guard recoverableCount > 0 else { return nil }
        if recoverableCount >= totalCount {
            return AtlasL10n.string("apps.actionbar.promise.full", retentionDays)
        }
        return AtlasL10n.string("apps.actionbar.promise.partial", recoverableCount, totalCount, retentionDays)
    }

    /// Mono action-bar metric: selected app footprint bytes.
    public static func actionBarMetric(selectedApp: AppFootprint?) -> String? {
        guard let selectedApp else { return nil }
        return AtlasFormatters.byteCount(selectedApp.bytes)
    }
}
