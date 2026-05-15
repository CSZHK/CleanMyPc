import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct StorageFeatureView: View {
    private let insights: [StorageInsight]

    public init(insights: [StorageInsight] = AtlasScaffoldFixtures.storageInsights) {
        self.insights = insights
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("storage.screen.title"),
            subtitle: AtlasL10n.string("storage.screen.subtitle")
        ) {
            AtlasInfoCard(
                title: AtlasL10n.string("storage.largeItems.title"),
                subtitle: AtlasL10n.string("storage.largeItems.subtitle")
            ) {
                if insights.isEmpty {
                    AtlasEmptyState(
                        title: AtlasL10n.string("storage.empty.title"),
                        detail: AtlasL10n.string("storage.empty.detail"),
                        systemImage: "internaldrive",
                        tone: .neutral
                    )
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ForEach(insights) { insight in
                            AtlasDetailRow(
                                title: insight.title,
                                subtitle: insight.path,
                                systemImage: "doc.fill",
                                tone: .neutral
                            ) {
                                VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
                                    AtlasStatusChip(insight.ageDescription, tone: .neutral)

                                    Text(AtlasFormatters.byteCount(insight.bytes))
                                        .font(AtlasTypography.label)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
