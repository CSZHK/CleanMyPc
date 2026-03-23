import Foundation

public enum AtlasRoute: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case overview
    case smartClean
    case apps
    case history
    case permissions
    case settings
    case about

    public var id: String { rawValue }

    // MARK: - Sidebar

    public enum SidebarSection: String, CaseIterable, Identifiable, Sendable {
        case core
        case manage

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .core:
                return AtlasL10n.string("sidebar.section.core")
            case .manage:
                return AtlasL10n.string("sidebar.section.manage")
            }
        }

        public var routes: [AtlasRoute] {
            switch self {
            case .core:
                return [.overview, .smartClean, .apps]
            case .manage:
                return [.history, .permissions]
            }
        }
    }

    public var isSidebarRoute: Bool {
        switch self {
        case .settings, .about:
            return false
        default:
            return true
        }
    }

    public static var sidebarRoutes: [AtlasRoute] {
        allCases.filter(\.isSidebarRoute)
    }

    public var sidebarSection: SidebarSection? {
        switch self {
        case .overview, .smartClean, .apps:
            return .core
        case .history, .permissions:
            return .manage
        case .settings, .about:
            return nil
        }
    }

    public var title: String {
        switch self {
        case .overview:
            return AtlasL10n.string("route.overview.title")
        case .smartClean:
            return AtlasL10n.string("route.smartclean.title")
        case .apps:
            return AtlasL10n.string("route.apps.title")
        case .history:
            return AtlasL10n.string("route.history.title")
        case .permissions:
            return AtlasL10n.string("route.permissions.title")
        case .settings:
            return AtlasL10n.string("route.settings.title")
        case .about:
            return AtlasL10n.string("route.about.title")
        }
    }

    public var subtitle: String {
        switch self {
        case .overview:
            return AtlasL10n.string("route.overview.subtitle")
        case .smartClean:
            return AtlasL10n.string("route.smartclean.subtitle")
        case .apps:
            return AtlasL10n.string("route.apps.subtitle")
        case .history:
            return AtlasL10n.string("route.history.subtitle")
        case .permissions:
            return AtlasL10n.string("route.permissions.subtitle")
        case .settings:
            return AtlasL10n.string("route.settings.subtitle")
        case .about:
            return AtlasL10n.string("route.about.subtitle")
        }
    }

    public var systemImage: String {
        switch self {
        case .overview:
            return "rectangle.grid.2x2"
        case .smartClean:
            return "sparkles"
        case .apps:
            return "square.stack.3d.up"
        case .history:
            return "clock.arrow.circlepath"
        case .permissions:
            return "lock.shield"
        case .settings:
            return "gearshape"
        case .about:
            return "person.crop.circle"
        }
    }
}

public enum RiskLevel: String, CaseIterable, Codable, Hashable, Sendable {
    case safe
    case review
    case advanced

    public var title: String {
        switch self {
        case .safe:
            return AtlasL10n.string("risk.safe")
        case .review:
            return AtlasL10n.string("risk.review")
        case .advanced:
            return AtlasL10n.string("risk.advanced")
        }
    }
}

public struct Finding: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var detail: String
    public var bytes: Int64
    public var risk: RiskLevel
    public var category: String
    public var targetPaths: [String]?

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        bytes: Int64,
        risk: RiskLevel,
        category: String,
        targetPaths: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.bytes = bytes
        self.risk = risk
        self.category = category
        self.targetPaths = targetPaths
    }
}

public struct ActionItem: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case removeCache
        case removeApp
        case archiveFile
        case inspectPermission
        case reviewEvidence
    }

    public var id: UUID
    public var title: String
    public var detail: String
    public var kind: Kind
    public var recoverable: Bool
    public var targetPaths: [String]?
    public var evidencePaths: [String]?

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        kind: Kind,
        recoverable: Bool,
        targetPaths: [String]? = nil,
        evidencePaths: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.recoverable = recoverable
        self.targetPaths = targetPaths
        self.evidencePaths = evidencePaths
    }
}

public struct ActionPlan: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var items: [ActionItem]
    public var estimatedBytes: Int64

    public init(
        id: UUID = UUID(),
        title: String,
        items: [ActionItem],
        estimatedBytes: Int64
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.estimatedBytes = estimatedBytes
    }
}

public enum TaskKind: String, Codable, Hashable, Sendable {
    case scan
    case executePlan
    case uninstallApp
    case restore
    case inspectPermissions

    public var title: String {
        switch self {
        case .scan:
            return AtlasL10n.string("taskkind.scan")
        case .executePlan:
            return AtlasL10n.string("taskkind.executePlan")
        case .uninstallApp:
            return AtlasL10n.string("taskkind.uninstallApp")
        case .restore:
            return AtlasL10n.string("taskkind.restore")
        case .inspectPermissions:
            return AtlasL10n.string("taskkind.inspectPermissions")
        }
    }
}

public enum TaskStatus: String, Codable, Hashable, Sendable {
    case queued
    case running
    case completed
    case failed
    case cancelled

    public var title: String {
        switch self {
        case .queued:
            return AtlasL10n.string("taskstatus.queued")
        case .running:
            return AtlasL10n.string("taskstatus.running")
        case .completed:
            return AtlasL10n.string("taskstatus.completed")
        case .failed:
            return AtlasL10n.string("taskstatus.failed")
        case .cancelled:
            return AtlasL10n.string("taskstatus.cancelled")
        }
    }
}

public struct TaskRun: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: TaskKind
    public var status: TaskStatus
    public var summary: String
    public var startedAt: Date
    public var finishedAt: Date?

    public init(
        id: UUID = UUID(),
        kind: TaskKind,
        status: TaskStatus,
        summary: String,
        startedAt: Date,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.summary = summary
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

public enum AtlasAppFootprintEvidenceCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case supportFiles
    case caches
    case preferences
    case logs
    case launchItems
}

public struct AtlasAppFootprintEvidenceItem: Identifiable, Codable, Hashable, Sendable {
    public var path: String
    public var bytes: Int64

    public var id: String { path }

    public init(path: String, bytes: Int64) {
        self.path = path
        self.bytes = bytes
    }
}

public struct AtlasAppFootprintEvidenceGroup: Identifiable, Codable, Hashable, Sendable {
    public var category: AtlasAppFootprintEvidenceCategory
    public var items: [AtlasAppFootprintEvidenceItem]

    public var id: AtlasAppFootprintEvidenceCategory { category }

    public var totalBytes: Int64 {
        items.map(\.bytes).reduce(0, +)
    }

    public init(category: AtlasAppFootprintEvidenceCategory, items: [AtlasAppFootprintEvidenceItem]) {
        self.category = category
        self.items = items
    }
}

public struct AtlasAppUninstallEvidence: Codable, Hashable, Sendable {
    public var bundlePath: String
    public var bundleBytes: Int64
    public var reviewOnlyGroups: [AtlasAppFootprintEvidenceGroup]

    public var reviewOnlyGroupCount: Int {
        reviewOnlyGroups.count
    }

    public var reviewOnlyItemCount: Int {
        reviewOnlyGroups.reduce(0) { partial, group in
            partial + group.items.count
        }
    }

    public var reviewOnlyBytes: Int64 {
        reviewOnlyGroups.reduce(0) { partial, group in
            partial + group.totalBytes
        }
    }

    public init(bundlePath: String, bundleBytes: Int64, reviewOnlyGroups: [AtlasAppFootprintEvidenceGroup]) {
        self.bundlePath = bundlePath
        self.bundleBytes = bundleBytes
        self.reviewOnlyGroups = reviewOnlyGroups
    }
}

public enum AtlasRecoveryPayloadSchemaVersion {
    public static let current = 1
}

public struct AtlasAppRecoveryPayload: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var app: AppFootprint
    public var uninstallEvidence: AtlasAppUninstallEvidence

    public init(
        schemaVersion: Int = AtlasRecoveryPayloadSchemaVersion.current,
        app: AppFootprint,
        uninstallEvidence: AtlasAppUninstallEvidence
    ) {
        self.schemaVersion = schemaVersion
        self.app = app
        self.uninstallEvidence = uninstallEvidence
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case app
        case uninstallEvidence
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? AtlasRecoveryPayloadSchemaVersion.current
        self.app = try container.decode(AppFootprint.self, forKey: .app)
        self.uninstallEvidence = try container.decode(AtlasAppUninstallEvidence.self, forKey: .uninstallEvidence)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(app, forKey: .app)
        try container.encode(uninstallEvidence, forKey: .uninstallEvidence)
    }
}

public enum RecoveryPayload: Codable, Hashable, Sendable {
    case finding(Finding)
    case app(AtlasAppRecoveryPayload)

    private enum CodingKeys: String, CodingKey {
        case finding
        case app
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.finding) {
            self = .finding(try container.decode(Finding.self, forKey: .finding))
            return
        }

        if container.contains(.app) {
            if let payload = try? container.decode(AtlasAppRecoveryPayload.self, forKey: .app) {
                self = .app(payload)
                return
            }

            let legacyApp = try container.decode(AppFootprint.self, forKey: .app)
            self = .app(
                AtlasAppRecoveryPayload(
                    app: legacyApp,
                    uninstallEvidence: AtlasAppUninstallEvidence(
                        bundlePath: legacyApp.bundlePath,
                        bundleBytes: legacyApp.bytes,
                        reviewOnlyGroups: []
                    )
                )
            )
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "RecoveryPayload must contain either a finding or app payload."
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .finding(finding):
            try container.encode(finding, forKey: .finding)
        case let .app(payload):
            try container.encode(payload, forKey: .app)
        }
    }
}

public struct RecoveryPathMapping: Codable, Hashable, Sendable {
    public var originalPath: String
    public var trashedPath: String

    public init(originalPath: String, trashedPath: String) {
        self.originalPath = originalPath
        self.trashedPath = trashedPath
    }
}

public struct RecoveryItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var detail: String
    public var originalPath: String
    public var bytes: Int64
    public var deletedAt: Date
    public var expiresAt: Date?
    public var payload: RecoveryPayload?
    public var restoreMappings: [RecoveryPathMapping]?

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        originalPath: String,
        bytes: Int64,
        deletedAt: Date,
        expiresAt: Date? = nil,
        payload: RecoveryPayload? = nil,
        restoreMappings: [RecoveryPathMapping]? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.originalPath = originalPath
        self.bytes = bytes
        self.deletedAt = deletedAt
        self.expiresAt = expiresAt
        self.payload = payload
        self.restoreMappings = restoreMappings
    }
}

public struct AppFootprint: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var bundleIdentifier: String
    public var bundlePath: String
    public var bytes: Int64
    public var leftoverItems: Int

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        bundlePath: String,
        bytes: Int64,
        leftoverItems: Int
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
        self.bytes = bytes
        self.leftoverItems = leftoverItems
    }
}

public enum PermissionKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case fullDiskAccess
    case accessibility
    case notifications

    public var id: String { rawValue }

    public var isRequiredForCurrentWorkflows: Bool {
        switch self {
        case .fullDiskAccess:
            return true
        case .accessibility, .notifications:
            return false
        }
    }

    public var title: String {
        switch self {
        case .fullDiskAccess:
            return AtlasL10n.string("permission.fullDiskAccess")
        case .accessibility:
            return AtlasL10n.string("permission.accessibility")
        case .notifications:
            return AtlasL10n.string("permission.notifications")
        }
    }

    public var systemImage: String {
        switch self {
        case .fullDiskAccess:
            return "externaldrive.badge.checkmark"
        case .accessibility:
            return "figure.wave"
        case .notifications:
            return "bell.badge"
        }
    }
}

public struct PermissionState: Identifiable, Codable, Hashable, Sendable {
    public var kind: PermissionKind
    public var isGranted: Bool
    public var rationale: String

    public init(kind: PermissionKind, isGranted: Bool, rationale: String) {
        self.kind = kind
        self.isGranted = isGranted
        self.rationale = rationale
    }

    public var id: PermissionKind { kind }
}

public struct AtlasOptimizationRecommendation: Identifiable, Codable, Hashable, Sendable {
    public var id: String { action }
    public var category: String
    public var name: String
    public var detail: String
    public var action: String
    public var isSafe: Bool

    public init(category: String, name: String, detail: String, action: String, isSafe: Bool) {
        self.category = category
        self.name = name
        self.detail = detail
        self.action = action
        self.isSafe = isSafe
    }
}

public struct AtlasHealthSnapshot: Codable, Hashable, Sendable {
    public var memoryUsedGB: Double
    public var memoryTotalGB: Double
    public var diskUsedGB: Double
    public var diskTotalGB: Double
    public var diskUsedPercent: Double
    public var uptimeDays: Double
    public var optimizations: [AtlasOptimizationRecommendation]

    public init(
        memoryUsedGB: Double,
        memoryTotalGB: Double,
        diskUsedGB: Double,
        diskTotalGB: Double,
        diskUsedPercent: Double,
        uptimeDays: Double,
        optimizations: [AtlasOptimizationRecommendation]
    ) {
        self.memoryUsedGB = memoryUsedGB
        self.memoryTotalGB = memoryTotalGB
        self.diskUsedGB = diskUsedGB
        self.diskTotalGB = diskTotalGB
        self.diskUsedPercent = diskUsedPercent
        self.uptimeDays = uptimeDays
        self.optimizations = optimizations
    }
}

public struct StorageInsight: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var path: String
    public var bytes: Int64
    public var ageDescription: String

    public init(
        id: UUID = UUID(),
        title: String,
        path: String,
        bytes: Int64,
        ageDescription: String
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.bytes = bytes
        self.ageDescription = ageDescription
    }
}

public struct AtlasSettings: Codable, Hashable, Sendable {
    public var recoveryRetentionDays: Int
    public var notificationsEnabled: Bool
    public var excludedPaths: [String]
    public var language: AtlasLanguage
    public var acknowledgementText: String
    public var thirdPartyNoticesText: String

    public init(
        recoveryRetentionDays: Int,
        notificationsEnabled: Bool,
        excludedPaths: [String],
        language: AtlasLanguage = .default,
        acknowledgementText: String? = nil,
        thirdPartyNoticesText: String? = nil
    ) {
        self.recoveryRetentionDays = recoveryRetentionDays
        self.notificationsEnabled = notificationsEnabled
        self.excludedPaths = excludedPaths
        self.language = language
        self.acknowledgementText = acknowledgementText ?? AtlasL10n.acknowledgement(language: language)
        self.thirdPartyNoticesText = thirdPartyNoticesText ?? AtlasL10n.thirdPartyNotices(language: language)
    }

    private enum CodingKeys: String, CodingKey {
        case recoveryRetentionDays
        case notificationsEnabled
        case excludedPaths
        case language
        case acknowledgementText
        case thirdPartyNoticesText
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let language = try container.decodeIfPresent(AtlasLanguage.self, forKey: .language) ?? .default
        self.recoveryRetentionDays = try container.decodeIfPresent(Int.self, forKey: .recoveryRetentionDays) ?? 7
        self.notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        self.excludedPaths = try container.decodeIfPresent([String].self, forKey: .excludedPaths) ?? []
        self.language = language
        self.acknowledgementText = try container.decodeIfPresent(String.self, forKey: .acknowledgementText)
            ?? AtlasL10n.acknowledgement(language: language)
        self.thirdPartyNoticesText = try container.decodeIfPresent(String.self, forKey: .thirdPartyNoticesText)
            ?? AtlasL10n.thirdPartyNotices(language: language)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recoveryRetentionDays, forKey: .recoveryRetentionDays)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(excludedPaths, forKey: .excludedPaths)
        try container.encode(language, forKey: .language)
        try container.encode(acknowledgementText, forKey: .acknowledgementText)
        try container.encode(thirdPartyNoticesText, forKey: .thirdPartyNoticesText)
    }
}

public enum AtlasScaffoldFixtures {
    private static func uuid(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }

    private static let now = Date()

    public static var findings: [Finding] {
        findings(language: AtlasL10n.currentLanguage)
    }

    public static func findings(language: AtlasLanguage) -> [Finding] {
        [
            Finding(
                id: uuid("00000000-0000-0000-0000-000000000001"),
                title: AtlasL10n.string("fixture.finding.derivedData.title", language: language),
                detail: AtlasL10n.string("fixture.finding.derivedData.detail", language: language),
                bytes: 18_400_000_000,
                risk: .safe,
                category: "Developer"
            ),
            Finding(
                id: uuid("00000000-0000-0000-0000-000000000002"),
                title: AtlasL10n.string("fixture.finding.browserCaches.title", language: language),
                detail: AtlasL10n.string("fixture.finding.browserCaches.detail", language: language),
                bytes: 4_800_000_000,
                risk: .safe,
                category: "System"
            ),
            Finding(
                id: uuid("00000000-0000-0000-0000-000000000003"),
                title: AtlasL10n.string("fixture.finding.oldRuntimes.title", language: language),
                detail: AtlasL10n.string("fixture.finding.oldRuntimes.detail", language: language),
                bytes: 12_100_000_000,
                risk: .review,
                category: "Developer"
            ),
            Finding(
                id: uuid("00000000-0000-0000-0000-000000000004"),
                title: AtlasL10n.string("fixture.finding.launchAgents.title", language: language),
                detail: AtlasL10n.string("fixture.finding.launchAgents.detail", language: language),
                bytes: 820_000_000,
                risk: .advanced,
                category: "Apps"
            ),
        ]
    }

    public static var actionPlan: ActionPlan {
        actionPlan(language: AtlasL10n.currentLanguage)
    }

    public static func actionPlan(language: AtlasLanguage) -> ActionPlan {
        ActionPlan(
            id: uuid("00000000-0000-0000-0000-000000000010"),
            title: AtlasL10n.string("fixture.plan.reclaimCommonClutter.title", language: language),
            items: [
                ActionItem(
                    id: uuid("00000000-0000-0000-0000-000000000011"),
                    title: AtlasL10n.string("fixture.plan.item.moveDerivedData.title", language: language),
                    detail: AtlasL10n.string("fixture.plan.item.moveDerivedData.detail", language: language),
                    kind: .removeCache,
                    recoverable: true,
                    targetPaths: ["~/Library/Developer/Xcode/DerivedData/AtlasFixture"]
                ),
                ActionItem(
                    id: uuid("00000000-0000-0000-0000-000000000012"),
                    title: AtlasL10n.string("fixture.plan.item.reviewRuntimes.title", language: language),
                    detail: AtlasL10n.string("fixture.plan.item.reviewRuntimes.detail", language: language),
                    kind: .archiveFile,
                    recoverable: true,
                    targetPaths: ["~/Library/Developer/Xcode/iOS DeviceSupport/AtlasFixtureRuntime"]
                ),
                ActionItem(
                    id: uuid("00000000-0000-0000-0000-000000000013"),
                    title: AtlasL10n.string("fixture.plan.item.inspectAgents.title", language: language),
                    detail: AtlasL10n.string("fixture.plan.item.inspectAgents.detail", language: language),
                    kind: .inspectPermission,
                    recoverable: false,
                    targetPaths: ["~/Library/LaunchAgents/com.example.atlas-fixture.plist"]
                ),
            ],
            estimatedBytes: 23_200_000_000
        )
    }

    public static let apps: [AppFootprint] = [
        AppFootprint(
            id: uuid("00000000-0000-0000-0000-000000000020"),
            name: "Final Cut Pro",
            bundleIdentifier: "com.apple.FinalCut",
            bundlePath: "/Applications/Final Cut Pro.app",
            bytes: 9_600_000_000,
            leftoverItems: 6
        ),
        AppFootprint(
            id: uuid("00000000-0000-0000-0000-000000000021"),
            name: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            bundlePath: "/Applications/Xcode.app",
            bytes: 34_800_000_000,
            leftoverItems: 12
        ),
        AppFootprint(
            id: uuid("00000000-0000-0000-0000-000000000022"),
            name: "Docker",
            bundleIdentifier: "com.docker.docker",
            bundlePath: "/Applications/Docker.app",
            bytes: 7_400_000_000,
            leftoverItems: 8
        ),
    ]

    public static var taskRuns: [TaskRun] {
        taskRuns(language: AtlasL10n.currentLanguage)
    }

    public static func taskRuns(language: AtlasLanguage) -> [TaskRun] {
        [
            TaskRun(
                id: uuid("00000000-0000-0000-0000-000000000030"),
                kind: .scan,
                status: .completed,
                summary: AtlasL10n.string("fixture.task.scan.summary", language: language),
                startedAt: now.addingTimeInterval(-9_000),
                finishedAt: now.addingTimeInterval(-8_940)
            ),
            TaskRun(
                id: uuid("00000000-0000-0000-0000-000000000031"),
                kind: .executePlan,
                status: .running,
                summary: AtlasL10n.string("fixture.task.execute.summary", language: language),
                startedAt: now.addingTimeInterval(-800)
            ),
            TaskRun(
                id: uuid("00000000-0000-0000-0000-000000000032"),
                kind: .inspectPermissions,
                status: .completed,
                summary: AtlasL10n.string("fixture.task.permissions.summary", language: language),
                startedAt: now.addingTimeInterval(-300),
                finishedAt: now.addingTimeInterval(-285)
            ),
        ]
    }

    public static var recoveryItems: [RecoveryItem] {
        recoveryItems(language: AtlasL10n.currentLanguage)
    }

    public static func recoveryItems(language: AtlasLanguage) -> [RecoveryItem] {
        [
            RecoveryItem(
                id: uuid("00000000-0000-0000-0000-000000000040"),
                title: AtlasL10n.string("fixture.recovery.chromeCache.title", language: language),
                detail: AtlasL10n.string("fixture.recovery.chromeCache.detail", language: language),
                originalPath: "~/Library/Caches/Google/Chrome",
                bytes: 1_200_000_000,
                deletedAt: now.addingTimeInterval(-86_400),
                expiresAt: now.addingTimeInterval(518_400),
                payload: .finding(
                    Finding(
                        title: AtlasL10n.string("fixture.recovery.chromeCache.title", language: language),
                        detail: AtlasL10n.string("fixture.recovery.chromeCache.payload", language: language),
                        bytes: 1_200_000_000,
                        risk: .safe,
                        category: "Browsers"
                    )
                )
            ),
            RecoveryItem(
                id: uuid("00000000-0000-0000-0000-000000000041"),
                title: AtlasL10n.string("fixture.recovery.simulatorSupport.title", language: language),
                detail: AtlasL10n.string("fixture.recovery.simulatorSupport.detail", language: language),
                originalPath: "~/Library/Developer/Xcode/iOS DeviceSupport",
                bytes: 3_400_000_000,
                deletedAt: now.addingTimeInterval(-172_800),
                expiresAt: now.addingTimeInterval(432_000),
                payload: .finding(
                    Finding(
                        title: AtlasL10n.string("fixture.recovery.simulatorSupport.title", language: language),
                        detail: AtlasL10n.string("fixture.recovery.simulatorSupport.payload", language: language),
                        bytes: 3_400_000_000,
                        risk: .review,
                        category: "Developer"
                    )
                )
            ),
        ]
    }

    public static var permissions: [PermissionState] {
        permissions(language: AtlasL10n.currentLanguage)
    }

    public static func permissions(language: AtlasLanguage) -> [PermissionState] {
        [
            PermissionState(
                kind: .fullDiskAccess,
                isGranted: false,
                rationale: AtlasL10n.string("fixture.permission.fullDiskAccess.rationale", language: language)
            ),
            PermissionState(
                kind: .accessibility,
                isGranted: false,
                rationale: AtlasL10n.string("fixture.permission.accessibility.rationale", language: language)
            ),
            PermissionState(
                kind: .notifications,
                isGranted: true,
                rationale: AtlasL10n.string("fixture.permission.notifications.rationale", language: language)
            ),
        ]
    }

    public static var healthSnapshot: AtlasHealthSnapshot {
        healthSnapshot(language: AtlasL10n.currentLanguage)
    }

    public static func healthSnapshot(language: AtlasLanguage) -> AtlasHealthSnapshot {
        AtlasHealthSnapshot(
            memoryUsedGB: 14.2,
            memoryTotalGB: 24.0,
            diskUsedGB: 303.0,
            diskTotalGB: 460.0,
            diskUsedPercent: 65.9,
            uptimeDays: 6.4,
            optimizations: [
                AtlasOptimizationRecommendation(
                    category: "system",
                    name: AtlasL10n.string("fixture.health.optimization.dns.title", language: language),
                    detail: AtlasL10n.string("fixture.health.optimization.dns.detail", language: language),
                    action: "system_maintenance",
                    isSafe: true
                ),
                AtlasOptimizationRecommendation(
                    category: "system",
                    name: AtlasL10n.string("fixture.health.optimization.finder.title", language: language),
                    detail: AtlasL10n.string("fixture.health.optimization.finder.detail", language: language),
                    action: "cache_refresh",
                    isSafe: true
                ),
                AtlasOptimizationRecommendation(
                    category: "system",
                    name: AtlasL10n.string("fixture.health.optimization.memory.title", language: language),
                    detail: AtlasL10n.string("fixture.health.optimization.memory.detail", language: language),
                    action: "memory_pressure_relief",
                    isSafe: true
                ),
            ]
        )
    }

    public static var storageInsights: [StorageInsight] {
        storageInsights(language: AtlasL10n.currentLanguage)
    }

    public static func storageInsights(language: AtlasLanguage) -> [StorageInsight] {
        [
            StorageInsight(
                id: uuid("00000000-0000-0000-0000-000000000050"),
                title: AtlasL10n.string("fixture.storage.downloads.title", language: language),
                path: "~/Downloads",
                bytes: 13_100_000_000,
                ageDescription: AtlasL10n.string("fixture.storage.downloads.age", language: language)
            ),
            StorageInsight(
                id: uuid("00000000-0000-0000-0000-000000000051"),
                title: AtlasL10n.string("fixture.storage.movies.title", language: language),
                path: "~/Movies/Exports",
                bytes: 21_400_000_000,
                ageDescription: AtlasL10n.string("fixture.storage.movies.age", language: language)
            ),
            StorageInsight(
                id: uuid("00000000-0000-0000-0000-000000000052"),
                title: AtlasL10n.string("fixture.storage.installers.title", language: language),
                path: "~/Desktop/Installers",
                bytes: 6_200_000_000,
                ageDescription: AtlasL10n.string("fixture.storage.installers.age", language: language)
            ),
        ]
    }

    public static let settings: AtlasSettings = settings(language: .default)

    public static func settings(language: AtlasLanguage) -> AtlasSettings {
        AtlasSettings(
            recoveryRetentionDays: 7,
            notificationsEnabled: true,
            excludedPaths: [
                "~/Projects/ActiveClientWork",
                "~/Movies/Exports",
            ],
            language: language
        )
    }
}
