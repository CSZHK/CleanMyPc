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
            AtlasInfoCard(title: AtlasL10n.string("storage.largeItems.title")) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(insights) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(insight.title)
                                    .font(.headline)
                                Text(insight.path)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 8) {
                                AtlasStatusChip(insight.ageDescription, tone: .neutral)
                                Text(AtlasFormatters.byteCount(insight.bytes))
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                    }
                }
            }
        }
    }
}
