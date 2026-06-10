import AtlasDomain
import SwiftUI

// MARK: - Toast Item Model

/// A data model representing a single toast notification.
///
/// G6 extensions (spec §4.3 「已入账 №N · 撤销」): an optional inline action
/// (`actionTitle` + `onAction`, e.g. undo) and an optional whole-toast tap
/// (`onTap`, e.g. jump to the ledger entry — 回链红线 §1.6). All default to
/// nil, so existing call sites compile unchanged. Closures are
/// `@MainActor @Sendable` so MainActor callers can capture their models.
///
/// Equality intentionally ignores the closures (function values are not
/// equatable); identity is carried by `id` + visible content.
public struct AtlasToastItem: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var message: String
    public var tone: AtlasTone
    public var systemImage: String?
    public var actionTitle: String?
    public var onAction: (@MainActor @Sendable () -> Void)?
    public var onTap: (@MainActor @Sendable () -> Void)?

    public init(
        id: UUID = UUID(),
        message: String,
        tone: AtlasTone = .neutral,
        systemImage: String? = nil,
        actionTitle: String? = nil,
        onAction: (@MainActor @Sendable () -> Void)? = nil,
        onTap: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.id = id
        self.message = message
        self.tone = tone
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.onAction = onAction
        self.onTap = onTap
    }

    public static func == (lhs: AtlasToastItem, rhs: AtlasToastItem) -> Bool {
        lhs.id == rhs.id
            && lhs.message == rhs.message
            && lhs.tone == rhs.tone
            && lhs.systemImage == rhs.systemImage
            && lhs.actionTitle == rhs.actionTitle
    }

    /// The inline action renders only when both title and handler exist.
    public static func showsAction(title: String?, action: (@MainActor @Sendable () -> Void)?) -> Bool {
        title != nil && action != nil
    }
}

// MARK: - Toast Container

/// Displays a stack of toast notifications, bottom-trailing aligned.
/// Append an `AtlasToastItem` to the bound `items` array to present a toast.
/// Toasts auto-dismiss after `autoDismissInterval` seconds (default 3).
public struct AtlasToastContainer: View {
    @Binding var items: [AtlasToastItem]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Time in seconds before each toast auto-dismisses.
    /// Set to `nil` to disable auto-dismiss.
    public var autoDismissInterval: Double?

    public init(
        items: Binding<[AtlasToastItem]>,
        autoDismissInterval: Double? = 3.0
    ) {
        self._items = items
        self.autoDismissInterval = autoDismissInterval
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
            ForEach(items) { item in
                AtlasToastRow(
                    item: item,
                    autoDismissInterval: autoDismissInterval,
                    onDismiss: {
                        withAnimation(reduceMotion ? nil : AtlasMotion.standard) {
                            items.removeAll { $0.id == item.id }
                        }
                    }
                )
                .transition(toastTransition)
            }
        }
        .animation(reduceMotion ? nil : AtlasMotion.standard, value: items)
    }

    private var toastTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
    }
}

// MARK: - Single Toast Row

private struct AtlasToastRow: View {
    let item: AtlasToastItem
    let autoDismissInterval: Double?
    let onDismiss: () -> Void

    @State private var isHovered = false

    private static let fixedHeight: CGFloat = 52

    var body: some View {
        HStack(spacing: AtlasSpacing.md) {
            // Tone icon
            Image(systemName: item.systemImage ?? item.tone.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(item.tone.tint)
                .frame(width: 20)
                .accessibilityHidden(true)

            // Message text
            Text(item.message)
                .font(AtlasTypography.body)
                .foregroundStyle(AtlasColor.textPrimary)
                .lineLimit(2)
                .layoutPriority(1)

            Spacer(minLength: AtlasSpacing.sm)

            // Inline action (e.g. 撤销) — does NOT auto-dismiss; the caller
            // owns the `items` binding and removes the toast if appropriate.
            if AtlasToastItem.showsAction(title: item.actionTitle, action: item.onAction),
               let actionTitle = item.actionTitle, let onAction = item.onAction {
                Button(actionTitle) {
                    onAction()
                }
                .buttonStyle(.plain)
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.brand)
                .accessibilityLabel(actionTitle)
            }

            // Manual close button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AtlasColor.textTertiary)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AtlasL10n.string("ds.toast.dismiss"))
        }
        .padding(.horizontal, AtlasSpacing.lg)
        .frame(height: Self.fixedHeight)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.card)
                .background(
                    RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                        .fill(item.tone.softFill)
                )
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.12 : 0.06),
                    radius: isHovered ? 16 : 8,
                    x: 0,
                    y: isHovered ? 6 : 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(item.tone.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous))
        .onTapGesture {
            // Whole-toast tap (回链红线 §1.6: 「已入账 №N」 must reach the ledger).
            // Inner buttons win hit-testing over this gesture.
            item.onTap?()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            scheduleAutoDismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.tone.accessibilityLabel): \(item.message)")
        .accessibilityHint(item.onTap != nil ? AtlasL10n.string("ds.toast.open") : "")
        .accessibilityAddTraits(item.onTap != nil ? .isButton : [])
    }

    private func scheduleAutoDismiss() {
        guard let interval = autoDismissInterval, interval > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            onDismiss()
        }
    }
}

// MARK: - AtlasTone Accessibility Convenience

extension AtlasTone {
    /// Human-readable label for accessibility announcements (localized via
    /// `ds.tone.*` — was hardcoded English before the G6 pass).
    var accessibilityLabel: String {
        switch self {
        case .neutral: return AtlasL10n.string("ds.tone.info")
        case .success: return AtlasL10n.string("ds.tone.success")
        case .warning: return AtlasL10n.string("ds.tone.warning")
        case .danger:  return AtlasL10n.string("ds.tone.danger")
        }
    }
}
