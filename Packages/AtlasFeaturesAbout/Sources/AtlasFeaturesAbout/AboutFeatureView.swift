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
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(AtlasColor.brand)
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

            AtlasInfoCard(
                title: AtlasL10n.string("about.social.title")
            ) {
                HStack(spacing: AtlasSpacing.md) {
                    Image(systemName: "ellipsis.bubble")
                        .font(.title3)
                        .foregroundStyle(AtlasColor.brand)
                        .accessibilityHidden(true)

                    Text(AtlasL10n.string("about.social.detail"))
                        .font(AtlasTypography.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("about.screen")
    }
}

#Preview {
    AboutFeatureView()
}
