import SwiftUI

/// Warm ledger-paper container (spec §4.2): `ledgerPaper` ground, 1px
/// `ledgerBorder`, continuous `AtlasRadius.md` corners and — deliberately —
/// **no shadow**: the ledger surface reads as "printed on paper" (§1.4),
/// flat by definition, unlike the cool work-surface cards.
///
/// Usage boundary (spec §1.2 暖面使用边界): the warm surface is reserved for
/// the ledger screen, the workflow stage-④ receipt view, and the overview
/// ledger-stream cards. Every other container stays on the cool work
/// surfaces (`AtlasScreen` cards / `atlasCard`).
///
/// The optional `title` renders in ledger voice ③ (`ledgerTitle`, serif 19
/// bold with the Songti cascade) above a 1.5pt `ledgerInk` rule (§1.4).
public struct AtlasLedgerSurface<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    /// The serif title + 1.5pt ink rule render only for non-blank titles —
    /// a whitespace-only title would float the rule with nothing above it.
    public static func showsTitleBlock(title: String?) -> Bool {
        guard let title else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            if Self.showsTitleBlock(title: title), let title {
                VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                    Text(title)
                        .font(AtlasTypography.ledgerTitle)
                        .foregroundStyle(AtlasColor.ledgerInk)

                    Rectangle()
                        .fill(AtlasColor.ledgerInk)
                        .frame(height: 1.5)
                        .accessibilityHidden(true) // decorative title rule (§1.4)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .fill(AtlasColor.ledgerPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .strokeBorder(AtlasColor.ledgerBorder, lineWidth: 1)
        )
        // No .shadow on purpose — paper-print flatness (spec §1.4).
    }
}

// MARK: - Dotted ledger rule

public extension View {
    /// Dotted entry separator for ledger surfaces (spec §1.4 点状分隔线):
    /// a 1pt `ledgerRule`-colored line dashed [1, 3], drawn along the view's
    /// bottom edge. Decorative only — hidden from accessibility.
    func atlasLedgerRule() -> some View {
        modifier(AtlasLedgerRuleModifier())
    }

    /// Conditionally apply the ledger rule — e.g. skip the last row of a feed
    /// so no dangling hairline renders beneath the final entry (round-12).
    @ViewBuilder
    func atlasLedgerRule(if condition: Bool) -> some View {
        if condition {
            modifier(AtlasLedgerRuleModifier())
        } else {
            self
        }
    }
}

private struct AtlasLedgerRuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                AtlasLedgerRuleLine()
                    .stroke(
                        AtlasColor.ledgerRule,
                        style: StrokeStyle(lineWidth: 1, dash: [1, 3])
                    )
                    .frame(height: 1)
                    .accessibilityHidden(true)
            }
    }
}

/// Horizontal hairline path stroked with the dotted ledger style.
private struct AtlasLedgerRuleLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
