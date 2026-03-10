import SwiftUI

@main
struct XCUITestReproApp: App {
    var body: some Scene {
        WindowGroup("XCUITestRepro") {
            VStack(spacing: 16) {
                Text("Hello UI Test")
                    .accessibilityIdentifier("repro.hello")
                Button("Tap Me") {}
                    .accessibilityIdentifier("repro.tap")
            }
            .frame(width: 480, height: 320)
        }
    }
}
