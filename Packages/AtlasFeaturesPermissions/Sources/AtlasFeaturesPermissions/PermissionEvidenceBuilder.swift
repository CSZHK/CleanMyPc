import AtlasDesignSystem
import AtlasDomain

// MARK: - Permission evidence (Calm Ledger Batch M, spec §3 权限行)

/// Pure mapping from a `PermissionState` to the three-segment inline evidence
/// (为什么需要 / 影响范围 / 如何授权). Behavior is unchanged — the content is
/// reorganized from the existing rationale + support fields plus two new
/// per-kind L10n keys (scope / authorize). Nothing is fabricated: every field
/// comes from real permission data or a localized constant tied to the kind.
///
/// The builder produces an `AtlasEvidenceContent` so the row-level disclosure
/// reuses the same value shape as the work-module evidence panels (why text +
/// mono KV evidence + recovery ⛨ box). For permissions the recovery box is
/// always suppressed (`recoveryText == nil`) — there is no file recovery
/// semantics here; the third segment is 「如何授权」, rendered as the recovery
/// section is *not* (the panel renders why + KV evidence only). The authorize
/// sentence is surfaced as a KV row under the evidence section instead.
public enum PermissionEvidenceBuilder {

    /// Three-segment content for one permission row.
    public static func content(for state: PermissionState) -> AtlasEvidenceContent {
        AtlasEvidenceContent(
            title: state.kind.title,
            whyText: whyText(for: state),
            evidence: evidenceItems(for: state),
            recoveryText: nil
        )
    }

    /// Why this permission is needed. Uses the permission's own rationale when
    /// present (the real, runtime-provided sentence); falls back to the
    /// per-kind support copy (same source the legacy callout used).
    public static func whyText(for state: PermissionState) -> String {
        if !state.rationale.isEmpty {
            return state.rationale
        }
        return supportText(for: state.kind)
    }

    /// Mono KV evidence rows. The permission title + status lead, then the
    /// per-kind scope (影响范围) and authorize (如何授权) sentences as KV rows
    /// so the three segments are all visible inside the inline panel.
    public static func evidenceItems(for state: PermissionState) -> [AtlasEvidenceItem] {
        var items: [AtlasEvidenceItem] = []
        items.append(AtlasEvidenceItem(
            id: "status",
            label: AtlasL10n.string("permissions.evidence.section.why"),
            value: state.isGranted
                ? AtlasL10n.string("permissions.row.ready")
                : (state.kind.isRequiredForCurrentWorkflows
                    ? AtlasL10n.string("permissions.row.required")
                    : AtlasL10n.string("permissions.row.optional"))
        ))
        items.append(AtlasEvidenceItem(
            id: "scope",
            label: AtlasL10n.string("permissions.evidence.section.scope"),
            value: scopeText(for: state.kind)
        ))
        items.append(AtlasEvidenceItem(
            id: "authorize",
            label: AtlasL10n.string("permissions.evidence.section.authorize"),
            value: authorizeText(for: state.kind)
        ))
        return items
    }

    /// Per-kind 影响范围 sentence.
    public static func scopeText(for kind: PermissionKind) -> String {
        switch kind {
        case .fullDiskAccess:
            return AtlasL10n.string("permissions.evidence.scope.fullDiskAccess")
        case .accessibility:
            return AtlasL10n.string("permissions.evidence.scope.accessibility")
        case .notifications:
            return AtlasL10n.string("permissions.evidence.scope.notifications")
        }
    }

    /// Per-kind 如何授权 sentence.
    public static func authorizeText(for kind: PermissionKind) -> String {
        switch kind {
        case .fullDiskAccess:
            return AtlasL10n.string("permissions.evidence.authorize.fullDiskAccess")
        case .accessibility:
            return AtlasL10n.string("permissions.evidence.authorize.accessibility")
        case .notifications:
            return AtlasL10n.string("permissions.evidence.authorize.notifications")
        }
    }

    private static func supportText(for kind: PermissionKind) -> String {
        switch kind {
        case .fullDiskAccess:
            return AtlasL10n.string("permissions.support.fullDiskAccess")
        case .accessibility:
            return AtlasL10n.string("permissions.support.accessibility")
        case .notifications:
            return AtlasL10n.string("permissions.support.notifications")
        }
    }
}
