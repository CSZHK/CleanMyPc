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

        // `P1-18`（CONTRACT）：设置走 app 菜单的 **Settings 槽位**。
        //
        // 实测教训：把带 ⌘, 的 Button 放进自定义 `CommandMenu` 是**不够的** ——
        // 菜单项确实建出来了（可访问性树里「设置」项存在且 enabled），但 ⌘, 不触发，
        // 而同一菜单里的 ⌘1–⌘6 正常。原因是 macOS 在自己的 app 菜单里为「设置…」
        // 保留着 ⌘, 槽位，那个（不可见的）槽位先匹配走了按键。
        // `CommandGroup(replacing: .appSettings)` 正是 SwiftUI 为这一槽位指定的入口，
        // 替换它才能让 ⌘, 按惯例生效 —— 也顺带把设置放进了它该在的位置。
        CommandGroup(replacing: .appSettings) {
            Button(AtlasRoute.settings.title) {
                model.navigate(to: .settings)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu(AtlasL10n.string("commands.navigate.menu")) {
            ForEach(AtlasRoute.sidebarRoutes) { route in
                // `shortcutKey` 现为可选（`I-11` 前置 2）；sidebar 路由恒非 nil。
                if let key = route.shortcutKey {
                    Button(route.title) {
                        model.navigate(to: route)
                    }
                    .keyboardShortcut(key, modifiers: .command)
                }
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

// `I-11` 前置 1：访问级别。原为 `private extension` —— 文件级 `private` 对 extension
// 成员等价于 `fileprivate`，而 `@testable import` **只放开 internal**，
// 路由可达性守卫根本编不过（`inaccessible due to 'fileprivate' protection level`）。
extension AtlasRoute {
    /// `I-11` 前置 2：返回 `KeyEquivalent?` 而非 `preconditionFailure`。
    ///
    /// 原实现对 `.settings / .about` 直接 `preconditionFailure` —— 遍历 `allCases`
    /// 调用它会**崩掉测试进程**，而不是断言失败。
    ///
    /// `P1-18`（CONTRACT，2026-09-14 已签字）：`.settings` 补上 ⌘, —— 此前设置
    /// **没有任何菜单入口或键盘路径**（`iterations/REQ-ui-ux-overhaul` 的 P1-3 把
    /// 「⌘, 打开 Settings」标为 DONE 却从未交付）。
    var shortcutKey: KeyEquivalent? {
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
        case .settings:
            // macOS 惯例：⌘, 打开设置。
            return ","
        case .about:
            // 关于由 `CommandGroup(replacing: .appInfo)` 的「关于 Atlas」承载，
            // 不占用快捷键（macOS 惯例）。
            return nil
        }
    }
}
