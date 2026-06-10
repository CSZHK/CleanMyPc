import SwiftUI

/// Animated circular progress indicator with CleanMyMac/Raycast style.
/// Uses `animatableData` for smooth transitions.
public struct AtlasCircularProgress: View {
    private let progress: Double
    private let tone: AtlasTone
    private let lineWidth: CGFloat
    private let showTrack: Bool
    private let icon: String?
    private let text: String?
    private let textSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        progress: Double,
        tone: AtlasTone = .neutral,
        lineWidth: CGFloat = 8,
        showTrack: Bool = true,
        icon: String? = nil,
        text: String? = nil,
        textSize: CGFloat = 16
    ) {
        self.progress = progress
        self.tone = tone
        self.lineWidth = lineWidth
        self.showTrack = showTrack
        self.icon = icon
        self.text = text
        self.textSize = textSize
    }

    public var body: some View {
        let clampedProgress = min(max(progress, 0), 1)

        ZStack {
            if showTrack {
                Circle()
                    .stroke(
                        AtlasColor.border, // G6 token pass: was Color.primary.opacity(0.06)
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
            }

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    gradientForTone,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : AtlasMotion.standard, value: progress)

            centerContent
        }
        .accessibilityValue(Text("\(Int(round(clampedProgress * 100)))%"))
    }

    @ViewBuilder
    private var centerContent: some View {
        if let icon {
            Image(systemName: icon)
                .font(.system(size: textSize, weight: .semibold, design: .monospaced))
                .foregroundStyle(tone.tint)
        } else if let text {
            Text(text)
                .font(.system(size: textSize, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
    }

    /// Conic ring gradient (spec §4.3: AngularGradient, not linear).
    ///
    /// Seam handling (G6 decision: 起止同色): the first and last stops share
    /// the same color, so the 0°/360° wrap point blends invisibly at 100% —
    /// the lighter band sits mid-arc instead of at the seam. A round line cap
    /// alone cannot hide a first≠last discontinuity once the ring closes.
    /// Defined before `rotationEffect(-90°)`, so the wrap point (and the start
    /// of the arc) sits at 12 o'clock.
    private var gradientForTone: some ShapeStyle {
        AngularGradient(
            gradient: Gradient(colors: [tone.tint, tone.tint.opacity(0.6), tone.tint]),
            center: .center
        )
    }
}

