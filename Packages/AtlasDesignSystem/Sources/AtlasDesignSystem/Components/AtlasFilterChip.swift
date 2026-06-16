import SwiftUI

/// A rounded capsule filter chip used in horizontal filter bars.
/// Selected state uses a brand fill; unselected uses a bordered style.
public struct AtlasFilterChip: View {
    private let title: String
    private let isSelected: Bool
    private let count: Int?
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        isSelected: Bool,
        count: Int? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.count = count
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: AtlasSpacing.xs) {
                Text(title)
                    .font(AtlasTypography.caption)

                if let count {
                    Text("\(count)")
                        .font(AtlasTypography.captionSmall)
                        .padding(.horizontal, AtlasSpacing.xxs)
                        .padding(.vertical, 1)
                        .background(
                            // Selected badge keeps a white overlay: it is white-on-brand
                            // foreground decoration (like the chip's white text), not a
                            // palette composition — no token exists for it (G6 note).
                            Capsule(style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.2) : AtlasColor.surfaceInput)
                        )
                }
            }
            .foregroundStyle(isSelected ? AtlasColor.onBrand : .secondary)
            .padding(.horizontal, AtlasSpacing.md)
            .padding(.vertical, AtlasSpacing.xs)
            .frame(minHeight: 44, alignment: .center) // round-20: ≥44pt tap target
            .background(
                // G6 token pass: resting chips sit on the surfaceSubdued row tone
                // (was a 4% brand wash composed via opacity).
                Capsule(style: .continuous)
                    .fill(isSelected ? AtlasColor.brand : AtlasColor.surfaceSubdued)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected ? AtlasColor.brand : AtlasColor.border,
                        lineWidth: isSelected ? 0 : 1
                    )
            )
        }
        .buttonStyle(AtlasFilterChipButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityLabel: String {
        if let count {
            return "\(title), \(count) items"
        }
        return title
    }
}

/// Plain button style that preserves the chip's visual appearance on press.
private struct AtlasFilterChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AtlasMotion.fast, value: configuration.isPressed)
    }
}
