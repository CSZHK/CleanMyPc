import SwiftUI

/// Shared transition definitions for consistent page transitions.
public enum AtlasTransition {
    /// Slide in from right with vertical offset.
    public static let slideIn: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    /// Combined fade + slide — the default page transition.
    public static let fadeSlide: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .move(edge: .trailing)),
        removal: .opacity
    )

    /// Scale from 0.95 → 1.0 + fade in.
    public static let scaleIn: AnyTransition = .asymmetric(
        insertion: .scale(scale: 0.95).combined(with: .opacity),
        removal: .scale(scale: 0.95).combined(with: .opacity)
    )

    /// Hero card entrance — scale from 0.9 + fade.
    public static let heroEntrance: AnyTransition = .asymmetric(
        insertion: .scale(scale: 0.9).combined(with: .opacity),
        removal: .opacity
    )
}

/// Modifier for staggered entrance animations.
public struct AtlasStaggeredEntrance: ViewModifier {
    let index: Int
    let delayPerItem: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public init(index: Int, delayPerItem: Double = 0.05) {
        self.index = index
        self.delayPerItem = delayPerItem
    }

    public func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : (appeared ? 1 : 0))
            .offset(x: reduceMotion ? 0 : (appeared ? 0 : 12))
            .animation(
                reduceMotion
                    ? nil
                    : AtlasMotion.slow.delay(Double(index) * delayPerItem),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

public extension View {
    /// Applies a staggered entrance animation based on item index.
    func atlasStaggeredEntrance(index: Int, delayPerItem: Double = 0.05) -> some View {
        modifier(AtlasStaggeredEntrance(index: index, delayPerItem: delayPerItem))
    }
}
