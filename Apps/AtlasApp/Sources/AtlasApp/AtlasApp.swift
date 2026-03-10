import AtlasDomain
import SwiftUI

@main
struct AtlasApp: App {
    @StateObject private var model = AtlasAppModel()

    var body: some Scene {
        WindowGroup(AtlasL10n.string("app.name")) {
            AppShellView(model: model)
                .environment(\.locale, model.appLanguage.locale)
                .frame(minWidth: 940, minHeight: 640)
        }
        .commands {
            AtlasAppCommands(model: model)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
