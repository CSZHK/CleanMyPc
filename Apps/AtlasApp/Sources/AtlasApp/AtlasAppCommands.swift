import AtlasDomain
import SwiftUI

struct AtlasAppCommands: Commands {
    @ObservedObject var model: AtlasAppModel

    var body: some Commands {
        CommandMenu(AtlasL10n.string("commands.navigate.menu")) {
            ForEach(AtlasRoute.allCases) { route in
                Button(route.title) {
                    model.navigate(to: route)
                }
                .keyboardShortcut(route.shortcutKey, modifiers: .command)
            }

            Divider()

            Button(model.isTaskCenterPresented ? AtlasL10n.string("commands.taskcenter.close") : AtlasL10n.string("commands.taskcenter.open")) {
                model.toggleTaskCenter()
            }
            .keyboardShortcut("7", modifiers: .command)
        }

        CommandMenu(AtlasL10n.string("commands.actions.menu")) {
            Button(AtlasL10n.string("commands.actions.refreshCurrent")) {
                Task {
                    await model.refreshCurrentRoute()
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button(AtlasL10n.string("commands.actions.runScan")) {
                Task {
                    await model.runSmartCleanScan()
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(model.isWorkflowBusy)

            Button(AtlasL10n.string("commands.actions.refreshApps")) {
                Task {
                    model.navigate(to: .apps)
                    await model.refreshApps()
                }
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            .disabled(model.isWorkflowBusy)

            Button(AtlasL10n.string("commands.actions.refreshPermissions")) {
                Task {
                    model.navigate(to: .permissions)
                    await model.inspectPermissions()
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
            .disabled(model.isWorkflowBusy)

            Button(AtlasL10n.string("commands.actions.refreshHealth")) {
                Task {
                    model.navigate(to: .overview)
                    await model.refreshHealthSnapshot()
                }
            }
            .keyboardShortcut("h", modifiers: [.command, .option])
            .disabled(model.isWorkflowBusy)
        }
    }
}

private extension AtlasRoute {
    var shortcutKey: KeyEquivalent {
        switch self {
        case .overview:
            return "1"
        case .smartClean:
            return "2"
        case .apps:
            return "3"
        case .history:
            return "4"
        case .permissions:
            return "5"
        case .settings:
            return "6"
        case .about:
            return "7"
        }
    }
}
