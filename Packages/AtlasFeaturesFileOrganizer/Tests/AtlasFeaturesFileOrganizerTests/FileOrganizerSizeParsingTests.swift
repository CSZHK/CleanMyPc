@testable import AtlasFeaturesFileOrganizer
import XCTest

/// FileOrganizerSizeParsing.bytes(fromMB:) — rule size-band parsing (audit #6
/// + final-audit test gap). Pins the Int64 clamp (no trap on huge input) and
/// the nil-on-invalid contract.
final class FileOrganizerSizeParsingTests: XCTestCase {
    func testParsesPositiveMB() {
        XCTAssertEqual(FileOrganizerSizeParsing.bytes(fromMB: "1"), 1_048_576)
        XCTAssertEqual(FileOrganizerSizeParsing.bytes(fromMB: "0.5"), 524_288)
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(FileOrganizerSizeParsing.bytes(fromMB: "  2  "), 2_097_152)
    }

    func testNonNumericReturnsNil() {
        XCTAssertNil(FileOrganizerSizeParsing.bytes(fromMB: "abc"))
        XCTAssertNil(FileOrganizerSizeParsing.bytes(fromMB: ""))
    }

    func testNonPositiveReturnsNil() {
        XCTAssertNil(FileOrganizerSizeParsing.bytes(fromMB: "0"))
        XCTAssertNil(FileOrganizerSizeParsing.bytes(fromMB: "-5"))
    }

    func testHugeValueClampsToInt64MaxNoTrap() {
        // Must not trap and must clamp rather than wrap.
        let result = FileOrganizerSizeParsing.bytes(fromMB: "100000000000000000000")
        XCTAssertEqual(result, Int64.max)
    }
}
