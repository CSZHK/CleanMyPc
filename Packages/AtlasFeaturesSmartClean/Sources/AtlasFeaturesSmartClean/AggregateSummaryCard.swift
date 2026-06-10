import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Data Model

/// Aggregated metrics for a single risk-level bucket.
public struct RiskLevelAggregate: Identifiable, Equatable {
    public let riskLevel: RiskLevel
    public let totalBytes: Int64
    public let findingCount: Int

    public var id: RiskLevel { riskLevel }

    public init(riskLevel: RiskLevel, totalBytes: Int64, findingCount: Int) {
        self.riskLevel = riskLevel
        self.totalBytes = totalBytes
        self.findingCount = findingCount
    }
}

// MARK: - Card View

/// Hero-style card that summarises total reclaimable space grouped by risk level.
///
/// Displays three segments (safe → success, review → warning, advanced → danger)
/// with a visual proportion bar, per-level byte counts, finding counts, and a
/// brief summary text like *"3.2 GB can be safely cleaned, 890 MB requires review"*.
///
/// Follows the `AtlasHeroCard` pattern for card background, border, and tone tinting.
public struct AggregateSummaryCard: View {

    private let aggregates: [RiskLevelAggregate]
    private let totalBytes: Int64
    private let summaryText: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(findings: [Finding]) {
        let grouped = Dictionary(grouping: findings, by: \.risk)

        let safeAgg = RiskLevelAggregate(
            riskLevel: .safe,
            totalBytes: grouped[.safe]?.reduce(0) { $0 + $1.bytes } ?? 0,
            findingCount: grouped[.safe]?.count ?? 0
        )
        let reviewAgg = RiskLevelAggregate(
            riskLevel: .review,
            totalBytes: grouped[.review]?.reduce(0) { $0 + $1.bytes } ?? 0,
            findingCount: grouped[.review]?.count ?? 0
        )
        let advancedAgg = RiskLevelAggregate(
            riskLevel: .advanced,
            totalBytes: grouped[.advanced]?.reduce(0) { $0 + $1.bytes } ?? 0,
            findingCount: grouped[.advanced]?.count ?? 0
        )

        self.aggregates = [safeAgg, reviewAgg, advancedAgg]
        self.totalBytes = safeAgg.totalBytes + reviewAgg.totalBytes + advancedAgg.totalBytes
        self.summaryText = Self.buildSummary(safe: safeAgg, review: reviewAgg, advanced: advancedAgg)
    }

    public var body: some View {
        VStack(spacing: AtlasSpacing.xl) {
            headerSection
            proportionBar
            breakdownRows
            summaryFooter
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AtlasSpacing.section)
        .padding(.horizontal, AtlasSpacing.xxl)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AtlasSpacing.xs) {
            Text(AtlasFormatters.byteCount(totalBytes))
                .font(AtlasTypography.dataHero)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(AtlasL10n.string("smartclean.summary.totalReclaimable"))
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Proportion Bar

    private var proportionBar: some View {
        let total = max(totalBytes, 1)

        return GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(aggregates) { agg in
                    let fraction = CGFloat(agg.totalBytes) / CGFloat(total)
                    if agg.totalBytes > 0 {
                        RoundedRectangle(cornerRadius: fraction < 0.05 ? 1 : 3, style: .continuous)
                            .fill(agg.riskLevel.atlasTone.tint)
                            .frame(width: max(fraction * geometry.size.width, 2))
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(height: 8)
        .animation(reduceMotion ? nil : AtlasMotion.standard, value: totalBytes)
    }

    // MARK: - Breakdown Rows

    private var breakdownRows: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            ForEach(aggregates) { agg in
                HStack(spacing: AtlasSpacing.md) {
                    Circle()
                        .fill(agg.riskLevel.atlasTone.tint)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(agg.riskLevel.title)
                            .font(AtlasTypography.label)
                            .foregroundStyle(.primary)

                        Text(AtlasL10n.string(
                            "smartclean.summary.findingCount",
                            agg.findingCount
                        ))
                        .font(AtlasTypography.bodySmall)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(AtlasFormatters.byteCount(agg.totalBytes))
                        .font(AtlasTypography.dataMetric)
                        .foregroundStyle(agg.riskLevel.atlasTone.tint)
                        .contentTransition(.numericText())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(agg.riskLevel.title): \(AtlasFormatters.byteCount(agg.totalBytes)), \(agg.findingCount) findings")
            }
        }
    }

    // MARK: - Summary Footer

    private var summaryFooter: some View {
        Text(summaryText)
            .font(AtlasTypography.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }

    // MARK: - Card Styling (follows AtlasHeroCard pattern)

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
                .fill(AtlasColor.card)

            RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AtlasColor.brand.opacity(0.06),
                            AtlasColor.brand.opacity(0.01),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.primary.opacity(0.05), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )

            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                AtlasColor.brand.opacity(0.03),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 48)
            }
        }
        .shadow(
            color: Color.black.opacity(AtlasElevation.prominent.shadowOpacity),
            radius: AtlasElevation.prominent.shadowRadius,
            y: AtlasElevation.prominent.shadowY
        )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        AtlasColor.brand.opacity(0.18),
                        Color.primary.opacity(0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }

    // MARK: - Helpers

    private var accessibilitySummary: String {
        let total = AtlasFormatters.byteCount(totalBytes)
        let lines = aggregates.map { agg in
            "\(agg.riskLevel.title): \(AtlasFormatters.byteCount(agg.totalBytes)), \(agg.findingCount) findings"
        }
        return "\(total) total. " + lines.joined(separator: ". ")
    }

    private static func buildSummary(
        safe: RiskLevelAggregate,
        review: RiskLevelAggregate,
        advanced: RiskLevelAggregate
    ) -> String {
        var parts: [String] = []

        if safe.totalBytes > 0 {
            parts.append(
                AtlasL10n.string(
                    "smartclean.summary.safeSegment",
                    AtlasFormatters.byteCount(safe.totalBytes)
                )
            )
        }
        if review.totalBytes > 0 {
            parts.append(
                AtlasL10n.string(
                    "smartclean.summary.reviewSegment",
                    AtlasFormatters.byteCount(review.totalBytes)
                )
            )
        }
        if advanced.totalBytes > 0 {
            parts.append(
                AtlasL10n.string(
                    "smartclean.summary.advancedSegment",
                    AtlasFormatters.byteCount(advanced.totalBytes)
                )
            )
        }

        if parts.isEmpty {
            return AtlasL10n.string("smartclean.summary.empty")
        }

        return parts.joined(separator: ", ")
    }
}
