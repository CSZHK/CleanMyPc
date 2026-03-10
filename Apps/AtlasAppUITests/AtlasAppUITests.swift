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

        for routeID in ["overview", "smartClean", "apps", "history", "permissions", "settings"] {
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

        app.staticTexts["route.smartClean"].click()
        XCTAssertTrue(app.buttons["smartclean.runScan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["smartclean.refreshPreview"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["smartclean.executePreview"].waitForExistence(timeout: 2))

        app.staticTexts["route.settings"].click()
        XCTAssertTrue(app.segmentedControls["settings.language"].waitForExistence(timeout: 5) || app.radioGroups["settings.language"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["settings.notifications"].waitForExistence(timeout: 5))
        let recoveryPanelButton = app.buttons["settings.panel.recovery"]
        XCTAssertTrue(recoveryPanelButton.waitForExistence(timeout: 5))
        recoveryPanelButton.click()
        XCTAssertTrue(app.steppers["settings.recoveryRetention"].waitForExistence(timeout: 5))
    }

    func testKeyboardShortcutsNavigateAndOpenTaskCenter() {
        let app = makeApp()
        app.launch()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        window.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.buttons["smartclean.runScan"].waitForExistence(timeout: 5))

        window.typeKey("5", modifierFlags: .command)
        XCTAssertTrue(app.buttons["permissions.refresh"].waitForExistence(timeout: 5))

        window.typeKey("7", modifierFlags: .command)
        XCTAssertTrue(app.otherElements["taskcenter.panel"].waitForExistence(timeout: 5))
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        let stateFile = NSTemporaryDirectory() + UUID().uuidString + "/workspace-state.json"
        app.launchEnvironment["ATLAS_STATE_FILE"] = stateFile
        return app
    }
}
