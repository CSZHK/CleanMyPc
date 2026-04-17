import SwiftUI

/// Large hero card — the visual focal point of each screen.
/// Features a brand gradient background, embedded circular progress ring,
/// and a large centered metric number.
public struct AtlasHeroCard<CenterContent: View, FooterContent: View>: View {
    private let tone: AtlasTone
    private let centerContent: CenterContent
    private let footerContent: FooterContent

    public init(
        tone: AtlasTone = .neutral,
        @ViewBuilder center: () -> CenterContent,
        @ViewBuilder footer: () -> FooterContent
    ) {
        self.tone = tone
        self.centerContent = center()
        self.footerContent = footer()
    }

    public var body: some View {
        VStack(spacing: AtlasSpacing.xxl) {
            centerContent
            footerContent
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AtlasSpacing.section)
        .padding(.horizontal, AtlasSpacing.xxl)
        .background(heroBackground)
        .overlay(heroBorder)
        .clipShape(RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous))
    }

    private var heroBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
                .fill(AtlasColor.card)

            RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tone.tint.opacity(0.08),
                            tone.tint.opacity(0.02),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Top-left inner glow
            RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.primary.opacity(0.06), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )

            // Brand gradient accent at bottom
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                tone.tint.opacity(0.04),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 60)
            }
        }
        .shadow(
            color: Color.black.opacity(AtlasElevation.prominent.shadowOpacity),
            radius: AtlasElevation.prominent.shadowRadius,
            y: AtlasElevation.prominent.shadowY
        )
    }

    private var heroBorder: some View {
        RoundedRectangle(cornerRadius: AtlasElevation.prominent.cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        tone.tint.opacity(0.20),
                        Color.primary.opacity(0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}

// MARK: - Convenience initializers

public extension AtlasHeroCard where CenterContent == AtlasHeroCardDefaultCenter, FooterContent == EmptyView {
    /// Creates a hero card with a circular progress ring and metric value.
    init(
        progress: Double,
        value: String,
        subtitle: String = "",
        tone: AtlasTone = .neutral,
        icon: String? = nil,
        ringSize: CGFloat = 120,
        lineWidth: CGFloat = 10
    ) {
        self.tone = tone
        self.centerContent = AtlasHeroCardDefaultCenter(
            progress: progress,
            value: value,
            subtitle: subtitle,
            tone: tone,
            icon: icon,
            ringSize: ringSize,
            lineWidth: lineWidth
        )
        self.footerContent = EmptyView()
    }
}

/// Default center content with progress ring + metric text.
public struct AtlasHeroCardDefaultCenter: View {
    let progress: Double
    let value: String
    let subtitle: String
    let tone: AtlasTone
    let icon: String?
    let ringSize: CGFloat
    let lineWidth: CGFloat

    public init(
        progress: Double,
        value: String,
        subtitle: String = "",
        tone: AtlasTone = .neutral,
        icon: String? = nil,
        ringSize: CGFloat = 120,
        lineWidth: CGFloat = 10
    ) {
        self.progress = progress
        self.value = value
        self.subtitle = subtitle
        self.tone = tone
        self.icon = icon
        self.ringSize = ringSize
        self.lineWidth = lineWidth
    }

    public var body: some View {
        VStack(spacing: AtlasSpacing.lg) {
            ZStack {
                AtlasCircularProgress(
                    progress: progress,
                    tone: tone,
                    lineWidth: lineWidth,
                    icon: icon
                )
                .frame(width: ringSize, height: ringSize)
            }

            VStack(spacing: AtlasSpacing.xs) {
                Text(value)
                    .font(AtlasTypography.heroMetric)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AtlasTypography.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
