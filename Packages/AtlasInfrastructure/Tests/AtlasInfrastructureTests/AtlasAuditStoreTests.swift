import XCTest
@testable import AtlasInfrastructure

final class AtlasAuditStoreTests: XCTestCase {

    // MARK: - Empty State

    func testEmptyStoreReturnsEmptyEntries() async {
        let store = AtlasAuditStore()
        let entries = await store.allEntries()
        XCTAssertTrue(entries.isEmpty, "New store should have no entries")
    }

    // MARK: - Append

    func testAppendInsertsEntry() async {
        let store = AtlasAuditStore()
        await store.append("test message")
        let entries = await store.allEntries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].message, "test message")
    }

    func testAppendInsertsNewestFirst() async {
        let store = AtlasAuditStore()
        await store.append("first")
        await store.append("second")
        await store.append("third")
        let entries = await store.allEntries()
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].message, "third")
        XCTAssertEqual(entries[1].message, "second")
        XCTAssertEqual(entries[2].message, "first")
    }

    // MARK: - Max Entries Eviction

    func testMaxEntriesEvictsOldest() async {
        let store = AtlasAuditStore(maxEntries: 3)
        await store.append("a")
        await store.append("b")
        await store.append("c")
        await store.append("d")
        let entries = await store.allEntries()
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].message, "d")
        XCTAssertEqual(entries[1].message, "c")
        XCTAssertEqual(entries[2].message, "b")
    }

    func testMaxEntriesDefaultIs512() async {
        let store = AtlasAuditStore()
        for i in 0..<600 {
            await store.append("entry-\(i)")
        }
        let entries = await store.allEntries()
        XCTAssertEqual(entries.count, 512)
        XCTAssertEqual(entries[0].message, "entry-599")
        XCTAssertEqual(entries[511].message, "entry-88")
    }

    // MARK: - Pre-populated Init

    func testInitWithPrePopulatedEntries() async {
        let initial = [
            AuditEntry(message: "a"),
            AuditEntry(message: "b"),
        ]
        let store = AtlasAuditStore(entries: initial, maxEntries: 10)
        let entries = await store.allEntries()
        XCTAssertEqual(entries.count, 2)
    }

    // MARK: - AuditEntry

    func testAuditEntryAutoGeneratesID() {
        let entry = AuditEntry(message: "test")
        XCTAssertNotEqual(entry.id, UUID())
        XCTAssertFalse(entry.message.isEmpty)
    }

    func testAuditEntryCustomValues() {
        let id = UUID()
        let date = Date.distantPast
        let entry = AuditEntry(id: id, createdAt: date, message: "custom")
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.createdAt, date)
        XCTAssertEqual(entry.message, "custom")
    }

    func testAuditEntryHashableAndIdentifiable() {
        let id = UUID()
        let a = AuditEntry(id: id, createdAt: .distantPast, message: "x")
        let b = AuditEntry(id: id, createdAt: .distantPast, message: "x")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }
}
