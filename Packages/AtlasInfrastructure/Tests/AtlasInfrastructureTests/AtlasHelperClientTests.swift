import XCTest
@testable import AtlasInfrastructure
import AtlasProtocol

final class AtlasHelperClientTests: XCTestCase {
    func testHelperClientDecodesStructuredJSONResponse() async throws {
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let script = "#!/bin/sh\ncat >/dev/null\nprintf '%s' '{\"action\":{\"id\":\"00000000-0000-0000-0000-000000000111\",\"kind\":\"trashItems\",\"targetPath\":\"/Applications/Sample.app\"},\"message\":\"ok\",\"resolvedPath\":\"/Trash/Sample.app\",\"success\":true}'\n"
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let client = AtlasPrivilegedHelperClient(executableURL: scriptURL)
        let result = try await client.perform(AtlasHelperAction(kind: .trashItems, targetPath: "/Applications/Sample.app"))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "ok")
        XCTAssertEqual(result.resolvedPath, "/Trash/Sample.app")
    }
}
