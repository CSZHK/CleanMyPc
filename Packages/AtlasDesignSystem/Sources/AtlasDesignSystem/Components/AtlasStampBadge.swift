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

    public var body: some View {
        let diameter = Self.baseDiameter * style.sizeMultiplier

        ZStack {
            Circle()
                .strokeBorder(AtlasColor.brand, lineWidth: 2.5)

            VStack(spacing: AtlasSpacing.xxs) {
                if let numberText {
                    Text(numberText)
                        .font(AtlasTypography.ledgerNumber)
                }

                Text(title)
                    .font(AtlasTypography.ledgerFont(size: 13, weight: .bold))
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(AtlasTypography.ledgerFont(size: 10, weight: .regular))
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(AtlasColor.brand)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .padding(AtlasSpacing.md)
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
