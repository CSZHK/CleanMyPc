import XCTest

final class XCUITestReproUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHelloLabelExists() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["repro.hello"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["repro.tap"].waitForExistence(timeout: 5))
    }
}
