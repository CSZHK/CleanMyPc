import SwiftUI

// MARK: - Data voice modifiers (spec §4.2 `.atlasData()` 一致入口)

public extension View {
    /// Data voice ② entry point: SF Mono `dataBody` + `monospacedDigit()`.
    /// Apply to every number, size, path, timestamp and count (spec §1.3) —
    /// never to narrative text.
    func atlasData() -> some View {
        font(AtlasTypography.dataBody)
            .monospacedDigit()
    }

    /// Caption-scale data voice: SF Mono `dataCaption` + `monospacedDigit()`.
    func atlasDataCaption() -> some View {
        font(AtlasTypography.dataCaption)
            .monospacedDigit()
    }
}

// MARK: - Count-up metric text

/// Metric text with the §1.5 `countUp` treatment: digits roll via
/// `contentTransition(.numericText())` whenever `text` changes. Reduce-motion
/// downgrades to an in-place swap (`.identity`) — no rolling digits.
///
/// The caller owns formatting (mono byte counts, percentages…); the view only
/// guarantees voice (mono + monospacedDigit) and motion discipline.
public struct AtlasCountUpText: View {
    let text: String
    let font: Font

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(text: String, font: Font = AtlasTypography.dataMetric) {
        self.text = text
        self.font = font
    }

    /// Pure motion decision (unit-tested): numericText rolls digits;
    /// reduce-motion swaps in place.
    public static func contentTransition(reduceMotion: Bool) -> ContentTransition {
        reduceMotion ? .identity : .numericText()
    }

    public var body: some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .contentTransition(Self.contentTransition(reduceMotion: reduceMotion))
    }
}
