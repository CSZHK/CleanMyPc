import SwiftUI

/// Recovery-point / completion stamp (spec §1.6/§4.2): a perfect circle with a
/// 2.5pt teal `brand` stroke, serif ledger-voice content, rotated −11°.
///
/// Constraints (公章规避, findings): teal stroke only — never red, never a
/// five-pointed star. Copy must be fact-driven and supplied by the caller
/// (state-driven, fail-closed §1.6). The stamp is purely decorative:
/// `accessibilityHidden(true)` — adjacent text carries the information.
///
/// `style: .watermark` renders at 0.45 opacity, ×1.4 size, and never intercepts
/// clicks (ledger detail underlay). Appears with `AtlasMotion.stampIn`
/// (scale 1.15→1 + rotate to −11°); reduce-motion settles immediately.
public struct AtlasStampBadge: View {
    public enum Style: Equatable, Sendable {
        case badge
        case watermark

        /// Watermark sits behind content at 45% opacity.
        public var opacity: Double {
            self == .watermark ? 0.45 : 1.0
        }

        /// Watermark scales the stamp ×1.4 (spec §4.2).
        public var sizeMultiplier: CGFloat {
            self == .watermark ? 1.4 : 1.0
        }

        /// Watermark never intercepts interaction with the content beneath it.
        public var allowsHitTesting: Bool {
            self == .badge
        }
    }

    private let title: String
    private let subtitle: String?
    private let numberText: String?
    private let style: Style

    @State private var settled = false
    @State private var contentSide: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Base stamp diameter before the style multiplier.
    private static let baseDiameter: CGFloat = 96
    /// Final resting rotation (spec §1.5/§4.2).
    private static let restingAngle: Double = -11

    public init(title: String, subtitle: String?, numberText: String?, style: Style = .badge) {
        self.title = title
        self.subtitle = subtitle
        self.numberText = numberText
        self.style = style
    }

    /// Font sizes are FIXED (no minimumScaleFactor): the zh serif red line demands
    /// ≥13pt bold (§1.3) and scaling would silently drop below it. The badge grows
    /// to its content instead: the circle side is max(base, measured content side).
    public var body: some View {
        let diameter = max(Self.baseDiameter, contentSide) * style.sizeMultiplier

        ZStack {
            Circle()
                .strokeBorder(AtlasColor.brand, lineWidth: 2.5)

            VStack(spacing: AtlasSpacing.xxs) {
                if let numberText {
                    // №+digits are a Latin/numeral artifact — the zh ≥13pt serif
                    // red line does not apply; small serif keeps the stamp hierarchy.
                    Text(numberText)
                        .font(AtlasTypography.ledgerFont(size: 10, weight: .bold))
                }

                // Ledger voice ③ at the 13pt-bold token — satisfies the zh serif red line.
                Text(title)
                    .font(AtlasTypography.ledgerNumber)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    // Voice classification: subtitle carries facts ("X GB · 保留 N 天"),
                    // which is data voice ② (§1.3) — mono dataCaption, not serif.
                    Text(subtitle)
                        .font(AtlasTypography.dataCaption)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(AtlasColor.brand)
            .lineLimit(2)
            .padding(AtlasSpacing.md)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contentSide = max(proxy.size.width, proxy.size.height) }
                        .onChange(of: proxy.size) { _, size in
                            contentSide = max(size.width, size.height)
                        }
                }
            )
        }
        .frame(width: diameter, height: diameter)
        .rotationEffect(.degrees(settled ? Self.restingAngle : 0))
        .scaleEffect(settled ? 1.0 : 1.15)
        .opacity(settled ? style.opacity : 0)
        .allowsHitTesting(style.allowsHitTesting)
        .accessibilityHidden(true) // decorative — adjacent text carries the facts
        .onAppear {
            if reduceMotion {
                settled = true // settle immediately, no spring
            } else {
                withAnimation(AtlasMotion.stampIn) {
                    settled = true
                }
            }
        }
    }
}
