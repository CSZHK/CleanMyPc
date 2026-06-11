import AtlasDomain
import SwiftUI

@main
struct AtlasApp: App {
    @StateObject private var model = AtlasAppModel()

    private let readmeAssetExportDirectory = Self.resolveReadmeAssetExportDirectory()

    var body: some Scene {
        WindowGroup(readmeAssetExportDirectory == nil ? AtlasL10n.string("app.name") : "Atlas README Asset Export") {
            if let readmeAssetExportDirectory {
                ReadmeAssetExportView(outputDirectory: readmeAssetExportDirectory)
                    .frame(minWidth: 420, minHeight: 240)
            } else {
                AppShellView(model: model)
                    .environment(\.locale, model.appLanguage.locale)
                    // Calm Ledger §2.1: min 980×640 — keep in sync with window.minSize below.
                    .frame(minWidth: 980, minHeight: 640)
                    .onAppear {
                        if let window = NSApp.windows.first(where: { $0.isVisible }) {
                            window.minSize = NSSize(width: 980, height: 640)
                        }
                    }
            }
        }
        .commands {
            AtlasAppCommands(model: model)
        }
        // Calm Ledger §2.1: default 1180×740. Frame autosave keeps existing users'
        // sizes (≈1024×680 → drawer tier) — accepted behavior (D-012).
        .defaultSize(width: 1180, height: 740)
        .windowStyle(.hiddenTitleBar)
    }

    private static func resolveReadmeAssetExportDirectory() -> URL? {
        guard let rawValue = ProcessInfo.processInfo.environment["ATLAS_EXPORT_README_ASSETS_DIR"],
              !rawValue.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: rawValue, isDirectory: true)
    }
}
