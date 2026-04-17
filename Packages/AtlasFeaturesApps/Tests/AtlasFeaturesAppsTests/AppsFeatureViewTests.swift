import XCTest
@testable import AtlasFeaturesApps
import AtlasDomain

@MainActor
final class AppsFeatureViewTests: XCTestCase {

    // MARK: - View Initialization

    func testDefaultInitUsesFixtureData() {
        let view = AppsFeatureView()
        XCTAssertNotNil(view, "AppsFeatureView should initialize with default fixture data")
    }

    func testInitWithEmptyApps() {
        let view = AppsFeatureView(
            apps: [],
            isRunning: false
        )
        XCTAssertNotNil(view)
    }
    func testInitWithAppsList() {
        let apps = [
            AppFootprint(
                id: UUID(),
                name: "Test App",
                bundleIdentifier: "com.test.app",
                bundlePath: "/Applications/TestApp.app",
                bytes: 100_000_000,
                leftoverItems: 5
            ),
            AppFootprint(
                id: UUID(),
                name: "Another App",
                bundleIdentifier: "com.another.app",
                bundlePath: "/Applications/AnotherApp.app",
                bytes: 50_000_000,
                leftoverItems: 2
            ),
        ]
        let view = AppsFeatureView(apps: apps, isRunning: false)
        XCTAssertNotNil(view)
    }
    func testInitWithRunningState() {
        let view = AppsFeatureView(
            apps: AtlasScaffoldFixtures.apps,
            isRunning: true
        )
        XCTAssertNotNil(view)
    }
    func testInitWithSingleAppAndActivePreview() {
        let appID = UUID()
        let app = AppFootprint(
            id: appID,
            name: "Single App",
            bundleIdentifier: "com.single.app",
            bundlePath: "/Applications/Single.app",
            bytes: 50_000_000,
            leftoverItems: 1
        )
        let view = AppsFeatureView(
            apps: [app],
            isRunning: true,
            activePreviewAppID: appID
        )
        XCTAssertNotNil(view)
    }
    func testInitWithRestoreRefreshStatus() {
        let status = AtlasAppPostRestoreRefreshStatus(
            appName: "Restored App",
            bundleIdentifier: "com.restored.app",
            bundlePath: "/Applications/Restored.app",
            state: .refreshed,
            recordedLeftoverItems: 5,
            refreshedLeftoverItems: nil
        )
        let view = AppsFeatureView(
            apps: [],
            restoreRefreshStatus: status,
            isRunning: false
        )
        XCTAssertNotNil(view)
    }
}
