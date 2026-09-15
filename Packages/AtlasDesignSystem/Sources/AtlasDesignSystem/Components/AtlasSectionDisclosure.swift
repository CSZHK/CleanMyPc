import SwiftUI

/// Progressive disclosure collapsible section with animated chevron.
/// Replaces "Show All" buttons with a cleaner, animated expand/collapse.
public struct AtlasSectionDisclosure<Content: View>: View {
    private let title: String
    private let count: Int?
    /// 折叠态下必须透出的关键参数（`P1-12`）—— 折叠标题本身不足以让用户
    /// 在执行前看到「文件会被整理到哪」。展开后隐藏，避免与面板内容重复。
    private let summary: String?
    private let defaultExpanded: Bool
    private let content: Content

    @State private var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        count: Int? = nil,
        summary: String? = nil,
        defaultExpanded: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.count = count
        self.summary = summary
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

                // `P1-12`：折叠态透出关键参数（去向）。展开后由面板内容承载，不再重复。
                if !isExpanded, let summary {
                    Text(summary)
                        .font(AtlasTypography.bodySmall)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("section.disclosure.summary")
                }

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
