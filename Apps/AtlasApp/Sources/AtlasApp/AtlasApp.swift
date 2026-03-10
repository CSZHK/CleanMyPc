import AtlasDomain
import SwiftUI

@main
struct AtlasApp: App {
    @StateObject private var model = AtlasAppModel()

    var body: some Scene {
        WindowGroup(AtlasL10n.string("app.name")) {
            AppShellView(model: model)
                .environment(\.locale, model.appLanguage.locale)
                .frame(minWidth: 1120, minHeight: 720)
        }
        .commands {
            AtlasAppCommands(model: model)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
