import SwiftUI

// MARK: - Skeleton Components

/// A skeleton placeholder that mimics the shape of an `AtlasInfoCard`.
/// Displays a rounded rectangle with a shimmer animation to indicate loading.
public struct AtlasSkeletonCard: View {
    private let width: CGFloat?
    private let height: CGFloat

    public init(width: CGFloat? = nil, height: CGFloat = 120) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
            .fill(AtlasColor.border)
            .frame(width: width, height: height)
            .skeletonShimmer()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Loading"))
    }
}

/// A skeleton placeholder that mimics the shape of a detail row (icon + text).
/// Displays a circle placeholder alongside two rectangles of varying width.
public struct AtlasSkeletonRow: View {
    public init() {}

    public var body: some View {
        HStack(spacing: AtlasSpacing.lg) {
            // Icon placeholder
            Circle()
                .fill(AtlasColor.border)
                .frame(width: 32, height: 32)
                .skeletonShimmer()

            // Text placeholders
            VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                RoundedRectangle(cornerRadius: AtlasSpacing.xxs, style: .continuous)
                    .fill(AtlasColor.border)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                    .skeletonShimmer()

                RoundedRectangle(cornerRadius: AtlasSpacing.xxs, style: .continuous)
                    .fill(AtlasColor.border)
                    .frame(height: 12)
                    .frame(maxWidth: 200)
                    .skeletonShimmer()
            }
        }
        .padding(AtlasSpacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading"))
    }
}

// MARK: - Shimmer Modifier

/// A private modifier that overlays a sweeping linear gradient highlight
/// to create a shimmer/pulse effect on skeleton placeholders.
/// Respects `accessibilityReduceMotion` by disabling animation.
private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    // G6 token review: the white sweep stays — it is a lighting
                    // EFFECT over the `border`-token placeholder (appearance-
                    // agnostic highlight), not a composed palette color.
                    let highlight = Color.white.opacity(0.15)
                    let base = Color.clear

                    LinearGradient(
                        stops: [
                            .init(color: base, location: 0.0),
                            .init(color: base, location: max(phase - 0.15, 0.0)),
                            .init(color: highlight, location: phase),
                            .init(color: base, location: min(phase + 0.15, 1.0)),
                            .init(color: base, location: 1.0),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous))
                }
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 2.0
                }
            }
    }
}

// MARK: - View Extension

public extension View {
    /// Applies a shimmer animation overlay to skeleton placeholders.
    /// The animation is automatically disabled when the user has
    /// enabled "Reduce Motion" in accessibility settings.
    func skeletonShimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
