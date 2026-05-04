import AtlasDomain
import XCTest
@testable import AtlasCoreAdapters

final class MoleSmartCleanAdapterTests: XCTestCase {
    // MARK: - Existing tests (enriched with additional assertions)

    func testParseFindingsBuildsStructuredSmartCleanItems() {
        let sample = """
        ➤ Browsers
          → Chrome old versions, 2 dirs, 1.37GB dry

        ➤ Developer tools
          → npm cache · would clean
          → Xcode runtime volumes · 2 unused, 1 in use
          • Runtime volumes total: 3.50GB (unused 2.25GB, in-use 1.25GB)
          → JetBrains Toolbox · would remove 3 old versions (4.00GB), keeping 1 most recent

        ➤ Orphaned data
          → Would remove 4 orphaned launch agent(s), 12MB
        """

        let findings = MoleSmartCleanAdapter.parseFindings(from: sample)

        XCTAssertEqual(findings.first?.title, "JetBrains Toolbox")
        XCTAssertEqual(findings.first?.bytes, Int64(4.0 * 1024 * 1024 * 1024))
        XCTAssertTrue(findings.contains(where: { $0.title == "Chrome old versions" && $0.category == "Browsers" }))
        XCTAssertTrue(findings.contains(where: { $0.title == "Xcode runtime volumes" && $0.bytes == Int64(2.25 * 1024 * 1024 * 1024) }))
        XCTAssertTrue(findings.contains(where: { $0.category == "Orphaned data" && $0.risk.rawValue == "advanced" }))
    }

    func testParseDetailedFindingsBuildsExecutableTargets() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectA	1024
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectB	2048
Browsers	/Users/test/Library/Caches/Google/Chrome/Default/Cache_Data	512
Developer tools	/Users/test/Library/pnpm/store/v3/files/atlas-fixture/package.tgz	256
Developer tools	/Users/test/Library/Containers/com.example.preview/Data/Library/Caches/cache.db	128
Developer tools	/Users/test/Library/Containers/com.example.preview/Data/Library/Logs/runtime.log	64
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)

        XCTAssertTrue(findings.contains(where: { $0.title == "Xcode DerivedData" && ($0.targetPaths?.count ?? 0) == 2 }))
        XCTAssertTrue(findings.contains(where: { $0.title == "Chrome cache" && ($0.targetPaths?.first?.contains("Chrome/Default") ?? false) }))
        XCTAssertTrue(findings.contains(where: { $0.title == "pnpm store" && ($0.targetPaths?.first?.contains("/Library/pnpm/store") ?? false) }))
        XCTAssertTrue(findings.contains(where: { $0.title == "com.example.preview container cache" && ($0.targetPaths?.first?.contains("/Data/Library/Caches") ?? false) }))
        XCTAssertTrue(findings.contains(where: { $0.title == "com.example.preview container logs" && ($0.targetPaths?.first?.contains("/Data/Library/Logs") ?? false) }))
    }

    // MARK: - Enriched TSV parsing with risk and category columns

    func testParseDetailedFindingsWithEnrichedRiskAndCategoryColumns() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let dateFormatter = ISO8601DateFormatter()
        let accessedDate = dateFormatter.string(from: Date().addingTimeInterval(-90 * 24 * 3600))
        let createdDate = dateFormatter.string(from: Date().addingTimeInterval(-365 * 24 * 3600))

        try """
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectA	1024	safe	developerArtifact	\(accessedDate)	\(createdDate)
Browsers	/Users/test/Library/Caches/Google/Chrome/Default/Cache_Data	512	safe	browserData		\(createdDate)
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectB	2048	review	developerArtifact	\(accessedDate)
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)

        // DerivedData entries should be grouped together
        let derivedData = findings.first(where: { $0.title == "Xcode DerivedData" })
        XCTAssertNotNil(derivedData)
        XCTAssertEqual(derivedData?.risk, .safe)
        XCTAssertEqual(derivedData?.storageCategory, .developerArtifact)
        XCTAssertNotNil(derivedData?.fileAge)
        XCTAssertNotNil(derivedData?.explanation)
        XCTAssertFalse(derivedData?.explanation?.isEmpty ?? true)
        XCTAssertEqual(derivedData?.bytes, (1024 + 2048) * 1024)

        let chromeCache = findings.first(where: { $0.title == "Chrome cache" })
        XCTAssertNotNil(chromeCache)
        XCTAssertEqual(chromeCache?.risk, .safe)
        XCTAssertEqual(chromeCache?.storageCategory, .browserData)
        XCTAssertNotNil(chromeCache?.fileAge)
        // Chrome entry has no lastAccessed but has createdDate
        XCTAssertNil(chromeCache?.fileAge?.lastAccessedDate)
        XCTAssertNotNil(chromeCache?.fileAge?.creationDate)
        XCTAssertNotNil(chromeCache?.explanation)
    }

    func testParseDetailedFindingsWithPartialEnrichedColumns() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Only risk level column provided (4 columns), no category or dates
        try """
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectA	1024	review
Browsers	/Users/test/Library/Caches/Google/Chrome/Default/Cache_Data	512	safe
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)

        let derivedData = findings.first(where: { $0.title == "Xcode DerivedData" })
        XCTAssertNotNil(derivedData)
        XCTAssertEqual(derivedData?.risk, .review)
        // storageCategory falls back to path-based classification
        XCTAssertEqual(derivedData?.storageCategory, .developerArtifact)
        XCTAssertNotNil(derivedData?.explanation)

        let chrome = findings.first(where: { $0.title == "Chrome cache" })
        XCTAssertNotNil(chrome)
        XCTAssertEqual(chrome?.risk, .safe)
        XCTAssertEqual(chrome?.storageCategory, .browserData)
    }

    // MARK: - Fallback parsing when enriched fields are missing

    func testParseDetailedFindingsFallbackWithoutEnrichedColumns() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Classic 3-column TSV — no risk, category, or date columns
        try """
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectA	1024
Browsers	/Users/test/Library/Caches/Google/Chrome/Default/Cache_Data	512
Developer tools	/Users/test/Library/pnpm/store/v3/files/pkg.tgz	256
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)

        // Risk levels should be resolved via fallback logic
        let derivedData = findings.first(where: { $0.title == "Xcode DerivedData" })
        XCTAssertNotNil(derivedData)
        // DerivedData is in Developer tools section — fallback should assign .safe
        XCTAssertEqual(derivedData?.risk, .safe)
        // storageCategory should be resolved via path-based classification
        XCTAssertEqual(derivedData?.storageCategory, .developerArtifact)
        // fileAge should be nil since no date columns provided
        XCTAssertNil(derivedData?.fileAge)
        // Explanation should still be generated from fallback values
        XCTAssertNotNil(derivedData?.explanation)
        XCTAssertFalse(derivedData?.explanation?.isEmpty ?? true)

        let chrome = findings.first(where: { $0.title == "Chrome cache" })
        XCTAssertNotNil(chrome)
        XCTAssertEqual(chrome?.storageCategory, .browserData)
        XCTAssertNil(chrome?.fileAge)

        let pnpm = findings.first(where: { $0.title == "pnpm store" })
        XCTAssertNotNil(pnpm)
        XCTAssertEqual(pnpm?.storageCategory, .developerArtifact)
    }

    func testParseFindingsFallbackPopulatesExplanationAndStorageCategory() {
        let sample = """
        ➤ Developer tools
          → npm cache · would clean

        ➤ Browsers
          → Chrome old versions, 2 dirs, 1.37GB dry

        ➤ Orphaned data
          → Would remove 4 orphaned launch agent(s), 12MB
        """

        let findings = MoleSmartCleanAdapter.parseFindings(from: sample)

        let npm = findings.first(where: { $0.title == "npm cache" })
        XCTAssertNotNil(npm)
        XCTAssertEqual(npm?.risk, .safe)
        XCTAssertEqual(npm?.storageCategory, .developerArtifact)
        XCTAssertNotNil(npm?.explanation)
        XCTAssertFalse(npm?.explanation?.isEmpty ?? true)

        let chrome = findings.first(where: { $0.title == "Chrome old versions" })
        XCTAssertNotNil(chrome)
        // storageCategory falls back to .systemCache when title alone doesn't match path patterns
        XCTAssertNotNil(chrome?.storageCategory)
        XCTAssertNotNil(chrome?.explanation)

        let launchAgent = findings.first(where: { $0.title.contains("orphaned launch agent") })
        XCTAssertNotNil(launchAgent)
        XCTAssertEqual(launchAgent?.risk, .advanced)
        XCTAssertNotNil(launchAgent?.explanation)
    }

    // MARK: - File age extraction from TSV date columns

    func testFileAgeExtractionFromEnrichedTSV() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let dateFormatter = ISO8601DateFormatter()
        let lastAccessed = Date().addingTimeInterval(-180 * 24 * 3600)  // 6 months ago
        let created = Date().addingTimeInterval(-730 * 24 * 3600)       // 2 years ago

        try """
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectA	1024	safe	developerArtifact	\(dateFormatter.string(from: lastAccessed))	\(dateFormatter.string(from: created))
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)
        XCTAssertEqual(findings.count, 1)

        let finding = findings[0]
        XCTAssertNotNil(finding.fileAge)
        XCTAssertNotNil(finding.fileAge?.lastAccessedDate)
        XCTAssertNotNil(finding.fileAge?.creationDate)

        // Verify dates are approximately correct (within 60 seconds tolerance)
        let accessedDelta = abs(finding.fileAge!.lastAccessedDate!.timeIntervalSinceNow - lastAccessed.timeIntervalSinceNow)
        XCTAssertLessThan(accessedDelta, 60)
        let createdDelta = abs(finding.fileAge!.creationDate!.timeIntervalSinceNow - created.timeIntervalSinceNow)
        XCTAssertLessThan(createdDelta, 60)
    }

    func testFileAgeParsingWithEmptyDateColumns() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        // 7 columns but date columns are empty strings
        try """
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectA	1024	safe	developerArtifact
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)
        XCTAssertEqual(findings.count, 1)
        XCTAssertNil(findings[0].fileAge)
    }

    func testFileAgeParsingWithOnlyLastAccessedDate() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let dateFormatter = ISO8601DateFormatter()
        let accessed = dateFormatter.string(from: Date().addingTimeInterval(-30 * 24 * 3600))

        // 6 columns: section, path, size, risk, category, lastAccessed (no createdDate)
        try """
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectA	1024	safe	developerArtifact	\(accessed)
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)
        XCTAssertEqual(findings.count, 1)
        XCTAssertNotNil(findings[0].fileAge)
        XCTAssertNotNil(findings[0].fileAge?.lastAccessedDate)
        XCTAssertNil(findings[0].fileAge?.creationDate)
    }

    // MARK: - Storage category classification via path patterns

    func testStorageCategoryClassificationViaDetailedFindings() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        try """
Unknown	/Users/test/Library/Caches/com.app/snapshot.db	100
Unknown	/Users/test/Library/Logs/system.log	200
Unknown	/Users/test/Library/Mail/Attachments/msg.eml	300
Unknown	/Users/test/Downloads/installer.pkg	400
Unknown	/Users/test/Library/Application Support/com.app/data.db	500
Unknown	/Users/test/Library/Google/Chrome/Default/Cache_Data/index	600
Unknown	/Users/test/Backup/old_backup.tar	700
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)

        // systemCache: /Library/Caches/ path
        XCTAssertTrue(findings.contains(where: { $0.storageCategory == .systemCache }))
        // logFile: .log extension or /Library/Logs/ path
        XCTAssertTrue(findings.contains(where: { $0.storageCategory == .logFile }))
        // mailAttachment: /Library/Mail/ path
        XCTAssertTrue(findings.contains(where: { $0.storageCategory == .mailAttachment }))
        // downloadArtifact: /Downloads/ path
        XCTAssertTrue(findings.contains(where: { $0.storageCategory == .downloadArtifact }))
        // appCache: /Library/Application Support/ path
        XCTAssertTrue(findings.contains(where: { $0.storageCategory == .appCache }))
        // browserData: /Google/Chrome/ path
        XCTAssertTrue(findings.contains(where: { $0.storageCategory == .browserData }))
        // oldBackup: /Backup/ path contains "backup"
        XCTAssertTrue(findings.contains(where: { $0.storageCategory == .oldBackup }))
    }

    // MARK: - FindingAggregate computation

    func testAggregatesByRiskReturnsAllRiskLevels() {
        let findings: [Finding] = [
            Finding(title: "A", detail: "", bytes: 1024, risk: .safe, category: "Test"),
            Finding(title: "B", detail: "", bytes: 2048, risk: .safe, category: "Test"),
            Finding(title: "C", detail: "", bytes: 512, risk: .review, category: "Test"),
            Finding(title: "D", detail: "", bytes: 4096, risk: .advanced, category: "Test"),
        ]

        let aggregates = findings.aggregatesByRisk()
        XCTAssertEqual(aggregates.count, 3)

        let safeAgg = aggregates.first(where: { $0.risk == .safe })
        XCTAssertEqual(safeAgg?.totalBytes, 1024 + 2048)
        XCTAssertEqual(safeAgg?.count, 2)

        let reviewAgg = aggregates.first(where: { $0.risk == .review })
        XCTAssertEqual(reviewAgg?.totalBytes, 512)
        XCTAssertEqual(reviewAgg?.count, 1)

        let advancedAgg = aggregates.first(where: { $0.risk == .advanced })
        XCTAssertEqual(advancedAgg?.totalBytes, 4096)
        XCTAssertEqual(advancedAgg?.count, 1)
    }

    func testAggregatesByRiskWithEmptyFindings() {
        let findings: [Finding] = []
        let aggregates = findings.aggregatesByRisk()

        XCTAssertEqual(aggregates.count, 3)
        for agg in aggregates {
            XCTAssertEqual(agg.totalBytes, 0)
            XCTAssertEqual(agg.count, 0)
        }
    }

    func testAggregatesByRiskWithSingleRiskLevel() {
        let findings: [Finding] = [
            Finding(title: "A", detail: "", bytes: 100, risk: .safe, category: "Test"),
            Finding(title: "B", detail: "", bytes: 200, risk: .safe, category: "Test"),
            Finding(title: "C", detail: "", bytes: 300, risk: .safe, category: "Test"),
        ]

        let aggregates = findings.aggregatesByRisk()

        let safeAgg = aggregates.first(where: { $0.risk == .safe })
        XCTAssertEqual(safeAgg?.totalBytes, 600)
        XCTAssertEqual(safeAgg?.count, 3)

        let reviewAgg = aggregates.first(where: { $0.risk == .review })
        XCTAssertEqual(reviewAgg?.totalBytes, 0)
        XCTAssertEqual(reviewAgg?.count, 0)

        let advancedAgg = aggregates.first(where: { $0.risk == .advanced })
        XCTAssertEqual(advancedAgg?.totalBytes, 0)
        XCTAssertEqual(advancedAgg?.count, 0)
    }

    // MARK: - Grouped by storage category

    func testGroupedByStorageCategory() {
        let findings: [Finding] = [
            Finding(title: "A", detail: "", bytes: 100, risk: .safe, category: "Test", storageCategory: .systemCache),
            Finding(title: "B", detail: "", bytes: 200, risk: .safe, category: "Test", storageCategory: .systemCache),
            Finding(title: "C", detail: "", bytes: 300, risk: .review, category: "Test", storageCategory: .developerArtifact),
            Finding(title: "D", detail: "", bytes: 400, risk: .advanced, category: "Test", storageCategory: .browserData),
            Finding(title: "E", detail: "", bytes: 500, risk: .safe, category: "Test"),
        ]

        let grouped = findings.groupedByStorageCategory()

        XCTAssertEqual(grouped["systemCache"]?.count, 2)
        XCTAssertEqual(grouped["developerArtifact"]?.count, 1)
        XCTAssertEqual(grouped["browserData"]?.count, 1)
        XCTAssertEqual(grouped["uncategorized"]?.count, 1)
        XCTAssertEqual(grouped["uncategorized"]?.first?.title, "E")
    }

    func testGroupedByStorageCategoryAllUncategorized() {
        let findings: [Finding] = [
            Finding(title: "A", detail: "", bytes: 100, risk: .safe, category: "Test"),
            Finding(title: "B", detail: "", bytes: 200, risk: .safe, category: "Test"),
        ]

        let grouped = findings.groupedByStorageCategory()
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped["uncategorized"]?.count, 2)
    }

    func testGroupedByStorageCategoryEmpty() {
        let findings: [Finding] = []
        let grouped = findings.groupedByStorageCategory()
        XCTAssertTrue(grouped.isEmpty)
    }

    // MARK: - Mixed enriched and non-enriched rows

    func testParseDetailedFindingsWithMixedEnrichedAndBasicRows() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let dateFormatter = ISO8601DateFormatter()
        let accessedDate = dateFormatter.string(from: Date().addingTimeInterval(-60 * 24 * 3600))

        // Row 1: fully enriched (7 columns)
        // Row 2: basic (3 columns)
        // Row 3: partial (4 columns — risk only)
        try """
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectA	1024	safe	developerArtifact	\(accessedDate)
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectB	2048
Browsers	/Users/test/Library/Caches/Google/Chrome/Default/Cache_Data	512	review
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)

        // Both DerivedData rows should be grouped together
        let derivedData = findings.first(where: { $0.title == "Xcode DerivedData" })
        XCTAssertNotNil(derivedData)
        // First entry provided enrichment; second is basic — group should inherit from first
        XCTAssertEqual(derivedData?.storageCategory, .developerArtifact)
        XCTAssertEqual(derivedData?.risk, .safe)
        XCTAssertNotNil(derivedData?.fileAge)
        XCTAssertEqual(derivedData?.bytes, (1024 + 2048) * 1024)

        let chrome = findings.first(where: { $0.title == "Chrome cache" })
        XCTAssertNotNil(chrome)
        XCTAssertEqual(chrome?.risk, .review)
        // Fallback classification via path
        XCTAssertEqual(chrome?.storageCategory, .browserData)
    }

    // MARK: - Explanation generation for parsed findings

    func testDetailedFindingsGenerateNonEmptyExplanations() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("tsv")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        try """
Developer tools	/Users/test/Library/Developer/Xcode/DerivedData/ProjectA	1024
Browsers	/Users/test/Library/Caches/Google/Chrome/Default/Cache_Data	512
Unknown	/Users/test/Library/Logs/system.log	256
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)

        for finding in findings {
            XCTAssertNotNil(finding.explanation, "Finding '\(finding.title)' should have an explanation")
            XCTAssertFalse(finding.explanation?.isEmpty ?? true, "Finding '\(finding.title)' explanation should not be empty")
        }
    }

    func testParseFindingsGenerateNonEmptyExplanations() {
        let sample = """
        ➤ Developer tools
          → npm cache · would clean
          → Xcode runtime volumes · 2 unused, 1 in use
          • Runtime volumes total: 3.50GB (unused 2.25GB, in-use 1.25GB)

        ➤ Browsers
          → Chrome old versions, 2 dirs, 1.37GB dry

        ➤ Orphaned data
          → Would remove 4 orphaned launch agent(s), 12MB
        """

        let findings = MoleSmartCleanAdapter.parseFindings(from: sample)

        for finding in findings {
            XCTAssertNotNil(finding.explanation, "Finding '\(finding.title)' should have an explanation")
            XCTAssertFalse(finding.explanation?.isEmpty ?? true, "Finding '\(finding.title)' explanation should not be empty")
        }
    }
}
