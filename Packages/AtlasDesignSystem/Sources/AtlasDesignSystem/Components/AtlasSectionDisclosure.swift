import SwiftUI

/// Progressive disclosure collapsible section with animated chevron.
/// Replaces "Show All" buttons with a cleaner, animated expand/collapse.
public struct AtlasSectionDisclosure<Content: View>: View {
    private let title: String
    private let count: Int?
    private let defaultExpanded: Bool
    private let content: Content

    @State private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        count: Int? = nil,
        defaultExpanded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.count = count
        self.defaultExpanded = defaultExpanded
        self.content = content()
        self._isExpanded = State(initialValue: defaultExpanded)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton

            if isExpanded {
                VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                    content
                }
                .padding(.top, AtlasSpacing.lg)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .move(edge: .top))
                )
            }
        }
    }

    private var headerButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : AtlasMotion.standard) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: AtlasSpacing.md) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AtlasColor.brand)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(reduceMotion ? nil : AtlasMotion.fast, value: isExpanded)
                    .frame(width: 16)

                Text(title)
                    .font(AtlasTypography.sectionTitle)
                    .foregroundStyle(.primary)

                if let count {
                    Text("\(count)")
                        .font(AtlasTypography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AtlasSpacing.sm)
                        .padding(.vertical, AtlasSpacing.xxs)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
