import AtlasDomain
import SwiftUI

/// "Next action" recommendation banner (spec §3 概览/§4.2): a brand-gradient
/// card carrying one headline, a short rationale (timeliness supplied by the
/// caller), a white primary capsule, an optional ghost secondary action and an
/// optional top-right dismiss ("忽略" — the 7-day cooldown is the caller's
/// persistence concern; `onDismiss == nil` renders no dismiss control).
///
/// **Gradient angle decision** (findings 遗项 ③, resolved here): the spec
/// sketches 135°; `AtlasColor.bannerGradient` runs topLeading→bottomTrailing,
/// which equals 135° only on a square frame and flattens toward horizontal on
/// a wide banner. This is **explicitly accepted as the diagonal gradient** —
/// no UnitPoint angle math; the token stays the single gradient truth source.
///
/// **Contrast**: white headline on the darker `brand` origin ≈5.5:1. The
/// rationale is rendered at 90% white — the sketched 85% measures 4.43:1 on
/// `#0F766E` (just under AA); 90% measures ≈4.77:1. Text is leading-anchored
/// over the darker gradient origin; the lighter bottom-trailing region carries
/// controls (≥3:1 non-text), not body text.
public struct AtlasNextActionBanner: View {
    // Internal (not private) so logic tests can exercise the stored callbacks.
    let headline: String
    let rationale: String
    let primaryTitle: String
    let onPrimary: () -> Void
    let secondaryTitle: String?
    let onSecondary: (() -> Void)?
    let onDismiss: (() -> Void)?

    /// Banner headline scale step (per plan: bold 15) — sits between the
    /// `rowTitle` 13 and `sectionTitle` 17 tokens; banner-scoped on purpose.
    private static let headlineFont = Font.system(size: 15, weight: .bold)
    /// Rationale white opacity — raised from the sketched 85% to clear
    /// 4.5:1 on the `brand` gradient origin (see type doc).
    public static let rationaleOpacity: Double = 0.9
    /// Dismiss ghost sits at 60% white (icon-only control, ≥3:1 non-text).
    private static let dismissOpacity: Double = 0.6

    public init(
        headline: String,
        rationale: String,
        primaryTitle: String,
        onPrimary: @escaping () -> Void,
        secondaryTitle: String?,
        onSecondary: (() -> Void)?,
        onDismiss: (() -> Void)?
    ) {
        self.headline = headline
        self.rationale = rationale
        self.primaryTitle = primaryTitle
        self.onPrimary = onPrimary
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
        self.onDismiss = onDismiss
    }

    // MARK: Pure render predicates (unit-tested)

    /// The ghost secondary renders only when both title and action exist.
    public static func showsSecondary(title: String?, action: (() -> Void)?) -> Bool {
        title != nil && action != nil
    }

    /// No `onDismiss` ⇒ no dismiss control at all (caller opted out of 忽略).
    public static func showsDismiss(_ onDismiss: (() -> Void)?) -> Bool {
        onDismiss != nil
    }

    // MARK: Body

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            HStack(alignment: .top, spacing: AtlasSpacing.md) {
                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    Text(headline)
                        .font(Self.headlineFont)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(rationale)
                        .font(AtlasTypography.bodySmall)
                        .foregroundStyle(.white.opacity(Self.rationaleOpacity))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AtlasSpacing.sm)

                if Self.showsDismiss(onDismiss), let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(AtlasTypography.caption)
                            .foregroundStyle(.white.opacity(Self.dismissOpacity))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(AtlasL10n.string("ds.banner.dismiss")))
                }
            }

            HStack(spacing: AtlasSpacing.md) {
                Button(action: onPrimary) {
                    Text(primaryTitle)
                        .font(AtlasTypography.label)
                        .foregroundStyle(AtlasColor.brand)
                        .lineLimit(1)
                        .padding(.horizontal, AtlasSpacing.xl)
                        .padding(.vertical, AtlasSpacing.sm)
                        .background(Capsule(style: .continuous).fill(.white))
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(primaryTitle))

                if Self.showsSecondary(title: secondaryTitle, action: onSecondary),
                   let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .font(AtlasTypography.label)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, AtlasSpacing.xl)
                            .padding(.vertical, AtlasSpacing.sm)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                            )
                            .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(secondaryTitle))
                }
            }
        }
        .padding(AtlasSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.bannerGradient)
        )
    }
}
