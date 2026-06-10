import AtlasDomain
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// DEPRECATED (Calm Ledger M2, G6): absorbed by `AtlasEvidencePanel` — this file
// is deleted with the M3 Apps migration. Do NOT adopt in new code; build the
// single/aggregate/executing evidence states on `AtlasEvidencePanel` instead.
//
// The `@available(*, deprecated)` marker lives on the typealias below rather
// than on the struct itself: two pre-M3 consumers remain (AppsFeatureView:629,
// HistoryFeatureView:1045) and Swift has no per-use deprecation exemption, so
// marking the struct would break the zero-warning build until M3 (verified:
// 2 warnings). M3 deletes the consumers, then this whole file.
// ─────────────────────────────────────────────────────────────────────────────

/// Deprecation marker for ``AtlasEvidenceGroupCard`` (see file header).
@available(*, deprecated, message: "Absorbed by AtlasEvidencePanel — remove with M3 Apps migration")
public typealias AtlasLegacyEvidenceGroupCard = AtlasEvidenceGroupCard

/// Controls how an ``AtlasEvidenceGroupCard`` renders its content.
public enum AtlasEvidenceGroupDisplayMode: Sendable {
    /// Compact inline display used in uninstall preview cards.
    case preview
    /// Full display with verified/divergent indicators used after uninstall completion.
    case completion
    /// Ledger-oriented display with timestamp context for recovery items
    /// (renamed from `history`, Calm Ledger §2.2).
    case ledger
}

/// A compact card representing a single evidence group (e.g. Caches, Support Files)
/// in the app uninstall workflow.  Adapts its content based on ``mode``.
///
/// > Deprecated: Absorbed by ``AtlasEvidencePanel`` — removed with the M3 Apps
/// > migration (see file header for why the attribute sits on the typealias).
public struct AtlasEvidenceGroupCard: View {
    let group: AtlasAppEvidenceGroup
    let mode: AtlasEvidenceGroupDisplayMode

    public init(group: AtlasAppEvidenceGroup, mode: AtlasEvidenceGroupDisplayMode) {
        self.group = group
        self.mode = mode
    }

    public var body: some View {
        HStack(alignment: .center, spacing: AtlasSpacing.md) {
            categoryIcon

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                    Text(group.category.title)
                        .font(AtlasTypography.rowTitle)
                        .lineLimit(1)

                    safetyBadge
                }

                HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                    Text(AtlasL10n.string(
                        group.itemCount == 1
                            ? "evidence.card.items.one"
                            : "evidence.card.items.other",
                        group.itemCount
                    ))
                    .font(AtlasTypography.bodySmall)
                    .foregroundStyle(.secondary)

                    Text(AtlasFormatters.byteCount(group.totalBytes))
                        .font(AtlasTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: AtlasSpacing.sm)

            trailingContent
        }
        .padding(AtlasSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .fill(cardBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var categoryIcon: some View {
        let iconTint = safetyTone.tint
        ZStack {
            Circle()
                .fill(safetyTone.softFill)
                .frame(width: AtlasLayout.sidebarIconSize, height: AtlasLayout.sidebarIconSize)

            Image(systemName: categorySystemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconTint)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var safetyBadge: some View {
        AtlasStatusChip(group.safetyLevel.title, tone: safetyTone)
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch mode {
        case .preview:
            EmptyView()

        case .completion:
            completionTrailing

        case .ledger:
            if group.items.isEmpty {
                AtlasStatusChip(
                    AtlasL10n.string("evidence.legacy.badge"),
                    tone: .neutral
                )
            }
        }
    }

    @ViewBuilder
    private var completionTrailing: some View {
        let verifiedCount = group.items.filter(\.verified).count
        let divergentCount = group.items.count - verifiedCount

        if divergentCount > 0 {
            HStack(spacing: AtlasSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.warning)
                    .accessibilityHidden(true)

                Text(AtlasL10n.string(
                    "evidence.card.divergent",
                    divergentCount
                ))
                .font(AtlasTypography.captionSmall)
                .foregroundStyle(AtlasColor.warning)
            }
        } else if verifiedCount > 0 {
            Image(systemName: "checkmark.circle.fill")
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.success)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Computed Properties

    private var safetyTone: AtlasTone {
        switch group.safetyLevel {
        case .safe: return .success
        case .conditional: return .warning
        case .protected: return .danger
        }
    }

    private var cardBackgroundColor: Color {
        switch mode {
        case .preview:
            return AtlasColor.cardRaised
        case .completion:
            let divergent = group.items.contains { !$0.verified }
            return divergent ? AtlasColor.warning.opacity(0.04) : AtlasColor.cardRaised
        case .ledger:
            return AtlasColor.cardRaised
        }
    }

    private var cardBorderColor: Color {
        switch mode {
        case .preview:
            return AtlasColor.border
        case .completion:
            let divergent = group.items.contains { !$0.verified }
            return divergent ? AtlasColor.warning.opacity(0.2) : AtlasColor.border
        case .ledger:
            return AtlasColor.border
        }
    }

    private var categorySystemImage: String {
        switch group.category {
        case .appBundle: return "app.fill"
        case .supportFiles: return "folder.fill"
        case .caches: return "arrow.triangle.2.circlepath"
        case .preferences: return "slider.horizontal.3"
        case .logs: return "doc.text.fill"
        case .launchItems: return "rocket.fill"
        case .savedState: return "internaldrive"
        case .containers: return "archivebox.fill"
        case .groupContainers: return "square.stack.3d.up.fill"
        case .miscLeftovers: return "tray.full"
        }
    }

    private var accessibilityLabel: String {
        let base = "\(group.category.title): \(group.itemCount) items, \(AtlasFormatters.byteCount(group.totalBytes))"
        switch mode {
        case .completion:
            let verified = group.items.filter(\.verified).count
            let divergent = group.items.count - verified
            if divergent > 0 {
                return "\(base), \(divergent) changed since preview"
            }
            return "\(base), verified"
        default:
            return base
        }
    }
}
