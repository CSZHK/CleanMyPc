import XCTest
@testable import AtlasCoreAdapters
import AtlasDomain

final class MacAppsInventoryAdapterTests: XCTestCase {
    func testCollectInstalledAppsBuildsStructuredFootprints() async throws {
        let sandboxURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appsRoot = sandboxURL.appendingPathComponent("Applications", isDirectory: true)
        let homeRoot = sandboxURL.appendingPathComponent("Home", isDirectory: true)
        let appURL = appsRoot.appendingPathComponent("Sample.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/sample")
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        let leftoverURL = homeRoot.appendingPathComponent("Library/Application Support/Sample", isDirectory: true)

        try FileManager.default.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: leftoverURL, withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 1024).write(to: executableURL)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleIdentifier</key>
          <string>com.example.Sample</string>
          <key>CFBundleName</key>
          <string>Sample</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
        </dict>
        </plist>
        """.data(using: .utf8)!.write(to: infoPlistURL)

        let adapter = MacAppsInventoryAdapter(searchRoots: [appsRoot], homeDirectoryURL: homeRoot)
        let apps = try await adapter.collectInstalledApps()

        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps.first?.name, "Sample")
        XCTAssertEqual(apps.first?.bundleIdentifier, "com.example.Sample")
        XCTAssertTrue(apps.first?.bundlePath.hasSuffix("/Applications/Sample.app") == true)
        XCTAssertEqual(apps.first?.leftoverItems, 1)
        XCTAssertGreaterThan(apps.first?.bytes ?? 0, 0)
    }

    // MARK: - computeEvidenceSummary coverage via collectInstalledApps

    func testComputeEvidenceSummary_multipleCategories() async throws {
        let fm = FileManager.default
        let sandboxURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appsRoot = sandboxURL.appendingPathComponent("Applications", isDirectory: true)
        let homeRoot = sandboxURL.appendingPathComponent("Home", isDirectory: true)
        let bundleIdentifier = "com.test.evidence.summary"
        let appName = "EvidenceSummaryTest"

        // Create .app bundle with Info.plist
        let appURL = appsRoot.appendingPathComponent("\(appName).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/evidencesummary")
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        try fm.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 512).write(to: executableURL)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleIdentifier</key>
          <string>\(bundleIdentifier)</string>
          <key>CFBundleName</key>
          <string>\(appName)</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
        </dict>
        </plist>
        """.data(using: .utf8)!.write(to: infoPlistURL)

        // Create leftover paths for multiple categories
        // supportFiles: ~/Library/Application Support/{appName} + ~/Library/Application Support/{bundleIdentifier}
        let supportByName = homeRoot.appendingPathComponent("Library/Application Support/\(appName)", isDirectory: true)
        let supportByID = homeRoot.appendingPathComponent("Library/Application Support/\(bundleIdentifier)", isDirectory: true)
        try fm.createDirectory(at: supportByName, withIntermediateDirectories: true)
        try fm.createDirectory(at: supportByID, withIntermediateDirectories: true)

        // caches: ~/Library/Caches/{bundleIdentifier}
        let cachesURL = homeRoot.appendingPathComponent("Library/Caches/\(bundleIdentifier)", isDirectory: true)
        try fm.createDirectory(at: cachesURL, withIntermediateDirectories: true)

        // preferences: ~/Library/Preferences/{bundleIdentifier}.plist
        let prefsDir = homeRoot.appendingPathComponent("Library/Preferences", isDirectory: true)
        let prefsURL = prefsDir.appendingPathComponent("\(bundleIdentifier).plist")
        try fm.createDirectory(at: prefsDir, withIntermediateDirectories: true)
        try Data("pref".utf8).write(to: prefsURL)

        // logs: ~/Library/Logs/{appName}
        let logsURL = homeRoot.appendingPathComponent("Library/Logs/\(appName)", isDirectory: true)
        try fm.createDirectory(at: logsURL, withIntermediateDirectories: true)

        // savedState: ~/Library/Saved Application State/{bundleIdentifier}.savedState
        let savedStateURL = homeRoot.appendingPathComponent("Library/Saved Application State/\(bundleIdentifier).savedState", isDirectory: true)
        try fm.createDirectory(at: savedStateURL, withIntermediateDirectories: true)

        // containers: ~/Library/Containers/{bundleIdentifier}
        let containersURL = homeRoot.appendingPathComponent("Library/Containers/\(bundleIdentifier)", isDirectory: true)
        try fm.createDirectory(at: containersURL, withIntermediateDirectories: true)

        addTeardownBlock {
            try? fm.removeItem(at: sandboxURL)
        }

        let adapter = MacAppsInventoryAdapter(searchRoots: [appsRoot], homeDirectoryURL: homeRoot)
        let apps = try await adapter.collectInstalledApps()

        guard let app = apps.first else {
            return XCTFail("Expected one app")
        }

        XCTAssertEqual(app.name, appName)
        XCTAssertEqual(app.bundleIdentifier, bundleIdentifier)

        // Verify evidenceSummary has correct category counts
        guard let summary = app.evidenceSummary else {
            return XCTFail("Expected evidenceSummary to be non-nil")
        }

        // supportFiles: 2 paths (appName + bundleIdentifier)
        XCTAssertEqual(summary[.supportFiles], 2, "supportFiles should count 2 existing paths")

        // caches: 1 path
        XCTAssertEqual(summary[.caches], 1, "caches should count 1 path")

        // preferences: 1 path
        XCTAssertEqual(summary[.preferences], 1, "preferences should count 1 path")

        // logs: 1 path (only appName log dir created; adapter scans both appName and bundleIdentifier
        // but bundleIdentifier log dir does not exist in this fixture)
        XCTAssertEqual(summary[.logs], 1, "logs should count 1 path")

        // savedState: 1 path
        XCTAssertEqual(summary[.savedState], 1, "savedState should count 1 path")

        // containers: 1 path
        XCTAssertEqual(summary[.containers], 1, "containers should count 1 path")

        // leftoverItems should be sum of all category counts
        // supportFiles(2) + caches(1) + preferences(1) + logs(1) + savedState(1) + containers(1) = 7
        XCTAssertEqual(app.leftoverItems, 7, "leftoverItems should equal sum of all category counts")
    }

    func testComputeEvidenceSummary_noLeftovers() async throws {
        let fm = FileManager.default
        let sandboxURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appsRoot = sandboxURL.appendingPathComponent("Applications", isDirectory: true)
        let homeRoot = sandboxURL.appendingPathComponent("Home", isDirectory: true)

        // Create .app bundle with Info.plist but NO leftover paths
        let appURL = appsRoot.appendingPathComponent("CleanApp.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let executableURL = contentsURL.appendingPathComponent("MacOS/cleanapp")
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        try fm.createDirectory(at: executableURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x1, count: 256).write(to: executableURL)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleIdentifier</key>
          <string>com.test.cleanapp</string>
          <key>CFBundleName</key>
          <string>CleanApp</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
        </dict>
        </plist>
        """.data(using: .utf8)!.write(to: infoPlistURL)

        addTeardownBlock {
            try? fm.removeItem(at: sandboxURL)
        }

        let adapter = MacAppsInventoryAdapter(searchRoots: [appsRoot], homeDirectoryURL: homeRoot)
        let apps = try await adapter.collectInstalledApps()

        guard let app = apps.first else {
            return XCTFail("Expected one app")
        }

        XCTAssertEqual(app.leftoverItems, 0, "No leftover paths → leftoverItems should be 0")
        guard let summary = app.evidenceSummary else {
            return XCTFail("evidenceSummary should be non-nil even when all categories are zero")
        }
        for category in AtlasAppEvidenceCategory.allCases where category != .appBundle {
            let count = summary[category] ?? 0
            XCTAssertEqual(count, 0, "\(category) should be 0 for clean app")
        }
    }
}
