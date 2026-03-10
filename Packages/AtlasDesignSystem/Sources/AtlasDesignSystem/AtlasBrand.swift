// MARK: - Atlas Brand Identity & Design Tokens
//
// Brand Concept: "Calm Authority"
// Atlas — like a cartographer mapping your system's terrain.
// Precise, trustworthy, and quietly confident.
//
// Visual Language:
//   - Cool indigo base with warm amber highlights
//   - Generous whitespace, constrained reading width
//   - Three elevation tiers for clear visual hierarchy
//   - Rounded, organic shapes (continuous corners)
//   - Subtle glassmorphism on cards
//   - Motion: snappy but never bouncy
//
// Color Story:
//   - Indigo (Primary): trust, depth, tech-premium
//   - Amber (Accent): warmth, discovery, the gold on a map
//   - Semantic tones keep green/orange/red for system states

import AppKit
import SwiftUI

// MARK: - Color Tokens

/// Atlas brand color palette — all colors adapt to light/dark automatically.
public enum AtlasColor {

    // ── Brand ──────────────────────────────────────────

    /// Primary brand teal — used for key actions and active states.
    public static let brand = Color("AtlasBrand", bundle: .module)

    /// Fresh mint accent — used for highlights, badges, and discovery cues.
    public static let accent = Color("AtlasAccent", bundle: .module)

    // ── Semantic ───────────────────────────────────────

    public static let success = Color(nsColor: .systemGreen)
    public static let warning = Color(nsColor: .systemOrange)
    public static let danger  = Color(nsColor: .systemRed)
    public static let info    = Color(nsColor: .systemBlue)

    // ── Surfaces ───────────────────────────────────────

    /// App canvas — top of gradient.
    public static let canvasTop = Color(nsColor: .windowBackgroundColor)
    /// App canvas — bottom of gradient.
    public static let canvasBottom = Color(nsColor: .underPageBackgroundColor)

    /// Card surface that adapts to light/dark.
    public static var card: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    /// Raised card overlay — glassmorphic tint.
    public static var cardRaised: Color {
        if NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            return Color.white.opacity(0.06)
        } else {
            return Color.white.opacity(0.65)
        }
    }

    // ── Text ───────────────────────────────────────────

    /// Primary text on canvas.
    public static let textPrimary = Color.primary
    /// Secondary / muted text.
    public static let textSecondary = Color.secondary
    /// Tertiary text — footnotes, timestamps.
    public static let textTertiary = Color.secondary.opacity(0.6)

    // ── Border ─────────────────────────────────────────

    /// Subtle card border.
    public static let border = Color.primary.opacity(0.08)
    /// Emphasis border — used on prominent cards and focus states.
    public static let borderEmphasis = Color.primary.opacity(0.14)
}

// MARK: - Typography Tokens

/// Centralized type scale. All fonts use `.rounded` design for brand warmth.
public enum AtlasTypography {

    // ── Display ────────────────────────────────────────

    /// Screen title — the large bold header on each feature screen.
    public static let screenTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    /// Hero metric — the single most important number on a dashboard.
    public static let heroMetric  = Font.system(size: 40, weight: .bold, design: .rounded)

    // ── Heading ────────────────────────────────────────

    /// Section heading inside a card or screen area.
    public static let sectionTitle = Font.title3.weight(.semibold)
    /// Card metric value — secondary metrics in grids.
    public static let cardMetric   = Font.system(size: 28, weight: .bold, design: .rounded)

    // ── Label ──────────────────────────────────────────

    /// Semibold label for metric titles, sidebar primary text, etc.
    public static let label      = Font.subheadline.weight(.semibold)
    /// Headline weight for row titles.
    public static let rowTitle   = Font.headline
    /// Standard body text.
    public static let body       = Font.subheadline
    /// Small secondary body text.
    public static let bodySmall  = Font.caption

    // ── Caption ────────────────────────────────────────

    /// Chip labels, footnotes, overlines.
    public static let caption    = Font.caption.weight(.semibold)
    /// Extra-small legal and timestamp text.
    public static let captionSmall = Font.caption2
}

// MARK: - Spacing Tokens

/// Consistent spacing scale based on a 4pt grid.
public enum AtlasSpacing {
    /// 4pt — minimal inner padding.
    public static let xxs: CGFloat = 4
    /// 6pt — tight insets, chip padding.
    public static let xs: CGFloat = 6
    /// 8pt — compact row spacing.
    public static let sm: CGFloat = 8
    /// 12pt — default inner element gap.
    public static let md: CGFloat = 12
    /// 16pt — card inner padding, section gaps.
    public static let lg: CGFloat = 16
    /// 20pt — generous card padding.
    public static let xl: CGFloat = 20
    /// 24pt — screen-level vertical rhythm.
    public static let xxl: CGFloat = 24
    /// 28pt — screen horizontal margin.
    public static let screenH: CGFloat = 28
    /// 32pt — large section separation.
    public static let section: CGFloat = 32
}

// MARK: - Radius Tokens

/// Corner radius scale — all use `.continuous` style.
public enum AtlasRadius {
    /// 8pt — small elements: chips, tags.
    public static let sm: CGFloat = 8
    /// 12pt — inline cards, callouts.
    public static let md: CGFloat = 12
    /// 16pt — detail rows, compact cards.
    public static let lg: CGFloat = 16
    /// 20pt — standard cards and info cards.
    public static let xl: CGFloat = 20
    /// 24pt — prominent/hero cards.
    public static let xxl: CGFloat = 24
}

// MARK: - Elevation Tokens

/// Three-tier elevation system for visual hierarchy.
public enum AtlasElevation: Sendable {
    /// Flat — no shadow, subtle border only. For nested/secondary content.
    case flat
    /// Raised — default card level. Gentle lift.
    case raised
    /// Prominent — hero cards, primary action areas. Strong presence.
    case prominent

    public var shadowRadius: CGFloat {
        switch self {
        case .flat:      return 0
        case .raised:    return 18
        case .prominent: return 28
        }
    }

    public var shadowY: CGFloat {
        switch self {
        case .flat:      return 0
        case .raised:    return 10
        case .prominent: return 16
        }
    }

    public var shadowOpacity: Double {
        switch self {
        case .flat:      return 0
        case .raised:    return 0.05
        case .prominent: return 0.09
        }
    }

    public var cornerRadius: CGFloat {
        switch self {
        case .flat:      return AtlasRadius.lg
        case .raised:    return AtlasRadius.xl
        case .prominent: return AtlasRadius.xxl
        }
    }

    public var borderOpacity: Double {
        switch self {
        case .flat:      return 0.04
        case .raised:    return 0.08
        case .prominent: return 0.12
        }
    }
}

// MARK: - Animation Tokens

/// Standardized animation curves and durations.
public enum AtlasMotion {
    /// Fast micro-interaction — hover, press, chip.
    public static let fast = Animation.snappy(duration: 0.15)
    /// Standard transition — selection, toggle, card state.
    public static let standard = Animation.snappy(duration: 0.22)
    /// Slow emphasis — page transitions, hero reveals.
    public static let slow = Animation.snappy(duration: 0.35)
    /// Spring for playful feedback — completion, celebration.
    public static let spring = Animation.spring(response: 0.45, dampingFraction: 0.7)
}

// MARK: - Layout Tokens

/// Shared layout constants.
public enum AtlasLayout {
    /// Maximum content reading width — prevents overly long text lines.
    public static let maxReadingWidth: CGFloat = 960
    /// Standard 3-column metric grid definition.
    public static let metricColumns: [GridItem] = [
        GridItem(.flexible(minimum: 220), spacing: AtlasSpacing.lg),
        GridItem(.flexible(minimum: 220), spacing: AtlasSpacing.lg),
        GridItem(.flexible(minimum: 220), spacing: AtlasSpacing.lg),
    ]
    /// 2-column grid for wider cards.
    public static let wideColumns: [GridItem] = [
        GridItem(.flexible(minimum: 300), spacing: AtlasSpacing.lg),
        GridItem(.flexible(minimum: 300), spacing: AtlasSpacing.lg),
    ]
    /// Sidebar width range.
    public static let sidebarMinWidth: CGFloat = 230
    public static let sidebarIdealWidth: CGFloat = 260
    /// Sidebar icon container size (pill-style like System Settings).
    public static let sidebarIconSize: CGFloat = 32
}

// MARK: - Icon Tokens

/// Named SF Symbol references for consistent iconography.
public enum AtlasIcon {
    // ── Navigation ─────────────────────────────────────
    public static let overview    = "gauge.with.dots.needle.33percent"
    public static let smartClean  = "sparkles"
    public static let apps        = "square.grid.2x2"
    public static let history     = "clock.arrow.circlepath"
    public static let permissions = "lock.shield"
    public static let settings    = "gearshape"
    public static let storage     = "internaldrive"

    // ── Toolbar ────────────────────────────────────────
    public static let taskCenter  = "list.bullet.rectangle.portrait"
    public static let refresh     = "arrow.clockwise"

    // ── Status ─────────────────────────────────────────
    public static let success     = "checkmark.circle.fill"
    public static let warning     = "exclamationmark.triangle.fill"
    public static let danger      = "xmark.octagon.fill"
    public static let info        = "info.circle.fill"
    public static let neutral     = "circle.fill"

    // ── Actions ────────────────────────────────────────
    public static let scan        = "magnifyingglass"
    public static let clean       = "trash"
    public static let restore     = "arrow.uturn.backward"
    public static let preview     = "eye"
    public static let grant       = "hand.raised"
}

// MARK: - Brand Helpers

/// Convenience for building elevation-aware card backgrounds.
public func atlasCardBackground(tone: AtlasTone = .neutral, elevation: AtlasElevation = .raised) -> some View {
    let cr = elevation.cornerRadius
    return ZStack {
        RoundedRectangle(cornerRadius: cr, style: .continuous)
            .fill(AtlasColor.card)
            .background(
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .fill(tone.softFill.opacity(0.55))
            )
            .shadow(
                color: Color.black.opacity(elevation.shadowOpacity),
                radius: elevation.shadowRadius,
                x: 0,
                y: elevation.shadowY
            )

        // Prominent cards get a subtle top-left inner glow
        if elevation == .prominent {
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
        }
    }
}

/// Convenience for building elevation-aware card borders.
public func atlasCardBorder(tone: AtlasTone = .neutral, elevation: AtlasElevation = .raised) -> some View {
    RoundedRectangle(cornerRadius: elevation.cornerRadius, style: .continuous)
        .strokeBorder(
            LinearGradient(
                colors: [
                    tone.border.opacity(elevation.borderOpacity / 0.08),
                    Color.primary.opacity(elevation.borderOpacity),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: elevation == .prominent ? 1.5 : 1
        )
}

// MARK: - View Modifiers

/// Applies Atlas card styling (background + border + elevation) to any view.
public struct AtlasCardModifier: ViewModifier {
    let tone: AtlasTone
    let elevation: AtlasElevation
    let padding: CGFloat

    public init(tone: AtlasTone = .neutral, elevation: AtlasElevation = .raised, padding: CGFloat = AtlasSpacing.xl) {
        self.tone = tone
        self.elevation = elevation
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(atlasCardBackground(tone: tone, elevation: elevation))
            .overlay(atlasCardBorder(tone: tone, elevation: elevation))
    }
}

public extension View {
    /// Wraps the view in an Atlas-styled card with the given tone and elevation.
    func atlasCard(tone: AtlasTone = .neutral, elevation: AtlasElevation = .raised, padding: CGFloat = AtlasSpacing.xl) -> some View {
        modifier(AtlasCardModifier(tone: tone, elevation: elevation, padding: padding))
    }
}

/// Hover + press microinteraction for interactive cards.
public struct AtlasHoverModifier: ViewModifier {
    @State private var isHovered = false

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.008 : 1.0)
            .shadow(
                color: Color.black.opacity(isHovered ? 0.08 : 0),
                radius: isHovered ? 24 : 0,
                y: isHovered ? 12 : 0
            )
            .animation(AtlasMotion.fast, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public extension View {
    /// Adds subtle hover lift effect to the view.
    func atlasHover() -> some View {
        modifier(AtlasHoverModifier())
    }
}

// MARK: - Button Styles

/// Primary filled button — the single most important action on screen.
public struct AtlasPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AtlasTypography.label)
            .foregroundStyle(.white)
            .padding(.horizontal, AtlasSpacing.xxl)
            .padding(.vertical, AtlasSpacing.md)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? AtlasColor.brand : AtlasColor.brand.opacity(0.4))
            )
            .shadow(
                color: AtlasColor.brand.opacity(configuration.isPressed ? 0 : 0.25),
                radius: configuration.isPressed ? 4 : 12,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AtlasMotion.fast, value: configuration.isPressed)
    }
}

/// Secondary outlined button — supporting actions.
public struct AtlasSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AtlasTypography.label)
            .foregroundStyle(AtlasColor.brand)
            .padding(.horizontal, AtlasSpacing.xxl)
            .padding(.vertical, AtlasSpacing.md)
            .background(
                Capsule(style: .continuous)
                    .fill(AtlasColor.brand.opacity(configuration.isPressed ? 0.08 : 0.04))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AtlasColor.brand.opacity(0.3), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AtlasMotion.fast, value: configuration.isPressed)
    }
}

/// Ghost/tertiary button — minimal weight, for infrequent actions.
public struct AtlasGhostButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AtlasTypography.label)
            .foregroundStyle(AtlasColor.brand)
            .padding(.horizontal, AtlasSpacing.lg)
            .padding(.vertical, AtlasSpacing.sm)
            .background(
                Capsule(style: .continuous)
                    .fill(configuration.isPressed ? AtlasColor.brand.opacity(0.06) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(AtlasMotion.fast, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == AtlasPrimaryButtonStyle {
    static var atlasPrimary: AtlasPrimaryButtonStyle { AtlasPrimaryButtonStyle() }
}

public extension ButtonStyle where Self == AtlasSecondaryButtonStyle {
    static var atlasSecondary: AtlasSecondaryButtonStyle { AtlasSecondaryButtonStyle() }
}

public extension ButtonStyle where Self == AtlasGhostButtonStyle {
    static var atlasGhost: AtlasGhostButtonStyle { AtlasGhostButtonStyle() }
}
