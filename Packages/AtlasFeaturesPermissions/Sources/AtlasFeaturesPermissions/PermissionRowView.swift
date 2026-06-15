import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Permission row with inline three-segment evidence (Calm Ledger Batch M)

/// One permission row plus an inline three-segment evidence disclosure
/// (spec §3 权限: 「每行证据三段式展开 — 为什么需要 / 影响范围 / 如何授权」).
///
/// The row chrome (`AtlasDetailRow`) is unchanged — same icon/title/subtitle/
/// status chip/authorize button as before (behavior unchanged). Below the row,
/// a disclosure toggles a compact three-segment panel built from the same
/// `AtlasEvidenceContent` value the work-module panels use; content comes from
/// `PermissionEvidenceBuilder` (rationale → why, per-kind scope/authorize
/// constants). No file-recovery box renders (no recovery semantics for
/// permissions — `recoveryText == nil`).
struct PermissionRowView: View {

    let state: PermissionState
    let onAuthorize: (PermissionKind) -> Void

    @State private var isEvidenceExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
            AtlasDetailRow(
                title: state.kind.title,
                subtitle: state.rationale,
                footnote: footnote,
                systemImage: state.kind.systemImage,
                tone: state.isGranted ? .success : statusTone
            ) {
                VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
                    AtlasStatusChip(statusText, tone: statusTone)

                    if !state.isGranted {
                        Button(authorizeTitle) {
                            onAuthorize(state.kind)
                        }
                        .buttonStyle(.atlasSecondary)
                    }
                }
            }

            disclosureToggle
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var disclosureToggle: some View {
        DisclosureGroup(isExpanded: $isEvidenceExpanded) {
            AtlasEvidencePanel(state: .single(PermissionEvidenceBuilder.content(for: state)))
                .padding(.top, AtlasSpacing.xs)
        } label: {
            HStack(spacing: AtlasSpacing.xxs) {
                Image(systemName: "info.circle")
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(AtlasL10n.string("permissions.evidence.toggle"))
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var footnote: String {
        if state.isGranted {
            return AtlasL10n.string("permissions.row.ready")
        }
        return state.kind.isRequiredForCurrentWorkflows
            ? AtlasL10n.string("permissions.row.required")
            : AtlasL10n.string("permissions.row.optional")
    }

    private var statusText: String {
        if state.isGranted {
            return AtlasL10n.string("common.granted")
        }
        return state.kind.isRequiredForCurrentWorkflows
            ? AtlasL10n.string("permissions.status.required")
            : AtlasL10n.string("permissions.status.optional")
    }

    private var statusTone: AtlasTone {
        if state.isGranted {
            return .success
        }
        return state.kind.isRequiredForCurrentWorkflows ? .warning : .neutral
    }

    private var authorizeTitle: String {
        switch state.kind {
        case .notifications:
            return AtlasL10n.string("permissions.grant.notifications")
        case .fullDiskAccess, .accessibility:
            return AtlasL10n.string("permissions.grant.action")
        }
    }
}
