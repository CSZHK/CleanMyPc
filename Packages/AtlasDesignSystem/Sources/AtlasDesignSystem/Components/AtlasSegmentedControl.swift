import SwiftUI

/// A unified segmented control replacing native `.pickerStyle(.segmented)`.
/// Provides capsule-shaped option buttons with brand-colored selection state.
public struct AtlasSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    public init(
        options: [Option],
        selection: Binding<Option>,
        label: @escaping (Option) -> String
    ) {
        self.options = options
        self._selection = selection
        self.label = label
    }

    public var body: some View {
        HStack(spacing: AtlasSpacing.xs) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option
                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .font(AtlasTypography.caption)
                        .foregroundStyle(isSelected ? AtlasColor.onBrand : AtlasColor.textSecondary)
                        .padding(.horizontal, AtlasSpacing.lg)
                        .padding(.vertical, AtlasSpacing.xs)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? AtlasColor.brand : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .contentTransition(.numericText())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(AtlasSpacing.xxs)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}
