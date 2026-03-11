import Foundation
import XCTest
@testable import AtlasApplication

final class AtlasUpdateCheckerTests: XCTestCase {
    func testCheckForUpdateReturnsAvailableRelease() async throws {
        let checker = AtlasUpdateChecker { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://api.github.com/repos/CSZHK/CleanMyPc/releases/latest"
            )
            let body = """
            {
              "tag_name": "V1.2.3",
              "html_url": "https://github.com/CSZHK/CleanMyPc/releases/tag/V1.2.3",
              "body": "Release notes"
            }
            """
            return (
                Data(body.utf8),
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            )
        }

        let result = try await checker.checkForUpdate(currentVersion: "1.0.0")

        XCTAssertEqual(result.currentVersion, "1.0.0")
        XCTAssertEqual(result.latestVersion, "V1.2.3")
        XCTAssertEqual(result.releaseURL?.absoluteString, "https://github.com/CSZHK/CleanMyPc/releases/tag/V1.2.3")
        XCTAssertEqual(result.releaseNotes, "Release notes")
        XCTAssertTrue(result.isUpdateAvailable)
    }

    func testCheckForUpdateTreatsMissingReleaseAsUnavailable() async {
        let checker = AtlasUpdateChecker { request in
            (
                Data(),
                HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            )
        }

        do {
            _ = try await checker.checkForUpdate(currentVersion: "1.0.0")
            XCTFail("Expected missing releases to be reported explicitly")
        } catch let error as AtlasUpdateCheckerError {
            XCTAssertEqual(error, .noPublishedRelease)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCheckForUpdateMapsUnexpectedStatusToRequestFailure() async {
        let checker = AtlasUpdateChecker { request in
            (
                Data(),
                HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            )
        }

        do {
            _ = try await checker.checkForUpdate(currentVersion: "1.0.0")
            XCTFail("Expected a request failure")
        } catch let error as AtlasUpdateCheckerError {
            XCTAssertEqual(error, .requestFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
