import AtlasDomain
import XCTest
@testable import AtlasCoreAdapters

final class AtlasFileOrganizerScannerTests: XCTestCase {
    private var testDir: String!

    override func setUp() {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("AtlasScannerTests-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        testDir = base.path
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testDir)
    }

    // MARK: - Empty Directory

    func testScanEmptyDirectoryReturnsNoEntries() async throws {
        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.totalFiles, 0)
        XCTAssertEqual(result.totalBytes, 0)
    }

    // MARK: - Single File Scan

    func testScanSingleImageFile() async throws {
        let fileURL = URL(fileURLWithPath: testDir).appendingPathComponent("photo.png")
        try Data("fake-png".utf8).write(to: fileURL)

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.entries.count, 1)
        let entry = result.entries[0]
        XCTAssertEqual(entry.fileName, "photo.png")
        XCTAssertEqual(entry.category, .images)
        XCTAssertTrue(entry.bytes > 0)
        XCTAssertTrue(entry.proposedDestination.contains("/Images/photo.png"))
    }

    func testScanClassifiesAllCategories() async throws {
        let files: [(String, FileOrganizerCategory)] = [
            ("pic.jpg", .images),
            ("video.mp4", .videos),
            ("song.mp3", .audio),
            ("doc.pdf", .documents),
            ("archive.zip", .archives),
            ("script.swift", .code),
            ("app.dmg", .installers),
            ("unknown.xyz", .other),
        ]
        for (name, _) in files {
            try Data("data".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent(name))
        }

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.entries.count, 8)
        XCTAssertEqual(result.categoryCounts[.images], 1)
        XCTAssertEqual(result.categoryCounts[.videos], 1)
        XCTAssertEqual(result.categoryCounts[.audio], 1)
        XCTAssertEqual(result.categoryCounts[.documents], 1)
        XCTAssertEqual(result.categoryCounts[.archives], 1)
        XCTAssertEqual(result.categoryCounts[.code], 1)
        XCTAssertEqual(result.categoryCounts[.installers], 1)
        XCTAssertEqual(result.categoryCounts[.other], 1)
    }

    // MARK: - Non-Recursive (Default)

    func testNonRecursiveSkipsSubdirectories() async throws {
        let rootFile = URL(fileURLWithPath: testDir).appendingPathComponent("root.txt")
        try Data("root".utf8).write(to: rootFile)

        let subDir = URL(fileURLWithPath: testDir).appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: subDir.appendingPathComponent("nested.txt"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir], recursive: false)

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].fileName, "root.txt")
    }

    // MARK: - Recursive

    func testRecursiveIncludesSubdirectories() async throws {
        let rootFile = URL(fileURLWithPath: testDir).appendingPathComponent("root.txt")
        try Data("root".utf8).write(to: rootFile)

        let subDir = URL(fileURLWithPath: testDir).appendingPathComponent("subdir", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try Data("nested".utf8).write(to: subDir.appendingPathComponent("nested.txt"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir], recursive: true)

        XCTAssertEqual(result.entries.count, 2)
        let names = Set(result.entries.map(\.fileName))
        XCTAssertTrue(names.contains("root.txt"))
        XCTAssertTrue(names.contains("nested.txt"))
    }

    // MARK: - Hidden Files Skipped

    func testHiddenFilesAreSkipped() async throws {
        let visibleFile = URL(fileURLWithPath: testDir).appendingPathComponent("visible.txt")
        try Data("v".utf8).write(to: visibleFile)

        let hiddenFile = URL(fileURLWithPath: testDir).appendingPathComponent(".hidden")
        try Data("h".utf8).write(to: hiddenFile)

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].fileName, "visible.txt")
    }

    // MARK: - Custom Destination Path

    func testCustomDestinationBasePath() async throws {
        try Data("data".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("file.pdf"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir], destinationBasePath: "~/MyFiles")

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertTrue(result.entries[0].proposedDestination.hasPrefix("~/MyFiles/"))
        XCTAssertTrue(result.entries[0].proposedDestination.contains("/Documents/file.pdf"))
    }

    func testDestinationPathStripsTrailingSlash() async throws {
        try Data("data".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("img.png"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir], destinationBasePath: "~/Output/")

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertFalse(result.entries[0].proposedDestination.contains("//"))
    }

    // MARK: - Multiple Folders

    func testScanMultipleFolders() async throws {
        let fm = FileManager.default
        let dir2 = fm.temporaryDirectory.appendingPathComponent("AtlasScannerTests2-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir2, withIntermediateDirectories: true)
        addTeardownBlock { try? fm.removeItem(at: dir2) }

        try Data("a".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("a.png"))
        try Data("b".utf8).write(to: URL(fileURLWithPath: dir2.path).appendingPathComponent("b.pdf"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir, dir2.path])

        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.totalFiles, 2)
    }

    // MARK: - Nonexistent Folder

    func testScanNonexistentFolderReturnsEmpty() async throws {
        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders(["/nonexistent/path/that/does/not/exist"])
        XCTAssertTrue(result.entries.isEmpty)
    }

    // MARK: - Total Bytes

    func testTotalBytesAccumulated() async throws {
        try Data("12345".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("a.txt"))
        try Data("1234567890".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("b.txt"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.totalBytes, 5 + 10)
    }

    // MARK: - Category Counts

    func testCategoryCountsCorrect() async throws {
        for name in ["a.png", "b.jpg", "c.pdf"] {
            try Data("x".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent(name))
        }

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.categoryCounts[.images], 2)
        XCTAssertEqual(result.categoryCounts[.documents], 1)
    }
}

final class AtlasFileOrganizerClassifierTests: XCTestCase {
    private let classifier = AtlasFileOrganizerClassifier()

    // MARK: - Extension-Based Classification

    func testClassifyByExtension() async {
        let entries = [
            makeEntry(fileName: "photo.png", category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "Images", extensionPatterns: ["png", "jpg"], category: .images),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .images)
    }

    // MARK: - Name Pattern Classification

    func testClassifyByNamePattern() async {
        let entries = [
            makeEntry(fileName: "screenshot_2024.png", category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "Screenshots", extensionPatterns: [], namePatterns: ["screenshot"], category: .images),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .images)
    }

    // MARK: - Size Filtering

    func testRuleSkipsEntryBelowMinSize() async {
        let entries = [
            makeEntry(fileName: "small.png", bytes: 100, category: .other),
            makeEntry(fileName: "big.png", bytes: 10_000, category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "Large Images", extensionPatterns: ["png"], category: .documents, minSizeBytes: 1000),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .images) // too small for custom rule → UTType fallback .images
        XCTAssertEqual(result[1].category, .documents) // matches custom rule
    }

    func testRuleSkipsEntryAboveMaxSize() async {
        let entries = [
            makeEntry(fileName: "huge.zip", bytes: 1_000_000, category: .other),
            makeEntry(fileName: "small.zip", bytes: 100, category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "Small Archives", extensionPatterns: ["zip"], category: .code, maxSizeBytes: 500_000),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .archives) // too large for custom rule → UTType fallback .archives
        XCTAssertEqual(result[1].category, .code) // matches custom rule
    }

    // MARK: - Priority: Custom Rules Before UTType

    func testCustomRuleTakesPriorityOverUTType() async {
        let entries = [
            makeEntry(fileName: "data.json", category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "JSON as Documents", extensionPatterns: ["json"], category: .documents),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .documents) // custom rule, not UTType .sourceCode
    }

    // MARK: - UTType Fallback

    func testUTTypeFallbackWhenNoRulesMatch() async {
        let entries = [
            makeEntry(fileName: "photo.heic", category: .other),
        ]
        let result = await classifier.classify(entries, rules: [])
        XCTAssertEqual(result[0].category, .images) // UTType .image
    }

    // MARK: - Existing Category Fallback

    func testFallbackToExistingCategory() async {
        let entries = [
            makeEntry(fileName: "mysteryfile", category: .documents),
        ]
        let result = await classifier.classify(entries, rules: [])
        XCTAssertEqual(result[0].category, .documents) // no rule, no UTType match → keep existing
    }

    // MARK: - Custom Destination Base Path

    func testCustomDestinationPathApplied() async {
        let entries = [
            makeEntry(fileName: "file.png", category: .images),
        ]
        let result = await classifier.classify(entries, rules: [], destinationBasePath: "~/Custom")
        XCTAssertTrue(result[0].proposedDestination.hasPrefix("~/Custom/Images/"))
    }

    // MARK: - Empty Input

    func testClassifyEmptyArray() async {
        let result = await classifier.classify([], rules: [])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Multiple Rules First Match Wins

    func testFirstMatchingRuleWins() async {
        let entries = [
            makeEntry(fileName: "test.png", category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "Rule A", extensionPatterns: ["png"], category: .documents),
            FileOrganizerRule(name: "Rule B", extensionPatterns: ["png"], category: .videos),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .documents) // first rule wins
    }

    // MARK: - Helper

    private func makeEntry(fileName: String, bytes: Int64 = 100, category: FileOrganizerCategory = .other) -> FileOrganizerEntry {
        FileOrganizerEntry(
            path: "~/Desktop/\(fileName)",
            fileName: fileName,
            bytes: bytes,
            category: category,
            proposedDestination: "~/Organized/Other/\(fileName)"
        )
    }
}

// MARK: - Boundary Condition Tests

extension AtlasFileOrganizerScannerTests {

    // MARK: Symlink Handling

    func testSymlinkToFileIsResolved() async throws {
        let target = URL(fileURLWithPath: testDir).appendingPathComponent("real.png")
        try Data("img".utf8).write(to: target)

        let link = URL(fileURLWithPath: testDir).appendingPathComponent("link.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        // Symlink resolves to same path prefix → included (not skipped)
        XCTAssertGreaterThanOrEqual(result.entries.count, 1)
    }

    func testSymlinkToOutsideDirectoryIsSkipped() async throws {
        let outsideDir = FileManager.default.temporaryDirectory.appendingPathComponent("AtlasOutside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: outsideDir) }
        try Data("outside".utf8).write(to: outsideDir.appendingPathComponent("secret.txt"))

        let link = URL(fileURLWithPath: testDir).appendingPathComponent("outside_link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outsideDir)

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        // Symlink to outside should not produce entries
        XCTAssertTrue(result.entries.isEmpty)
    }

    // MARK: Uppercase Extensions

    func testUppercaseExtensionClassifiesCorrectly() async throws {
        let files = ["photo.PNG", "video.MP4", "doc.PDF"]
        for name in files {
            try Data("x".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent(name))
        }

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.entries.count, 3)
        let cats = Dictionary(grouping: result.entries, by: \.fileName)
        XCTAssertEqual(cats["photo.PNG"]?.first?.category, .images)
        XCTAssertEqual(cats["video.MP4"]?.first?.category, .videos)
        XCTAssertEqual(cats["doc.PDF"]?.first?.category, .documents)
    }

    // MARK: Files Without Extension

    func testFileWithNoExtensionClassifiesAsOther() async throws {
        try Data("data".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("Makefile"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].category, .other)
    }

    // MARK: Deep Nesting with Recursive Scan

    func testDeepNestingRecursiveScan() async throws {
        var currentDir = URL(fileURLWithPath: testDir)
        for i in 0..<5 {
            currentDir = currentDir.appendingPathComponent("level\(i)", isDirectory: true)
            try FileManager.default.createDirectory(at: currentDir, withIntermediateDirectories: true)
            try Data("f\(i)".utf8).write(to: currentDir.appendingPathComponent("file\(i).txt"))
        }

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir], recursive: true)

        XCTAssertEqual(result.entries.count, 5)
    }

    // MARK: Filenames with Special Characters

    func testFilenameWithSpaces() async throws {
        try Data("x".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("my photo.png"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].fileName, "my photo.png")
    }

    func testFilenameWithUnicode() async throws {
        try Data("x".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("截图_2024.png"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].fileName, "截图_2024.png")
    }

    func testFilenameWithMultipleDots() async throws {
        try Data("x".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("archive.tar.gz"))

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].category, .archives)
    }

    // MARK: Large File Count

    func testLargeFileCount() async throws {
        for i in 0..<500 {
            try Data("x".utf8).write(to: URL(fileURLWithPath: testDir).appendingPathComponent("file\(i).txt"))
        }

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir])

        XCTAssertEqual(result.entries.count, 500)
        XCTAssertEqual(result.totalFiles, 500)
    }

    // MARK: Duplicate Filenames in Different Subdirs (recursive)

    func testDuplicateFilenamesInDifferentSubdirs() async throws {
        for sub in ["A", "B"] {
            let dir = URL(fileURLWithPath: testDir).appendingPathComponent(sub, isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("x".utf8).write(to: dir.appendingPathComponent("same.txt"))
        }

        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([testDir], recursive: true)

        XCTAssertEqual(result.entries.count, 2)
        // Both have the same fileName but different paths
        let paths = result.entries.map(\.path)
        XCTAssertEqual(Set(paths).count, 2)
    }

    // MARK: Tilde Expansion in Folder Paths

    func testScanWithTildePath() async throws {
        let scanner = AtlasFileOrganizerScanner()
        // ~/Desktop should exist and be scannable (may have 0 or more files)
        let result = try await scanner.scanFolders(["~/Desktop"])
        XCTAssertNotNil(result)
    }

    // MARK: Empty Folder List

    func testScanEmptyFolderList() async throws {
        let scanner = AtlasFileOrganizerScanner()
        let result = try await scanner.scanFolders([])
        XCTAssertTrue(result.entries.isEmpty)
    }
}

extension AtlasFileOrganizerClassifierTests {

    // MARK: Rule with Destination Subfolder

    func testRuleWithDestinationSubfolder() async {
        let entries = [makeEntry(fileName: "photo.png", category: .images)]
        let rules = [
            FileOrganizerRule(name: "Photos", extensionPatterns: ["png"], category: .images, destinationSubfolder: "Vacation"),
        ]
        let result = await classifier.classify(entries, rules: rules, destinationBasePath: "~/Organized")
        XCTAssertEqual(result[0].proposedDestination, "~/Organized/Images/Vacation/photo.png")
    }

    // MARK: Rule with Both Extension and Name Pattern

    func testRuleMatchesEitherExtensionOrName() async {
        let entries = [
            makeEntry(fileName: "screenshot.png", category: .other),
            makeEntry(fileName: "screenshot_readme.txt", category: .other),
            makeEntry(fileName: "readme.txt", category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "Screenshots", extensionPatterns: ["png"], namePatterns: ["screenshot"], category: .images),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .images) // matches extension
        XCTAssertEqual(result[1].category, .images) // matches name pattern
        XCTAssertEqual(result[2].category, .other)   // matches neither → fallback
    }

    // MARK: Case-Insensitive Extension Matching

    func testCaseInsensitiveExtensionMatching() async {
        let entries = [
            makeEntry(fileName: "photo.PNG", category: .other),
            makeEntry(fileName: "photo.png", category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "Images", extensionPatterns: ["png"], category: .images),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .images)
        XCTAssertEqual(result[1].category, .images)
    }

    // MARK: Rule with Empty Patterns Matches Nothing

    func testRuleWithEmptyPatternsMatchesNothing() async {
        let entries = [makeEntry(fileName: "test.png", category: .documents)]
        let rules = [
            FileOrganizerRule(name: "Empty", extensionPatterns: [], namePatterns: [], category: .audio),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .images) // no rule match → UTType fallback
    }

    // MARK: Multiple Size Filters in Same Rule

    func testRuleWithBothMinAndMaxSize() async {
        let entries = [
            makeEntry(fileName: "small.png", bytes: 50, category: .other),
            makeEntry(fileName: "medium.png", bytes: 500, category: .other),
            makeEntry(fileName: "large.png", bytes: 5000, category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "Mid-size", extensionPatterns: ["png"], category: .documents, minSizeBytes: 100, maxSizeBytes: 1000),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .images)  // too small → UTType
        XCTAssertEqual(result[1].category, .documents) // in range → custom rule
        XCTAssertEqual(result[2].category, .images)  // too large → UTType
    }

    // MARK: Proposed Destination with Special Characters

    func testProposedDestinationPreservesFilename() async {
        let entries = [makeEntry(fileName: "my photo (2).png", category: .images)]
        let result = await classifier.classify(entries, rules: [], destinationBasePath: "~/Output")
        XCTAssertTrue(result[0].proposedDestination.contains("my photo (2).png"))
    }

    // MARK: Trailing Slash in Destination Base Path

    func testDestinationBasePathWithTrailingSlash() async {
        let entries = [makeEntry(fileName: "file.pdf", category: .other)]
        let result = await classifier.classify(entries, rules: [], destinationBasePath: "~/Output/")
        XCTAssertFalse(result[0].proposedDestination.contains("//"))
        XCTAssertTrue(result[0].proposedDestination.contains("/Documents/file.pdf"))
    }

    // MARK: Name Pattern is Substring Match

    func testNamePatternIsSubstringMatch() async {
        let entries = [
            makeEntry(fileName: "project_backup_2024.zip", category: .other),
        ]
        let rules = [
            FileOrganizerRule(name: "Backups", extensionPatterns: [], namePatterns: ["backup"], category: .documents),
        ]
        let result = await classifier.classify(entries, rules: rules)
        XCTAssertEqual(result[0].category, .documents)
    }

    // MARK: Large Number of Entries

    func testClassifyLargeNumberOfEntries() async {
        let entries = (0..<500).map { makeEntry(fileName: "file\($0).txt", bytes: Int64($0)) }
        let result = await classifier.classify(entries, rules: [])
        XCTAssertEqual(result.count, 500)
    }
}
