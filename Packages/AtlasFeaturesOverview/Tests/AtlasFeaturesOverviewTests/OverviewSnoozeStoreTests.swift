import XCTest
@testable import AtlasFeaturesOverview
import Foundation

@MainActor
final class OverviewSnoozeStoreTests: XCTestCase {

    // MARK: - Isolated UserDefaults suite (does NOT touch .standard)

    /// A per-test UserDefaults suite that is wiped on tearDown. The store keys
    /// are namespaced `atlas.overview.snooze.*`, so this isolates the writes
    /// from any other test or the real app.
    private var suiteName: String = ""
    private var suite: UserDefaults!
    private var store: OverviewUserDefaultsSnoozeStore!

    private let now = Date(timeIntervalSince1970: 1_730_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "atlas.test.overview.snooze.\(UUID().uuidString)"
        UserDefaults().removePersistentDomain(forName: suiteName)
        suite = UserDefaults(suiteName: suiteName)!
        store = OverviewUserDefaultsSnoozeStore(defaults: suite)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        suite = nil
        store = nil
        super.tearDown()
    }

    // MARK: Tests

    func testEmptyStoreReturnsNoActiveSnoozes() {
        XCTAssertEqual(store.activeSnoozes(now: now).count, 0)
    }

    func testSnoozeWritesAndReadsBack() {
        store.snooze(id: "plan.7", durationDays: 7, now: now)
        let active = store.activeSnoozes(now: now)
        XCTAssertEqual(active.count, 1)
        XCTAssertNotNil(active["plan.7"])
        // Expiry is 7 days in the future.
        let expected = now.addingTimeInterval(7 * 86_400)
        XCTAssertEqual(active["plan.7"]?.timeIntervalSince1970 ?? 0, expected.timeIntervalSince1970, accuracy: 1)
    }

    func testSnoozeOverwritesPriorValue() {
        store.snooze(id: "x", durationDays: 7, now: now)
        store.snooze(id: "x", durationDays: 1, now: now)
        let active = store.activeSnoozes(now: now)
        XCTAssertEqual(active.count, 1)
        let expected = now.addingTimeInterval(1 * 86_400)
        XCTAssertEqual(active["x"]?.timeIntervalSince1970 ?? 0, expected.timeIntervalSince1970, accuracy: 1)
    }

    func testActiveSnoozesPrunesExpired() {
        // Snooze 1 day in the PAST — already expired.
        store.snooze(id: "expired", durationDays: -1, now: now)
        let active = store.activeSnoozes(now: now)
        XCTAssertEqual(active.count, 0, "expired snoozes must be pruned on read")
        // The underlying key should also be removed.
        XCTAssertNil(suite.object(forKey: OverviewUserDefaultsSnoozeStore.keyPrefix + "expired"))
    }

    func testClearRemovesEntry() {
        store.snooze(id: "plan.7", durationDays: 7, now: now)
        store.clear(id: "plan.7")
        XCTAssertEqual(store.activeSnoozes(now: now).count, 0)
        XCTAssertNil(suite.object(forKey: OverviewUserDefaultsSnoozeStore.keyPrefix + "plan.7"))
    }

    func testKeyPrefixMatchesSpec() {
        XCTAssertEqual(OverviewUserDefaultsSnoozeStore.keyPrefix, "atlas.overview.snooze.")
    }

    func testMultipleActiveSnoozes() {
        store.snooze(id: "plan.1", durationDays: 7, now: now)
        store.snooze(id: "plan.2", durationDays: 3, now: now)
        store.snooze(id: "scan.stale", durationDays: 7, now: now)
        let active = store.activeSnoozes(now: now)
        XCTAssertEqual(active.count, 3)
        XCTAssertNotNil(active["plan.1"])
        XCTAssertNotNil(active["plan.2"])
        XCTAssertNotNil(active["scan.stale"])
    }
}
