import XCTest
@testable import AtlasPrivilegedHelperCore
import AtlasProtocol

final class AtlasPrivilegedHelperTests: XCTestCase {
    func testRepairOwnershipSucceedsForAllowedCurrentUserFile() throws {
        let root = makeAllowedRoot()
        let fileURL = root.appendingPathComponent("Sample.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("sample".utf8).write(to: fileURL)

        let executor = AtlasPrivilegedHelperActionExecutor(allowedRoots: [root.path])
        let result = try executor.perform(AtlasHelperAction(kind: .repairOwnership, targetPath: fileURL.path))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.resolvedPath, fileURL.path)
    }

    func testRestoreItemMovesTrashedFileBackToAllowedDestination() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
        let root = home.appendingPathComponent("Applications", isDirectory: true)
        let sourceURL = trash.appendingPathComponent("Sample.app", isDirectory: true)
        let destinationURL = root.appendingPathComponent("Sample.app", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let executor = AtlasPrivilegedHelperActionExecutor(allowedRoots: [root.path], homeDirectoryURL: home)
        let result = try executor.perform(AtlasHelperAction(kind: .restoreItem, targetPath: sourceURL.path, destinationPath: destinationURL.path))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.resolvedPath, destinationURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
    }

    func testRemoveLaunchServiceRejectsNonPlistPath() throws {
        let root = makeAllowedRoot()
        let fileURL = root.appendingPathComponent("not-a-plist.txt")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("sample".utf8).write(to: fileURL)

        let executor = AtlasPrivilegedHelperActionExecutor(allowedRoots: [root.path])

        XCTAssertThrowsError(try executor.perform(AtlasHelperAction(kind: .removeLaunchService, targetPath: fileURL.path)))
    }

    private func makeAllowedRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
