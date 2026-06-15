import AtlasDomain
import SwiftUI

// MARK: - Panel

/// Persistent evidence panel (spec §4.2): single = why/evidence/recovery
/// three-segment; aggregate = count + mono total + risk distribution;
/// executing = live row status stream with expandable failure details;
/// empty = "select an item" hint. Actions slot renders below the content.
public struct AtlasEvidencePanel<Actions: View>: View {
    private let state: AtlasEvidenceState
    private let actions: Actions

    @State private var expandedRows: Set<Int> = []

    public init(state: AtlasEvidenceState, @ViewBuilder actions: () -> Actions) {
        self.state = state
        self.actions = actions()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            switch state {
            case .empty:
                emptyView
            case .single(let content):
                singleView(content)
            case .aggregate(let aggregate):
                aggregateView(aggregate)
            case .executing(let rows):
                executingView(rows)
            }

            actions
        }
        .frame(minWidth: AtlasLayout.evidencePanelMinWidth, maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: Empty

    private var emptyView: some View {
        VStack(spacing: AtlasSpacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(AtlasColor.textTertiary)
                .accessibilityHidden(true)
            Text(AtlasL10n.string("ds.evidence.empty"))
                .font(AtlasTypography.body)
                .foregroundStyle(AtlasColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AtlasSpacing.section)
        .background(surfaceCard)
    }

    // MARK: Single (three-segment)

    private func singleView(_ content: AtlasEvidenceContent) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            Text(content.title)
                .font(AtlasTypography.sectionTitle)
                .foregroundStyle(AtlasColor.ink)
                .lineLimit(2)

            section(titleKey: "ds.evidence.section.why") {
                Text(content.whyText)
                    .font(AtlasTypography.body)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AtlasSpacing.lg)
            .background(surfaceCard)

            section(titleKey: "ds.evidence.section.evidence") {
                VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                    ForEach(content.evidence) { item in
                        evidenceRow(item)
                    }
                }
            }
            .padding(AtlasSpacing.lg)
            .background(inputCard)

            if state.showsRecoveryBox, let recovery = content.recoveryText {
                recoveryBox(recovery)
            }
        }
    }

    private func evidenceRow(_ item: AtlasEvidenceItem) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
            Text(item.label)
                .font(AtlasTypography.captionSmall)
                .foregroundStyle(AtlasColor.textSecondary)
            Text(item.value)
                .font(AtlasTypography.dataBody)
                .monospacedDigit()
                .foregroundStyle(AtlasColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle) // paths middle-truncate (spec §1.3)
                .help(item.value)        // hover reveals the full value/path
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.label))
        .accessibilityValue(Text(item.value))
    }

    // MARK: Aggregate

    private func aggregateView(_ aggregate: AtlasEvidenceAggregate) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: AtlasSpacing.md) {
                Text(AtlasL10n.string("ds.evidence.aggregate.selected", aggregate.count))
                    .font(AtlasTypography.sectionTitle)
                    .foregroundStyle(AtlasColor.ink)
                Spacer(minLength: AtlasSpacing.sm)
                Text(aggregate.totalText)
                    .font(AtlasTypography.dataMetric)
                    .monospacedDigit()
                    .foregroundStyle(AtlasColor.inkData)
            }
            .padding(AtlasSpacing.lg)
            .background(surfaceCard)

            VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                ForEach(Array(aggregate.riskBreakdown.enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: AtlasSpacing.sm) {
                        Circle()
                            .fill(entry.tone.tint)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(entry.label)
                            .font(AtlasTypography.body)
                            .foregroundStyle(AtlasColor.textPrimary)
                        Spacer(minLength: AtlasSpacing.sm)
                        Text("\(entry.count)")
                            .font(AtlasTypography.dataBody)
                            .monospacedDigit()
                            .foregroundStyle(AtlasColor.textSecondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(entry.label))
                    .accessibilityValue(Text("\(entry.count)"))
                }
            }
            .padding(AtlasSpacing.lg)
            .background(inputCard)

            if state.showsRecoveryBox, let recovery = aggregate.commonRecoveryText {
                recoveryBox(recovery)
            }
        }
    }

    // MARK: Executing

    private func executingView(_ rows: [(title: String, status: AtlasTone, detail: String?)]) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
            Text(AtlasL10n.string("ds.evidence.executing.title"))
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textSecondary)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                executingRow(row, index: index)
            }
        }
        .padding(AtlasSpacing.lg)
        .background(surfaceCard)
    }

    private func executingRow(_ row: (title: String, status: AtlasTone, detail: String?), index: Int) -> some View {
        let isExpanded = expandedRows.contains(index)
        return VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            HStack(spacing: AtlasSpacing.sm) {
                Image(systemName: row.status.symbol)
                    .font(AtlasTypography.caption)
                    .foregroundStyle(row.status.tint)
                    .accessibilityHidden(true)

                Text(row.title)
                    .font(AtlasTypography.body)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(row.title)
                    // The status is otherwise icon+color only (hidden above).
                    // Prefix it onto the title's announcement so VoiceOver
                    // conveys success/warning/danger — the row's most safety-
                    // relevant fact (round-3 a11y; reuses AtlasTone's label).
                    .accessibilityLabel(Text("\(row.status.accessibilityLabel), \(row.title)"))

                Spacer(minLength: AtlasSpacing.sm)

                if row.detail != nil {
                    Button {
                        if isExpanded { expandedRows.remove(index) } else { expandedRows.insert(index) }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(AtlasTypography.captionSmall)
                            .foregroundStyle(AtlasColor.textSecondary)
                            // 44pt hit target — the visible glyph stays small
                            // (round-2 a11y; matches the Toast close pattern).
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(AtlasL10n.string(
                        isExpanded ? "ds.evidence.executing.detail.hide" : "ds.evidence.executing.detail.show"
                    )))
                }
            }

            if isExpanded, let detail = row.detail {
                Text(detail)
                    .font(AtlasTypography.bodySmall)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, AtlasSpacing.xl)
            }
        }
        .padding(.vertical, AtlasSpacing.xxs)
    }

    // MARK: Shared chrome

    private func section(titleKey: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            Text(AtlasL10n.string(titleKey))
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// ⛨ brand-stroked recovery box — rendered ONLY via `showsRecoveryBox` (fail-closed).
    private func recoveryBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AtlasSpacing.sm) {
            Image(systemName: "checkmark.shield.fill")
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.brand)
                .accessibilityHidden(true)
            Text(text)
                .font(AtlasTypography.bodySmall)
                .foregroundStyle(AtlasColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AtlasSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .fill(AtlasColor.successFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .strokeBorder(AtlasColor.brand, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(AtlasL10n.string("ds.evidence.section.recovery")))
        .accessibilityValue(Text(text))
    }

    private var surfaceCard: some View {
        RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
            .fill(AtlasColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                    .strokeBorder(AtlasColor.border, lineWidth: 1)
            )
    }

    private var inputCard: some View {
        RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
            .fill(AtlasColor.surfaceInput)
            .overlay(
                RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                    .strokeBorder(AtlasColor.border, lineWidth: 1)
            )
    }
}

public extension AtlasEvidencePanel where Actions == EmptyView {
    /// Convenience: panel without a row-level actions slot.
    init(state: AtlasEvidenceState) {
        self.init(state: state) { EmptyView() }
    }
}
