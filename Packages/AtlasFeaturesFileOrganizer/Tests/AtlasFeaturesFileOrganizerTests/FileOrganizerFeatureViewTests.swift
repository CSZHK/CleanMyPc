import AtlasDomain
import XCTest

final class FileOrganizerFeatureViewTests: XCTestCase {
    func testFileOrganizerCategoryHasExpectedCases() {
        XCTAssertEqual(FileOrganizerCategory.allCases.count, 8)
        XCTAssertTrue(FileOrganizerCategory.allCases.contains(.images))
        XCTAssertTrue(FileOrganizerCategory.allCases.contains(.documents))
        XCTAssertTrue(FileOrganizerCategory.allCases.contains(.videos))
        XCTAssertTrue(FileOrganizerCategory.allCases.contains(.audio))
        XCTAssertTrue(FileOrganizerCategory.allCases.contains(.archives))
        XCTAssertTrue(FileOrganizerCategory.allCases.contains(.code))
        XCTAssertTrue(FileOrganizerCategory.allCases.contains(.installers))
        XCTAssertTrue(FileOrganizerCategory.allCases.contains(.other))
    }

    func testFileOrganizerEntryCreation() {
        let entry = FileOrganizerEntry(
            path: "~/Desktop/test.png",
            fileName: "test.png",
            bytes: 1024,
            category: .images,
            proposedDestination: "~/Organized/Images/test.png"
        )
        XCTAssertEqual(entry.fileName, "test.png")
        XCTAssertEqual(entry.category, .images)
        XCTAssertEqual(entry.bytes, 1024)
    }

    func testFileOrganizerScanResultCreation() {
        let entries = [
            FileOrganizerEntry(path: "~/Desktop/a.png", fileName: "a.png", bytes: 100, category: .images, proposedDestination: "~/Organized/Images/a.png"),
            FileOrganizerEntry(path: "~/Desktop/b.pdf", fileName: "b.pdf", bytes: 200, category: .documents, proposedDestination: "~/Organized/Documents/b.pdf"),
        ]
        let result = FileOrganizerScanResult(entries: entries, totalFiles: 2, totalBytes: 300, categoryCounts: [.images: 1, .documents: 1])
        XCTAssertEqual(result.totalFiles, 2)
        XCTAssertEqual(result.totalBytes, 300)
        XCTAssertEqual(result.categoryCounts[.images], 1)
    }

    func testFileOrganizerMoveMappingCreation() {
        let mapping = FileOrganizerMoveMapping(originalPath: "~/Desktop/a.png", destinationPath: "~/Organized/Images/a.png")
        XCTAssertEqual(mapping.originalPath, "~/Desktop/a.png")
        XCTAssertEqual(mapping.destinationPath, "~/Organized/Images/a.png")
    }

    func testFileOrganizerRuleCreation() {
        let rule = FileOrganizerRule(
            name: "Image Files",
            extensionPatterns: ["png", "jpg"],
            category: .images
        )
        XCTAssertEqual(rule.name, "Image Files")
        XCTAssertEqual(rule.extensionPatterns, ["png", "jpg"])
        XCTAssertEqual(rule.category, .images)
        XCTAssertNil(rule.destinationSubfolder)
    }

    func testFileOrganizerRecoveryPayloadCreation() {
        let payload = FileOrganizerRecoveryPayload(
            moveMappings: [FileOrganizerMoveMapping(originalPath: "~/Desktop/a.png", destinationPath: "~/Organized/Images/a.png")],
            sourceFolder: "~/Desktop"
        )
        XCTAssertEqual(payload.moveMappings.count, 1)
        XCTAssertEqual(payload.sourceFolder, "~/Desktop")
    }

    func testRecoveryPayloadFileOrganizerEncoding() throws {
        let payload = FileOrganizerRecoveryPayload(
            moveMappings: [FileOrganizerMoveMapping(originalPath: "~/Desktop/a.png", destinationPath: "~/Organized/Images/a.png")],
            sourceFolder: "~/Desktop"
        )
        let recovery = RecoveryPayload.fileOrganizer(payload)
        let encoder = JSONEncoder()
        let data = try encoder.encode(recovery)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RecoveryPayload.self, from: data)
        if case let .fileOrganizer(decodedPayload) = decoded {
            XCTAssertEqual(decodedPayload.sourceFolder, "~/Desktop")
            XCTAssertEqual(decodedPayload.moveMappings.count, 1)
        } else {
            XCTFail("Expected fileOrganizer payload")
        }
    }

    func testAtlasRouteFileOrganizer() {
        let route = AtlasRoute.fileOrganizer
        XCTAssertEqual(route.sidebarSection, .core)
        XCTAssertTrue(route.isSidebarRoute)
        XCTAssertTrue(AtlasRoute.SidebarSection.core.routes.contains(.fileOrganizer))
    }

    func testTaskKindOrganizeFiles() {
        let kind = TaskKind.organizeFiles
        XCTAssertNotNil(kind.title)
    }

    func testActionItemKindOrganizeFile() {
        let kind = ActionItem.Kind.organizeFile
        XCTAssertEqual(kind.rawValue, "organizeFile")
    }

    func testFileOrganizerCategoryFolderNames() {
        XCTAssertEqual(FileOrganizerCategory.images.folderName, "Images")
        XCTAssertEqual(FileOrganizerCategory.documents.folderName, "Documents")
        XCTAssertEqual(FileOrganizerCategory.videos.folderName, "Videos")
        XCTAssertEqual(FileOrganizerCategory.audio.folderName, "Audio")
        XCTAssertEqual(FileOrganizerCategory.archives.folderName, "Archives")
        XCTAssertEqual(FileOrganizerCategory.code.folderName, "Code")
        XCTAssertEqual(FileOrganizerCategory.installers.folderName, "Installers")
        XCTAssertEqual(FileOrganizerCategory.other.folderName, "Other")
    }
}
