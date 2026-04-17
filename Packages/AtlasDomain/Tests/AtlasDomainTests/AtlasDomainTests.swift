import XCTest
@testable import AtlasDomain

final class AtlasDomainTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AtlasL10n.setCurrentLanguage(.zhHans)
    }

    func testPrimaryRoutesMatchFrozenMVP() {
        XCTAssertEqual(
            AtlasRoute.allCases
                .filter { $0 != .about }
                .map(\.title),
            ["概览", "智能清理", "应用", "历史", "权限", "设置"]
        )
    }

    func testScaffoldFixturesExposeRecoveryItems() {
        XCTAssertFalse(AtlasScaffoldFixtures.recoveryItems.isEmpty)
        XCTAssertGreaterThan(AtlasScaffoldFixtures.findings.map(\.bytes).reduce(0, +), 0)
    }


    func testSettingsDecodeDefaultsLanguageToChineseWhenMissing() throws {
        let data = Data("""
        {
          "recoveryRetentionDays": 7,
          "notificationsEnabled": true,
          "excludedPaths": []
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AtlasSettings.self, from: data)

        XCTAssertEqual(settings.language, .zhHans)
        XCTAssertEqual(settings.acknowledgementText, AtlasL10n.acknowledgement(language: .zhHans))
    }

    func testOnlyFullDiskAccessIsRequiredForCurrentWorkflows() {
        XCTAssertTrue(PermissionKind.fullDiskAccess.isRequiredForCurrentWorkflows)
        XCTAssertFalse(PermissionKind.accessibility.isRequiredForCurrentWorkflows)
        XCTAssertFalse(PermissionKind.notifications.isRequiredForCurrentWorkflows)
    }

    func testRecoveryPayloadDecodesLegacyAppShape() throws {
        let data = Data(
            """
            {
              "app": {
                "id": "10000000-0000-0000-0000-000000000111",
                "name": "Legacy App",
                "bundleIdentifier": "com.example.legacy",
                "bundlePath": "/Applications/Legacy App.app",
                "bytes": 1024,
                "leftoverItems": 2
              }
            }
            """.utf8
        )

        let payload = try JSONDecoder().decode(RecoveryPayload.self, from: data)

        guard case let .app(appPayload) = payload else {
            return XCTFail("Expected app payload")
        }

        XCTAssertEqual(appPayload.schemaVersion, AtlasRecoveryPayloadSchemaVersion.current)
        XCTAssertEqual(appPayload.app.name, "Legacy App")
        XCTAssertEqual(appPayload.app.leftoverItems, 2)
        XCTAssertEqual(appPayload.uninstallEvidence.reviewOnlyGroupCount, 0)
        XCTAssertEqual(appPayload.uninstallEvidence.bundlePath, "/Applications/Legacy App.app")
    }

    func testActionItemExecutionBoundaryDetectsHelperAndReviewOnlyCases() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let direct = ActionItem(
            title: "Direct cache",
            detail: "User cache",
            kind: .removeCache,
            recoverable: true,
            targetPaths: [home + "/.swiftpm/cache/repositories/direct.bin"]
        )
        XCTAssertEqual(direct.executionBoundary, .direct)

        let helper = ActionItem(
            title: "Launch agent cleanup",
            detail: "Protected path",
            kind: .removeCache,
            recoverable: true,
            targetPaths: [home + "/Library/LaunchAgents/com.example.fixture.plist"]
        )
        XCTAssertEqual(helper.executionBoundary, .helper)

        let reviewOnly = ActionItem(
            title: "Review first",
            detail: "No supported targets",
            kind: .inspectPermission,
            recoverable: false
        )
        XCTAssertEqual(reviewOnly.executionBoundary, .reviewOnly)
    }

}
