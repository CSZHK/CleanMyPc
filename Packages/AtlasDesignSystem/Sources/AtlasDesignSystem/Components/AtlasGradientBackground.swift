import SwiftUI

/// Screen-level gradient background with optional hero area tint.
/// Used as the canvas behind content areas that need a richer visual depth.
public struct AtlasGradientBackground: View {
    private let tone: AtlasTone
    private let intensity: Double

    public init(tone: AtlasTone = .neutral, intensity: Double = 0.06) {
        self.tone = tone
        self.intensity = intensity
    }

    public var body: some View {
        ZStack {
            // Base canvas gradient
            LinearGradient(
                colors: [AtlasColor.canvasTop, AtlasColor.canvasBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            // Tone-tinted radial glow at top
            RadialGradient(
                colors: [
                    tone.tint.opacity(intensity),
                    Color.clear,
                ],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
        }
    }
}
