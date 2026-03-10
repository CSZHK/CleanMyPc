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

                Divider()
                    .padding(.vertical, AtlasSpacing.xs)

                HStack(spacing: AtlasSpacing.md) {
                    SocialBadge(
                        assetName: "icon-wechat",
                        label: AtlasL10n.string("about.social.wechat")
                    )
                    SocialBadge(
                        assetName: "icon-xiaohongshu",
                        label: AtlasL10n.string("about.social.xiaohongshu")
                    )
                    SocialBadge(
                        assetName: "icon-x",
                        label: AtlasL10n.string("about.social.x"),
                        url: "https://x.com/lizikk_zhu"
                    )
                    SocialBadge(
                        assetName: "icon-discord",
                        label: AtlasL10n.string("about.social.discord"),
                        url: "https://discord.gg"
                    )
                }
            }

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

private struct SocialBadge: View {
    let assetName: String
    let label: String
    var url: String? = nil

    var body: some View {
        let content = VStack(spacing: AtlasSpacing.xs) {
            Image(assetName, bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)

        if let url, let destination = URL(string: url) {
            Link(destination: destination) { content }
        } else {
            content
        }
    }
}

#Preview {
    AboutFeatureView()
}
