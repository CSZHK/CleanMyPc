import XCTest
@testable import AtlasDomain

final class AtlasDomainTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AtlasL10n.setCurrentLanguage(.zhHans)
    }

    func testPrimaryRoutesMatchFrozenMVP() {
        XCTAssertEqual(
            AtlasRoute.allCases.map(\.title),
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

}
