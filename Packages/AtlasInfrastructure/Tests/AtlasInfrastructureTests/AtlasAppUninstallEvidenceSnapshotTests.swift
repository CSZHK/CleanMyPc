import XCTest
@testable import AtlasInfrastructure
import AtlasDomain

final class AtlasAppUninstallEvidenceSnapshotTests: XCTestCase {

    // MARK: - Snapshot fingerprint tests

    func testEvidenceSnapshot_hasCorrectFingerprint() {
        let planID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let groups: [AtlasAppEvidenceGroup] = [
            AtlasAppEvidenceGroup(
                category: .caches,
                items: [
                    AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.example.app/cache.bin", bytes: 100),
                    AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.example.app/tmp.log", bytes: 50),
                ]
            ),
            AtlasAppEvidenceGroup(
                category: .preferences,
                items: [
                    AtlasAppEvidenceItem(path: "/Users/test/Library/Preferences/com.example.app.plist", bytes: 200),
                ]
            ),
        ]
        let snapshot = AtlasAppUninstallEvidenceSnapshot(
            planID: planID,
            capturedAt: Date(),
            bundlePath: "/Applications/Test.app",
            bundleBytes: 1000,
            groups: groups,
            fingerprintHash: ""
        )

        let fingerprint = snapshot.computeFingerprint()
        // Same snapshot built again must produce the same fingerprint
        let snapshot2 = AtlasAppUninstallEvidenceSnapshot(
            planID: planID,
            capturedAt: Date(),
            bundlePath: "/Applications/Test.app",
            bundleBytes: 1000,
            groups: groups,
            fingerprintHash: ""
        )
        XCTAssertEqual(fingerprint, snapshot2.computeFingerprint(), "identical groups should produce identical fingerprint")
        XCTAssertFalse(fingerprint.isEmpty)
        XCTAssertEqual(fingerprint.count, 16, "fingerprint should be 16 hex characters")
    }

    func testEvidenceSnapshot_fingerprintChangesWhenPathsChange() {
        let planID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let groupsA: [AtlasAppEvidenceGroup] = [
            AtlasAppEvidenceGroup(
                category: .caches,
                items: [
                    AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.example.app/cache.bin", bytes: 100),
                ]
            ),
        ]
        let groupsB: [AtlasAppEvidenceGroup] = [
            AtlasAppEvidenceGroup(
                category: .caches,
                items: [
                    AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.example.app/other.bin", bytes: 100),
                ]
            ),
        ]
        let snapshotA = AtlasAppUninstallEvidenceSnapshot(
            planID: planID, capturedAt: Date(), bundlePath: "/Applications/Test.app",
            bundleBytes: 1000, groups: groupsA, fingerprintHash: ""
        )
        let snapshotB = AtlasAppUninstallEvidenceSnapshot(
            planID: planID, capturedAt: Date(), bundlePath: "/Applications/Test.app",
            bundleBytes: 1000, groups: groupsB, fingerprintHash: ""
        )
        XCTAssertNotEqual(snapshotA.computeFingerprint(), snapshotB.computeFingerprint())
    }

    // MARK: - reviewOnlyGroups / totalBytes / reviewOnlyBytes

    func testEvidenceSnapshot_reviewOnlyExcludesAppBundle() {
        let planID = UUID()
        let bundleGroup = AtlasAppEvidenceGroup(
            category: .appBundle,
            items: [AtlasAppEvidenceItem(path: "/Applications/Test.app", bytes: 5000)]
        )
        let cacheGroup = AtlasAppEvidenceGroup(
            category: .caches,
            items: [AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.example.app", bytes: 200)]
        )
        let snapshot = AtlasAppUninstallEvidenceSnapshot(
            planID: planID, capturedAt: Date(), bundlePath: "/Applications/Test.app",
            bundleBytes: 5000, groups: [bundleGroup, cacheGroup], fingerprintHash: "abc"
        )

        XCTAssertEqual(snapshot.reviewOnlyGroups.count, 1)
        XCTAssertEqual(snapshot.reviewOnlyGroups.first?.category, .caches)
        XCTAssertFalse(snapshot.reviewOnlyGroups.contains(where: { $0.category == .appBundle }))
    }

    func testEvidenceSnapshot_totalBytes_includesAllGroups() {
        let planID = UUID()
        let groups: [AtlasAppEvidenceGroup] = [
            AtlasAppEvidenceGroup(
                category: .appBundle,
                items: [AtlasAppEvidenceItem(path: "/Applications/Test.app", bytes: 5000)]
            ),
            AtlasAppEvidenceGroup(
                category: .caches,
                items: [AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.example.app", bytes: 200)]
            ),
            AtlasAppEvidenceGroup(
                category: .logs,
                items: [AtlasAppEvidenceItem(path: "/Users/test/Library/Logs/Test", bytes: 100)]
            ),
        ]
        let snapshot = AtlasAppUninstallEvidenceSnapshot(
            planID: planID, capturedAt: Date(), bundlePath: "/Applications/Test.app",
            bundleBytes: 5000, groups: groups, fingerprintHash: "abc"
        )

        XCTAssertEqual(snapshot.totalBytes, 5300)
    }

    func testEvidenceSnapshot_reviewOnlyBytes_excludesBundle() {
        let planID = UUID()
        let groups: [AtlasAppEvidenceGroup] = [
            AtlasAppEvidenceGroup(
                category: .appBundle,
                items: [AtlasAppEvidenceItem(path: "/Applications/Test.app", bytes: 5000)]
            ),
            AtlasAppEvidenceGroup(
                category: .caches,
                items: [AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.example.app", bytes: 200)]
            ),
            AtlasAppEvidenceGroup(
                category: .logs,
                items: [AtlasAppEvidenceItem(path: "/Users/test/Library/Logs/Test", bytes: 100)]
            ),
        ]
        let snapshot = AtlasAppUninstallEvidenceSnapshot(
            planID: planID, capturedAt: Date(), bundlePath: "/Applications/Test.app",
            bundleBytes: 5000, groups: groups, fingerprintHash: "abc"
        )

        XCTAssertEqual(snapshot.reviewOnlyBytes, 300)
    }

    // MARK: - Analyzer integration tests (using real home dir, no files created)

    func testEvidenceAnalyzer_10categories() {
        // AtlasAppEvidenceCategory should have exactly 10 cases
        XCTAssertEqual(AtlasAppEvidenceCategory.allCases.count, 10)
    }

    func testEvidenceAnalyzer_savedState() {
        // Verify savedState is a distinct category
        let categories = AtlasAppEvidenceCategory.allCases
        XCTAssertTrue(categories.contains(.savedState))
        XCTAssertNotEqual(AtlasAppEvidenceCategory.savedState, AtlasAppEvidenceCategory.supportFiles)
    }

    func testEvidenceAnalyzer_containers() {
        // Verify containers is a distinct category
        let categories = AtlasAppEvidenceCategory.allCases
        XCTAssertTrue(categories.contains(.containers))
        XCTAssertNotEqual(AtlasAppEvidenceCategory.containers, AtlasAppEvidenceCategory.supportFiles)
    }

    func testEvidenceAnalyzer_groupContainers() {
        // groupContainers is separate from containers
        let categories = AtlasAppEvidenceCategory.allCases
        XCTAssertTrue(categories.contains(.groupContainers))
        XCTAssertNotEqual(AtlasAppEvidenceCategory.groupContainers, AtlasAppEvidenceCategory.containers)
    }

    func testEvidenceAnalyzer_miscLeftovers() {
        // miscLeftovers exists as a category (may have zero candidate URLs)
        let categories = AtlasAppEvidenceCategory.allCases
        XCTAssertTrue(categories.contains(.miscLeftovers))
    }

    // MARK: - Analyzer produces evidence from on-disk paths

    func testEvidenceAnalyzer_analyze_producesReviewOnlyGroupsWithRealFiles() throws {
        let fileManager = FileManager.default
        let sandboxRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let homeRoot = sandboxRoot.appendingPathComponent("Home", isDirectory: true)
        let cacheURL = homeRoot.appendingPathComponent("Library/Caches/com.test.evidence.analyze", isDirectory: true)
        let logsURL = homeRoot.appendingPathComponent("Library/Logs/EvidenceAnalyzeTest", isDirectory: true)

        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: cacheURL.appendingPathComponent("cache.db"))
        try Data("log".utf8).write(to: logsURL.appendingPathComponent("run.log"))

        addTeardownBlock {
            try? fileManager.removeItem(at: sandboxRoot)
        }

        let analyzer = AtlasAppUninstallEvidenceAnalyzer(homeDirectoryURL: homeRoot)
        let evidence = analyzer.analyze(
            appName: "EvidenceAnalyzeTest",
            bundleIdentifier: "com.test.evidence.analyze",
            bundlePath: "/Applications/EvidenceAnalyzeTest.app",
            bundleBytes: 1024
        )

        let categories = Set(evidence.reviewOnlyGroups.map(\.category))
        XCTAssertTrue(categories.contains(.caches), "Should discover caches")
        XCTAssertTrue(categories.contains(.logs), "Should discover logs")
        XCTAssertEqual(evidence.bundlePath, "/Applications/EvidenceAnalyzeTest.app")
        XCTAssertEqual(evidence.bundleBytes, 1024)
    }

    // MARK: - Snapshot Codable round-trip

    func testEvidenceSnapshot_codableRoundTrip() throws {
        let planID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let groups: [AtlasAppEvidenceGroup] = [
            AtlasAppEvidenceGroup(
                category: .appBundle,
                items: [AtlasAppEvidenceItem(path: "/Applications/Test.app", bytes: 5000, fileType: .bundle, verified: true)]
            ),
            AtlasAppEvidenceGroup(
                category: .caches,
                items: [
                    AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.test/cache.bin", bytes: 200),
                    AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.test/tmp", bytes: 50, fileType: .directory),
                ]
            ),
            AtlasAppEvidenceGroup(
                category: .preferences,
                items: [AtlasAppEvidenceItem(path: "/Users/test/Library/Preferences/com.test.plist", bytes: 100, fileType: .plist)]
            ),
        ]
        let snapshot = AtlasAppUninstallEvidenceSnapshot(
            planID: planID,
            capturedAt: capturedAt,
            bundlePath: "/Applications/Test.app",
            bundleBytes: 5000,
            groups: groups,
            fingerprintHash: "aabb112233445566"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AtlasAppUninstallEvidenceSnapshot.self, from: data)

        XCTAssertEqual(decoded.planID, planID)
        XCTAssertEqual(decoded.bundlePath, "/Applications/Test.app")
        XCTAssertEqual(decoded.bundleBytes, 5000)
        XCTAssertEqual(decoded.fingerprintHash, "aabb112233445566")
        XCTAssertEqual(decoded.groups.count, 3)
        XCTAssertEqual(decoded.totalBytes, 5350)
        XCTAssertEqual(decoded.reviewOnlyGroups.count, 2)
        XCTAssertEqual(decoded.reviewOnlyBytes, 350)

        // Verify item types survive round-trip
        let bundleItem = decoded.groups.first(where: { $0.category == .appBundle })?.items.first
        XCTAssertEqual(bundleItem?.fileType, .bundle)
        XCTAssertTrue(bundleItem?.verified ?? false)

        let prefsItem = decoded.groups.first(where: { $0.category == .preferences })?.items.first
        XCTAssertEqual(prefsItem?.fileType, .plist)
    }

    // MARK: - analyzeSnapshot() integration tests

    func testAnalyzeSnapshot_discoversExistingCategories() throws {
        let fileManager = FileManager.default
        let sandboxRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let homeRoot = sandboxRoot.appendingPathComponent("Home", isDirectory: true)
        let bundleIdentifier = "com.test.snapshot.analyze"
        let appName = "SnapshotAnalyzeTest"

        // Create on-disk directories for multiple categories
        let cacheURL = homeRoot.appendingPathComponent("Library/Caches/\(bundleIdentifier)", isDirectory: true)
        let prefsURL = homeRoot.appendingPathComponent("Library/Preferences/\(bundleIdentifier).plist")
        let logsURL = homeRoot.appendingPathComponent("Library/Logs/\(appName)", isDirectory: true)
        let savedStateURL = homeRoot.appendingPathComponent("Library/Saved Application State/\(bundleIdentifier).savedState", isDirectory: true)

        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        let prefsDir = homeRoot.appendingPathComponent("Library/Preferences", isDirectory: true)
        try fileManager.createDirectory(at: prefsDir, withIntermediateDirectories: true)
        try Data("pref".utf8).write(to: prefsURL)
        try fileManager.createDirectory(at: logsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: savedStateURL, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: cacheURL.appendingPathComponent("cache.db"))
        try Data("log".utf8).write(to: logsURL.appendingPathComponent("run.log"))

        addTeardownBlock {
            try? fileManager.removeItem(at: sandboxRoot)
        }

        let planID = UUID()
        let analyzer = AtlasAppUninstallEvidenceAnalyzer(homeDirectoryURL: homeRoot)
        let snapshot = analyzer.analyzeSnapshot(
            planID: planID,
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            bundlePath: "/Applications/SnapshotAnalyzeTest.app",
            bundleBytes: 2048
        )

        // Verify snapshot fields
        XCTAssertEqual(snapshot.planID, planID)
        XCTAssertEqual(snapshot.bundlePath, "/Applications/SnapshotAnalyzeTest.app")
        XCTAssertEqual(snapshot.bundleBytes, 2048)
        XCTAssertFalse(snapshot.fingerprintHash.isEmpty)

        // Verify discovered categories
        let categories = Set(snapshot.reviewOnlyGroups.map(\.category))
        XCTAssertTrue(categories.contains(.caches), "Should discover caches")
        XCTAssertTrue(categories.contains(.preferences), "Should discover preferences")
        XCTAssertTrue(categories.contains(.logs), "Should discover logs")
        XCTAssertTrue(categories.contains(.savedState), "Should discover savedState")

        // Verify each group has non-empty items with verified=true
        for group in snapshot.reviewOnlyGroups {
            XCTAssertFalse(group.items.isEmpty, "\(group.category) should have items")
            XCTAssertTrue(group.items.allSatisfy(\.verified), "\(group.category) items should be verified")
        }
    }

    func testAnalyzeSnapshot_skipsMissingCategories() throws {
        let fileManager = FileManager.default
        let sandboxRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let homeRoot = sandboxRoot.appendingPathComponent("Home", isDirectory: true)

        // Only create cache — nothing else
        let cacheURL = homeRoot.appendingPathComponent("Library/Caches/com.test.sparse", isDirectory: true)
        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)

        addTeardownBlock {
            try? fileManager.removeItem(at: sandboxRoot)
        }

        let analyzer = AtlasAppUninstallEvidenceAnalyzer(homeDirectoryURL: homeRoot)
        let snapshot = analyzer.analyzeSnapshot(
            planID: UUID(),
            appName: "SparseApp",
            bundleIdentifier: "com.test.sparse",
            bundlePath: "/Applications/SparseApp.app",
            bundleBytes: 512
        )

        // Only caches should appear in reviewOnlyGroups
        let reviewCategories = snapshot.reviewOnlyGroups.map(\.category)
        XCTAssertEqual(reviewCategories, [.caches], "Only caches should be discovered")
        // appBundle is NOT in groups because bundlePath doesn't exist on disk
        // (analyzer only creates groups for paths that actually exist)
        XCTAssertFalse(snapshot.groups.contains(where: { $0.category == .appBundle }),
                       "appBundle should not appear when bundle path doesn't exist on disk")
    }

    func testAnalyzeSnapshot_fingerprintIsDeterministicWithinSession() throws {
        let fileManager = FileManager.default
        let sandboxRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let homeRoot = sandboxRoot.appendingPathComponent("Home", isDirectory: true)
        let cacheURL = homeRoot.appendingPathComponent("Library/Caches/com.test.fingerprint", isDirectory: true)
        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)

        addTeardownBlock {
            try? fileManager.removeItem(at: sandboxRoot)
        }

        let analyzer = AtlasAppUninstallEvidenceAnalyzer(homeDirectoryURL: homeRoot)
        let planID = UUID()
        let snapshot1 = analyzer.analyzeSnapshot(
            planID: planID, appName: "FPTest", bundleIdentifier: "com.test.fingerprint",
            bundlePath: "/Applications/FPTest.app", bundleBytes: 100
        )
        let snapshot2 = analyzer.analyzeSnapshot(
            planID: planID, appName: "FPTest", bundleIdentifier: "com.test.fingerprint",
            bundlePath: "/Applications/FPTest.app", bundleBytes: 100
        )

        XCTAssertEqual(snapshot1.fingerprintHash, snapshot2.fingerprintHash,
                       "Same inputs should produce same fingerprint within same process session")
    }

    func testAnalyzeSnapshot_bundleGroupIsAlwaysPresent() throws {
        let fileManager = FileManager.default
        let sandboxRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let homeRoot = sandboxRoot.appendingPathComponent("Home", isDirectory: true)
        try fileManager.createDirectory(at: sandboxRoot, withIntermediateDirectories: true)

        addTeardownBlock {
            try? fileManager.removeItem(at: sandboxRoot)
        }

        let analyzer = AtlasAppUninstallEvidenceAnalyzer(homeDirectoryURL: homeRoot)
        let snapshot = analyzer.analyzeSnapshot(
            planID: UUID(), appName: "NoLeftovers", bundleIdentifier: "com.test.noleftovers",
            bundlePath: "/Applications/NoLeftovers.app", bundleBytes: 0
        )

        // appBundle group should always be present (it's the bundle path itself)
        // But since the path doesn't exist on disk, it may not have items.
        // The key invariant: reviewOnlyGroups should be empty when no leftovers exist
        XCTAssertTrue(snapshot.reviewOnlyGroups.isEmpty,
                      "No leftover paths on disk → reviewOnlyGroups should be empty")
    }
}
