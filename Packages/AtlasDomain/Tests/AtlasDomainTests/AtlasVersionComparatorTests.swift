import XCTest
@testable import AtlasDomain

final class AtlasVersionComparatorTests: XCTestCase {

    func testEqualVersions() {
        XCTAssertEqual(
            AtlasVersionComparator.compare("1.0.0", "1.0.0"),
            .orderedSame
        )
    }

    func testPrefixVIsStripped() {
        XCTAssertEqual(
            AtlasVersionComparator.compare("V1.0.0", "1.0.0"),
            .orderedSame
        )
    }

    func testLowercaseVPrefix() {
        XCTAssertEqual(
            AtlasVersionComparator.compare("v1.0.0", "1.0.0"),
            .orderedSame
        )
    }

    func testNewerPatchVersion() {
        XCTAssertTrue(
            AtlasVersionComparator.isNewer("1.0.1", than: "1.0.0")
        )
    }

    func testNewerMinorVersion() {
        XCTAssertTrue(
            AtlasVersionComparator.isNewer("1.1.0", than: "1.0.0")
        )
    }

    func testNewerMajorVersion() {
        XCTAssertTrue(
            AtlasVersionComparator.isNewer("2.0.0", than: "1.99.99")
        )
    }

    func testVPrefixNewerThanCurrent() {
        XCTAssertTrue(
            AtlasVersionComparator.isNewer("V1.30.0", than: "1.0.0")
        )
    }

    func testVPrefixOlderThanCurrent() {
        XCTAssertFalse(
            AtlasVersionComparator.isNewer("V1.0.0", than: "1.0.1")
        )
    }

    func testBothVPrefixed() {
        XCTAssertTrue(
            AtlasVersionComparator.isNewer("V2.0.0", than: "V1.99.99")
        )
    }

    func testSameVersionIsNotNewer() {
        XCTAssertFalse(
            AtlasVersionComparator.isNewer("1.0.0", than: "1.0.0")
        )
    }

    func testTwoComponentVersion() {
        XCTAssertTrue(
            AtlasVersionComparator.isNewer("1.1", than: "1.0")
        )
    }

    func testMismatchedComponentCount() {
        XCTAssertTrue(
            AtlasVersionComparator.isNewer("1.0.1", than: "1.0")
        )
    }
}
