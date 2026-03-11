import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct AboutFeatureView: View {
    public init() {}

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("about.screen.title"),
            subtitle: AtlasL10n.string("about.screen.subtitle")
        ) {
            AtlasInfoCard(
                title: AtlasL10n.string("about.author.title")
            ) {
                HStack(alignment: .center, spacing: AtlasSpacing.md) {
                    Image("avatar", bundle: .module)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                        Text(AtlasL10n.string("about.author.name"))
                            .font(AtlasTypography.sectionTitle)

                        Text(AtlasL10n.string("about.author.role"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, AtlasSpacing.sm)

                Text(AtlasL10n.string("about.author.bio"))
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)

            }

            SocialGrid()

            AtlasCallout(
                title: AtlasL10n.string("about.author.quote"),
                detail: AtlasL10n.string("about.author.name"),
                tone: .neutral,
                systemImage: "quote.opening"
            )

            AtlasInfoCard(
                title: AtlasL10n.string("about.product.title")
            ) {
                AtlasDetailRow(
                    title: AtlasL10n.string("about.product.name"),
                    subtitle: AtlasL10n.string("about.product.detail"),
                    systemImage: "sparkle"
                )

                Link(destination: URL(string: "https://studio.atomstorm.ai")!) {
                    Text(AtlasL10n.string("about.product.visit"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.atlasPrimary)
                .padding(.top, AtlasSpacing.sm)
            }

            AtlasInfoCard(
                title: AtlasL10n.string("about.opensource.title")
            ) {
                AtlasDetailRow(
                    title: AtlasL10n.string("about.opensource.name"),
                    subtitle: AtlasL10n.string("about.opensource.detail"),
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )

                Link(destination: URL(string: "https://github.com/CSZHK/CleanMyPc")!) {
                    Text(AtlasL10n.string("about.opensource.visit"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.atlasSecondary)
                .padding(.top, AtlasSpacing.sm)
            }

        }
        .accessibilityIdentifier("about.screen")
    }
}

// MARK: - Social Grid

private struct SocialGrid: View {
    var body: some View {
        HStack(spacing: AtlasSpacing.md) {
            SocialCard(
                iconAsset: "icon-wechat",
                label: AtlasL10n.string("about.social.wechat"),
                qrCodeAsset: "qrcode-wechat"
            )
            SocialCard(
                iconAsset: "icon-xiaohongshu",
                label: AtlasL10n.string("about.social.xiaohongshu"),
                qrCodeAsset: "qrcode-xiaohongshu"
            )
            SocialCard(
                iconAsset: "icon-x",
                label: AtlasL10n.string("about.social.x"),
                url: "https://x.com/lizikk_zhu"
            )
            SocialCard(
                iconAsset: "icon-discord",
                label: AtlasL10n.string("about.social.discord"),
                url: "https://discord.gg/aR2kF8Xman"
            )
        }
    }
}

private struct SocialCard: View {
    let iconAsset: String
    let label: String
    var qrCodeAsset: String? = nil
    var url: String? = nil

    @State private var isHovering = false

    var body: some View {
        Group {
            if let url, let destination = URL(string: url) {
                Link(destination: destination) { cardContent }
            } else {
                cardContent
            }
        }
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var cardContent: some View {
        VStack(spacing: AtlasSpacing.sm) {
            if let qrCodeAsset {
                Image(qrCodeAsset, bundle: .module)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(.horizontal, AtlasSpacing.section)
                    .padding(.top, AtlasSpacing.sm)
            } else {
                Spacer()

                Image(iconAsset, bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)

                Spacer()
            }

            HStack(spacing: AtlasSpacing.xxs) {
                Image(iconAsset, bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)

                Text(label)
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if url != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, AtlasSpacing.xs)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.cardRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(
                    isHovering ? AtlasColor.borderEmphasis : AtlasColor.border,
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

#Preview {
    AboutFeatureView()
}
