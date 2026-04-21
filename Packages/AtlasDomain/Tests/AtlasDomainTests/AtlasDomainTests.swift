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
            ["概览", "智能清理", "文件整理", "应用", "历史", "权限", "设置"]
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

    // MARK: - Finding Initialization with New Fields

    func testFindingInitializesWithExplanationField() {
        let finding = Finding(
            title: "Xcode Derived Data",
            detail: "Build artifacts from older projects",
            bytes: 18_400_000_000,
            risk: .safe,
            category: "Developer",
            explanation: "Safe to remove build artifacts"
        )
        XCTAssertEqual(finding.explanation, "Safe to remove build artifacts")
        XCTAssertNil(finding.fileAge)
        XCTAssertNil(finding.storageCategory)
    }

    func testFindingInitializesWithFileAgeField() {
        let now = Date()
        let fileAge = FileAgeInfo(
            lastAccessedDate: now.addingTimeInterval(-90 * 86400),
            creationDate: now.addingTimeInterval(-365 * 86400)
        )
        let finding = Finding(
            title: "Old Cache",
            detail: "Cache not accessed in 90 days",
            bytes: 500_000,
            risk: .safe,
            category: "System",
            fileAge: fileAge
        )
        XCTAssertNotNil(finding.fileAge)
        XCTAssertNotNil(finding.fileAge?.lastAccessedDate)
        XCTAssertNotNil(finding.fileAge?.creationDate)
        XCTAssertNil(finding.explanation)
        XCTAssertNil(finding.storageCategory)
    }

    func testFindingInitializesWithStorageCategoryField() {
        let finding = Finding(
            title: "Browser Cache",
            detail: "WebKit cache folder",
            bytes: 4_800_000_000,
            risk: .safe,
            category: "Browsers",
            storageCategory: .browserData
        )
        XCTAssertEqual(finding.storageCategory, .browserData)
        XCTAssertNil(finding.explanation)
        XCTAssertNil(finding.fileAge)
    }

    func testFindingInitializesWithAllNewFields() {
        let fileAge = FileAgeInfo(lastAccessedDate: Date().addingTimeInterval(-180 * 86400))
        let finding = Finding(
            title: "System Cache",
            detail: "System-level cache data",
            bytes: 2_000_000,
            risk: .review,
            category: "System",
            targetPaths: ["/Library/Caches/com.example"],
            explanation: "Review before removal",
            fileAge: fileAge,
            storageCategory: .systemCache
        )
        XCTAssertEqual(finding.explanation, "Review before removal")
        XCTAssertNotNil(finding.fileAge)
        XCTAssertEqual(finding.storageCategory, .systemCache)
        XCTAssertEqual(finding.targetPaths?.count, 1)
    }

    func testFindingDefaultsNewFieldsToNil() {
        let finding = Finding(
            title: "Basic",
            detail: "Basic finding",
            bytes: 100,
            risk: .safe,
            category: "System"
        )
        XCTAssertNil(finding.explanation)
        XCTAssertNil(finding.fileAge)
        XCTAssertNil(finding.storageCategory)
        XCTAssertNil(finding.targetPaths)
    }

    // MARK: - AtlasStorageCategory

    func testStorageCategoryRawValues() {
        XCTAssertEqual(AtlasStorageCategory.systemCache.rawValue, "systemCache")
        XCTAssertEqual(AtlasStorageCategory.appCache.rawValue, "appCache")
        XCTAssertEqual(AtlasStorageCategory.developerArtifact.rawValue, "developerArtifact")
        XCTAssertEqual(AtlasStorageCategory.browserData.rawValue, "browserData")
        XCTAssertEqual(AtlasStorageCategory.logFile.rawValue, "logFile")
        XCTAssertEqual(AtlasStorageCategory.downloadArtifact.rawValue, "downloadArtifact")
        XCTAssertEqual(AtlasStorageCategory.mailAttachment.rawValue, "mailAttachment")
        XCTAssertEqual(AtlasStorageCategory.oldBackup.rawValue, "oldBackup")
    }

    func testStorageCategoryCaseIterableCount() {
        XCTAssertEqual(AtlasStorageCategory.allCases.count, 8)
    }

    func testStorageCategoryTitlesAreLocalized() {
        AtlasL10n.setCurrentLanguage(.en)
        for category in AtlasStorageCategory.allCases {
            XCTAssertFalse(category.title.isEmpty, "Title for \(category.rawValue) should not be empty")
        }
        AtlasL10n.setCurrentLanguage(.zhHans)
        for category in AtlasStorageCategory.allCases {
            XCTAssertFalse(category.title.isEmpty, "Title for \(category.rawValue) should not be empty in Chinese")
        }
    }

    func testStorageCategorySystemImages() {
        for category in AtlasStorageCategory.allCases {
            XCTAssertFalse(category.systemImage.isEmpty, "systemImage for \(category.rawValue) should not be empty")
        }
    }

    // MARK: - FileAgeInfo

    func testFileAgeInfoDefaultInit() {
        let fileAge = FileAgeInfo()
        XCTAssertNil(fileAge.lastAccessedDate)
        XCTAssertNil(fileAge.creationDate)
    }

    func testFileAgeInfoWithLastAccessedOnly() {
        let date = Date().addingTimeInterval(-30 * 86400)
        let fileAge = FileAgeInfo(lastAccessedDate: date)
        XCTAssertEqual(fileAge.lastAccessedDate, date)
        XCTAssertNil(fileAge.creationDate)
    }

    func testFileAgeInfoWithCreationOnly() {
        let date = Date().addingTimeInterval(-365 * 86400)
        let fileAge = FileAgeInfo(creationDate: date)
        XCTAssertNil(fileAge.lastAccessedDate)
        XCTAssertEqual(fileAge.creationDate, date)
    }

    func testFileAgeInfoWithBothDates() {
        let accessed = Date().addingTimeInterval(-60 * 86400)
        let created = Date().addingTimeInterval(-365 * 86400)
        let fileAge = FileAgeInfo(lastAccessedDate: accessed, creationDate: created)
        XCTAssertEqual(fileAge.lastAccessedDate, accessed)
        XCTAssertEqual(fileAge.creationDate, created)
    }

    func testFileAgeInfoIsHashable() {
        let date = Date()
        let a = FileAgeInfo(lastAccessedDate: date, creationDate: date)
        let b = FileAgeInfo(lastAccessedDate: date, creationDate: date)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testFileAgeInfoIsCodable() throws {
        let date = Date()
        let original = FileAgeInfo(lastAccessedDate: date, creationDate: date)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FileAgeInfo.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - FindingAggregate

    func testFindingAggregateInit() {
        let aggregate = FindingAggregate(risk: .safe, totalBytes: 1_000, count: 5)
        XCTAssertEqual(aggregate.risk, .safe)
        XCTAssertEqual(aggregate.totalBytes, 1_000)
        XCTAssertEqual(aggregate.count, 5)
    }

    func testAggregatesByRiskFromEmptyFindings() {
        let findings: [Finding] = []
        let aggregates = findings.aggregatesByRisk()
        XCTAssertEqual(aggregates.count, RiskLevel.allCases.count)
        for aggregate in aggregates {
            XCTAssertEqual(aggregate.totalBytes, 0)
            XCTAssertEqual(aggregate.count, 0)
        }
    }

    func testAggregatesByRiskGroupsCorrectly() {
        let findings: [Finding] = [
            Finding(title: "A", detail: "a", bytes: 100, risk: .safe, category: "System"),
            Finding(title: "B", detail: "b", bytes: 200, risk: .safe, category: "System"),
            Finding(title: "C", detail: "c", bytes: 500, risk: .review, category: "System"),
            Finding(title: "D", detail: "d", bytes: 1_000, risk: .advanced, category: "System"),
        ]
        let aggregates = findings.aggregatesByRisk()

        let safeAgg = aggregates.first { $0.risk == .safe }
        let reviewAgg = aggregates.first { $0.risk == .review }
        let advancedAgg = aggregates.first { $0.risk == .advanced }

        XCTAssertEqual(safeAgg?.totalBytes, 300)
        XCTAssertEqual(safeAgg?.count, 2)
        XCTAssertEqual(reviewAgg?.totalBytes, 500)
        XCTAssertEqual(reviewAgg?.count, 1)
        XCTAssertEqual(advancedAgg?.totalBytes, 1_000)
        XCTAssertEqual(advancedAgg?.count, 1)
    }

    func testGroupedByStorageCategory() {
        let findings: [Finding] = [
            Finding(title: "A", detail: "a", bytes: 100, risk: .safe, category: "System", storageCategory: .systemCache),
            Finding(title: "B", detail: "b", bytes: 200, risk: .safe, category: "System", storageCategory: .systemCache),
            Finding(title: "C", detail: "c", bytes: 300, risk: .review, category: "Developer", storageCategory: .developerArtifact),
            Finding(title: "D", detail: "d", bytes: 400, risk: .safe, category: "System"),
        ]
        let grouped = findings.groupedByStorageCategory()

        XCTAssertEqual(grouped["systemCache"]?.count, 2)
        XCTAssertEqual(grouped["developerArtifact"]?.count, 1)
        XCTAssertEqual(grouped["uncategorized"]?.count, 1)
        XCTAssertNil(grouped["browserData"])
    }

}
