import Foundation

public struct AtlasSidebarContext: Sendable {
    public var findingsCount: Int
    public var reclaimableBytes: Int64
    public var appsCount: Int
    public var recoveryItemsCount: Int
    public var requiredPermissionsGranted: Int
    public var requiredPermissionsTotal: Int
    public var diskUsedPercent: Double?
    public var fileOrganizerEntriesCount: Int

    public init(
        findingsCount: Int = 0,
        reclaimableBytes: Int64 = 0,
        appsCount: Int = 0,
        recoveryItemsCount: Int = 0,
        requiredPermissionsGranted: Int = 0,
        requiredPermissionsTotal: Int = 0,
        diskUsedPercent: Double? = nil,
        fileOrganizerEntriesCount: Int = 0
    ) {
        self.findingsCount = findingsCount
        self.reclaimableBytes = reclaimableBytes
        self.appsCount = appsCount
        self.recoveryItemsCount = recoveryItemsCount
        self.requiredPermissionsGranted = requiredPermissionsGranted
        self.requiredPermissionsTotal = requiredPermissionsTotal
        self.diskUsedPercent = diskUsedPercent
        self.fileOrganizerEntriesCount = fileOrganizerEntriesCount
    }
}

public enum AtlasRoute: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case overview
    case smartClean
    case fileOrganizer
    case apps
    case history
    case permissions
    case settings
    case about

    public var id: String { rawValue }

    public func dynamicSubtitle(context: AtlasSidebarContext) -> String {
        switch self {
        case .overview:
            if let pct = context.diskUsedPercent {
                return AtlasL10n.string("sidebar.overview.dynamic", Int(pct))
            }
            return subtitle
        case .smartClean:
            if context.findingsCount > 0 {
                return AtlasL10n.string("sidebar.smartclean.dynamic", context.findingsCount, Self.formatBytes(context.reclaimableBytes))
            }
            return subtitle
        case .fileOrganizer:
            if context.fileOrganizerEntriesCount > 0 {
                return AtlasL10n.string("sidebar.fileorganizer.dynamic", context.fileOrganizerEntriesCount)
            }
            return subtitle
        case .apps:
            if context.appsCount > 0 {
                return AtlasL10n.string("sidebar.apps.dynamic", context.appsCount)
            }
            return subtitle
        case .history:
            if context.recoveryItemsCount > 0 {
                return AtlasL10n.string("sidebar.history.dynamic", context.recoveryItemsCount)
            }
            return subtitle
        case .permissions:
            if context.requiredPermissionsTotal > 0 {
                if context.requiredPermissionsGranted == context.requiredPermissionsTotal {
                    return AtlasL10n.string("sidebar.permissions.ready")
                }
                return AtlasL10n.string("sidebar.permissions.partial", context.requiredPermissionsGranted, context.requiredPermissionsTotal)
            }
            return subtitle
        case .settings, .about:
            return subtitle
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

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
                return [.overview, .smartClean, .fileOrganizer, .apps]
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
        case .overview, .smartClean, .fileOrganizer, .apps:
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
        case .fileOrganizer:
            return AtlasL10n.string("route.fileorganizer.title")
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
        case .fileOrganizer:
            return AtlasL10n.string("route.fileorganizer.subtitle")
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
        case .fileOrganizer:
            return "folder.badge.gearshape"
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

public struct FileAgeInfo: Codable, Hashable, Sendable {
    public var lastModifiedDate: Date?
    public var creationDate: Date?

    public init(
        lastModifiedDate: Date? = nil,
        creationDate: Date? = nil
    ) {
        self.lastModifiedDate = lastModifiedDate
        self.creationDate = creationDate
    }
}

public struct FindingAggregate: Codable, Hashable, Sendable {
    public var risk: RiskLevel
    public var totalBytes: Int64
    public var count: Int

    public init(risk: RiskLevel, totalBytes: Int64, count: Int) {
        self.risk = risk
        self.totalBytes = totalBytes
        self.count = count
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
    public var explanation: String?
    public var fileAge: FileAgeInfo?
    public var storageCategory: AtlasStorageCategory?

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        bytes: Int64,
        risk: RiskLevel,
        category: String,
        targetPaths: [String]? = nil,
        explanation: String? = nil,
        fileAge: FileAgeInfo? = nil,
        storageCategory: AtlasStorageCategory? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.bytes = bytes
        self.risk = risk
        self.category = category
        self.targetPaths = targetPaths
        self.explanation = explanation
        self.fileAge = fileAge
        self.storageCategory = storageCategory
    }
}

// MARK: - Finding Aggregation

extension Array where Element == Finding {
    /// Computes aggregate summaries grouped by risk level.
    /// Returns one ``FindingAggregate`` per ``RiskLevel`` case, including
    /// levels with zero findings so the UI can display complete summaries.
    public func aggregatesByRisk() -> [FindingAggregate] {
        RiskLevel.allCases.map { risk in
            let matching = filter { $0.risk == risk }
            let totalBytes = matching.reduce(Int64(0)) { $0 + $1.bytes }
            return FindingAggregate(risk: risk, totalBytes: totalBytes, count: matching.count)
        }
    }

    /// Groups findings by their storage category.
    /// Findings with a `nil` storageCategory are placed under the key "uncategorized".
    public func groupedByStorageCategory() -> [String: [Finding]] {
        Dictionary(grouping: self) { finding in
            finding.storageCategory?.rawValue ?? "uncategorized"
        }
    }
}

public struct ActionItem: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case removeCache
        case removeApp
        case archiveFile
        case inspectPermission
        case reviewEvidence
        case organizeFile
    }

    public enum ExecutionBoundary: String, Codable, Hashable, Sendable {
        case direct
        case helper
        case reviewOnly

        public var isExecutable: Bool {
            switch self {
            case .direct, .helper:
                return true
            case .reviewOnly:
                return false
            }
        }
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

    public var executionBoundary: ExecutionBoundary {
        Self.derivedExecutionBoundary(
            kind: kind,
            targetPaths: targetPaths,
            evidencePaths: evidencePaths
        )
    }

    /// Resolves the effective execution boundary by first checking the item's own boundary,
    /// then falling back to target paths discovered from an associated finding.
    public func effectiveExecutionBoundary(
        findings: [Finding],
        homeDirectoryPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> ExecutionBoundary {
        if executionBoundary.isExecutable {
            return executionBoundary
        }

        guard kind != .inspectPermission, kind != .reviewEvidence else {
            return .reviewOnly
        }

        let paths = resolvedTargetPaths(findings: findings)
        guard !paths.isEmpty else {
            return executionBoundary
        }

        return Self.derivedExecutionBoundary(
            kind: kind,
            targetPaths: paths,
            evidencePaths: evidencePaths,
            homeDirectoryPath: homeDirectoryPath
        )
    }

    /// Resolves target paths by checking the item's own paths first, then falling back
    /// to paths from an associated finding matched by ID.
    public func resolvedTargetPaths(findings: [Finding]) -> [String] {
        if let targetPaths, !targetPaths.isEmpty {
            return targetPaths
        }

        guard let finding = findings.first(where: { $0.id == id }) else {
            return []
        }

        return finding.targetPaths ?? []
    }

    public static func derivedExecutionBoundary(
        kind: Kind,
        targetPaths: [String]?,
        evidencePaths: [String]?,
        homeDirectoryPath: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> ExecutionBoundary {
        switch kind {
        case .inspectPermission, .reviewEvidence:
            return .reviewOnly
        case .removeApp:
            return .helper
        case .removeCache, .archiveFile, .organizeFile:
            break
        }

        let resolvedTargetPaths = Array(Set((targetPaths ?? []).filter { !$0.isEmpty })).sorted()
        if resolvedTargetPaths.isEmpty {
            return .reviewOnly
        }

        if resolvedTargetPaths.contains(where: { requiresHelper(path: $0, homeDirectoryPath: homeDirectoryPath) }) {
            return .helper
        }

        return .direct
    }

    private static func requiresHelper(path: String, homeDirectoryPath: String) -> Bool {
        let helperRoots = [
            "/Applications",
            homeDirectoryPath + "/Applications",
            homeDirectoryPath + "/Library/LaunchAgents",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
        ]

        return helperRoots.contains { root in
            path == root || path.hasPrefix(root + "/")
        }
    }
}

public struct ActionPlan: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var items: [ActionItem]
    public var estimatedBytes: Int64
    public var evidencePlanID: UUID?
    public var estimatedReviewOnlyBytes: Int64?
    public var evidenceGroups: [AtlasAppEvidenceGroup]?

    public init(
        id: UUID = UUID(),
        title: String,
        items: [ActionItem],
        estimatedBytes: Int64,
        evidencePlanID: UUID? = nil,
        estimatedReviewOnlyBytes: Int64? = nil,
        evidenceGroups: [AtlasAppEvidenceGroup]? = nil
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.estimatedBytes = estimatedBytes
        self.evidencePlanID = evidencePlanID
        self.estimatedReviewOnlyBytes = estimatedReviewOnlyBytes
        self.evidenceGroups = evidenceGroups
    }
}

public enum TaskKind: String, Codable, Hashable, Sendable {
    case scan
    case executePlan
    case uninstallApp
    case restore
    case inspectPermissions
    case organizeFiles

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
        case .organizeFiles:
            return AtlasL10n.string("taskkind.organizeFiles")
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

public enum AtlasAppEvidenceCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case appBundle
    case supportFiles
    case caches
    case preferences
    case logs
    case launchItems
    case savedState
    case containers
    case groupContainers
    case miscLeftovers

    public var title: String {
        switch self {
        case .appBundle: return AtlasL10n.string("evidence.category.appBundle")
        case .supportFiles: return AtlasL10n.string("evidence.category.supportFiles")
        case .caches: return AtlasL10n.string("evidence.category.caches")
        case .preferences: return AtlasL10n.string("evidence.category.preferences")
        case .logs: return AtlasL10n.string("evidence.category.logs")
        case .launchItems: return AtlasL10n.string("evidence.category.launchItems")
        case .savedState: return AtlasL10n.string("evidence.category.savedState")
        case .containers: return AtlasL10n.string("evidence.category.containers")
        case .groupContainers: return AtlasL10n.string("evidence.category.groupContainers")
        case .miscLeftovers: return AtlasL10n.string("evidence.category.miscLeftovers")
        }
    }

    public var safetyLevel: AtlasEvidenceSafetyLevel {
        switch self {
        case .appBundle, .caches, .logs, .savedState: return .safe
        case .supportFiles, .preferences, .containers, .miscLeftovers: return .conditional
        case .launchItems, .groupContainers: return .protected
        }
    }
}

public enum AtlasEvidenceSafetyLevel: String, Codable, Hashable, Sendable {
    case safe
    case conditional
    case protected

    public var title: String {
        switch self {
        case .safe: return AtlasL10n.string("evidence.safety.safe")
        case .conditional: return AtlasL10n.string("evidence.safety.conditional")
        case .protected: return AtlasL10n.string("evidence.safety.protected")
        }
    }
}

public enum AtlasEvidenceFileType: String, Codable, Hashable, Sendable {
    case file
    case directory
    case plist
    case symlink
    case bundle
}

public struct AtlasAppEvidenceItem: Identifiable, Codable, Hashable, Sendable {
    public var path: String
    public var bytes: Int64
    public var fileType: AtlasEvidenceFileType
    public var verified: Bool

    public var id: String { path }

    public init(path: String, bytes: Int64, fileType: AtlasEvidenceFileType = .file, verified: Bool = false) {
        self.path = path
        self.bytes = bytes
        self.fileType = fileType
        self.verified = verified
    }
}

public struct AtlasAppEvidenceGroup: Identifiable, Codable, Hashable, Sendable {
    public var category: AtlasAppEvidenceCategory
    public var safetyLevel: AtlasEvidenceSafetyLevel
    public var items: [AtlasAppEvidenceItem]

    public var id: AtlasAppEvidenceCategory { category }
    public var totalBytes: Int64 { items.map(\.bytes).reduce(0, +) }
    public var itemCount: Int { items.count }

    public init(category: AtlasAppEvidenceCategory, safetyLevel: AtlasEvidenceSafetyLevel? = nil, items: [AtlasAppEvidenceItem] = []) {
        self.category = category
        self.safetyLevel = safetyLevel ?? category.safetyLevel
        self.items = items
    }
}

public struct AtlasAppUninstallEvidenceSnapshot: Codable, Hashable, Sendable {
    public var planID: UUID
    public var capturedAt: Date
    public var bundlePath: String
    public var bundleBytes: Int64
    public var groups: [AtlasAppEvidenceGroup]
    public var fingerprintHash: String

    public var reviewOnlyGroups: [AtlasAppEvidenceGroup] {
        groups.filter { $0.category != .appBundle }
    }
    public var reviewOnlyBytes: Int64 {
        reviewOnlyGroups.reduce(0) { $0 + $1.totalBytes }
    }
    public var reviewOnlyItemCount: Int {
        reviewOnlyGroups.reduce(0) { $0 + $1.itemCount }
    }
    public var totalBytes: Int64 {
        groups.reduce(0) { $0 + $1.totalBytes }
    }

    public init(planID: UUID, capturedAt: Date, bundlePath: String, bundleBytes: Int64, groups: [AtlasAppEvidenceGroup], fingerprintHash: String) {
        self.planID = planID
        self.capturedAt = capturedAt
        self.bundlePath = bundlePath
        self.bundleBytes = bundleBytes
        self.groups = groups
        self.fingerprintHash = fingerprintHash
    }

    /// Compute a fingerprint over the sorted file paths in the given groups.
    ///
    /// - Important: Uses Swift's `Hasher` which is seeded per-process. The fingerprint is
    ///   deterministic **within a single process session** (preview → execute in the same
    ///   worker). It is NOT stable across app launches or XPC worker restarts. For
    ///   cross-session comparison, replace with a cryptographic hash (e.g., SHA-256).
    public static func computeFingerprint(for groups: [AtlasAppEvidenceGroup]) -> String {
        let paths = groups.flatMap { $0.items.map(\.path) }.sorted().joined(separator: "\n")
        var hasher = Hasher()
        hasher.combine(paths)
        let hashValue = hasher.finalize()
        // Bitcast Int to UInt64 for deterministic hex representation within the same process.
        // Direct conversion via Int64 crashes when the hash is negative,
        // so we go through the truncating bitPattern initializer instead.
        let unsigned = UInt64(truncatingIfNeeded: hashValue)
        return String(format: "%016llx", unsigned)
    }

    public func computeFingerprint() -> String {
        Self.computeFingerprint(for: groups)
    }
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

    public var bundleItem: AtlasAppFootprintEvidenceItem {
        AtlasAppFootprintEvidenceItem(path: bundlePath, bytes: bundleBytes)
    }

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

    public var trackedGroupCount: Int {
        1 + reviewOnlyGroupCount
    }

    public var trackedItemCount: Int {
        1 + reviewOnlyItemCount
    }

    public var trackedBytes: Int64 {
        bundleBytes + reviewOnlyBytes
    }

    public init(bundlePath: String, bundleBytes: Int64, reviewOnlyGroups: [AtlasAppFootprintEvidenceGroup]) {
        self.bundlePath = bundlePath
        self.bundleBytes = bundleBytes
        self.reviewOnlyGroups = reviewOnlyGroups
    }
}

public enum AtlasAppPostRestoreRefreshState: String, Hashable, Sendable {
    case refreshing
    case refreshed
    case stale
}

public struct AtlasAppPostRestoreRefreshStatus: Hashable, Sendable {
    public var appName: String
    public var bundleIdentifier: String
    public var bundlePath: String
    public var state: AtlasAppPostRestoreRefreshState
    public var recordedLeftoverItems: Int
    public var refreshedLeftoverItems: Int?
    public var issueDescription: String?
    public var evidenceDivergenceDetected: Bool
    public var divergentCategories: [AtlasAppEvidenceCategory]

    public init(
        appName: String,
        bundleIdentifier: String,
        bundlePath: String,
        state: AtlasAppPostRestoreRefreshState,
        recordedLeftoverItems: Int,
        refreshedLeftoverItems: Int? = nil,
        issueDescription: String? = nil,
        evidenceDivergenceDetected: Bool = false,
        divergentCategories: [AtlasAppEvidenceCategory] = []
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
        self.state = state
        self.recordedLeftoverItems = recordedLeftoverItems
        self.refreshedLeftoverItems = refreshedLeftoverItems
        self.issueDescription = issueDescription
        self.evidenceDivergenceDetected = evidenceDivergenceDetected
        self.divergentCategories = divergentCategories
    }
}

public enum AtlasRecoveryPayloadSchemaVersion {
    public static let current = 1
}

public struct AtlasAppRecoveryPayload: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var app: AppFootprint
    public var uninstallEvidence: AtlasAppUninstallEvidence
    public var uninstallSnapshot: AtlasAppUninstallEvidenceSnapshot?
    /// True when files changed between preview and execution (fingerprint mismatch).
    /// Indicates the snapshot may not exactly reflect what existed at trash time.
    public var evidenceDivergenceAtExecution: Bool

    public init(
        schemaVersion: Int = AtlasRecoveryPayloadSchemaVersion.current,
        app: AppFootprint,
        uninstallEvidence: AtlasAppUninstallEvidence,
        uninstallSnapshot: AtlasAppUninstallEvidenceSnapshot? = nil,
        evidenceDivergenceAtExecution: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.app = app
        self.uninstallEvidence = uninstallEvidence
        self.uninstallSnapshot = uninstallSnapshot
        self.evidenceDivergenceAtExecution = evidenceDivergenceAtExecution
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case app
        case uninstallEvidence
        case uninstallSnapshot
        case evidenceDivergenceAtExecution
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? AtlasRecoveryPayloadSchemaVersion.current
        self.app = try container.decode(AppFootprint.self, forKey: .app)
        self.uninstallEvidence = try container.decode(AtlasAppUninstallEvidence.self, forKey: .uninstallEvidence)
        self.uninstallSnapshot = try container.decodeIfPresent(AtlasAppUninstallEvidenceSnapshot.self, forKey: .uninstallSnapshot)
        self.evidenceDivergenceAtExecution = try container.decodeIfPresent(Bool.self, forKey: .evidenceDivergenceAtExecution) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(app, forKey: .app)
        try container.encode(uninstallEvidence, forKey: .uninstallEvidence)
        try container.encodeIfPresent(uninstallSnapshot, forKey: .uninstallSnapshot)
        if evidenceDivergenceAtExecution {
            try container.encode(evidenceDivergenceAtExecution, forKey: .evidenceDivergenceAtExecution)
        }
    }
}

public enum RecoveryPayload: Codable, Hashable, Sendable {
    case finding(Finding)
    case app(AtlasAppRecoveryPayload)
    case fileOrganizer(FileOrganizerRecoveryPayload)

    private enum CodingKeys: String, CodingKey {
        case finding
        case app
        case fileOrganizer
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

        if container.contains(.fileOrganizer) {
            self = .fileOrganizer(try container.decode(FileOrganizerRecoveryPayload.self, forKey: .fileOrganizer))
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "RecoveryPayload must contain a finding, app, or fileOrganizer payload."
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
        case let .fileOrganizer(payload):
            try container.encode(payload, forKey: .fileOrganizer)
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
    public var evidenceSummary: [AtlasAppEvidenceCategory: Int]?

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        bundlePath: String,
        bytes: Int64,
        leftoverItems: Int,
        evidenceSummary: [AtlasAppEvidenceCategory: Int]? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
        self.bytes = bytes
        self.leftoverItems = leftoverItems
        self.evidenceSummary = evidenceSummary
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

// MARK: - File Organizer Types

public enum FileOrganizerCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case images
    case documents
    case videos
    case audio
    case archives
    case code
    case installers
    case other

    public var title: String {
        switch self {
        case .images: return AtlasL10n.string("fileorganizer.category.images")
        case .documents: return AtlasL10n.string("fileorganizer.category.documents")
        case .videos: return AtlasL10n.string("fileorganizer.category.videos")
        case .audio: return AtlasL10n.string("fileorganizer.category.audio")
        case .archives: return AtlasL10n.string("fileorganizer.category.archives")
        case .code: return AtlasL10n.string("fileorganizer.category.code")
        case .installers: return AtlasL10n.string("fileorganizer.category.installers")
        case .other: return AtlasL10n.string("fileorganizer.category.other")
        }
    }

    public var systemImage: String {
        switch self {
        case .images: return "photo"
        case .documents: return "doc"
        case .videos: return "film"
        case .audio: return "music.note"
        case .archives: return "doc.zipper"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .installers: return "internaldrive"
        case .other: return "doc.badge.ellipsis"
        }
    }

    public var folderName: String {
        switch self {
        case .images: return "Images"
        case .documents: return "Documents"
        case .videos: return "Videos"
        case .audio: return "Audio"
        case .archives: return "Archives"
        case .code: return "Code"
        case .installers: return "Installers"
        case .other: return "Other"
        }
    }
}

public struct FileOrganizerEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var path: String
    public var fileName: String
    public var bytes: Int64
    public var category: FileOrganizerCategory
    public var proposedDestination: String

    public init(
        id: UUID = UUID(),
        path: String,
        fileName: String,
        bytes: Int64,
        category: FileOrganizerCategory,
        proposedDestination: String
    ) {
        self.id = id
        self.path = path
        self.fileName = fileName
        self.bytes = bytes
        self.category = category
        self.proposedDestination = proposedDestination
    }
}

public struct FileOrganizerScanResult: Codable, Hashable, Sendable {
    public var entries: [FileOrganizerEntry]
    public var totalFiles: Int
    public var totalBytes: Int64
    public var categoryCounts: [FileOrganizerCategory: Int]

    public init(
        entries: [FileOrganizerEntry],
        totalFiles: Int,
        totalBytes: Int64,
        categoryCounts: [FileOrganizerCategory: Int]
    ) {
        self.entries = entries
        self.totalFiles = totalFiles
        self.totalBytes = totalBytes
        self.categoryCounts = categoryCounts
    }
}

public struct FileOrganizerMoveMapping: Codable, Hashable, Sendable {
    public var originalPath: String
    public var destinationPath: String

    public init(originalPath: String, destinationPath: String) {
        self.originalPath = originalPath
        self.destinationPath = destinationPath
    }
}

public struct FileOrganizerRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var extensionPatterns: [String]
    public var namePatterns: [String]
    public var category: FileOrganizerCategory
    public var destinationSubfolder: String?
    public var minSizeBytes: Int64?
    public var maxSizeBytes: Int64?

    public init(
        id: UUID = UUID(),
        name: String,
        extensionPatterns: [String],
        namePatterns: [String] = [],
        category: FileOrganizerCategory,
        destinationSubfolder: String? = nil,
        minSizeBytes: Int64? = nil,
        maxSizeBytes: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.extensionPatterns = extensionPatterns
        self.namePatterns = namePatterns
        self.category = category
        self.destinationSubfolder = destinationSubfolder
        self.minSizeBytes = minSizeBytes
        self.maxSizeBytes = maxSizeBytes
    }
}

public struct FileOrganizerRecoveryPayload: Codable, Hashable, Sendable {
    public var moveMappings: [FileOrganizerMoveMapping]
    public var sourceFolder: String

    public init(moveMappings: [FileOrganizerMoveMapping], sourceFolder: String) {
        self.moveMappings = moveMappings
        self.sourceFolder = sourceFolder
    }
}

public struct AtlasSettings: Codable, Hashable, Sendable {
    public var recoveryRetentionDays: Int
    public var notificationsEnabled: Bool
    public var excludedPaths: [String]
    public var language: AtlasLanguage
    public var theme: AtlasTheme
    public var fileOrganizerDestinationBasePath: String
    public var fileOrganizerRecursiveScan: Bool
    public var fileOrganizerCustomRules: [FileOrganizerRule]?

    public var acknowledgementText: String {
        AtlasL10n.acknowledgement(language: language)
    }

    public var thirdPartyNoticesText: String {
        AtlasL10n.thirdPartyNotices(language: language)
    }

    public init(
        recoveryRetentionDays: Int,
        notificationsEnabled: Bool,
        excludedPaths: [String],
        language: AtlasLanguage = .default,
        theme: AtlasTheme = .default,
        fileOrganizerDestinationBasePath: String = "~/Organized",
        fileOrganizerRecursiveScan: Bool = false,
        fileOrganizerCustomRules: [FileOrganizerRule]? = nil
    ) {
        self.recoveryRetentionDays = recoveryRetentionDays
        self.notificationsEnabled = notificationsEnabled
        self.excludedPaths = excludedPaths
        self.language = language
        self.theme = theme
        self.fileOrganizerDestinationBasePath = fileOrganizerDestinationBasePath
        self.fileOrganizerRecursiveScan = fileOrganizerRecursiveScan
        self.fileOrganizerCustomRules = fileOrganizerCustomRules
    }

    private enum CodingKeys: String, CodingKey {
        case recoveryRetentionDays
        case notificationsEnabled
        case excludedPaths
        case language
        case theme
        case fileOrganizerDestinationBasePath
        case fileOrganizerRecursiveScan
        case fileOrganizerCustomRules
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let language = try container.decodeIfPresent(AtlasLanguage.self, forKey: .language) ?? .default
        self.recoveryRetentionDays = try container.decodeIfPresent(Int.self, forKey: .recoveryRetentionDays) ?? 7
        self.notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        self.excludedPaths = try container.decodeIfPresent([String].self, forKey: .excludedPaths) ?? []
        self.language = language
        self.theme = try container.decodeIfPresent(AtlasTheme.self, forKey: .theme) ?? .default
        self.fileOrganizerDestinationBasePath = try container.decodeIfPresent(String.self, forKey: .fileOrganizerDestinationBasePath) ?? "~/Organized"
        self.fileOrganizerRecursiveScan = try container.decodeIfPresent(Bool.self, forKey: .fileOrganizerRecursiveScan) ?? false
        self.fileOrganizerCustomRules = try container.decodeIfPresent([FileOrganizerRule].self, forKey: .fileOrganizerCustomRules)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recoveryRetentionDays, forKey: .recoveryRetentionDays)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(excludedPaths, forKey: .excludedPaths)
        try container.encode(language, forKey: .language)
        try container.encode(theme, forKey: .theme)
        try container.encode(fileOrganizerDestinationBasePath, forKey: .fileOrganizerDestinationBasePath)
        try container.encode(fileOrganizerRecursiveScan, forKey: .fileOrganizerRecursiveScan)
        try container.encodeIfPresent(fileOrganizerCustomRules, forKey: .fileOrganizerCustomRules)
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

    // MARK: - File Organizer Fixtures

    public static var fileOrganizerEntries: [FileOrganizerEntry] {
        fileOrganizerEntries(language: AtlasL10n.currentLanguage)
    }

    public static func fileOrganizerEntries(language: AtlasLanguage) -> [FileOrganizerEntry] {
        [
            FileOrganizerEntry(
                id: uuid("00000000-0000-0000-0000-000000000060"),
                path: "~/Desktop/screenshot.png",
                fileName: "screenshot.png",
                bytes: 2_400_000,
                category: .images,
                proposedDestination: "~/Organized/Images/screenshot.png"
            ),
            FileOrganizerEntry(
                id: uuid("00000000-0000-0000-0000-000000000061"),
                path: "~/Desktop/report.pdf",
                fileName: "report.pdf",
                bytes: 850_000,
                category: .documents,
                proposedDestination: "~/Organized/Documents/report.pdf"
            ),
            FileOrganizerEntry(
                id: uuid("00000000-0000-0000-0000-000000000062"),
                path: "~/Desktop/clip.mp4",
                fileName: "clip.mp4",
                bytes: 45_000_000,
                category: .videos,
                proposedDestination: "~/Organized/Videos/clip.mp4"
            ),
            FileOrganizerEntry(
                id: uuid("00000000-0000-0000-0000-000000000063"),
                path: "~/Downloads/archive.zip",
                fileName: "archive.zip",
                bytes: 12_000_000,
                category: .archives,
                proposedDestination: "~/Organized/Archives/archive.zip"
            ),
        ]
    }

    public static var fileOrganizerRules: [FileOrganizerRule] {
        fileOrganizerRules(language: AtlasL10n.currentLanguage)
    }

    public static func fileOrganizerRules(language: AtlasLanguage) -> [FileOrganizerRule] {
        [
            FileOrganizerRule(
                id: uuid("00000000-0000-0000-0000-000000000070"),
                name: "Image Files",
                extensionPatterns: ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "svg", "heic"],
                category: .images
            ),
            FileOrganizerRule(
                id: uuid("00000000-0000-0000-0000-000000000071"),
                name: "Video Files",
                extensionPatterns: ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm"],
                category: .videos
            ),
            FileOrganizerRule(
                id: uuid("00000000-0000-0000-0000-000000000072"),
                name: "Audio Files",
                extensionPatterns: ["mp3", "wav", "aac", "flac", "ogg", "m4a", "wma"],
                category: .audio
            ),
            FileOrganizerRule(
                id: uuid("00000000-0000-0000-0000-000000000073"),
                name: "Document Files",
                extensionPatterns: ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv"],
                category: .documents
            ),
            FileOrganizerRule(
                id: uuid("00000000-0000-0000-0000-000000000074"),
                name: "Archive Files",
                extensionPatterns: ["zip", "tar", "gz", "bz2", "xz", "rar", "7z"],
                category: .archives
            ),
            FileOrganizerRule(
                id: uuid("00000000-0000-0000-0000-000000000075"),
                name: "Code Files",
                extensionPatterns: ["swift", "py", "js", "ts", "go", "rs", "java", "c", "cpp", "h", "html", "css", "json", "xml", "yaml", "yml", "sh"],
                category: .code
            ),
            FileOrganizerRule(
                id: uuid("00000000-0000-0000-0000-000000000076"),
                name: "Installer Files",
                extensionPatterns: ["dmg", "pkg", "deb", "rpm", "msi", "app"],
                category: .installers
            ),
        ]
    }
}
