import AtlasApplication
import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct OverviewFeatureView: View {
    private let snapshot: AtlasWorkspaceSnapshot
    private let isRefreshingHealthSnapshot: Bool

    public init(
        snapshot: AtlasWorkspaceSnapshot = AtlasScaffoldWorkspace.snapshot(),
        isRefreshingHealthSnapshot: Bool = false
    ) {
        self.snapshot = snapshot
        self.isRefreshingHealthSnapshot = isRefreshingHealthSnapshot
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

            LazyVGrid(columns: AtlasLayout.metricColumns, spacing: AtlasSpacing.lg) {
                AtlasMetricCard(
                    title: AtlasL10n.string("overview.metric.reclaimable.title"),
                    value: AtlasFormatters.byteCount(snapshot.reclaimableSpaceBytes),
                    detail: AtlasL10n.string("overview.metric.reclaimable.detail"),
                    tone: .success,
                    systemImage: "sparkles",
                    elevation: .prominent
                )
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

            AtlasInfoCard(
                title: AtlasL10n.string("overview.snapshot.title"),
                subtitle: AtlasL10n.string("overview.snapshot.subtitle")
            ) {
                if isRefreshingHealthSnapshot, snapshot.healthSnapshot == nil {
                    AtlasLoadingState(
                        title: AtlasL10n.string("overview.snapshot.loading.title"),
                        detail: AtlasL10n.string("overview.snapshot.loading.detail")
                    )
                } else if let healthSnapshot = snapshot.healthSnapshot {
                    LazyVGrid(columns: AtlasLayout.metricColumns, spacing: AtlasSpacing.lg) {
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

                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ForEach(Array(healthSnapshot.optimizations.prefix(4))) { optimization in
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
                } else {
                    AtlasEmptyState(
                        title: AtlasL10n.string("overview.snapshot.empty.title"),
                        detail: AtlasL10n.string("overview.snapshot.empty.detail"),
                        systemImage: "waveform.path.ecg",
                        tone: .warning
                    )
                }
            }

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
                                systemImage: icon(for: finding.category),
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
                    }
                }
            }

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
                                systemImage: icon(for: taskRun.kind),
                                tone: taskRun.status.atlasTone
                            ) {
                                AtlasStatusChip(taskRun.status.title, tone: taskRun.status.atlasTone)
                            }
                        }
                    }
                }
            }
        }
    }

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

    private func icon(for category: String) -> String {
        switch category.lowercased() {
        case "developer":
            return "hammer"
        case "system":
            return "gearshape.2"
        case "apps":
            return "square.stack.3d.up"
        case "browsers":
            return "globe"
        default:
            return "sparkles"
        }
    }

    private func icon(for kind: TaskKind) -> String {
        switch kind {
        case .scan:
            return "sparkles"
        case .executePlan:
            return "play.circle"
        case .uninstallApp:
            return "trash"
        case .restore:
            return "arrow.uturn.backward.circle"
        case .inspectPermissions:
            return "lock.shield"
        }
    }
}

private extension RiskLevel {
    var atlasTone: AtlasTone {
        switch self {
        case .safe:
            return .success
        case .review:
            return .warning
        case .advanced:
            return .danger
        }
    }
}

private extension TaskStatus {
    var atlasTone: AtlasTone {
        switch self {
        case .queued:
            return .neutral
        case .running:
            return .warning
        case .completed:
            return .success
        case .failed, .cancelled:
            return .danger
        }
    }
}
