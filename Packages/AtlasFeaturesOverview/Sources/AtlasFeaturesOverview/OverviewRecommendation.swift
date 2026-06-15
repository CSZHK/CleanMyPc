import AtlasApplication
import AtlasDesignSystem
import AtlasDomain
import Foundation

// MARK: - Recommendation priority (pure, spec §3 「下一步」表 1–5 行)

/// "Next action" recommendation for the overview banner (spec §3 概览「下一步」
/// 推荐优先级表 v1.1). Pure function over real model state — never fabricates
/// findings, scan dates, or reclaimable bytes; every input is supplied by the
/// caller from the live `AtlasWorkspaceSnapshot` and `AtlasAppModel` flags.
///
/// Priority order (highest wins):
/// 1. missing required permission → authorize
/// 2. fresh plan present → execute №N (safe group pre-selected — review NOT skipped)
/// 3. no scan / scan stale (>7 days) → run scan
/// 4. disk usage >85% → deep scan
/// 5. none of the above → "all clear" (returns nil — caller renders static card)
///
/// Snooze cooldown (PER Decision Log 2026-06-10): a recommendation id can be
/// snoozed for 7 days via `OverviewSnoozeStore`. A snoozed, unexpired
/// recommendation is skipped (priority falls through to the next candidate).
public enum OverviewRecommendation {

    /// Banner render configuration (caller maps onto `AtlasNextActionBanner`).
    public struct BannerConfig: Equatable {
        public enum PrimaryTarget: Equatable, Sendable {
            case authorizePermissions
            case executePlan(number: Int, reclaimableBytes: Int64, findingCount: Int)
            case runScan
        }

        public let id: String
        public let headline: String
        /// Timeliness rationale with a mono-style timestamp suffix
        /// ("基于 06-08 14:32 回执") — already localized & formatted.
        public let rationale: String
        public let primaryTitle: String
        public let primaryTarget: PrimaryTarget
        /// Secondary action title (e.g. "查看证据"). nil ⇒ no secondary.
        public let secondaryTitle: String?
        public let secondaryTarget: SecondaryTarget
        /// True when this banner supports the 忽略 (7-day cooldown) action.
        /// Permission banner is NOT snoozable (auth is a hard prerequisite).
        public let isSnoozeable: Bool

        public enum SecondaryTarget: Equatable, Sendable {
            case navigateToPermissions
            case navigateToSmartClean
            case none
        }

        public init(
            id: String,
            headline: String,
            rationale: String,
            primaryTitle: String,
            primaryTarget: PrimaryTarget,
            secondaryTitle: String?,
            secondaryTarget: SecondaryTarget,
            isSnoozeable: Bool
        ) {
            self.id = id
            self.headline = headline
            self.rationale = rationale
            self.primaryTitle = primaryTitle
            self.primaryTarget = primaryTarget
            self.secondaryTitle = secondaryTitle
            self.secondaryTarget = secondaryTarget
            self.isSnoozeable = isSnoozeable
        }
    }

    /// Inputs to `recommend(_:)`. Every field is sourced from real model state.
    public struct Inputs: Equatable {
        public var requiredPermissionsGranted: Int
        public var requiredPermissionsTotal: Int
        public var isCurrentSmartCleanPlanFresh: Bool
        public var currentPlanReclaimableBytes: Int64
        public var currentPlanFindingCount: Int
        public var currentPlanNumber: Int?
        /// Most recent scan activity date (finishedAt ?? startedAt of the latest
        /// .scan / .executePlan task run). nil ⇒ no scan ever.
        public var lastScanDate: Date?
        /// Disk-used percent from health snapshot. nil ⇒ health snapshot absent
        /// (row 4 cannot fire; falls through to row 5).
        public var diskUsedPercent: Double?
        /// Receipt code (first 4 hex of the scan digest) for the rationale's
        /// timeliness stamp. nil ⇒ no receipt yet.
        public var latestScanReceiptCode: String?
        /// Recommendation ids currently snoozed, mapped to their expiry date.
        public var snoozedIDs: [String: Date]
        /// "Now" injected for deterministic tests.
        public var now: Date

        public init(
            requiredPermissionsGranted: Int,
            requiredPermissionsTotal: Int,
            isCurrentSmartCleanPlanFresh: Bool,
            currentPlanReclaimableBytes: Int64,
            currentPlanFindingCount: Int,
            currentPlanNumber: Int?,
            lastScanDate: Date?,
            diskUsedPercent: Double?,
            latestScanReceiptCode: String?,
            snoozedIDs: [String: Date] = [:],
            now: Date = Date()
        ) {
            self.requiredPermissionsGranted = requiredPermissionsGranted
            self.requiredPermissionsTotal = requiredPermissionsTotal
            self.isCurrentSmartCleanPlanFresh = isCurrentSmartCleanPlanFresh
            self.currentPlanReclaimableBytes = currentPlanReclaimableBytes
            self.currentPlanFindingCount = currentPlanFindingCount
            self.currentPlanNumber = currentPlanNumber
            self.lastScanDate = lastScanDate
            self.diskUsedPercent = diskUsedPercent
            self.latestScanReceiptCode = latestScanReceiptCode
            self.snoozedIDs = snoozedIDs
            self.now = now
        }
    }

    // MARK: recommend (pure)

    /// Resolves the highest-priority non-snoozed recommendation, or nil when
    /// the workspace is "all clear" (row 5). Pure & deterministic for tests.
    public static func recommend(_ inputs: Inputs) -> BannerConfig? {
        // Row 1 — required permission missing. NOT snoozable (hard prerequisite).
        if inputs.requiredPermissionsTotal > 0
            && inputs.requiredPermissionsGranted < inputs.requiredPermissionsTotal {
            return BannerConfig(
                id: Self.permissionID,
                headline: AtlasL10n.string("overview.recommend.permission.headline"),
                rationale: AtlasL10n.string("overview.recommend.permission.rationale"),
                primaryTitle: AtlasL10n.string("overview.recommend.permission.primary"),
                primaryTarget: .authorizePermissions,
                secondaryTitle: nil,
                secondaryTarget: .none,
                isSnoozeable: false
            )
        }

        // Row 2 — fresh plan ready. Must have at least one finding (the plan is
        // "ready to execute", not a no-op).
        if inputs.isCurrentSmartCleanPlanFresh, inputs.currentPlanFindingCount > 0 {
            // Snooze lookup: a fresh-plan banner keyed by the plan № — snoozing
            // a specific plan does not suppress the next plan's banner.
            let planID = Self.planID(number: inputs.currentPlanNumber)
            if !isSnoozed(id: planID, inputs: inputs) {
                let number = inputs.currentPlanNumber ?? 0
                return BannerConfig(
                    id: planID,
                    headline: AtlasL10n.string("overview.recommend.plan.headline", number),
                    rationale: planRationale(inputs: inputs),
                    primaryTitle: AtlasL10n.string("overview.recommend.plan.primary", number),
                    primaryTarget: .executePlan(
                        number: number,
                        reclaimableBytes: inputs.currentPlanReclaimableBytes,
                        findingCount: inputs.currentPlanFindingCount
                    ),
                    secondaryTitle: nil,
                    secondaryTarget: .none,
                    isSnoozeable: true
                )
            }
        }

        // Row 3 — no scan ever, or scan older than 7 days.
        let scanAgeDays = ageInDays(inputs.lastScanDate, now: inputs.now)
        let scanStale = (inputs.lastScanDate == nil)
            || ((scanAgeDays ?? 0) > Double(Self.staleScanThresholdDays))
        if scanStale {
            if !isSnoozed(id: Self.scanStaleID, inputs: inputs) {
                return BannerConfig(
                    id: Self.scanStaleID,
                    headline: inputs.lastScanDate == nil
                        ? AtlasL10n.string("overview.recommend.scan.none.headline")
                        : AtlasL10n.string("overview.recommend.scan.stale.headline"),
                    rationale: scanRationale(
                        lastScanDate: inputs.lastScanDate,
                        receiptCode: inputs.latestScanReceiptCode
                    ),
                    primaryTitle: AtlasL10n.string("overview.recommend.scan.primary"),
                    primaryTarget: .runScan,
                    secondaryTitle: nil,
                    secondaryTarget: .none,
                    isSnoozeable: true
                )
            }
        }

        // Row 4 — disk > 85%.
        if let pct = inputs.diskUsedPercent, pct > Self.highDiskThresholdPercent {
            if !isSnoozed(id: Self.diskFullID, inputs: inputs) {
                let pctInt = Int(pct.rounded())
                return BannerConfig(
                    id: Self.diskFullID,
                    headline: AtlasL10n.string("overview.recommend.disk.headline"),
                    rationale: AtlasL10n.string("overview.recommend.disk.rationale", pctInt),
                    primaryTitle: AtlasL10n.string("overview.recommend.disk.primary"),
                    primaryTarget: .runScan,
                    secondaryTitle: nil,
                    secondaryTarget: .none,
                    isSnoozeable: true
                )
            }
        }

        // Row 5 — all clear.
        return nil
    }

    // MARK: - Constants (exposed for tests)

    /// >7 days ⇒ stale (spec §3 row 3).
    public static let staleScanThresholdDays = 7
    /// >85% disk ⇒ high-pressure (spec §3 row 4).
    public static let highDiskThresholdPercent = 85.0
    /// Snooze duration (spec §3 忽略: 7 days).
    public static let snoozeDurationDays = 7

    public static let permissionID = "permission"
    public static let scanStaleID = "scan.stale"
    public static let diskFullID = "disk.full"
    public static func planID(number: Int?) -> String {
        "plan.\(number ?? 0)"
    }

    // MARK: - Pure helpers

    /// True when the id is in the snooze table and its expiry is still future.
    public static func isSnoozed(id: String, inputs: Inputs) -> Bool {
        guard let expiry = inputs.snoozedIDs[id] else { return false }
        return expiry > inputs.now
    }

    /// Days between `date` and `now`. Negative or nil ⇒ nil (treated as "never").
    public static func ageInDays(_ date: Date?, now: Date) -> Double? {
        guard let date else { return nil }
        let seconds = now.timeIntervalSince(date)
        return max(0, seconds / 86_400)
    }

    // MARK: - Rationale builders (timeliness mono stamp — spec §3)

    private static func planRationale(inputs: Inputs) -> String {
        let bytesStr = AtlasFormatters.byteCount(inputs.currentPlanReclaimableBytes)
        if let receipt = inputs.latestScanReceiptCode, let scanDate = inputs.lastScanDate {
            let monoStamp = monoTimeliness(receipt: receipt, scanDate: scanDate)
            return AtlasL10n.string(
                "overview.recommend.plan.rationale.receipt",
                inputs.currentPlanFindingCount, bytesStr, monoStamp
            )
        }
        return AtlasL10n.string(
            "overview.recommend.plan.rationale",
            inputs.currentPlanFindingCount, bytesStr
        )
    }

    private static func scanRationale(lastScanDate: Date?, receiptCode: String?) -> String {
        if let scanDate = lastScanDate, let receipt = receiptCode {
            let monoStamp = monoTimeliness(receipt: receipt, scanDate: scanDate)
            return AtlasL10n.string("overview.recommend.scan.stale.rationale.receipt", monoStamp)
        }
        if lastScanDate != nil {
            return AtlasL10n.string("overview.recommend.scan.stale.rationale")
        }
        return AtlasL10n.string("overview.recommend.scan.none.rationale")
    }

    /// Mono-style timeliness stamp "基于 06-08 14:32 回执 #XXXX" — the receipt
    /// code is monospaced-digit rendered downstream by SwiftUI; the L10n value
    /// itself carries the receipt hash so the user always sees provenance.
    static func monoTimeliness(receipt: String, scanDate: Date) -> String {
        let stamp = AtlasFormatters.shortDate(scanDate)
        return AtlasL10n.string("overview.recommend.timeliness", stamp, receipt)
    }
}

// MARK: - Snooze store (client-side UserDefaults — PER Decision Log 2026-06-10)

/// Read/write for per-recommendation snooze expiries. Keys are namespaced
/// `atlas.overview.snooze.<id>` (PER da8c42f — pure client side; the worker
/// `sanitized(settings:)` silently drops unknown fields, so AtlasSettings is
/// NOT a safe home).
public protocol OverviewSnoozeStore: AnyObject, Sendable {
    /// All currently-active snoozes (id → expiry). Expired entries may be
    /// pruned by the implementation; readers compare `expiry > now`.
    func activeSnoozes(now: Date) -> [String: Date]
    /// Snooze `id` for `durationDays` from `now`. Overwrites any prior value.
    func snooze(id: String, durationDays: Int, now: Date)
    /// Remove a snooze entry (e.g. when its recommendation becomes irrelevant).
    func clear(id: String)
}

/// UserDefaults-backed default. Tests inject an isolated suite via the
/// `defaults` parameter (see `OverviewRecommendationTests`).
public final class OverviewUserDefaultsSnoozeStore: OverviewSnoozeStore, @unchecked Sendable {
    public static let keyPrefix = "atlas.overview.snooze."

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func activeSnoozes(now: Date) -> [String: Date] {
        var result: [String: Date] = [:]
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix(Self.keyPrefix),
                  let interval = value as? Double else { continue }
            let expiry = Date(timeIntervalSince1970: interval)
            if expiry > now {
                let id = String(key.dropFirst(Self.keyPrefix.count))
                result[id] = expiry
            } else {
                // Prune expired.
                defaults.removeObject(forKey: key)
            }
        }
        return result
    }

    public func snooze(id: String, durationDays: Int, now: Date) {
        let expiry = now.addingTimeInterval(TimeInterval(durationDays) * 86_400)
        defaults.set(expiry.timeIntervalSince1970, forKey: Self.keyPrefix + id)
    }

    public func clear(id: String) {
        defaults.removeObject(forKey: Self.keyPrefix + id)
    }
}

/// In-memory `OverviewSnoozeStore` for tests. No UserDefaults; isolated per
/// instance. Safe to share across tests since each test constructs its own.
public final class InMemorySnoozeStore: OverviewSnoozeStore, @unchecked Sendable {
    private var storage: [String: Date] = [:]
    private let lock = NSLock()

    public init() {}

    public func activeSnoozes(now: Date) -> [String: Date] {
        lock.lock(); defer { lock.unlock() }
        var active: [String: Date] = [:]
        for (id, expiry) in storage where expiry > now {
            active[id] = expiry
        }
        return active
    }

    public func snooze(id: String, durationDays: Int, now: Date) {
        lock.lock(); defer { lock.unlock() }
        storage[id] = now.addingTimeInterval(TimeInterval(durationDays) * 86_400)
    }

    public func clear(id: String) {
        lock.lock(); defer { lock.unlock() }
        storage[id] = nil
    }
}
