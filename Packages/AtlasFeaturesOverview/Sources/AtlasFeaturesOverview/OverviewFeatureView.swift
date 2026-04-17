import AtlasApplication
import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct OverviewFeatureView: View {
    private let snapshot: AtlasWorkspaceSnapshot
    private let isRefreshingHealthSnapshot: Bool
    private let onStartSmartClean: (() -> Void)?
    private let onNavigateToSmartClean: (() -> Void)?
    private let onNavigateToHistory: (() -> Void)?
    private let onNavigateToPermissions: (() -> Void)?

    @Environment(\.atlasContentWidth) private var contentWidth

    public init(
        snapshot: AtlasWorkspaceSnapshot = AtlasScaffoldWorkspace.snapshot(),
        isRefreshingHealthSnapshot: Bool = false,
        onStartSmartClean: (() -> Void)? = nil,
        onNavigateToSmartClean: (() -> Void)? = nil,
        onNavigateToHistory: (() -> Void)? = nil,
        onNavigateToPermissions: (() -> Void)? = nil
    ) {
        self.snapshot = snapshot
        self.isRefreshingHealthSnapshot = isRefreshingHealthSnapshot
        self.onStartSmartClean = onStartSmartClean
        self.onNavigateToSmartClean = onNavigateToSmartClean
        self.onNavigateToHistory = onNavigateToHistory
        self.onNavigateToPermissions = onNavigateToPermissions
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("overview.screen.title"),
            subtitle: AtlasL10n.string("overview.screen.subtitle")
        ) {
            AtlasCallout(
                title: overviewCalloutTitle,
                detail: overviewCalloutDetail,
                tone: overviewCalloutTone,
                systemImage: overviewCalloutTone.symbol
            )

            // MARK: - Hero metric — AtlasHeroCard with progress ring
            AtlasHeroCard(
                progress: heroDiskProgress,
                value: AtlasFormatters.byteCount(snapshot.reclaimableSpaceBytes),
                subtitle: AtlasL10n.string("overview.metric.reclaimable.detail"),
                tone: .success,
                icon: "sparkles",
                ringSize: 120,
                lineWidth: 10
            )

            // MARK: - Secondary metrics — adaptive 2/1 columns
            LazyVGrid(columns: secondaryColumns, spacing: AtlasSpacing.lg) {
                AtlasMetricCard(
                    title: AtlasL10n.string("overview.metric.findings.title"),
                    value: "\(snapshot.findings.count)",
                    detail: AtlasL10n.string("overview.metric.findings.detail"),
                    tone: .neutral,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                AtlasMetricCard(
                    title: AtlasL10n.string("overview.metric.permissions.title"),
                    value: "\(grantedRequiredPermissionCount)/\(max(requiredPermissionCount, 1))",
                    detail: requiredPermissionsReady
                        ? AtlasL10n.string("overview.metric.permissions.ready")
                        : AtlasL10n.string("overview.metric.permissions.limited"),
                    tone: requiredPermissionsReady ? .success : .warning,
                    systemImage: "lock.shield"
                )
            }

            // MARK: - Quick actions bar
            quickActionsBar

            // MARK: - System Snapshot (flattened — no InfoCard wrapper)
            systemSnapshotSection

            // MARK: - Recommended Actions
            AtlasInfoCard(
                title: AtlasL10n.string("overview.actions.title"),
                subtitle: AtlasL10n.string("overview.actions.subtitle")
            ) {
                if snapshot.findings.isEmpty {
                    AtlasEmptyState(
                        title: AtlasL10n.string("overview.actions.empty.title"),
                        detail: AtlasL10n.string("overview.actions.empty.detail"),
                        systemImage: "sparkles.slash",
                        tone: .neutral
                    )
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ForEach(Array(snapshot.findings.prefix(4))) { finding in
                            AtlasDetailRow(
                                title: finding.title,
                                subtitle: finding.detail,
                                footnote: "\(AtlasL10n.localizedCategory(finding.category)) • \(riskSupport(for: finding.risk))",
                                systemImage: AtlasCategoryIcon.systemImage(for: finding.category),
                                tone: finding.risk.atlasTone
                            ) {
                                VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
                                    AtlasStatusChip(finding.risk.title, tone: finding.risk.atlasTone)
                                    Text(AtlasFormatters.byteCount(finding.bytes))
                                        .font(AtlasTypography.label)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if snapshot.findings.count > 4, let onNavigateToSmartClean {
                            Button {
                                onNavigateToSmartClean()
                            } label: {
                                Label(
                                    AtlasL10n.string("overview.actions.viewAll", snapshot.findings.count),
                                    systemImage: "arrow.right.circle"
                                )
                            }
                            .buttonStyle(.atlasGhost)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }

            // MARK: - Recent Activity
            AtlasInfoCard(
                title: AtlasL10n.string("overview.activity.title"),
                subtitle: AtlasL10n.string("overview.activity.subtitle")
            ) {
                if snapshot.taskRuns.isEmpty {
                    AtlasEmptyState(
                        title: AtlasL10n.string("overview.activity.empty.title"),
                        detail: AtlasL10n.string("overview.activity.empty.detail"),
                        systemImage: "clock.badge.questionmark",
                        tone: .neutral
                    )
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ForEach(snapshot.taskRuns.prefix(3)) { taskRun in
                            AtlasDetailRow(
                                title: taskRun.kind.title,
                                subtitle: taskRun.summary,
                                footnote: timelineFootnote(for: taskRun),
                                systemImage: taskRun.kind.atlasSystemImage,
                                tone: taskRun.status.atlasTone
                            ) {
                                AtlasStatusChip(taskRun.status.title, tone: taskRun.status.atlasTone)
                            }
                        }

                        if snapshot.taskRuns.count > 3, let onNavigateToHistory {
                            Button {
                                onNavigateToHistory()
                            } label: {
                                Label(
                                    AtlasL10n.string("overview.activity.viewAll"),
                                    systemImage: "arrow.right.circle"
                                )
                            }
                            .buttonStyle(.atlasGhost)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions Bar

    @ViewBuilder
    private var quickActionsBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AtlasSpacing.lg) {
                quickActionButtons
            }

            VStack(spacing: AtlasSpacing.md) {
                quickActionButtons
            }
        }
    }

    @ViewBuilder
    private var quickActionButtons: some View {
        if let onStartSmartClean {
            Button {
                onStartSmartClean()
            } label: {
                Label(
                    AtlasL10n.string("overview.action.smartClean"),
                    systemImage: AtlasIcon.smartClean
                )
            }
            .buttonStyle(.atlasPrimary)
            .accessibilityHint(AtlasL10n.string("overview.action.smartClean.hint"))
        }

        if !requiredPermissionsReady, let onNavigateToPermissions {
            Button {
                onNavigateToPermissions()
            } label: {
                Label(
                    AtlasL10n.string("overview.action.permissions"),
                    systemImage: AtlasIcon.permissions
                )
            }
            .buttonStyle(.atlasSecondary)
            .accessibilityHint(AtlasL10n.string("overview.action.permissions.hint"))
        }
    }

    // MARK: - System Snapshot Section (flattened)

    @ViewBuilder
    private var systemSnapshotSection: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            // Section header
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text(AtlasL10n.string("overview.snapshot.title"))
                    .font(AtlasTypography.sectionTitle)

                Text(AtlasL10n.string("overview.snapshot.subtitle"))
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isRefreshingHealthSnapshot, snapshot.healthSnapshot == nil {
                AtlasLoadingState(
                    title: AtlasL10n.string("overview.snapshot.loading.title"),
                    detail: AtlasL10n.string("overview.snapshot.loading.detail")
                )
            } else if let healthSnapshot = snapshot.healthSnapshot {
                LazyVGrid(columns: adaptiveColumns, spacing: AtlasSpacing.lg) {
                    AtlasMetricCard(
                        title: AtlasL10n.string("overview.snapshot.memory.title"),
                        value: "\(formatted(healthSnapshot.memoryUsedGB))/\(formatted(healthSnapshot.memoryTotalGB)) GB",
                        detail: AtlasL10n.string("overview.snapshot.memory.detail"),
                        tone: healthSnapshot.memoryUsedGB / max(healthSnapshot.memoryTotalGB, 1) > 0.75 ? .warning : .neutral,
                        systemImage: "memorychip"
                    )
                    AtlasMetricCard(
                        title: AtlasL10n.string("overview.snapshot.disk.title"),
                        value: "\(formatted(healthSnapshot.diskUsedPercent))%",
                        detail: AtlasL10n.string("overview.snapshot.disk.detail", formatted(healthSnapshot.diskUsedGB), formatted(healthSnapshot.diskTotalGB)),
                        tone: healthSnapshot.diskUsedPercent > 80 ? .warning : .success,
                        systemImage: "internaldrive"
                    )
                    AtlasMetricCard(
                        title: AtlasL10n.string("overview.snapshot.uptime.title"),
                        value: "\(formatted(healthSnapshot.uptimeDays)) \(AtlasL10n.string("common.days"))",
                        detail: AtlasL10n.string("overview.snapshot.uptime.detail"),
                        tone: .neutral,
                        systemImage: "clock"
                    )
                }

                AtlasCallout(
                    title: healthSnapshot.diskUsedPercent > 80 ? AtlasL10n.string("overview.snapshot.callout.warning.title") : AtlasL10n.string("overview.snapshot.callout.ok.title"),
                    detail: healthSnapshot.diskUsedPercent > 80
                        ? AtlasL10n.string("overview.snapshot.callout.warning.detail")
                        : AtlasL10n.string("overview.snapshot.callout.ok.detail"),
                    tone: healthSnapshot.diskUsedPercent > 80 ? .warning : .success,
                    systemImage: healthSnapshot.diskUsedPercent > 80 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                )

                AtlasSectionDisclosure(
                    title: AtlasL10n.string("overview.snapshot.optimizations.title"),
                    count: healthSnapshot.optimizations.count,
                    defaultExpanded: healthSnapshot.optimizations.count <= 4
                ) {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ForEach(healthSnapshot.optimizations) { optimization in
                            AtlasDetailRow(
                                title: optimization.name,
                                subtitle: optimization.detail,
                                footnote: AtlasL10n.localizedCategory(optimization.category).capitalized,
                                systemImage: optimization.isSafe ? "checkmark.shield" : "slider.horizontal.3",
                                tone: optimization.isSafe ? .success : .warning
                            ) {
                                AtlasStatusChip(optimization.isSafe ? AtlasL10n.string("risk.safe") : AtlasL10n.string("risk.review"), tone: optimization.isSafe ? .success : .warning)
                            }
                        }
                    }
                }
            } else {
                AtlasEmptyState(
                    title: AtlasL10n.string("overview.snapshot.empty.title"),
                    detail: AtlasL10n.string("overview.snapshot.empty.detail"),
                    systemImage: "waveform.path.ecg",
                    tone: .warning
                )
            }
        }
    }

    // MARK: - Adaptive Columns

    private var adaptiveColumns: [GridItem] {
        AtlasLayout.adaptiveMetricColumns(for: contentWidth)
    }

    private var secondaryColumns: [GridItem] {
        contentWidth >= 420
            ? [
                GridItem(.flexible(minimum: 180), spacing: AtlasSpacing.lg),
                GridItem(.flexible(minimum: 180), spacing: AtlasSpacing.lg),
              ]
            : [
                GridItem(.flexible(minimum: 180), spacing: AtlasSpacing.lg),
              ]
    }

    // MARK: - Computed Properties

    private var requiredPermissionStates: [PermissionState] {
        snapshot.permissions.filter { $0.kind.isRequiredForCurrentWorkflows }
    }

    private var requiredPermissionCount: Int {
        requiredPermissionStates.count
    }

    private var grantedRequiredPermissionCount: Int {
        requiredPermissionStates.filter(\.isGranted).count
    }

    private var requiredPermissionsReady: Bool {
        requiredPermissionCount > 0 && grantedRequiredPermissionCount == requiredPermissionCount
    }

    private var overviewCalloutTitle: String {
        requiredPermissionsReady
            ? AtlasL10n.string("overview.callout.ready.title")
            : AtlasL10n.string("overview.callout.limited.title")
    }

    private var overviewCalloutDetail: String {
        requiredPermissionsReady
            ? AtlasL10n.string("overview.callout.ready.detail")
            : AtlasL10n.string("overview.callout.limited.detail")
    }

    private var overviewCalloutTone: AtlasTone {
        requiredPermissionsReady ? .success : .warning
    }

    private var heroDiskProgress: Double {
        guard let health = snapshot.healthSnapshot else { return 0 }
        return min(max(health.diskUsedPercent / 100.0, 0), 1)
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    private func riskSupport(for risk: RiskLevel) -> String {
        switch risk {
        case .safe:
            return AtlasL10n.string("overview.risk.safe")
        case .review:
            return AtlasL10n.string("overview.risk.review")
        case .advanced:
            return AtlasL10n.string("overview.risk.advanced")
        }
    }

    private func timelineFootnote(for taskRun: TaskRun) -> String {
        let start = AtlasFormatters.relativeDate(taskRun.startedAt)
        if let finishedAt = taskRun.finishedAt {
            return AtlasL10n.string("overview.activity.timeline.finished", start, AtlasFormatters.relativeDate(finishedAt))
        }
        return AtlasL10n.string("overview.activity.timeline.running", start)
    }

}
