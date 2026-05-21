import SwiftUI

/// A horizontal banner with message, undo action, and dismiss control.
/// Appears after a destructive or reversible operation (e.g. plan execution).
public struct AtlasUndoBanner: View {
    private let message: String
    private let actionTitle: String
    private let tone: AtlasTone
    private let onUndo: () -> Void
    private let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        message: String,
        actionTitle: String = "Undo",
        tone: AtlasTone = .success,
        onUndo: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.actionTitle = actionTitle
        self.tone = tone
        self.onUndo = onUndo
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: AtlasSpacing.md) {
            Image(systemName: tone.symbol)
                .font(AtlasTypography.caption)
                .foregroundStyle(tone.tint)
                .accessibilityHidden(true)

            Text(message)
                .font(AtlasTypography.body)
                .foregroundStyle(.primary)
                .layoutPriority(1)

            Spacer(minLength: AtlasSpacing.sm)

            Button(action: onUndo) {
                Text(actionTitle)
            }
            .buttonStyle(.atlasSecondary)
            .accessibilityHint("Revert the last operation")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, AtlasSpacing.lg)
        .padding(.vertical, AtlasSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .fill(tone.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .strokeBorder(tone.border, lineWidth: 1)
        )
    }
}
