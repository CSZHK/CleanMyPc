import AtlasDomain
import SwiftUI

// MARK: - Models

/// Lifecycle status of one ledger entry.
public enum AtlasLedgerEntryStatus: Equatable, Sendable {
    case inProgress
    case recoverable(daysLeft: Int)
    case verified
    case archived
    case superseded
}

/// One ledger timeline entry: № + title + mono data + status badge.
public struct AtlasLedgerEntryModel: Identifiable, Equatable, Sendable {
    public let id: String
    /// Global ledger sequence number (№N — monotonic, spec §1.6).
    public let number: Int
    public let title: String
    public let detail: String
    public let metricText: String?
    public let status: AtlasLedgerEntryStatus

    public init(id: String, number: Int, title: String, detail: String, metricText: String?, status: AtlasLedgerEntryStatus) {
        self.id = id
        self.number = number
        self.title = title
        self.detail = detail
        self.metricText = metricText
        self.status = status
    }
}

// MARK: - Timeline

/// Left-rail ledger timeline (spec §3 台账 / §4.2). Sits on warm ledger paper.
/// - Rail: `brand` 1.5pt for selected/in-progress entries, `ledgerRule` 1pt otherwise.
/// - № renders in the serif ledger voice, brand-colored.
/// - In-progress entries pin to the top; the rest sort by № descending.
/// - Every row is fully clickable and drives `selection` (anti-gimmick back-link
///   red line: a № must always reach its ledger detail).
public struct AtlasLedgerTimeline: View {
    private let entries: [AtlasLedgerEntryModel]
    @Binding private var selection: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(entries: [AtlasLedgerEntryModel], selection: Binding<String?>) {
        self.entries = entries
        self._selection = selection
    }

    // MARK: Pure logic (unit-tested)

    /// Pinned order: in-progress entries first, then everything else; both groups
    /// sort by № descending (newest plan on top of its group).
    public static func pinnedOrder(_ entries: [AtlasLedgerEntryModel]) -> [AtlasLedgerEntryModel] {
        let pinned = entries.filter { $0.status == .inProgress }.sorted { $0.number > $1.number }
        let rest = entries.filter { $0.status != .inProgress }.sorted { $0.number > $1.number }
        return pinned + rest
    }

    /// Resolved badge content for a status. `tone == nil` ⇒ muted ledger styling
    /// (archived/superseded are inert records, not semantic states).
    public struct BadgePresentation: Equatable, Sendable {
        public let symbol: String?
        public let text: String
        public let tone: AtlasTone?
    }

    public static func badge(for status: AtlasLedgerEntryStatus, language: AtlasLanguage? = nil) -> BadgePresentation {
        switch status {
        case .inProgress:
            return BadgePresentation(
                symbol: "arrow.triangle.2.circlepath",
                text: AtlasL10n.string("ds.ledger.status.inProgress", language: language),
                tone: .warning
            )
        case .recoverable(let daysLeft):
            return BadgePresentation(
                symbol: "checkmark.shield.fill", // ⛨ — teal shield, never red (公章规避)
                text: AtlasL10n.string("ds.ledger.status.recoverable", language: language, daysLeft),
                tone: .neutral
            )
        case .verified:
            return BadgePresentation(
                symbol: "checkmark",
                text: AtlasL10n.string("ds.ledger.status.verified", language: language),
                tone: .success
            )
        case .archived:
            return BadgePresentation(
                symbol: "archivebox",
                text: AtlasL10n.string("ds.ledger.status.archived", language: language),
                tone: nil
            )
        case .superseded:
            return BadgePresentation(
                symbol: nil,
                text: AtlasL10n.string("ds.ledger.status.superseded", language: language),
                tone: nil
            )
        }
    }

    /// Localized explicit a11y label: zh「计划编号 N，title」/ en "Plan number N, title".
    public static func accessibilityLabel(number: Int, title: String, language: AtlasLanguage? = nil) -> String {
        AtlasL10n.string("ds.ledger.entry.a11y", language: language, number, title)
    }

    // MARK: Body

    public var body: some View {
        let ordered = Self.pinnedOrder(entries)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, entry in
                row(entry, isLast: index == ordered.count - 1)
            }
        }
        .animation(reduceMotion ? nil : AtlasMotion.standard, value: selection)
    }

    // MARK: Row

    private func row(_ entry: AtlasLedgerEntryModel, isLast: Bool) -> some View {
        let isSelected = selection == entry.id
        let isEmphasized = isSelected || entry.status == .inProgress
        let badge = Self.badge(for: entry.status)

        return Button {
            selection = entry.id
        } label: {
            HStack(alignment: .top, spacing: AtlasSpacing.md) {
                rail(emphasized: isEmphasized, isLast: isLast)

                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: AtlasSpacing.sm) {
                        // № is a monotonic plan counter (spec §1.6). Recovery
                        // items are not plan-numbered (number == 0) — suppress the
                        // glyph so they don't render a misleading "№0" (round-4).
                        if entry.number > 0 {
                            Text("№\(entry.number)")
                                .font(AtlasTypography.ledgerNumber)
                                .foregroundStyle(AtlasColor.brand)
                        }

                        Text(entry.title)
                            .font(AtlasTypography.rowTitle)
                            .foregroundStyle(AtlasColor.ledgerInk)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: AtlasSpacing.sm)

                        badgeView(badge)
                    }

                    Text(entry.detail)
                        .font(AtlasTypography.bodySmall)
                        .foregroundStyle(AtlasColor.ledgerSecondary)
                        .lineLimit(2)

                    if let metricText = entry.metricText {
                        Text(metricText)
                            .font(AtlasTypography.dataCaption)
                            .monospacedDigit()
                            .foregroundStyle(AtlasColor.ledgerSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(metricText)
                    }
                }
                .padding(.bottom, AtlasSpacing.lg)
            }
            .padding(.horizontal, AtlasSpacing.sm)
            .padding(.top, AtlasSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                    .strokeBorder(isSelected ? AtlasColor.brand : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(entry.number > 0
            ? Self.accessibilityLabel(number: entry.number, title: entry.title)
            : entry.title))
        .accessibilityValue(Text(accessibilityValue(badge: badge, metricText: entry.metricText)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func accessibilityValue(badge: BadgePresentation, metricText: String?) -> String {
        guard let metricText else { return badge.text }
        return "\(badge.text) · \(metricText)"
    }

    // MARK: Rail (decorative — hidden from a11y)

    private func rail(emphasized: Bool, isLast: Bool) -> some View {
        VStack(spacing: AtlasSpacing.xxs) {
            Circle()
                .fill(emphasized ? AtlasColor.brand : AtlasColor.ledgerRule)
                .frame(width: 8, height: 8)
                .padding(.top, AtlasSpacing.xxs)

            if !isLast {
                Rectangle()
                    .fill(emphasized ? AtlasColor.brand : AtlasColor.ledgerRule)
                    .frame(width: emphasized ? 1.5 : 1)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 12)
        .accessibilityHidden(true)
    }

    // MARK: Badge

    @ViewBuilder
    private func badgeView(_ badge: BadgePresentation) -> some View {
        HStack(spacing: AtlasSpacing.xxs) {
            if let symbol = badge.symbol {
                Image(systemName: symbol)
                    .font(AtlasTypography.captionSmall)
                    .accessibilityHidden(true)
            }
            Text(badge.text)
                .font(AtlasTypography.captionSmall)
                .lineLimit(1)
        }
        .foregroundStyle(badgeForeground(badge.tone))
        .padding(.horizontal, AtlasSpacing.sm)
        .padding(.vertical, AtlasSpacing.xxs)
        .background(
            Capsule(style: .continuous)
                .fill(badgeBackground(badge.tone))
        )
    }

    /// Semantic fg/bg pairs from the token table (no opacity-composed fills):
    /// neutral→brand on safeFill, success→safe on safeFill, warning→review on
    /// reviewFill, muted (nil)→ledgerSecondary directly on the paper.
    private func badgeForeground(_ tone: AtlasTone?) -> Color {
        switch tone {
        case .neutral: return AtlasColor.brand
        case .success: return AtlasColor.success
        case .warning: return AtlasColor.warning
        case .danger:  return AtlasColor.danger
        case nil:      return AtlasColor.ledgerSecondary
        }
    }

    private func badgeBackground(_ tone: AtlasTone?) -> Color {
        switch tone {
        case .neutral, .success: return AtlasColor.successFill
        case .warning:           return AtlasColor.warningFill
        case .danger:            return AtlasColor.dangerFill
        case nil:                return .clear
        }
    }
}
