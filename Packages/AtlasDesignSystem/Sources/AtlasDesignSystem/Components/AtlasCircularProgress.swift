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
                        Color.primary.opacity(0.06),
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
                .font(.system(size: textSize, weight: .semibold, design: .rounded))
                .foregroundStyle(tone.tint)
        } else if let text {
            Text(text)
                .font(.system(size: textSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
    }

    private var gradientForTone: some ShapeStyle {
        LinearGradient(
            colors: [tone.tint, tone.tint.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

