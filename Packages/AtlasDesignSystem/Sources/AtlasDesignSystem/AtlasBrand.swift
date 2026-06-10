// MARK: - Atlas Brand Identity & Design Tokens
//
// Brand Concept: "Calm Ledger / 平静台账" (spec: Docs/design/2026-06-10-frontend-redesign-calm-ledger.md)
//   Calm shell × precise mono data × ledger trust artifacts.
//
// Visual Language:
//   - Cool work surfaces (white cards on mint-white canvas) vs warm ledger paper
//   - Three type voices: SF Pro (UI) / SF Mono (data) / New York+Songti (ledger artifacts only)
//   - Three elevation tiers, shadows softened 30% vs v2; no glassmorphism
//   - Continuous corners; motion snappy, never bouncy; reduce-motion respected
//
// Tokens are colorset-backed (AtlasColors.xcassets), generated from
// scripts/design/calm-ledger-tokens.json. Run scripts/design/contrast-check.mjs
// before changing any value.

import AppKit
import AtlasDomain
import SwiftUI

// MARK: - Color Tokens

/// Calm Ledger palette — palette values live in AtlasColors.xcassets (light+dark; borderEmphasis is the one opacity-based exception),
/// generated from scripts/design/calm-ledger-tokens.json. Do not hardcode hex here.
public enum AtlasColor {

    // ── Brand ──────────────────────────────────────────
    public static let brand = atlasColor("AtlasBrand")
    /// Hover/pressed fill variant — fills and borders only, never text (spec §1.2).
    public static let brandHover = atlasColor("AtlasBrandHover")
    /// Mint accent — non-text uses only (progress, badges, decoration).
    public static let accent = atlasColor("AtlasAccent")

    // ── Semantic (spec: safe/review/danger/info — API keeps legacy names) ──
    public static let success = atlasColor("AtlasSafe")
    public static let warning = atlasColor("AtlasReview")
    public static let danger  = atlasColor("AtlasDanger")
    public static let info    = atlasColor("AtlasInfo")
    public static let successFill = atlasColor("AtlasSafeFill")
    public static let warningFill = atlasColor("AtlasReviewFill")
    public static let dangerFill  = atlasColor("AtlasDangerFill")
    public static let infoFill    = atlasColor("AtlasInfoFill")

    // ── Surfaces ───────────────────────────────────────
    public static let canvasTop = atlasColor("AtlasCanvasTop")
    public static let canvasBottom = atlasColor("AtlasCanvasBottom")
    public static let surface = atlasColor("AtlasSurface")
    public static let surfaceSubdued = atlasColor("AtlasSurfaceSubdued")
    public static let surfaceInput = atlasColor("AtlasSurfaceInput")
    /// Legacy alias — migrate consumers to `surface` during M3, then remove.
    public static var card: Color { surface }
    public static let cardRaised = atlasColor("AtlasCardRaised")
    public static let heroSurface = atlasColor("AtlasHeroSurface")

    // ── Ledger paper (warm trust surface, spec §1.2 边界) ──
    public static let ledgerPaper = atlasColor("AtlasLedgerPaper")
    public static let ledgerInk = atlasColor("AtlasLedgerInk")
    public static let ledgerSecondary = atlasColor("AtlasLedgerSecondary")
    public static let ledgerBorder = atlasColor("AtlasLedgerBorder")
    public static let ledgerRule = atlasColor("AtlasLedgerRule")

    // ── Text ───────────────────────────────────────────
    public static let ink = atlasColor("AtlasInk")
    public static let inkData = atlasColor("AtlasInkData")
    public static let textPrimary = atlasColor("AtlasTextBody")
    public static let textSecondary = atlasColor("AtlasTextSecondary")
    /// Tertiary text — NOT directly on canvasTop (4.41:1 light, <AA); use on surface/surfaceSubdued only.
    public static let textTertiary = atlasColor("AtlasTextTertiary")

    // ── Border ─────────────────────────────────────────
    public static let border = atlasColor("AtlasSurfaceBorder")
    public static let borderEmphasis = Color.primary.opacity(0.14)

    // ── Action bar (ink-dark pinned bar) ───────────────
    public static let actionBarBg = atlasColor("AtlasActionBarBg")
    public static let actionBarText = atlasColor("AtlasActionBarText")
    public static let actionBarData = atlasColor("AtlasActionBarData")

    // ── Gradients ──────────────────────────────────────
    /// Legacy hero gradient (brand → accent). M3 migrates hero uses; keep for compatibility.
    public static var brandGradient: LinearGradient {
        LinearGradient(colors: [brand, accent], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    /// Next-action banner gradient (spec §3: brand → brandHover, top-leading → bottom-trailing).
    public static var bannerGradient: LinearGradient {
        LinearGradient(colors: [brand, brandHover], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Typography Tokens (three voices, spec §1.3)

/// ① UI voice: SF Pro (default design — rounded removed in v3)
/// ② Data voice: SF Mono — every number, size, path, timestamp
/// ③ Ledger voice: New York + Songti SC explicit cascade — ledger artifacts ONLY
public enum AtlasTypography {

    // ── ① UI voice ─────────────────────────────────────
    public static let screenTitle = Font.system(size: 28, weight: .bold)
    public static let sectionTitle = Font.system(size: 17, weight: .semibold)
    public static let label      = Font.subheadline.weight(.semibold)
    public static let rowTitle   = Font.system(size: 13, weight: .semibold)
    public static let body       = Font.system(size: 13)
    public static let bodySmall  = Font.system(size: 11)
    public static let caption    = Font.system(size: 11, weight: .semibold)
    public static let captionSmall = Font.system(size: 10)

    // ── ② Data voice (SF Mono) ─────────────────────────
    public static let dataHero   = Font.system(size: 42, weight: .semibold, design: .monospaced)
    public static let dataMetric = Font.system(size: 26, weight: .semibold, design: .monospaced)
    public static let dataBody   = Font.system(size: 12, design: .monospaced)
    public static let dataCaption = Font.system(size: 10.5, design: .monospaced)

    // ── ③ Ledger voice (serif + zh Songti cascade) ─────
    public static let ledgerTitle = ledgerFont(size: 19, weight: .bold)
    public static let ledgerNumber = ledgerFont(size: 13, weight: .bold)

    /// Serif with explicit Songti SC cascade so zh-Hans renders 宋体, not PingFang
    /// (system serif fallback for CJK is undefined across OS versions — spec §1.3).
    /// Supported weights: regular/medium/semibold/bold (others map to regular). Prefer the cached `ledgerTitle`/`ledgerNumber` tokens — this constructs a descriptor per call.
    public static func ledgerFont(size: CGFloat, weight: Font.Weight) -> Font {
        Font(ledgerNSFont(size: size, weight: weight.nsWeight))
    }

    /// NSFont variant exposed for CoreText feasibility tests.
    /// The cascade descriptor carries an explicit face so zh-Hans actually resolves
    /// Songti SC **Bold** for ≥semibold requests — a family-only cascade ignores the
    /// requested weight and always falls back to Songti Regular (M1 finding).
    public static func ledgerNSFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        var descriptor = base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor
        let face = weight.rawValue >= NSFont.Weight.semibold.rawValue ? "Bold" : "Regular"
        let songti = NSFontDescriptor(fontAttributes: [.family: "Songti SC", .face: face])
        descriptor = descriptor.addingAttributes([.cascadeList: [songti]])
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}

private extension Font.Weight {
    var nsWeight: NSFont.Weight {
        switch self {
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        default: return .regular
        }
    }
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
        case .raised:    return 0.035
        case .prominent: return 0.063
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
    /// Stage-bar content transition — 12pt slide + fade (spec §1.5).
    public static let stageTransition = Animation.snappy(duration: 0.30)
    /// Stamp-in spring for completion / recovery-point moments (spec §1.5).
    public static let stampIn = Animation.spring(response: 0.45, dampingFraction: 0.62)
    // countUp is NOT an Animation: implemented as contentTransition(.numericText()) in M2 components.
}

// MARK: - Layout Tokens

/// Shared layout constants.
public enum AtlasLayout {
    /// Maximum content reading width — prevents overly long text lines.
    public static let maxReadingWidth: CGFloat = 920
    /// Wider content ceiling for split-pane workspace screens.
    public static let maxWorkspaceWidth: CGFloat = 1200
    /// Slightly wider content ceiling for workflow-heavy screens.
    public static let maxWorkflowWidth: CGFloat = 1080
    /// DEPRECATED (Calm Ledger M3 removes): superseded by evidencePanelBreakpoint.
    /// Still consumed by AppsFeatureView / HistoryFeatureView until their M3 migration.
    public static let browserSplitThreshold: CGFloat = 860
    /// Evidence panel minimum width (spec §4.1).
    public static let evidencePanelMinWidth: CGFloat = 300
    /// Below this content width the evidence panel becomes a slide-over drawer (spec §2.4).
    public static let evidencePanelBreakpoint: CGFloat = 880
    /// Below this content width the action bar collapses to primary + shield badge (spec §2.4).
    public static let actionBarCompactBreakpoint: CGFloat = 740
    /// Keep enough readable width for text before detail-row accessories stay inline.
    public static let detailRowMinimumTextWidth: CGFloat = 240
    /// Standard 3-column metric grid definition.
    public static let metricColumns: [GridItem] = [
        GridItem(.flexible(minimum: 180), spacing: AtlasSpacing.lg),
        GridItem(.flexible(minimum: 180), spacing: AtlasSpacing.lg),
        GridItem(.flexible(minimum: 180), spacing: AtlasSpacing.lg),
    ]
    /// 2-column grid for wider cards.
    public static let wideColumns: [GridItem] = [
        GridItem(.flexible(minimum: 220), spacing: AtlasSpacing.lg),
        GridItem(.flexible(minimum: 220), spacing: AtlasSpacing.lg),
    ]
    /// Sidebar width range.
    public static let sidebarMinWidth: CGFloat = 180
    public static let sidebarIdealWidth: CGFloat = 220
    /// Sidebar icon container size (pill-style like System Settings).
    public static let sidebarIconSize: CGFloat = 32

    /// Returns an adaptive column layout based on available width.
    /// - 3 columns for widths >= 640
    /// - 2 columns for widths >= 420
    /// - 1 column for narrower widths
    public static func adaptiveMetricColumns(for width: CGFloat) -> [GridItem] {
        let spacing = AtlasSpacing.lg
        switch width {
        case 640...:
            return [
                GridItem(.flexible(minimum: 180), spacing: spacing),
                GridItem(.flexible(minimum: 180), spacing: spacing),
                GridItem(.flexible(minimum: 180), spacing: spacing),
            ]
        case 420...:
            return [
                GridItem(.flexible(minimum: 180), spacing: spacing),
                GridItem(.flexible(minimum: 180), spacing: spacing),
            ]
        default:
            return [
                GridItem(.flexible(minimum: 180), spacing: spacing),
            ]
        }
    }
}

// MARK: - Content Width Environment Key

private struct AtlasContentWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = 920
}

public extension EnvironmentValues {
    /// The actual content width injected by `AtlasScreen`.
    var atlasContentWidth: CGFloat {
        get { self[AtlasContentWidthKey.self] }
        set { self[AtlasContentWidthKey.self] = newValue }
    }
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
/// Multi-layered effect: border transition, background brightness, and gentle scale.
public struct AtlasHoverModifier: ViewModifier {
    @State private var isHovered = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.012 : 1.0)
            .brightness(isHovered ? 0.02 : 0)
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

/// Card-level hover effect with border emphasis and background tint.
public struct AtlasCardHoverModifier: ViewModifier {
    @State private var isHovered = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.012 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: AtlasRadius.xl, style: .continuous)
                    .strokeBorder(
                        isHovered ? AtlasColor.borderEmphasis : AtlasColor.border,
                        lineWidth: 1
                    )
                    .animation(AtlasMotion.fast, value: isHovered)
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.06 : 0),
                radius: isHovered ? 20 : 0,
                y: isHovered ? 10 : 0
            )
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

    /// Adds card-level hover with border emphasis transition.
    func atlasCardHover() -> some View {
        modifier(AtlasCardHoverModifier())
    }
}

// MARK: - Button Styles

/// Primary filled button — the single most important action on screen.
/// Features glow shadow, press microinteraction, and motion accessibility.
public struct AtlasPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .contentShape(Capsule(style: .continuous))
            .animation(reduceMotion ? nil : AtlasMotion.fast, value: configuration.isPressed)
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
            .contentShape(Capsule(style: .continuous))
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
            .contentShape(Capsule(style: .continuous))
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
