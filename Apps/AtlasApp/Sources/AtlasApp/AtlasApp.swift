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
                    .frame(minWidth: 940, minHeight: 640)
            }
        }
        .commands {
            AtlasAppCommands(model: model)
        }
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
