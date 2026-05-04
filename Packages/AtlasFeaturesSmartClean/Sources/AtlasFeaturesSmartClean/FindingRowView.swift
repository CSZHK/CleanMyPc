import AtlasDesignSystem
import AtlasDomain
import SwiftUI

/// Enhanced row component for displaying individual scan findings.
///
/// Presents a finding with its title, detail, byte size, risk badge (``AtlasStatusChip``),
/// file age indicator, storage category tag, and a collapsible human-readable explanation.
/// Uses the ``AtlasDetailRow`` pattern for layout consistency with the rest of the UI.
///
/// The risk badge is color-coded: green for safe, amber for review, and red for advanced.
/// File age is shown as a relative date string (e.g. "Last accessed 3 months ago").
/// The explanation is displayed as a one-line summary by default, with an expand option.
public struct FindingRowView: View {

    // MARK: - Properties

    private let finding: Finding
    private let showExplanation: Bool

    @State private var isExplanationExpanded = false

    // MARK: - Init

    public init(finding: Finding, showExplanation: Bool = true) {
        self.finding = finding
        self.showExplanation = showExplanation
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow

            if showExplanation, let explanation = resolvedExplanation {
                explanationSection(explanation)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Main Row

    private var mainRow: some View {
        AtlasDetailRow(
            title: finding.title,
            subtitle: finding.detail,
            footnote: footnoteText,
            systemImage: AtlasCategoryIcon.systemImage(for: finding.category),
            tone: finding.risk.atlasTone
        ) {
            VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
                AtlasStatusChip(
                    finding.risk.title,
                    tone: finding.risk.atlasTone
                )

                Text(AtlasFormatters.byteCount(finding.bytes))
                    .font(AtlasTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Explanation Section

    @ViewBuilder
    private func explanationSection(_ explanation: String) -> some View {
        HStack(alignment: .top, spacing: AtlasSpacing.md) {
            Image(systemName: "lightbulb")
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.brand)
                .frame(width: 16)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text(explanation)
                    .font(AtlasTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExplanationExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    withAnimation(AtlasMotion.standard) {
                        isExplanationExpanded.toggle()
                    }
                } label: {
                    Text(
                        isExplanationExpanded
                            ? AtlasL10n.string("smartclean.finding.collapse")
                            : AtlasL10n.string("smartclean.finding.expand")
                    )
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.brand)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isExplanationExpanded
                        ? AtlasL10n.string("smartclean.finding.collapse")
                        : AtlasL10n.string("smartclean.finding.expand")
                )
            }
        }
        .padding(.horizontal, AtlasSpacing.xxl)
        .padding(.top, AtlasSpacing.sm)
        .padding(.bottom, AtlasSpacing.md)
    }

    // MARK: - Helpers

    private var footnoteText: String? {
        var parts: [String] = []

        parts.append(categoryLabel)

        if let fileAge = finding.fileAge, let ageText = ageIndicator(from: fileAge) {
            parts.append(ageText)
        }

        return parts.joined(separator: " \u{2022} ")
    }

    private var categoryLabel: String {
        finding.storageCategory?.title
            ?? AtlasL10n.localizedCategory(finding.category)
    }

    private var resolvedExplanation: String? {
        if let explanation = finding.explanation, !explanation.isEmpty {
            return explanation
        }

        let category = finding.storageCategory ?? .systemCache
        let generated = AtlasFindingExplanations.explanation(
            for: category,
            risk: finding.risk,
            fileAge: finding.fileAge
        )
        return generated.isEmpty ? nil : generated
    }

    private func ageIndicator(from fileAge: FileAgeInfo) -> String? {
        if let lastAccessed = fileAge.lastAccessedDate {
            let relative = AtlasFormatters.relativeDate(lastAccessed)
            return AtlasL10n.string("smartclean.finding.lastAccessed", relative)
        }
        if let creationDate = fileAge.creationDate {
            let relative = AtlasFormatters.relativeDate(creationDate)
            return AtlasL10n.string("smartclean.finding.created", relative)
        }
        return nil
    }
}
