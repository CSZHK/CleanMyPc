import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - 「更早归档」 collapsible section (spec §3 台账底部)

/// Collapsible "earlier archive" group at the bottom of the ledger timeline.
///
/// Preserves the legacy HistoryFeatureView archive-judgment behavior: a run
/// is "recent" if completed/failed/cancelled within the last 7 days; anything
/// older falls into this collapsible section. Collapsed by default so the
/// active + recent runs stay in view.
public struct LedgerArchiveView: View {
    private let entries: [AtlasLedgerEntryModel]
    private let title: String
    @Binding private var isExpanded: Bool
    @Binding private var selection: String?

    public init(
        entries: [AtlasLedgerEntryModel],
        title: String,
        isExpanded: Binding<Bool>,
        selection: Binding<String?>
    ) {
        self.entries = entries
        self.title = title
        self._isExpanded = isExpanded
        self._selection = selection
    }

    public var body: some View {
        if entries.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Button {
                    withAnimation(AtlasMotion.standard) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: AtlasSpacing.xs) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(AtlasTypography.captionSmall)
                            .foregroundStyle(.secondary)
                        Text("\(title) · \(entries.count)")
                            .font(AtlasTypography.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: AtlasSpacing.sm)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(title), \(entries.count)"))
                .accessibilityValue(Text(isExpanded ? AtlasL10n.string("ledger.archive.expanded") : AtlasL10n.string("ledger.archive.collapsed")))
                .accessibilityHint(Text(AtlasL10n.string("ledger.archive.hint")))

                if isExpanded {
                    AtlasLedgerTimeline(entries: entries, selection: $selection)
                        .padding(.leading, AtlasSpacing.lg)
                        .transition(.opacity)
                }
            }
        }
    }
}
