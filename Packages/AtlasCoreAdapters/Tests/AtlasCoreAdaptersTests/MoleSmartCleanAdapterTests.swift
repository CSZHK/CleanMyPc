import XCTest
@testable import AtlasCoreAdapters

final class MoleSmartCleanAdapterTests: XCTestCase {
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
""".write(to: fileURL, atomically: true, encoding: .utf8)

        let findings = MoleSmartCleanAdapter.parseDetailedFindings(from: fileURL)

        XCTAssertTrue(findings.contains(where: { $0.title == "Xcode DerivedData" && ($0.targetPaths?.count ?? 0) == 2 }))
        XCTAssertTrue(findings.contains(where: { $0.title == "Chrome cache" && ($0.targetPaths?.first?.contains("Chrome/Default") ?? false) }))
        XCTAssertTrue(findings.contains(where: { $0.title == "pnpm store" && ($0.targetPaths?.first?.contains("/Library/pnpm/store") ?? false) }))
    }
}
