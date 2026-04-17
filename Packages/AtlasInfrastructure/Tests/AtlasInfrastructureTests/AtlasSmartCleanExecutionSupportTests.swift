import XCTest
@testable import AtlasInfrastructure
@testable import AtlasDomain
import Foundation

final class AtlasSmartCleanExecutionSupportTests: XCTestCase {

    let home = FileManager.default.homeDirectoryForCurrentUser

    // MARK: - requiresHelper

    func testRequiresHelperForSystemApplications() {
        let url = URL(fileURLWithPath: "/Applications/Xcode.app")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.requiresHelper(for: url, homeDirectoryURL: home))
    }

    func testRequiresHelperForUserApplications() {
        let url = home.appendingPathComponent("Applications/MyApp.app")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.requiresHelper(for: url, homeDirectoryURL: home))
    }

    func testRequiresHelperForLaunchAgents() {
        let url = URL(fileURLWithPath: "/Library/LaunchAgents/com.test.plist")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.requiresHelper(for: url, homeDirectoryURL: home))
    }

    func testRequiresHelperForLaunchDaemons() {
        let url = URL(fileURLWithPath: "/Library/LaunchDaemons/com.test.plist")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.requiresHelper(for: url, homeDirectoryURL: home))
    }

    func testRequiresHelperForUserLaunchAgents() {
        let url = home.appendingPathComponent("Library/LaunchAgents/com.test.plist")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.requiresHelper(for: url, homeDirectoryURL: home))
    }

    func testDoesNotRequireHelperForCachePath() {
        let url = home.appendingPathComponent("Library/Caches/com.test/cache.db")
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.requiresHelper(for: url, homeDirectoryURL: home))
    }

    // MARK: - isDirectlyTrashable

    func testCachePathIsTrashable() {
        let url = home.appendingPathComponent("Library/Caches/com.test")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    func testLogsPathIsTrashable() {
        let url = home.appendingPathComponent("Library/Logs/test.log")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    func testXcodeDerivedDataIsTrashable() {
        let url = home.appendingPathComponent("Library/Developer/Xcode/DerivedData/MyProject")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    func testNpmCacheIsTrashable() {
        let url = home.appendingPathComponent(".npm/_cacache")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    func testHomeDirectoryItselfNotTrashable() {
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(home, homeDirectoryURL: home))
    }

    func testHomeLibraryNotTrashable() {
        let url = home.appendingPathComponent("Library")
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    func testOutsideHomeNotTrashable() {
        let url = URL(fileURLWithPath: "/tmp/test")
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    func testPycFileIsTrashable() {
        let url = home.appendingPathComponent("project/module.pyc")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    func testSafeFragmentCache2IsTrashable() {
        let url = home.appendingPathComponent("Library/Application Support/Chrome/cache2")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    // MARK: - Container Cleanup

    func testContainerCacheIsTrashable() {
        let url = home.appendingPathComponent("Library/Containers/com.app/Data/Library/Caches/cache.db")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    func testContainerDataNotMatchingAllowedFragmentsNotTrashable() {
        let url = home.appendingPathComponent("Library/Containers/com.app/Data/Documents/file.txt")
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.isDirectlyTrashable(url, homeDirectoryURL: home))
    }

    // MARK: - isSupportedExecutionTarget

    func testSupportedTargetInApplications() {
        let url = URL(fileURLWithPath: "/Applications/Test.app")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(url, homeDirectoryURL: home))
    }

    func testSupportedTargetInCache() {
        let url = home.appendingPathComponent("Library/Caches/com.test")
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(url, homeDirectoryURL: home))
    }

    func testUnsupportedTarget() {
        let url = URL(fileURLWithPath: "/tmp/random")
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.isSupportedExecutionTarget(url, homeDirectoryURL: home))
    }

    // MARK: - isFindingExecutionSupported

    func testFindingWithNoTargetPathsNotSupported() {
        let finding = Finding(id: UUID(), title: "Test", detail: "", bytes: 0, risk: .safe, category: "System", targetPaths: nil)
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding, homeDirectoryURL: home))
    }

    func testFindingWithEmptyTargetPathsNotSupported() {
        let finding = Finding(id: UUID(), title: "Test", detail: "", bytes: 0, risk: .safe, category: "System", targetPaths: [])
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding, homeDirectoryURL: home))
    }

    func testFindingWithSupportedPaths() {
        let cachePath = home.appendingPathComponent("Library/Caches/com.test").path
        let finding = Finding(id: UUID(), title: "Cache", detail: "", bytes: 100, risk: .safe, category: "System", targetPaths: [cachePath])
        XCTAssertTrue(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding, homeDirectoryURL: home))
    }

    func testFindingWithMixedPathsFailsIfAnyUnsupported() {
        let cachePath = home.appendingPathComponent("Library/Caches/com.test").path
        let finding = Finding(id: UUID(), title: "Mixed", detail: "", bytes: 100, risk: .safe, category: "System", targetPaths: [cachePath, "/unsupported/path"])
        XCTAssertFalse(AtlasSmartCleanExecutionSupport.isFindingExecutionSupported(finding, homeDirectoryURL: home))
    }
}
