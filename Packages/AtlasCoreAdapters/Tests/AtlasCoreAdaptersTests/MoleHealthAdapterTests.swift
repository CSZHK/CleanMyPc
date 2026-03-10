import XCTest
@testable import AtlasCoreAdapters

final class MoleHealthAdapterTests: XCTestCase {
    func testCollectHealthSnapshotParsesStructuredJSON() async throws {
        let snapshot = try await MoleHealthAdapter().collectHealthSnapshot()

        XCTAssertGreaterThanOrEqual(snapshot.memoryTotalGB, 0)
        XCTAssertGreaterThan(snapshot.diskTotalGB, 0)
        XCTAssertFalse(snapshot.optimizations.isEmpty)
    }
}
