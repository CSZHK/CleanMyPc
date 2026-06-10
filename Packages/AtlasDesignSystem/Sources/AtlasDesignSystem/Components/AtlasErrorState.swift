import SwiftUI

/// Code-less error state (spec §4.2, 评审裁定: 协议冻结、无错误码分类法):
/// `danger`-tinted `exclamationmark.octagon.fill` on a `dangerFill` soft
/// ground, with title + message mapped from `executionIssue`/`planIssue`
/// strings, an optional suggestion and an optional recovery action.
///
/// Layouts:
/// - `.block` — centered block, mirroring the `AtlasEmptyState` composition;
///   for whole-pane failures.
/// - `.inlineRow` — leading compact row for execution-list failure rows.
public struct AtlasErrorState: View {
    public enum Layout: Equatable, Sendable {
        case block
        case inlineRow

        /// Block centers its stack; the inline row leads.
        public var isCentered: Bool { self == .block }

        /// Icon point size per layout (28 mirrors AtlasEmptyState, 14 mirrors
        /// list-row glyphs). Icon sizing is geometry, not a type voice.
        public var iconPointSize: CGFloat { self == .block ? 28 : 14 }
    }

    private let title: String
    private let message: String
    private let suggestion: String?
    private let actionTitle: String?
    private let onAction: (() -> Void)?
    private let layout: Layout

    public init(
        title: String,
        message: String,
        suggestion: String? = nil,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil,
        layout: Layout = .block
    ) {
        self.title = title
        self.message = message
        self.suggestion = suggestion
        self.actionTitle = actionTitle
        self.onAction = onAction
        self.layout = layout
    }

    /// The action button renders only when both title and handler exist
    /// (fail-closed — never an inert or unlabeled button).
    public static func showsAction(title: String?, action: (() -> Void)?) -> Bool {
        title != nil && action != nil
    }

    public var body: some View {
        switch layout {
        case .block:
            blockBody
        case .inlineRow:
            inlineRowBody
        }
    }

    // MARK: Block (centered, AtlasEmptyState composition)

    private var blockBody: some View {
        VStack(spacing: AtlasSpacing.lg) {
            icon

            VStack(spacing: AtlasSpacing.xs) {
                Text(title)
                    .font(AtlasTypography.rowTitle)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let suggestion {
                    Text(suggestion)
                        .font(AtlasTypography.bodySmall)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if Self.showsAction(title: actionTitle, action: onAction),
               let actionTitle, let onAction {
                Button(actionTitle, action: onAction)
                    .buttonStyle(.atlasSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AtlasSpacing.section)
        .background(ground(cornerRadius: AtlasRadius.xl))
        .overlay(border(cornerRadius: AtlasRadius.xl))
        .accessibilityElement(children: onAction != nil ? .contain : .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(accessibilityValueText))
    }

    // MARK: Inline row (compact, execution-list failure row)

    private var inlineRowBody: some View {
        HStack(alignment: .top, spacing: AtlasSpacing.md) {
            icon

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(title)
                    .font(AtlasTypography.rowTitle)

                Text(message)
                    .font(AtlasTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let suggestion {
                    Text(suggestion)
                        .font(AtlasTypography.captionSmall)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: AtlasSpacing.sm)

            if Self.showsAction(title: actionTitle, action: onAction),
               let actionTitle, let onAction {
                Button(actionTitle, action: onAction)
                    .buttonStyle(.atlasGhost)
            }
        }
        .padding(AtlasSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ground(cornerRadius: AtlasRadius.sm))
        .overlay(border(cornerRadius: AtlasRadius.sm))
        .accessibilityElement(children: onAction != nil ? .contain : .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(accessibilityValueText))
    }

    // MARK: Shared pieces

    private var icon: some View {
        Image(systemName: "exclamationmark.octagon.fill")
            .font(.system(size: layout.iconPointSize, weight: .semibold))
            .foregroundStyle(AtlasColor.danger)
            .accessibilityHidden(true)
    }

    private func ground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AtlasColor.dangerFill)
    }

    private func border(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(AtlasTone.danger.border, lineWidth: 1)
    }

    private var accessibilityValueText: String {
        guard let suggestion else { return message }
        return "\(message). \(suggestion)"
    }
}
