import AtlasDomain
import SwiftUI

struct AtlasAppCommands: Commands {
    @ObservedObject var model: AtlasAppModel

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(AtlasL10n.string("commands.about")) {
                model.navigate(to: .about)
            }
        }

        CommandMenu(AtlasL10n.string("commands.navigate.menu")) {
            ForEach(AtlasRoute.sidebarRoutes) { route in
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
                // Re-scan with an active plan № needs explicit confirmation
                // (spec §2.3: 「当前计划 №N 将作废」). The menu only raises the
                // intent flag; the dialog is presented by the screen (Batch I)
                // and calls supersedePlan(for:) on confirm. Without a plan the
                // scan starts directly, as before.
                if model.workflowState(for: .smartClean).planNumber != nil {
                    model.navigate(to: .smartClean)
                    model.requestRescanConfirmation(for: .smartClean)
                } else {
                    Task {
                        await model.runSmartCleanScan()
                    }
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
        case .fileOrganizer:
            return "3"
        case .apps:
            return "4"
        case .ledger:
            return "5"
        case .permissions:
            return "6"
        case .settings, .about:
            preconditionFailure("Non-sidebar routes have no shortcut key")
        }
    }
}
