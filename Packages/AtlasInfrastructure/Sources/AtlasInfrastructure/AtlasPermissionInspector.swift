import AtlasDomain
import ApplicationServices
import Foundation
import UserNotifications

public struct AtlasPermissionInspector: Sendable {
    private let fullDiskAccessProbeURLs: [URL]
    private let protectedLocationReader: @Sendable (URL) -> Bool
    private let accessibilityStatusProvider: @Sendable () -> Bool
    private let notificationsAuthorizationProvider: @Sendable () async -> Bool

    public init(
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        fullDiskAccessProbeURLs: [URL]? = nil,
        protectedLocationReader: (@Sendable (URL) -> Bool)? = nil,
        accessibilityStatusProvider: (@Sendable () -> Bool)? = nil,
        notificationsAuthorizationProvider: (@Sendable () async -> Bool)? = nil
    ) {
        self.fullDiskAccessProbeURLs = fullDiskAccessProbeURLs ?? Self.defaultFullDiskAccessProbeURLs(homeDirectoryURL: homeDirectoryURL)
        self.protectedLocationReader = protectedLocationReader ?? { url in
            Self.defaultProtectedLocationReader(url)
        }
        self.accessibilityStatusProvider = accessibilityStatusProvider ?? {
            Self.defaultAccessibilityStatusProvider()
        }
        self.notificationsAuthorizationProvider = notificationsAuthorizationProvider ?? {
            await Self.defaultNotificationsAuthorizationProvider()
        }
    }

    public func snapshot() async -> [PermissionState] {
        [
            fullDiskAccessState(),
            accessibilityState(),
            await notificationsState(),
        ]
    }

    private static func defaultFullDiskAccessProbeURLs(homeDirectoryURL: URL) -> [URL] {
        [
            homeDirectoryURL.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db"),
            homeDirectoryURL.appendingPathComponent("Library/Mail", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Safari", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Messages", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Calendars", isDirectory: true),
        ]
    }

    private static func defaultProtectedLocationReader(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }

        if isDirectory.boolValue {
            return (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) != nil
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return false
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            try handle.close()
            return true
        } catch {
            return false
        }
    }

    private static func defaultAccessibilityStatusProvider() -> Bool {
        AXIsProcessTrusted()
    }

    private static func defaultNotificationsAuthorizationProvider() async -> Bool {
        let settings = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    private func fullDiskAccessState() -> PermissionState {
        let accessibleProtectedPath = fullDiskAccessProbeURLs.first(where: protectedLocationReader)
        let isGranted = accessibleProtectedPath != nil
        let rationale = isGranted
            ? AtlasL10n.string("infrastructure.permission.fullDiskAccess.granted")
            : AtlasL10n.string("infrastructure.permission.fullDiskAccess.needed")

        return PermissionState(kind: .fullDiskAccess, isGranted: isGranted, rationale: rationale)
    }

    private func accessibilityState() -> PermissionState {
        let isGranted = accessibilityStatusProvider()
        let rationale = isGranted
            ? AtlasL10n.string("infrastructure.permission.accessibility.granted")
            : AtlasL10n.string("infrastructure.permission.accessibility.needed")
        return PermissionState(kind: .accessibility, isGranted: isGranted, rationale: rationale)
    }

    private func notificationsState() async -> PermissionState {
        let isGranted = await notificationsAuthorizationProvider()
        let rationale = isGranted
            ? AtlasL10n.string("infrastructure.permission.notifications.granted")
            : AtlasL10n.string("infrastructure.permission.notifications.needed")
        return PermissionState(kind: .notifications, isGranted: isGranted, rationale: rationale)
    }
}
