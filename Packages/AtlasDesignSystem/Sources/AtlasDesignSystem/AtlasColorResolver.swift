import AppKit
import SwiftUI

/// Resolves a design-token color by colorset name.
/// Order: compiled asset catalog (xcodebuild/release) → generated fallback table
/// (SwiftPM CLI runs, where actool never compiled the catalog).
/// See AtlasColorFallback.swift (generated) and scripts/design/generate-colorsets.mjs.
func atlasColor(_ name: String) -> Color {
    if NSColor(named: name, bundle: .module) != nil {
        return Color(name, bundle: .module)
    }
    guard let entry = AtlasColorFallback.table[name] else {
        // Unknown token: keep catalog semantics (renders clear + logs once in debug).
        return Color(name, bundle: .module)
    }
    let dynamic = NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let c = isDark ? entry.dark : entry.light
        return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
    }
    return Color(nsColor: dynamic)
}
