import XCTest
@testable import AtlasCoreAdapters

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
}
