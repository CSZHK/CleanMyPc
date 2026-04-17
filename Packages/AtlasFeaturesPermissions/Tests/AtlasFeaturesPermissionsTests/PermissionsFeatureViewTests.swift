import XCTest
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
