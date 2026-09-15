import XCTest

final class AtlasAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSidebarShowsFrozenMVPRoutes() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        let sidebar = app.outlines["atlas.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))

        // Calm Ledger renamed the .history route to .ledger (round-7: the
        // accessibility identifier is now "route.ledger", not "route.history").
        for routeID in ["overview", "smartClean", "apps", "ledger", "permissions", "settings"] {
            XCTAssertTrue(app.staticTexts["route.\(routeID)"].waitForExistence(timeout: 3), "Missing route: \(routeID)")
        }
    }

    func testDefaultLanguageIsChineseAndCanSwitchToEnglish() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["概览"].waitForExistence(timeout: 5))
        app.staticTexts["route.settings"].click()

        let englishButton = app.buttons["English"]
        let englishRadio = app.radioButtons["English"]
        let didFindEnglishControl = englishButton.waitForExistence(timeout: 3) || englishRadio.waitForExistence(timeout: 3)
        XCTAssertTrue(didFindEnglishControl)
        if englishButton.exists {
            englishButton.click()
            XCTAssertTrue(englishButton.exists)
        } else {
            englishRadio.click()
            XCTAssertTrue(englishRadio.exists)
        }
    }

    func testSmartCleanAndSettingsPrimaryControlsExist() {
        let app = makeApp()
        app.launch()

        let sidebar = app.outlines["atlas.sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch

        app.staticTexts["route.smartClean"].click()
        XCTAssertTrue(app.buttons["smartclean.runScan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["smartclean.refreshPreview"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["smartclean.executePreview"].waitForExistence(timeout: 2))

        // `P1-18`（CONTRACT）：设置此前**没有任何菜单入口或键盘路径**，侧栏行的合成
        // 点击只改焦点不触发导航（本用例原先正是卡在这一步）。现改走**菜单入口** ——
        // 已验证可用；键盘路径的覆盖情况见 `testSettingsMenuEntryOpensSettings`。
        let appMenuBar = app.menuBars.firstMatch.menuBarItems.element(boundBy: 1)
        appMenuBar.click()
        // `UI-02`：在 **app 菜单自己的子树内**按结构取 Settings 槽位，不写死中文标签
        // （见 `appMenuSettingsItem`）。
        Self.appMenuSettingsItem(in: appMenuBar).click()
        // 全部按**标识**查、不绑元素类型。原断言写死了 `segmentedControls` / `radioGroups` /
        // `switches` / `steppers` 等角色 —— 而 SwiftUI 控件在 macOS 上的 AX 角色未必一致
        // （如 `.toggleStyle(.switch)` 的 Toggle 就不是 `switch`）。这些断言自 Settings
        // 不可达以来**从未被执行过**，是本次修复导航后才暴露的潜在错配。
        func element(_ identifier: String) -> XCUIElement {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", identifier))
                .firstMatch
        }
        XCTAssertTrue(element("settings.language").waitForExistence(timeout: 5), "没有语言控件")
        XCTAssertTrue(element("settings.notifications").waitForExistence(timeout: 5), "没有 notifications 控件")
        let recoveryPanelButton = element("settings.panel.recovery")
        XCTAssertTrue(recoveryPanelButton.waitForExistence(timeout: 5), "没有恢复面板入口")
        recoveryPanelButton.click()
        XCTAssertTrue(element("settings.recoveryRetention").waitForExistence(timeout: 5), "没有恢复保留期控件")
    }

    func testKeyboardShortcutsNavigateAndOpenTaskCenter() {
        let app = makeApp()
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        window.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.buttons["smartclean.runScan"].waitForExistence(timeout: 5))

        // 快捷键映射（`shortcutKey`）：1=概览 2=智能清理 3=文件整理 4=应用 5=台账 6=权限。
        // 原期望值写的是 ⌘5=权限，与映射不符（陈旧期望）。
        window.typeKey("6", modifierFlags: .command)
        XCTAssertTrue(app.buttons["permissions.refresh"].waitForExistence(timeout: 5))

        window.typeKey("7", modifierFlags: .command)
        XCTAssertTrue(app.otherElements["taskcenter.panel"].waitForExistence(timeout: 5))
    }

    // MARK: - 守卫基座：I-2 / I-3（三态撤销控件）

    /// `I-3`（`P1-8`）：可恢复动作的回执在无可恢复项时**不得静默隐藏**。
    /// 断言撤销控件**仍在场**且 `isEnabled == false`，且同屏有理由文案 ——
    /// **隐藏即判失败**（那正是修复前的缺陷形状）。
    func testSmartCleanReceiptUndoIsPresentButDisabledWithoutRestorePoint() {
        let app = makeApp(fixture: "receipt-no-recovery")
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        window.typeKey("2", modifierFlags: .command) // 智能清理

        let undo = app.buttons["smartclean.receipt.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "I-3: 撤销控件必须在场（隐藏即判失败）")
        XCTAssertFalse(undo.isEnabled, "I-3: 本次无可恢复项时不得可点")
        XCTAssertTrue(
            app.staticTexts["smartclean.receipt.undo.reason"].waitForExistence(timeout: 5),
            "I-3: 同屏必须给出理由文案"
        )
    }

    /// `I-2`（`P0-2`）：File Organizer 回执的撤销此前**无任何门控**（总是可点），
    /// 点下去找不到恢复项就静默 return。修后：在场、置灰、有理由。
    func testFileOrganizerReceiptUndoIsPresentButDisabledWithoutRecoveryItem() {
        let app = makeApp(fixture: "receipt-no-recovery")
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        window.typeKey("3", modifierFlags: .command) // 文件整理

        let undo = app.buttons["fileorganizer.receipt.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "I-2: 撤销控件必须在场（隐藏/缺失即判失败）")
        XCTAssertFalse(undo.isEnabled, "I-2: 本次无恢复项时不得可点")
        XCTAssertTrue(
            app.staticTexts["fileorganizer.receipt.undo.reason"].waitForExistence(timeout: 5),
            "I-2: 同屏必须给出理由文案"
        )
    }

    /// `I-4`（`P0-3` `P0-4` `P0-5`）：`.destructive` 确认弹窗渲染 ①②③ 结构化字段；
    /// ④ 当且仅当作用于可恢复项集合时必需。
    ///
    /// **平台限制（实测，见 `verify.md`）**：macOS 把 `.confirmationDialog` 渲染成
    /// AppKit 警报 `Sheet` —— SwiftUI 的 `accessibilityIdentifier` **被系统替换**
    /// （树里是 `_NS:58` 之类），且正文**只渲染第一行**。因此本用例只能断言
    /// 「弹窗确实打开 + ① 渲染」；②③④ 记 `NOT RUN`，不冒充覆盖。
    /// ①②③ 的主载体仍是**构造器非可选参数**（缺项编译不过），④ 由**类型**保证。
    func testDestructiveConfirmationOpensAndRendersScopeQuestion() {
        let app = makeApp(fixture: "review-executable")
        app.launch()

        // `UI-02`：断言用中文串，故**在导航前**先确认语言前置条件。
        Self.pinnedLanguageIsZhHans(app)

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        window.typeKey("2", modifierFlags: .command) // 智能清理 → ② 复核

        let execute = app.buttons["smartclean.executeSelection"]
        XCTAssertTrue(execute.waitForExistence(timeout: 5), "fixture 必须落在可执行的复核页")
        XCTAssertTrue(execute.isEnabled, "计划必须是新鲜且有可执行目标的")
        execute.click()

        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 5), "破坏性确认弹窗必须打开")

        // ① 会动什么 —— 按**文本前缀**匹配（identifier 被 AppKit 剥掉了，见上，
        // 故此处无法改用 identifier 判据）。
        //
        // `UI-02`：语言前置条件已在 `launch()` 后显式确认（见本用例开头）。
        let scopeLine = app.staticTexts.matching(
            NSPredicate(format: "value BEGINSWITH %@", "将清理已选的")
        ).firstMatch
        // 等待存在，而非立刻 `.exists`：弹窗刚出现时正文可能还在动画/布局中
        // （同屏的开场断言已用 `waitForExistence`，这里此前是唯一的裸 `.exists`，
        // 构成动画期竞态 —— 复审 `UI-03`）。
        XCTAssertTrue(scopeLine.waitForExistence(timeout: 5), "I-4 ① 会动什么必须渲染")
    }

    /// `P1-18`（CONTRACT）：设置必须有**可点的菜单入口**，且点它能抵达设置屏。
    ///
    /// **`NOT RUN` 的部分（不冒充覆盖）**：⌘, 的**键盘路径无法由本仓库的 XCUITest 验证** ——
    /// 实测发现 `typeKey` 对**标点键**合成不出菜单键等价物：对照实验把 `.permissions`
    /// 临时绑到 `⌘;`（系统未保留的标点键）也**同样不触发**，而 `⌘1`–`⌘7` 正常。
    /// 故「⌘, 不生效」**不构成 App 缺陷的证据**；键盘路径记 `NOT RUN`，
    /// 真实按键行为列入 `macos-gui-acceptance` 的人工验收项。
    func testSettingsMenuEntryOpensSettings() {
        let app = makeApp()
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        // 设置位于 app 菜单的 Settings 槽位（`CommandGroup(replacing: .appSettings)`）。
        //
        // `UI-02`：**不写死中文标签**。此前用 `app.menuItems["设置"]` —— 该串只在
        // `AtlasLanguage.default == .zhHans`（编译期常量）时成立，把默认语言改成 en
        // 就会**假红**（而本用例其实没坏）。改按**结构**定位：Settings 槽位在 app 菜单里
        // 稳定地夹在「关于」（`_aboutThisMacRequested:` 之后的第一项）与「服务」分隔符
        // 之间 —— 位置与语言无关。实测（本机探针）app 菜单中该槽位的
        // `identifier == "menuAction:"`、`title == "设置"`。
        let appMenu = app.menuBars.firstMatch.menuBarItems.element(boundBy: 1)
        appMenu.click()

        let settingsItem = Self.appMenuSettingsItem(in: appMenu)
        XCTAssertTrue(settingsItem.exists, "app 菜单（\(appMenu.title)）里没有「设置」项")
        XCTAssertTrue(settingsItem.isEnabled, "「设置」项存在但被禁用")
        settingsItem.click()

        let arrived = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "settings."))
            .firstMatch
        XCTAssertTrue(arrived.waitForExistence(timeout: 5), "点菜单里的「设置」没有抵达设置屏")
    }

    /// `I-7`：同一屏内，**两个不同动作**的可交互控件不得共用同一可见标签。
    ///
    /// 口径（规格 §7 的原文裁定）：只枚举**可交互**控件（Button / Link /
    /// DisclosureGroup）；**纯分类标签**（`AtlasMetricCard` / `AtlasStatusChip` /
    /// **阶段条**）不计入。阶段条按标识前缀剔除。
    ///
    /// 判据：同一 label 下的元素必须同属**一个动作类型**（以 identifier 区分）。
    /// 两个不同 identifier 共用同一 label ⇒ 判失败 —— 用户会把它当成导航，
    /// 点下去发现行为不同（审计 `P2-2` 的形状）。
    func testReviewScreenHasNoConflictingInteractiveLabels() {
        let app = makeApp(fixture: "review-executable")
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        window.typeKey("2", modifierFlags: .command) // 智能清理 ② 复核
        XCTAssertTrue(app.buttons["smartclean.executeSelection"].waitForExistence(timeout: 5))

        var byLabel: [String: Set<String>] = [:]
        for button in app.buttons.allElementsBoundByIndex {
            let identifier = button.identifier
            if identifier.hasPrefix("stageBar.") { continue }   // 阶段条：明文排除
            let label = button.label
            guard !label.isEmpty else { continue }
            byLabel[label, default: []].insert(identifier.isEmpty ? "(no-id)" : identifier)
        }

        let conflicts = byLabel
            .filter { $0.value.count > 1 }
            .map { "\($0.key) ← \($0.value.sorted())" }
            .sorted()
        XCTAssertTrue(
            conflicts.isEmpty,
            "I-7：同屏出现了**不同动作**共用同一标签的可交互控件：\(conflicts)"
        )
    }

    /// `I-9`：被截断的列表必须同屏说明截断。
    ///
    /// 实证背景：任务中心固定只渲染 5 条且**从不说明被截断**，而同一时刻状态文件里
    /// `taskRuns = 147` —— 用户看到正好 5 条会以为这就是全部。
    /// `I-9`：被截断的列表必须同屏说明截断。
    ///
    /// 实证背景：任务中心固定只渲染 5 条且**从不说明被截断**，而同一时刻状态文件里
    /// `taskRuns = 147` —— 用户看到正好 5 条会以为这就是全部。
    ///
    /// 守卫基座的关键：`taskcenter-many-runs` fixture 需要**新增**数据，而 worker 的
    /// 快照重载会整体换掉内存态 —— 但本 fixture **不走**「重载后重新叠加」的路子：
    /// 它由 `AtlasAppModel.taskCenterTaskRuns` 在**读取侧**直接返回，故对重载免疫。
    func testTaskCenterStatesTruncation() {
        let app = makeApp(fixture: "taskcenter-many-runs")
        app.launch()

        // `UI-02`：断言用中文串（「还有」），故**在导航前**先确认语言前置条件。
        Self.pinnedLanguageIsZhHans(app)

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        // 与 `testKeyboardShortcutsNavigateAndOpenTaskCenter` 对齐：先做一次导航快捷键
        // 确保窗口已 key（刚 launch 时直接发 ⌘7 实测不生效），再开任务中心。
        window.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.otherElements["atlas.sidebar"].waitForExistence(timeout: 5) || app.outlines["atlas.sidebar"].waitForExistence(timeout: 5))
        window.typeKey("7", modifierFlags: .command)
        XCTAssertTrue(
            app.otherElements["taskcenter.panel"].waitForExistence(timeout: 5),
            "任务中心未打开 —— 后续断言无从谈起"
        )

        // 按**文案**断言（规格 §7 原文即「断言存在「还有 N 条」」），不按标识 ——
        // popover 的 `.accessibilityIdentifier("taskcenter.panel")` 会**传播覆盖**
        // 子元素自己的标识，实测子元素的 identifier 全是 `taskcenter.panel`。
        //
        // `UI-02`：语言前置条件已在 `launch()` 后显式确认（见本用例开头）。
        let more = app.staticTexts.matching(
            NSPredicate(format: "value BEGINSWITH %@", "还有")
        ).firstMatch
        XCTAssertTrue(
            more.waitForExistence(timeout: 5),
            "I-9：列表被截断时必须同屏说明「还有 N 条」。当前树：\n\(app.debugDescription)"
        )
    }

    /// `I-10`：估算值与实测值不得在同一事实组内等权渲染。
    /// 断言估算值渲染在**独立分组容器**内，且**不属于**实测事实组。
    func testReceiptEstimateSitsInItsOwnGroup() {
        let app = makeApp(fixture: "receipt-no-recovery")
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        window.typeKey("2", modifierFlags: .command) // 智能清理 ④ 回执

        func element(_ identifier: String) -> XCUIElement {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", identifier))
                .firstMatch
        }

        let estimatedGroup = element("smartclean.receipt.facts.estimated")
        XCTAssertTrue(estimatedGroup.waitForExistence(timeout: 5), "I-10：估算值必须在独立分组容器内")
        let measuredGroup = element("smartclean.receipt.facts.measured")
        XCTAssertTrue(measuredGroup.exists, "I-10：实测事实组必须存在（作为对照容器）")

        // 断言估算值**不在**实测组内。
        //
        // 判据用**标识**而非文案：事实行经 `.accessibilityElement(children: .ignore)`
        // 折叠成单个元素，其子 `Text` 不以 `staticText` 出现 —— 此前
        // `measuredGroup.descendants(matching: .staticText)` **恒为空集合**
        // （探针实测 `labels = []`），故「不含『预计』」的断言恒真：把估算行搬进
        // 实测组容器，守卫照旧通过（复审 `F-09` / `TS-04` 的实证）。
        // 产品侧已给每个事实行投放稳定标识，使本集合**非空**。
        let measuredIDs = measuredGroup.descendants(matching: .any)
            .allElementsBoundByIndex.map { $0.identifier }
        XCTAssertFalse(
            measuredIDs.isEmpty,
            "I-10：实测事实组必须**可枚举**（空集合会让本守卫恒真）。实际：\(measuredIDs)"
        )
        XCTAssertTrue(
            measuredIDs.contains("smartclean.receipt.fact.items"),
            "I-10：实测组应含其实事行（夹具探针）。实际：\(measuredIDs)"
        )
        XCTAssertFalse(
            measuredIDs.contains("smartclean.receipt.fact.estimated"),
            "I-10：估算行不得落在实测事实组内。实测组实际内容：\(measuredIDs)"
        )
    }

    /// `UI-02`：**显式钉住界面语言**，使依赖中文文案的断言不再依赖
    /// `AtlasLanguage.default` 的编译期取值。
    ///
    /// 机制：状态文件里的 `settings.language` 决定 app 用哪份 lproj
    /// （`AtlasAppModel.init` → `AtlasL10n.setCurrentLanguage(state.settings.language)`）。
    /// `ATLAS_STATE_FILE` 指向一个**不存在**的文件时，app 回落到
    /// `AtlasScaffoldWorkspace.state()`，其默认语言正是 `AtlasLanguage.default`
    /// —— 即中文断言此前**碰巧**成立。
    ///
    /// 本方法把该依赖变成**显式前置条件**：先让 app 启动并写出真实状态文件，
    /// 再读回它携带的语言，确认与断言所用语言一致；不一致即**立即失败并说明**，
    /// 而不是留下一堆看不懂的「找不到中文串」。这样把 `AtlasLanguage.default`
    /// 改成 en 时，失败信息会直接指向「语言未钉住」，而不是伪装成 UI 缺陷。
    ///
    /// **调用时机**：`app.launch()` 之后、任何导航之前 —— 此时侧栏恒在，
    /// 「概览」/「Overview」是可靠的语言标记。
    ///
    /// 返回：语言确为 zh-Hans 时为 `true`。
    @discardableResult
    private static func pinnedLanguageIsZhHans(_ app: XCUIApplication) -> Bool {
        // 语言生效的**可观测后果**：中文文案下侧栏第一条路由显示「概览」。
        // 若换成 en（`default` 被改），这里会先炸出明确信号。
        if app.staticTexts["概览"].waitForExistence(timeout: 5) { return true }
        if app.staticTexts["Overview"].waitForExistence(timeout: 2) {
            XCTFail(
                "UI-02：本用例期望 **zh-Hans** 文案，但 app 以 **en** 启动。"
                + "说明 `AtlasLanguage.default` 已被改动 —— 请在本用例里显式钉住语言，"
                + "不要把断言绑在编译期默认值上。"
            )
            return false
        }
        XCTFail("UI-02：无法确认界面语言（既看不到「概览」也看不到「Overview」）。")
        return false
    }

    /// `UI-02`：app 菜单里的 **Settings 槽位**，按**结构**定位而不是按本地化标签。
    ///
    /// 为什么不能按标签：槽位由 `CommandGroup(replacing: .appSettings)` 建立，
    /// 其标题走 `AtlasRoute.settings.title`（本地化）。写死 `menuItems["设置"]`
    /// 就绑定了 `AtlasLanguage.default` 的编译期取值 —— 换 en 即假红。
    ///
    /// 结构（本机实测的 app 菜单顺序）：`关于本机` → `系统信息` → **分隔符** →
    /// `系统设置…` → … → `关于 Atlas`(`menuAction:`) → **`设置`** → 分隔符 → `服务`。
    /// 故取「app 菜单里 `identifier == "menuAction:"` 且标题等于 About 项之后、
    /// 服务分隔符之前」的那一项 —— 与语言无关。
    ///
    /// 兜底：若结构法找不到，回退到**位置**（Settings 槽位恒为 app 菜单中
    /// keyEquivalent 为 ⌘, 的系统槽位），仍不依赖任何本地化串。
    private static func appMenuSettingsItem(in appMenuBarItem: XCUIElement) -> XCUIElement {
        // 只在 **app 菜单自己的子树**内找 —— `app.menuItems` 会把所有菜单的条目
        // 拍平返回（含「操作」菜单的同名 `menuAction:` 项），据此定位实测会选错
        // （探针：picked=[刷新系统快照]）。限定子树后，序列即 app 菜单的真实顺序：
        // `关于本机` … `关于 Atlas`(`menuAction:`) → **`设置`**(`menuAction:`) → `服务`。
        //
        // 结构判据：**「服务」项之前最后一个 `menuAction:`**。实测该槽位恒为
        // Settings，与其本地化标题无关。
        let items = appMenuBarItem.menuItems.allElementsBoundByIndex
        let servicesIndex = items.firstIndex { $0.identifier == "_configureServicesMenu:" } ?? items.count
        let candidates = items[..<servicesIndex].filter { $0.identifier == "menuAction:" }
        if let last = candidates.last {
            return last
        }
        // 兜底：⌘, 槽位（语言无关的键盘等价物）。
        return appMenuBarItem.menuItems.matching(
            NSPredicate(format: "identifier == %@", "menuAction:")
        ).element(boundBy: 1)
    }

    private func makeApp(fixture: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        let stateFile = NSTemporaryDirectory() + UUID().uuidString + "/workspace-state.json"
        app.launchEnvironment["ATLAS_STATE_FILE"] = stateFile
        // 守卫基座（规格 §9 纪律 4）：执行回执是内存态、不落盘，冷启动状态文件
        // 造不出「回执存在 + 无恢复项」这一态，故经启动环境变量注入 fixture。
        if let fixture {
            app.launchEnvironment["ATLAS_UI_TEST_FIXTURE"] = fixture
        }
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        return app
    }
}
