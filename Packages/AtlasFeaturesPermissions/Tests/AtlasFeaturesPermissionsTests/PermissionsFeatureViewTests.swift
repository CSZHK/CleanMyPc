import XCTest
import AtlasDomain
@testable import AtlasFeaturesPermissions
@testable import AtlasFeaturesPermissions
import AtlasDomain

@MainActor
final class PermissionsFeatureViewTests: XCTestCase {

    // MARK: - View Initialization

    func testDefaultInitUsesFixtureData() {
        let view = PermissionsFeatureView()
        XCTAssertNotNil(view, "PermissionsFeatureView should initialize with default fixture data")
    }

    func testInitWithEmptyPermissions() {
        let view = PermissionsFeatureView(permissionStates: [])
        XCTAssertNotNil(view)
    }

    func testInitWithAllGranted() {
        let permissions = [
            PermissionState(kind: .fullDiskAccess, isGranted: true, rationale: "Full disk access granted"),
            PermissionState(kind: .accessibility, isGranted: true, rationale: "Accessibility granted"),
            PermissionState(kind: .notifications, isGranted: true, rationale: "Notifications granted"),
        ]
        let view = PermissionsFeatureView(permissionStates: permissions)
        XCTAssertNotNil(view)
    }

    func testInitWithNoneGranted() {
        let permissions = [
            PermissionState(kind: .fullDiskAccess, isGranted: false, rationale: "Needed for scanning"),
            PermissionState(kind: .accessibility, isGranted: false, rationale: "Needed for cleanup"),
            PermissionState(kind: .notifications, isGranted: false, rationale: "Optional"),
        ]
        let view = PermissionsFeatureView(permissionStates: permissions)
        XCTAssertNotNil(view)
    }

    func testInitWithRefreshingState() {
        let view = PermissionsFeatureView(isRefreshing: true)
        XCTAssertNotNil(view)
    }

    // MARK: - Callbacks

    func testCallbackActionsCanBeStored() {
        var refreshTriggered = false
        var notificationTriggered = false

        let view = PermissionsFeatureView(
            onRefresh: { refreshTriggered = true },
            onRequestNotificationPermission: { notificationTriggered = true }
        )
        XCTAssertNotNil(view)
        XCTAssertFalse(refreshTriggered)
        XCTAssertFalse(notificationTriggered)
    }

    // MARK: - Data Variations

    func testInitWithPartialPermissions() {
        let permissions = [
            PermissionState(kind: .fullDiskAccess, isGranted: true, rationale: "Granted"),
            PermissionState(kind: .accessibility, isGranted: false, rationale: "Not granted"),
            PermissionState(kind: .notifications, isGranted: true, rationale: "Granted"),
        ]
        let view = PermissionsFeatureView(permissionStates: permissions)
        XCTAssertNotNil(view)
    }

    func testInitWithCustomSummary() {
        let view = PermissionsFeatureView(summary: "Custom summary text")
        XCTAssertNotNil(view)
    }

    func testInitWithOnlyNotifications() {
        let permissions = [
            PermissionState(kind: .notifications, isGranted: false, rationale: "Optional"),
        ]
        let view = PermissionsFeatureView(permissionStates: permissions)
        XCTAssertNotNil(view)
    }
}


/// `I-8`：同一计数在相邻两处不得给出相反结论。
///
/// 载体拆两半（规格 §7 的裁定）：**模型单测**断言两处渲染同源于一个值
/// —— 口径是否一致是模型层事实，UI 层读不到；`AtlasAppUITests` 只断言
/// 两个文案键在相邻两处仍都渲染。
///
/// 审计 `P1-4` 的原始形状：卡片标题「暂不需要」配缺失计数，列表写「N 项待处理」
/// —— 两处各自计算、结论相反。
final class PermissionsSummaryMetricsTests: XCTestCase {
    private func state(_ kind: PermissionKind, granted: Bool) -> PermissionState {
        PermissionState(kind: kind, isGranted: granted, rationale: "r")
    }

    func testOptionalMissingCountCountsOnlyNonRequiredUngranted() {
        let states = [
            state(.fullDiskAccess, granted: false),   // 必需
            state(.accessibility, granted: false),    // 可稍后
            state(.notifications, granted: true),     // 可稍后但已授予
        ]
        XCTAssertEqual(
            PermissionsSummaryMetrics.optionalMissingCount(states),
            1,
            "只应计入**非必需且未授予**的权限 —— 卡片值与列表计数都由这一个数派生"
        )
    }

    /// 卡片值「N 个」与列表「N 个权限可稍后授权」必须给出**同一个 N**。
    func testBothSurfacesShareOneSourceValue() {
        let states = [
            state(.fullDiskAccess, granted: true),
            state(.accessibility, granted: false),
            state(.notifications, granted: false),
        ]
        let n = PermissionsSummaryMetrics.optionalMissingCount(states)
        XCTAssertEqual(n, 2)

        // 断言**被测视图自己给出的串**（`summaryTexts` 正是 `body` 两处渲染的取值处），
        // 而不是测试自己按同一套键造一份期望串 —— 后者被测视图一行未读：把视图里
        // 列表侧的取值口径改成独立计算（变异），本用例照旧通过（复审 `F-05`）。
        let texts = PermissionsFeatureView(permissionStates: states).summaryTexts
        let cardValue = texts.card
        let sectionCount = texts.sectionCount

        XCTAssertTrue(cardValue.contains("\(n)"), "卡片值必须带同一个 N：\(cardValue)")
        XCTAssertTrue(sectionCount.contains("\(n)"), "列表计数必须带同一个 N：\(sectionCount)")

        // 从两个真实渲染串里**各抽出 N**，证明两处渲染的是同一个数。
        // 只断言 contains 还不够：两处各自渲染各自的数时也可能都含各自的值。
        XCTAssertEqual(
            number(in: cardValue), n,
            "卡片值里的 N 与 `PermissionsSummaryMetrics` 的口径必须一致：\(cardValue)"
        )
        XCTAssertEqual(
            number(in: sectionCount), n,
            "列表计数里的 N 与卡片值必须同源：\(sectionCount)"
        )
        XCTAssertEqual(
            number(in: cardValue), number(in: sectionCount),
            "两处渲染的必须是**同一个 N**：卡片「\(cardValue)」 vs 列表「\(sectionCount)」"
        )
    }

    /// 从渲染串里抽出其中的整数 N（两份文案都只带一个数字）。
    private func number(in text: String) -> Int? {
        let digits = text.split(whereSeparator: { !$0.isNumber }).first
        return digits.flatMap { Int($0) }
    }

    func testRequiredReadinessCountsOnlyRequired() {
        let states = [
            state(.fullDiskAccess, granted: true),
            state(.accessibility, granted: false),
            state(.notifications, granted: false),
        ]
        let readiness = PermissionsSummaryMetrics.requiredReadiness(states)
        XCTAssertEqual(readiness.granted, 1)
        XCTAssertEqual(readiness.total, 1, "分母只数必需权限，不把可稍后的算进去")
    }
}
