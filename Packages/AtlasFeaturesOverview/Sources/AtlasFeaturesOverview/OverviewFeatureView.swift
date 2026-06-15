import AtlasApplication
import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Overview feature (Calm Ledger spec §3 概览 — Batch K)

/// The product's front door (spec §3 概览):
/// 1. Greeting + status capsule row (disk / recovery / permissions)
/// 2. 「下一步」banner — driven by `OverviewRecommendation.recommend` (5-row table)
/// 3. Two-column body: left command column (health ring + module entries),
///    right ledger feed (recent № entries). Stacks vertically below 880pt.
///
/// Coordinator only — all logic lives in the pure enums:
/// `OverviewRecommendation`, `OverviewCommandColumn`, `OverviewLedgerFeed`.
public struct OverviewFeatureView: View {
    private let snapshot: AtlasWorkspaceSnapshot
    private let isRefreshingHealthSnapshot: Bool
    private let isLoading: Bool
    private let requiredPermissionsGranted: Int
    private let requiredPermissionsTotal: Int
    private let isCurrentSmartCleanPlanFresh: Bool
    private let currentPlanReclaimableBytes: Int64
    private let currentPlanFindingCount: Int
    private let currentPlanNumber: Int?
    private let latestScanReceiptCode: String?
    private let snoozeStore: OverviewSnoozeStore
    private let planNumberForRun: (TaskRun) -> Int?

    private let onStartSmartClean: (() -> Void)?
    private let onNavigateToSmartClean: (() -> Void)?
    private let onNavigateToApps: (() -> Void)?
    private let onNavigateToFileOrganizer: (() -> Void)?
    private let onNavigateToLedger: (() -> Void)?
    private let onNavigateToPermissions: (() -> Void)?
    private let onSelectLedgerEntry: ((String) -> Void)?

    @Environment(\.atlasContentWidth) private var contentWidth

    /// Bumped after a banner snooze write so the view re-renders and
    /// `recommendation` (which reads the non-observable snooze store) is
    /// re-evaluated immediately — otherwise the dismissed banner stays visible
    /// until some unrelated state change forces a redraw.
    @State private var snoozeRevision = 0

    public init(
        snapshot: AtlasWorkspaceSnapshot = AtlasScaffoldWorkspace.snapshot(),
        isRefreshingHealthSnapshot: Bool = false,
        isLoading: Bool = false,
        requiredPermissionsGranted: Int = 0,
        requiredPermissionsTotal: Int = 0,
        isCurrentSmartCleanPlanFresh: Bool = false,
        currentPlanReclaimableBytes: Int64 = 0,
        currentPlanFindingCount: Int = 0,
        currentPlanNumber: Int? = nil,
        latestScanReceiptCode: String? = nil,
        snoozeStore: OverviewSnoozeStore = OverviewUserDefaultsSnoozeStore(),
        planNumberForRun: @escaping (TaskRun) -> Int? = { _ in nil },
        onStartSmartClean: (() -> Void)? = nil,
        onNavigateToSmartClean: (() -> Void)? = nil,
        onNavigateToApps: (() -> Void)? = nil,
        onNavigateToFileOrganizer: (() -> Void)? = nil,
        onNavigateToLedger: (() -> Void)? = nil,
        onNavigateToPermissions: (() -> Void)? = nil,
        onSelectLedgerEntry: ((String) -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.isRefreshingHealthSnapshot = isRefreshingHealthSnapshot
        self.isLoading = isLoading
        self.requiredPermissionsGranted = requiredPermissionsGranted
        self.requiredPermissionsTotal = requiredPermissionsTotal
        self.isCurrentSmartCleanPlanFresh = isCurrentSmartCleanPlanFresh
        self.currentPlanReclaimableBytes = currentPlanReclaimableBytes
        self.currentPlanFindingCount = currentPlanFindingCount
        self.currentPlanNumber = currentPlanNumber
        self.latestScanReceiptCode = latestScanReceiptCode
        self.snoozeStore = snoozeStore
        self.planNumberForRun = planNumberForRun
        self.onStartSmartClean = onStartSmartClean
        self.onNavigateToSmartClean = onNavigateToSmartClean
        self.onNavigateToApps = onNavigateToApps
        self.onNavigateToFileOrganizer = onNavigateToFileOrganizer
        self.onNavigateToLedger = onNavigateToLedger
        self.onNavigateToPermissions = onNavigateToPermissions
        self.onSelectLedgerEntry = onSelectLedgerEntry
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("overview.screen.title"),
            subtitle: AtlasL10n.string("overview.screen.subtitle")
        ) {
            if isLoading {
                skeletonContent
            } else {
                loadedContent
            }
        }
    }

    // MARK: - Skeleton

    @ViewBuilder
    private var skeletonContent: some View {
        AtlasSkeletonCard(height: 60) // greeting + capsule row
        AtlasSkeletonCard(height: 110) // banner
        HStack(spacing: AtlasSpacing.lg) {
            AtlasSkeletonCard(height: 240)
            AtlasSkeletonCard(height: 240)
        }
    }

    // MARK: - Loaded content

    @ViewBuilder
    private var loadedContent: some View {
        // (1) Greeting + status capsule row
        greetingHeader

        // (2) 「下一步」banner (or all-clear card)
        nextStepSection

        // (3) Two-column body — stacks below 880pt
        if contentWidth >= OverviewFeatureView.twoColumnThreshold {
            HStack(alignment: .top, spacing: AtlasSpacing.lg) {
                OverviewCommandColumn(
                    snapshot: snapshot,
                    requiredPermissionsReady: requiredPermissionsReady,
                    onNavigateToSmartClean: onNavigateToSmartClean,
                    onNavigateToApps: onNavigateToApps,
                    onNavigateToFileOrganizer: onNavigateToFileOrganizer,
                    onNavigateToLedger: onNavigateToLedger
                )
                .frame(maxWidth: .infinity)

                OverviewLedgerFeed(
                    feed: ledgerFeed,
                    onNavigateToLedger: onNavigateToLedger,
                    onSelectEntry: onSelectLedgerEntry
                )
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                OverviewCommandColumn(
                    snapshot: snapshot,
                    requiredPermissionsReady: requiredPermissionsReady,
                    onNavigateToSmartClean: onNavigateToSmartClean,
                    onNavigateToApps: onNavigateToApps,
                    onNavigateToFileOrganizer: onNavigateToFileOrganizer,
                    onNavigateToLedger: onNavigateToLedger
                )
                OverviewLedgerFeed(
                    feed: ledgerFeed,
                    onNavigateToLedger: onNavigateToLedger,
                    onSelectEntry: onSelectLedgerEntry
                )
            }
        }
    }

    // MARK: - Greeting + status capsules

    @ViewBuilder
    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            Text(AtlasL10n.string("overview.greeting.morning"))
                .font(AtlasTypography.screenTitle)
                .tracking(-0.3)

            HStack(spacing: AtlasSpacing.sm) {
                statusCapsule(
                    label: diskLabel,
                    tone: diskTone,
                    systemImage: "internaldrive"
                )
                statusCapsule(
                    label: AtlasL10n.string("overview.capsule.recovery", snapshot.recoveryItems.count),
                    tone: .neutral,
                    systemImage: "checkmark.shield"
                )
                statusCapsule(
                    label: requiredPermissionsReady
                        ? AtlasL10n.string("overview.capsule.permissions.ready")
                        : AtlasL10n.string(
                            "overview.capsule.permissions.partial",
                            requiredPermissionsGranted, requiredPermissionsTotal
                        ),
                    tone: requiredPermissionsReady ? .success : .warning,
                    systemImage: "lock.shield"
                )
                Spacer(minLength: 0)
            }
        }
    }

    private func statusCapsule(label: String, tone: AtlasTone, systemImage: String) -> some View {
        HStack(spacing: AtlasSpacing.xxs) {
            Image(systemName: systemImage)
                .font(AtlasTypography.caption)
            Text(label)
                .font(AtlasTypography.caption)
                .lineLimit(1)
        }
        .foregroundStyle(tone.tint)
        .padding(.horizontal, AtlasSpacing.sm)
        .padding(.vertical, AtlasSpacing.xxs)
        .background(Capsule(style: .continuous).fill(tone.fill))
    }

    private var diskLabel: String {
        guard let health = snapshot.healthSnapshot else {
            return AtlasL10n.string("overview.capsule.disk.unknown")
        }
        return AtlasL10n.string("overview.capsule.disk", Int(health.diskUsedPercent.rounded()))
    }

    private var diskTone: AtlasTone {
        OverviewCommandColumn.tone(forDiskPercent: snapshot.healthSnapshot?.diskUsedPercent ?? 0)
    }

    // MARK: - Next step / banner

    @ViewBuilder
    private var nextStepSection: some View {
        let banner = recommendation
        if let banner {
            AtlasNextActionBanner(
                headline: banner.headline,
                rationale: banner.rationale,
                primaryTitle: banner.primaryTitle,
                onPrimary: { handlePrimary(banner) },
                secondaryTitle: banner.secondaryTitle,
                onSecondary: banner.secondaryTitle != nil
                    ? { handleSecondary(banner) }
                    : nil,
                onDismiss: banner.isSnoozeable
                    ? {
                        snoozeStore.snooze(
                            id: banner.id,
                            durationDays: OverviewRecommendation.snoozeDurationDays,
                            now: Date()
                        )
                        snoozeRevision &+= 1
                    }
                    : nil
            )
        } else {
            // All clear card — no button, shows most recent ledger entry teaser.
            allClearCard
        }
    }

    @ViewBuilder
    private var allClearCard: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            HStack(spacing: AtlasSpacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(AtlasColor.success)
                Text(AtlasL10n.string("overview.recommend.allclear.title"))
                    .font(AtlasTypography.sectionTitle)
            }
            Text(AtlasL10n.string("overview.recommend.allclear.detail"))
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.successFill)
        )
    }

    // MARK: - Banner action routing (one-tap start NEVER skips review)

    private func handlePrimary(_ banner: OverviewRecommendation.BannerConfig) {
        switch banner.primaryTarget {
        case .authorizePermissions:
            onNavigateToPermissions?()
        case .executePlan:
            // Navigate to smart clean review (②) — the plan is fresh and Batch I
            // pre-selects the safe group by default. We do NOT skip review:
            // the user still confirms on ② before ③ execute.
            onNavigateToSmartClean?()
        case .runScan:
            // Navigate + trigger scan (existing onStartSmartClean wiring).
            onStartSmartClean?()
        }
    }

    private func handleSecondary(_ banner: OverviewRecommendation.BannerConfig) {
        switch banner.secondaryTarget {
        case .navigateToPermissions: onNavigateToPermissions?()
        case .navigateToSmartClean: onNavigateToSmartClean?()
        case .none: break
        }
    }

    // MARK: - Pure derived values

    /// The active recommendation, or nil when all-clear. Re-evaluated each
    /// render so a snooze write / a permission grant is reflected immediately.
    private var recommendation: OverviewRecommendation.BannerConfig? {
        OverviewRecommendation.recommend(inputs)
    }

    private var inputs: OverviewRecommendation.Inputs {
        _ = snoozeRevision // re-evaluate when a banner snooze is written here
        return OverviewRecommendation.Inputs(
            requiredPermissionsGranted: requiredPermissionsGranted,
            requiredPermissionsTotal: requiredPermissionsTotal,
            isCurrentSmartCleanPlanFresh: isCurrentSmartCleanPlanFresh,
            currentPlanReclaimableBytes: currentPlanReclaimableBytes,
            currentPlanFindingCount: currentPlanFindingCount,
            currentPlanNumber: currentPlanNumber,
            lastScanDate: lastScanDate,
            diskUsedPercent: snapshot.healthSnapshot?.diskUsedPercent,
            latestScanReceiptCode: latestScanReceiptCode,
            snoozedIDs: snoozeStore.activeSnoozes(now: Date()),
            now: Date()
        )
    }

    /// Most recent scan activity date (finishedAt ?? startedAt of the latest
    /// .scan or .executePlan run). nil ⇒ no scan ever.
    private var lastScanDate: Date? {
        let scanRuns = snapshot.taskRuns.filter { $0.kind == .scan || $0.kind == .executePlan }
        return scanRuns.map { $0.finishedAt ?? $0.startedAt }.max()
    }

    private var ledgerFeed: OverviewLedgerFeed.FeedData {
        OverviewLedgerFeed.feedData(
            taskRuns: snapshot.taskRuns,
            planNumber: planNumberForRun
        )
    }

    private var requiredPermissionsReady: Bool {
        requiredPermissionsTotal > 0
            && requiredPermissionsGranted == requiredPermissionsTotal
    }

    /// Two-column body kicks in at 880pt content width (spec §3 <880 纵向堆叠).
    static let twoColumnThreshold: CGFloat = 880
}
