import SwiftUI

/// Placement options for the tooltip relative to its anchor view.
public enum AtlasTooltipPlacement {
    case top, bottom, leading, trailing
}

/// A hover-activated tooltip modifier that shows a small rounded rectangle with text.
/// Includes an arrow/triangle pointing toward the anchor view.
public struct AtlasTooltipModifier: ViewModifier {
    let text: String
    let placement: AtlasTooltipPlacement

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(text: String, placement: AtlasTooltipPlacement) {
        self.text = text
        self.placement = placement
    }

    public func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if reduceMotion {
                    isHovered = hovering
                } else {
                    withAnimation(AtlasMotion.fast) {
                        isHovered = hovering
                    }
                }
            }
            .overlay(alignment: alignment) {
                if isHovered {
                    tooltipContent
                        .transition(tooltipTransition)
                }
            }
    }

    private var alignment: Alignment {
        switch placement {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    private var tooltipTransition: AnyTransition {
        switch placement {
        case .top:
            return .opacity.combined(with: .move(edge: .bottom))
        case .bottom:
            return .opacity.combined(with: .move(edge: .top))
        case .leading:
            return .opacity.combined(with: .move(edge: .trailing))
        case .trailing:
            return .opacity.combined(with: .move(edge: .leading))
        }
    }

    private var tooltipContent: some View {
        VStack(spacing: 0) {
            if placement == .bottom {
                arrow
            }

            HStack(spacing: 0) {
                if placement == .trailing {
                    arrowHorizontal
                }

                Text(text)
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, AtlasSpacing.md)
                    .padding(.vertical, AtlasSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                            .fill(AtlasColor.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)

                if placement == .leading {
                    arrowHorizontal
                }
            }

            if placement == .top {
                arrow
            }
        }
        .offset(tooltipOffset)
    }

    private var tooltipOffset: CGSize {
        switch placement {
        case .top: return CGSize(width: 0, height: -AtlasSpacing.sm)
        case .bottom: return CGSize(width: 0, height: AtlasSpacing.sm)
        case .leading: return CGSize(width: -AtlasSpacing.sm, height: 0)
        case .trailing: return CGSize(width: AtlasSpacing.sm, height: 0)
        }
    }

    /// Small downward-pointing triangle for top placement, upward for bottom.
    private var arrow: some View {
        let flip = placement == .top
        return Triangle()
            .fill(AtlasColor.card)
            .frame(width: 8, height: 5)
            .rotationEffect(.degrees(flip ? 0 : 180))
    }

    /// Horizontal arrow for leading/trailing placement.
    private var arrowHorizontal: some View {
        let flip = placement == .leading
        return Triangle()
            .fill(AtlasColor.card)
            .frame(width: 5, height: 8)
            .rotationEffect(.degrees(flip ? 90 : -90))
    }
}

/// A simple triangle shape for tooltip arrows.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

public extension View {
    /// Shows a tooltip on hover with the given text and placement.
    func atlasTooltip(_ text: String, placement: AtlasTooltipPlacement = .top) -> some View {
        modifier(AtlasTooltipModifier(text: text, placement: placement))
    }
}
