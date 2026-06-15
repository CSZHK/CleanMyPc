import XCTest
@testable import AtlasFeaturesOverview
import AtlasApplication
import AtlasDomain
import Foundation

@MainActor
final class OverviewRecommendationTests: XCTestCase {

    // MARK: - Helpers

    private let now = Date(timeIntervalSince1970: 1_730_000_000) // stable

    private func inputs(
        granted: Int = 0,
        total: Int = 0,
        planFresh: Bool = false,
        planBytes: Int64 = 0,
        planCount: Int = 0,
        planNumber: Int? = nil,
        lastScanDate: Date? = nil,
        diskPct: Double? = nil,
        receipt: String? = nil,
        snoozed: [String: Date] = [:]
    ) -> OverviewRecommendation.Inputs {
        OverviewRecommendation.Inputs(
            requiredPermissionsGranted: granted,
            requiredPermissionsTotal: total,
            isCurrentSmartCleanPlanFresh: planFresh,
            currentPlanReclaimableBytes: planBytes,
            currentPlanFindingCount: planCount,
            currentPlanNumber: planNumber,
            lastScanDate: lastScanDate,
            diskUsedPercent: diskPct,
            latestScanReceiptCode: receipt,
            snoozedIDs: snoozed,
            now: now
        )
    }

    private func dayOffset(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    // MARK: Row 1 — permission missing (highest priority)

    func testRow1PermissionMissingBeatsEverything() {
        // Even with a fresh plan, missing permission wins.
        let out = OverviewRecommendation.recommend(inputs(
            granted: 0, total: 2,
            planFresh: true, planBytes: 1_000_000, planCount: 5, planNumber: 7,
            lastScanDate: dayOffset(1), diskPct: 95
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.permissionID)
        XCTAssertEqual(out?.primaryTarget, .authorizePermissions)
        XCTAssertFalse(out?.isSnoozeable ?? true, "permission banner is never snoozeable")
    }

    func testRow1DoesNotFireWhenAllGranted() {
        // Permissions all granted ⇒ row 1 does not fire. With a recent scan
        // and low disk, nothing else fires ⇒ all clear.
        let out = OverviewRecommendation.recommend(inputs(
            granted: 3, total: 3,
            planFresh: false, lastScanDate: dayOffset(1), diskPct: 30
        ))
        XCTAssertNil(out, "permissions OK, recent scan, low disk ⇒ all clear")
    }

    func testRow1DoesNotFireWhenNoRequiredPermissions() {
        // total == 0 means there are no required permissions to gate on.
        // With a recent scan and low disk, nothing else fires ⇒ all clear.
        let out = OverviewRecommendation.recommend(inputs(
            granted: 0, total: 0,
            planFresh: false, lastScanDate: dayOffset(1), diskPct: 30
        ))
        XCTAssertNil(out)
    }

    // MARK: Row 2 — fresh plan

    func testRow2FreshPlanBeatsScanStaleAndDisk() {
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: true, planBytes: 500_000_000, planCount: 12, planNumber: 42,
            lastScanDate: dayOffset(20), // stale, but plan beats it
            diskPct: 95
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.planID(number: 42))
        XCTAssertEqual(out?.primaryTarget, .executePlan(number: 42, reclaimableBytes: 500_000_000, findingCount: 12))
        XCTAssertTrue(out?.isSnoozeable ?? false)
    }

    func testRow2RequiresAtLeastOneFinding() {
        // Fresh plan with 0 findings is a no-op — fall through to scan/disk/clear.
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: true, planCount: 0, planNumber: 3,
            lastScanDate: dayOffset(1), diskPct: 40
        ))
        XCTAssertNil(out, "fresh plan with 0 findings is not actionable — all clear")
    }

    func testRow2UsesZeroWhenPlanNumberMissing() {
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: true, planCount: 3, planNumber: nil,
            lastScanDate: dayOffset(1), diskPct: 40
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.planID(number: nil))
        XCTAssertEqual(out?.primaryTarget, .executePlan(number: 0, reclaimableBytes: 0, findingCount: 3))
    }

    // MARK: Row 3 — no scan / stale

    func testRow3NoScanEverBeatsDisk() {
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: false,
            lastScanDate: nil,
            diskPct: 95
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.scanStaleID)
        XCTAssertEqual(out?.primaryTarget, .runScan)
    }

    func testRow3StaleScanBeyondThreshold() {
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: false,
            lastScanDate: dayOffset(8), // >7 ⇒ stale
            diskPct: 50
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.scanStaleID)
    }

    func testRow3ScanAtExactlyThresholdIsNotStale() {
        // 7 days exactly is NOT stale (the comparison is strictly >).
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: false,
            lastScanDate: dayOffset(7),
            diskPct: 50
        ))
        XCTAssertNil(out, "7-day-old scan is exactly at the threshold — all clear")
    }

    // MARK: Row 4 — disk > 85%

    func testRow4HighDiskWhenNothingElsePending() {
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: false,
            lastScanDate: dayOffset(1), // fresh
            diskPct: 90
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.diskFullID)
        XCTAssertEqual(out?.primaryTarget, .runScan)
    }

    func testRow4DiskAtExactly85DoesNotFire() {
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: false,
            lastScanDate: dayOffset(1),
            diskPct: 85 // strictly > 85 is required
        ))
        XCTAssertNil(out)
    }

    // MARK: Row 5 — all clear

    func testRow5AllClearWhenNothingPending() {
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: false,
            lastScanDate: dayOffset(1),
            diskPct: 40
        ))
        XCTAssertNil(out)
    }

    func testRow5AllClearWhenHealthSnapshotAbsent() {
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: false,
            lastScanDate: dayOffset(1),
            diskPct: nil
        ))
        XCTAssertNil(out)
    }

    // MARK: Snooze filtering

    func testSnoozedPlanFallsThroughToNextRow() {
        // Fresh plan is snoozed ⇒ falls through to disk full.
        let snoozed: [String: Date] = [
            OverviewRecommendation.planID(number: 7): now.addingTimeInterval(86_400) // 1 day future
        ]
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: true, planBytes: 1, planCount: 5, planNumber: 7,
            lastScanDate: dayOffset(1),
            diskPct: 90,
            snoozed: snoozed
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.diskFullID, "snoozed plan ⇒ fall through to disk")
    }

    func testExpiredSnoozeDoesNotFilter() {
        let snoozed: [String: Date] = [
            OverviewRecommendation.planID(number: 7): now.addingTimeInterval(-86_400) // 1 day ago
        ]
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: true, planBytes: 1, planCount: 5, planNumber: 7,
            lastScanDate: dayOffset(1), diskPct: 40,
            snoozed: snoozed
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.planID(number: 7), "expired snooze ⇒ recommendation fires")
    }

    func testPermissionBannerIsNeverSnoozed() {
        // Even if "permission" appears in the snooze table, it still fires.
        let snoozed: [String: Date] = [
            OverviewRecommendation.permissionID: now.addingTimeInterval(86_400)
        ]
        let out = OverviewRecommendation.recommend(inputs(
            granted: 0, total: 1,
            snoozed: snoozed
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.permissionID, "permission banner is unsnoozeable")
    }

    func testPlanSnoozeIsPerNumber() {
        // Snoozing plan 7 does not suppress plan 8.
        let snoozed: [String: Date] = [
            OverviewRecommendation.planID(number: 7): now.addingTimeInterval(86_400)
        ]
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: true, planBytes: 1, planCount: 5, planNumber: 8,
            lastScanDate: dayOffset(1), diskPct: 40,
            snoozed: snoozed
        ))
        XCTAssertEqual(out?.id, OverviewRecommendation.planID(number: 8))
    }

    // MARK: Pure helpers

    func testAgeInDaysNilForNil() {
        XCTAssertNil(OverviewRecommendation.ageInDays(nil, now: now))
    }

    func testAgeInDaysComputes() {
        let date = dayOffset(3.5)
        XCTAssertEqual(OverviewRecommendation.ageInDays(date, now: now) ?? 0, 3.5, accuracy: 0.01)
    }

    func testIsSnoozedRespectsExpiry() {
        let inputs = self.inputs(snoozed: ["x": now.addingTimeInterval(60)])
        XCTAssertTrue(OverviewRecommendation.isSnoozed(id: "x", inputs: inputs))
        let expiredInputs = self.inputs(snoozed: ["x": now.addingTimeInterval(-60)])
        XCTAssertFalse(OverviewRecommendation.isSnoozed(id: "x", inputs: expiredInputs))
    }

    func testConstantsMatchSpec() {
        XCTAssertEqual(OverviewRecommendation.staleScanThresholdDays, 7)
        XCTAssertEqual(OverviewRecommendation.highDiskThresholdPercent, 85.0)
        XCTAssertEqual(OverviewRecommendation.snoozeDurationDays, 7)
    }

    // MARK: Rationale timeliness stamp

    func testPlanRationaleWithReceiptContainsMonoStamp() {
        let scanDate = dayOffset(1)
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: true, planBytes: 1_000_000, planCount: 5, planNumber: 3,
            lastScanDate: scanDate,
            receipt: "ABCD"
        ))
        XCTAssertNotNil(out)
        // The rationale string must contain the receipt code (provenance).
        XCTAssertTrue(out?.rationale.contains("ABCD") ?? false, "rationale must cite the receipt code")
    }

    func testScanRationaleNeverHasNoReceiptCode() {
        let out = OverviewRecommendation.recommend(inputs(
            granted: 1, total: 1,
            planFresh: false,
            lastScanDate: nil,
            diskPct: 50
        ))
        XCTAssertNotNil(out)
        // The "never scanned" rationale is a fixed string — just verify it's non-empty.
        XCTAssertFalse(out?.rationale.isEmpty ?? true)
    }
}

// MARK: - Tone derivation (pure — for OverviewCommandColumn)

final class OverviewCommandColumnToneTests: XCTestCase {

    func testToneNeutralForZeroOrNoData() {
        XCTAssertEqual(OverviewCommandColumn.tone(forDiskPercent: 0), .neutral)
    }

    func testToneSuccessBelow85() {
        XCTAssertEqual(OverviewCommandColumn.tone(forDiskPercent: 30), .success)
        XCTAssertEqual(OverviewCommandColumn.tone(forDiskPercent: 84.9), .success)
    }

    func testToneWarningBetween85And95() {
        XCTAssertEqual(OverviewCommandColumn.tone(forDiskPercent: 85), .warning)
        XCTAssertEqual(OverviewCommandColumn.tone(forDiskPercent: 94.9), .warning)
    }

    func testToneDangerAbove95() {
        XCTAssertEqual(OverviewCommandColumn.tone(forDiskPercent: 95), .danger)
        XCTAssertEqual(OverviewCommandColumn.tone(forDiskPercent: 99), .danger)
    }
}
