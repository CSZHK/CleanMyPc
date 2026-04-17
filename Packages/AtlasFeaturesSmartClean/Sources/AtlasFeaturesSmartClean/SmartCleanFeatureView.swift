import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct SmartCleanFeatureView: View {
    @Environment(\.atlasContentWidth) private var contentWidth

    private let findings: [Finding]
    private let plan: ActionPlan
    private let scanSummary: String
    private let scanProgress: Double
    private let isScanning: Bool
    private let isExecutingPlan: Bool
    private let isCurrentPlanFresh: Bool
    private let canExecutePlan: Bool
    private let planIssue: String?
    private let executionIssue: String?
    private let onStartScan: () -> Void
    private let onRefreshPreview: () -> Void
    private let onExecutePlan: () -> Void

    @State private var showExecuteConfirmation = false

    public init(
        findings: [Finding] = AtlasScaffoldFixtures.findings,
        plan: ActionPlan = AtlasScaffoldFixtures.actionPlan,
        scanSummary: String = AtlasL10n.string("model.scan.ready"),
        scanProgress: Double = 0,
        isScanning: Bool = false,
        isExecutingPlan: Bool = false,
        isCurrentPlanFresh: Bool = false,
        canExecutePlan: Bool = false,
        planIssue: String? = nil,
        executionIssue: String? = nil,
        onStartScan: @escaping () -> Void = {},
        onRefreshPreview: @escaping () -> Void = {},
        onExecutePlan: @escaping () -> Void = {}
    ) {
        self.findings = findings
        self.plan = plan
        self.scanSummary = scanSummary
        self.scanProgress = scanProgress
        self.isScanning = isScanning
        self.isExecutingPlan = isExecutingPlan
        self.isCurrentPlanFresh = isCurrentPlanFresh
        self.canExecutePlan = canExecutePlan
        self.planIssue = planIssue
        self.executionIssue = executionIssue
        self.onStartScan = onStartScan
        self.onRefreshPreview = onRefreshPreview
        self.onExecutePlan = onExecutePlan
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("smartclean.screen.title"),
            subtitle: AtlasL10n.string("smartclean.screen.subtitle"),
            maxContentWidth: AtlasLayout.maxWorkflowWidth
        ) {
            AtlasCallout(
                title: statusTitle,
                detail: statusDetail,
                tone: statusTone,
                systemImage: statusSymbol
            )

            AtlasInfoCard(
                title: AtlasL10n.string("smartclean.controls.title"),
                subtitle: AtlasL10n.string("smartclean.controls.subtitle"),
                tone: statusTone
            ) {
                if isScanning || isExecutingPlan {
                    VStack(spacing: AtlasSpacing.lg) {
                        AtlasCircularProgress(
                            progress: scanProgress == 0 ? (isScanning ? 0.15 : 0.5) : scanProgress,
                            tone: isScanning ? .neutral : .warning,
                            lineWidth: 8,
                            icon: isScanning ? "sparkles" : "play.circle.fill"
                        )
                        .frame(width: 80, height: 80)

                        AtlasLoadingState(
                            title: isScanning ? AtlasL10n.string("smartclean.loading.scan") : AtlasL10n.string("smartclean.loading.execute"),
                            detail: scanSummary,
                            progress: scanProgress == 0 ? nil : scanProgress
                        )
                    }
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                        Text(scanSummary)
                            .font(AtlasTypography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if scanProgress > 0 {
                            ProgressView(value: max(scanProgress, 0), total: 1)
                                .controlSize(.large)
                                .tint(AtlasColor.brand)
                        }

                        Text(primaryAction.detail)
                            .font(AtlasTypography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: AtlasSpacing.md) {
                                primaryActionButton
                                supportingActionButtons
                                Spacer(minLength: 0)
                            }

                            VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                                primaryActionButton
                                HStack(alignment: .center, spacing: AtlasSpacing.md) {
                                    supportingActionButtons
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                }
            }

            LazyVGrid(columns: metricColumns, spacing: AtlasSpacing.lg) {
                AtlasMetricCard(
                    title: AtlasL10n.string("smartclean.metric.previewSize.title"),
                    value: AtlasFormatters.byteCount(resolvedPlanEstimatedBytes),
                    detail: AtlasL10n.string("smartclean.metric.previewSize.detail"),
                    tone: .success,
                    systemImage: "internaldrive"
                )
                AtlasMetricCard(
                    title: AtlasL10n.string("smartclean.metric.actions.title"),
                    value: "\(plan.items.count)",
                    detail: AtlasL10n.string("smartclean.metric.actions.detail"),
                    tone: .neutral,
                    systemImage: "checklist"
                )
                AtlasMetricCard(
                    title: AtlasL10n.string("smartclean.metric.review.title"),
                    value: "\(manualReviewCount)",
                    detail: manualReviewCount == 0 ? AtlasL10n.string("smartclean.metric.review.none") : AtlasL10n.string("smartclean.metric.review.some"),
                    tone: manualReviewCount == 0 ? .success : .warning,
                    systemImage: "exclamationmark.bubble"
                )
            }

            AtlasInfoCard(
                title: AtlasL10n.string("smartclean.preview.title"),
                subtitle: plan.title,
                tone: manualReviewCount == 0 ? .success : .warning
            ) {
                if !plan.items.isEmpty {
                    AtlasMetricCard(
                        title: AtlasL10n.string("smartclean.preview.metric.space.title"),
                        value: AtlasFormatters.byteCount(resolvedPlanEstimatedBytes),
                        detail: AtlasL10n.string(
                            plan.items.count == 1
                                ? "smartclean.preview.metric.space.detail.one"
                                : "smartclean.preview.metric.space.detail.other",
                            plan.items.count
                        ),
                        tone: .success,
                        systemImage: "internaldrive",
                        elevation: .prominent
                    )
                }

                if !plan.items.isEmpty, !hasExecutionFailure {
                    AtlasCallout(
                        title: planValidationCalloutTitle,
                        detail: planValidationCalloutDetail,
                        tone: planValidationCalloutTone,
                        systemImage: planValidationCalloutSymbol
                    )
                }

                if !hasExecutionFailure && (plan.items.isEmpty || manualReviewCount > 0) {
                    AtlasCallout(
                        title: manualReviewCount == 0 ? AtlasL10n.string("smartclean.preview.callout.safe.title") : AtlasL10n.string("smartclean.preview.callout.review.title"),
                        detail: manualReviewCount == 0
                            ? AtlasL10n.string("smartclean.preview.callout.safe.detail")
                            : AtlasL10n.string("smartclean.preview.callout.review.detail"),
                        tone: manualReviewCount == 0 ? .success : .warning,
                        systemImage: manualReviewCount == 0 ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
                    )
                }

                if plan.items.isEmpty {
                    AtlasEmptyState(
                        title: AtlasL10n.string("smartclean.preview.empty.title"),
                        detail: AtlasL10n.string("smartclean.preview.empty.detail"),
                        systemImage: "list.bullet.clipboard",
                        tone: .neutral,
                        actionTitle: AtlasL10n.string("emptystate.action.startScan"),
                        onAction: onStartScan
                    )
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ForEach(plan.items) { item in
                            let executionBoundary = effectiveExecutionBoundary(for: item)
                            AtlasDetailRow(
                                title: item.title,
                                subtitle: item.detail,
                                footnote: supportText(for: item, boundary: executionBoundary),
                                systemImage: item.kind.atlasSystemImage,
                                tone: item.recoverable ? .success : .warning
                            ) {
                                AtlasStatusChip(
                                    executionBoundaryTitle(for: executionBoundary),
                                    tone: executionBoundary.isExecutable ? .success : .warning
                                )
                            }
                        }
                    }
                }
            }

            if findings.isEmpty {
                AtlasEmptyState(
                    title: AtlasL10n.string("smartclean.empty.title"),
                    detail: AtlasL10n.string("smartclean.empty.detail"),
                    systemImage: "sparkles.tv",
                    tone: .neutral,
                    actionTitle: AtlasL10n.string("emptystate.action.startScan"),
                    onAction: onStartScan
                )
            } else {
                ForEach(RiskLevel.allCases, id: \.self) { risk in
                    riskSection(risk)
                }
            }
        }
    }

    private var metricColumns: [GridItem] {
        AtlasLayout.adaptiveMetricColumns(for: contentWidth)
    }

    @ViewBuilder
    private func riskSection(_ risk: RiskLevel) -> some View {
        let items = findings.filter { $0.risk == risk }

        if !items.isEmpty {
            AtlasSectionDisclosure(
                title: risk.title,
                count: items.count,
                defaultExpanded: risk == .safe
            ) {
                VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                    ForEach(items) { finding in
                        AtlasDetailRow(
                            title: finding.title,
                            subtitle: finding.detail,
                            footnote: "\(AtlasL10n.localizedCategory(finding.category)) • \(actionExpectation(for: finding.risk))",
                            systemImage: AtlasCategoryIcon.systemImage(for: finding.category),
                            tone: risk.atlasTone
                        ) {
                            AtlasStatusChip(
                                "\(AtlasL10n.localizedCategory(finding.category)) · \(AtlasFormatters.byteCount(finding.bytes))",
                                tone: risk.atlasTone
                            )
                        }
                    }
                }
            }
        }
    }

    private var resolvedPlanEstimatedBytes: Int64 {
        if plan.estimatedBytes > 0 {
            return plan.estimatedBytes
        }

        let planItemIDs = Set(plan.items.map(\.id))
        if !planItemIDs.isEmpty {
            let matchingFindings = findings.filter { planItemIDs.contains($0.id) }
            if !matchingFindings.isEmpty {
                return matchingFindings.map(\.bytes).reduce(0, +)
            }
        }

        return findings.map(\.bytes).reduce(0, +)
    }

    private var executablePlanItemCount: Int {
        plan.items.filter { effectiveExecutionBoundary(for: $0).isExecutable }.count
    }

    private var reviewOnlyPlanItemCount: Int {
        max(plan.items.count - executablePlanItemCount, 0)
    }

    private var executionCoverageTitle: String {
        if reviewOnlyPlanItemCount == 0 {
            return AtlasL10n.string("smartclean.execution.coverage.full", executablePlanItemCount)
        }
        return AtlasL10n.string("smartclean.execution.coverage.partial", executablePlanItemCount, plan.items.count)
    }

    private var executionCoverageDetail: String {
        if reviewOnlyPlanItemCount == 0 {
            return AtlasL10n.string("smartclean.execution.coverage.full.detail")
        }
        return AtlasL10n.string("smartclean.execution.coverage.partial.detail", reviewOnlyPlanItemCount)
    }

    private func isPhysicallyExecutable(_ item: ActionItem) -> Bool {
        item.effectiveExecutionBoundary(findings: findings).isExecutable
    }

    private func effectiveExecutionBoundary(for item: ActionItem) -> ActionItem.ExecutionBoundary {
        item.effectiveExecutionBoundary(findings: findings)
    }

    private var manualReviewCount: Int {
        plan.items.filter { !$0.recoverable }.count
    }

    private var hasPlanRevalidationFailure: Bool {
        !isCurrentPlanFresh && planIssue != nil
    }

    private var hasExecutionFailure: Bool {
        executionIssue != nil
    }

    private var isShowingCachedPlanState: Bool {
        !isCurrentPlanFresh && !plan.items.isEmpty
    }

    private var planValidationCalloutTitle: String {
        if isCurrentPlanFresh {
            return executionCoverageTitle
        }
        if hasPlanRevalidationFailure {
            return AtlasL10n.string("smartclean.revalidationFailed.title")
        }
        return AtlasL10n.string("smartclean.cached.title")
    }

    private var planValidationCalloutDetail: String {
        if isCurrentPlanFresh {
            return executionCoverageDetail
        }
        return planIssue ?? AtlasL10n.string("smartclean.cached.detail")
    }

    private var planValidationCalloutTone: AtlasTone {
        if hasPlanRevalidationFailure {
            return .danger
        }
        return isCurrentPlanFresh && reviewOnlyPlanItemCount == 0 ? .success : .warning
    }

    private var planValidationCalloutSymbol: String {
        if hasPlanRevalidationFailure {
            return "xmark.octagon.fill"
        }
        return isCurrentPlanFresh && reviewOnlyPlanItemCount == 0 ? "play.circle.fill" : "externaldrive.badge.exclamationmark"
    }

    private var statusTitle: String {
        if isScanning { return AtlasL10n.string("smartclean.status.scanning") }
        if isExecutingPlan { return AtlasL10n.string("smartclean.status.executing") }
        if hasExecutionFailure { return AtlasL10n.string("smartclean.status.executionFailed") }
        if hasPlanRevalidationFailure { return AtlasL10n.string("smartclean.status.revalidationFailed") }
        if isShowingCachedPlanState { return AtlasL10n.string("smartclean.status.cached") }
        if findings.isEmpty { return AtlasL10n.string("smartclean.status.empty") }
        return AtlasL10n.string("smartclean.status.ready")
    }

    private var statusDetail: String {
        if isScanning || isExecutingPlan { return scanSummary }
        if hasExecutionFailure { return executionIssue ?? scanSummary }
        if hasPlanRevalidationFailure { return planIssue ?? AtlasL10n.string("smartclean.cached.detail") }
        if isShowingCachedPlanState { return AtlasL10n.string("smartclean.cached.detail") }
        if findings.isEmpty { return AtlasL10n.string("smartclean.status.empty.detail") }
        return AtlasL10n.string("smartclean.status.ready.detail", findings.count)
    }

    private var statusTone: AtlasTone {
        if isExecutingPlan { return .warning }
        if isScanning { return .neutral }
        if hasExecutionFailure { return .danger }
        if hasPlanRevalidationFailure { return .danger }
        if isShowingCachedPlanState { return .warning }
        return manualReviewCount == 0 ? .success : .warning
    }

    private var statusSymbol: String {
        if isScanning { return "sparkles" }
        if isExecutingPlan { return "play.circle.fill" }
        if hasExecutionFailure { return "xmark.octagon.fill" }
        if hasPlanRevalidationFailure { return "xmark.octagon.fill" }
        if isShowingCachedPlanState { return "externaldrive.badge.exclamationmark" }
        return manualReviewCount == 0 ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
    }

    private var primaryAction: SmartCleanPrimaryAction {
        if plan.items.isEmpty {
            return findings.isEmpty ? .scan : .refresh
        }
        if isCurrentPlanFresh && canExecutePlan {
            return .execute
        }
        return .refresh
    }

    private func primaryActionTapped() {
        if primaryAction == .execute {
            showExecuteConfirmation = true
        } else {
            primaryAction.handler(startScan: onStartScan, refreshPreview: onRefreshPreview, executePlan: onExecutePlan)()
        }
    }

    private var primaryActionButton: some View {
        Button(action: primaryActionTapped) {
            Label(primaryAction.buttonTitle, systemImage: primaryAction.buttonSystemImage)
        }
        .buttonStyle(.atlasPrimary)
        .keyboardShortcut(.defaultAction)
        .disabled(primaryAction.isDisabled(canExecutePlan: canExecutePlan))
        .accessibilityIdentifier(primaryAction.accessibilityIdentifier)
        .accessibilityHint(primaryAction.accessibilityHint)
        .confirmationDialog(
            AtlasL10n.string("smartclean.confirm.execute.title"),
            isPresented: $showExecuteConfirmation,
            titleVisibility: .visible
        ) {
            Button(AtlasL10n.string("smartclean.action.execute"), role: .destructive) {
                onExecutePlan()
            }
            Button(AtlasL10n.string("confirm.cancel"), role: .cancel) {}
        } message: {
            Text(AtlasL10n.string("smartclean.confirm.execute.message"))
        }
    }

    @ViewBuilder
    private var supportingActionButtons: some View {
        if primaryAction != .scan {
            Button(action: onStartScan) {
                Label(AtlasL10n.string("smartclean.action.runScan"), systemImage: "sparkles")
            }
            .buttonStyle(.atlasSecondary)
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(isScanning || isExecutingPlan)
            .accessibilityIdentifier("smartclean.runScan")
            .accessibilityHint(AtlasL10n.string("smartclean.action.runScan.hint"))
        }

        if primaryAction != .refresh, !findings.isEmpty {
            Button(action: onRefreshPreview) {
                Label(AtlasL10n.string("smartclean.action.refreshPreview"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.atlasGhost)
            .disabled(isScanning || isExecutingPlan)
            .accessibilityIdentifier("smartclean.refreshPreview")
            .accessibilityHint(AtlasL10n.string("smartclean.action.refreshPreview.hint"))
        }
    }

    private func supportText(for item: ActionItem, boundary: ActionItem.ExecutionBoundary) -> String {
        switch boundary {
        case .direct:
            switch item.kind {
            case .removeCache:
                return AtlasL10n.string("smartclean.support.removeCache")
            case .removeApp:
                return AtlasL10n.string("smartclean.support.removeApp")
            case .archiveFile:
                return AtlasL10n.string("smartclean.support.archiveFile")
            case .inspectPermission:
                return AtlasL10n.string("smartclean.support.inspectPermission")
            case .reviewEvidence:
                return AtlasL10n.string("smartclean.support.archiveFile")
            }
        case .helper:
            return AtlasL10n.string("smartclean.support.helper")
        case .reviewOnly:
            if item.kind == .inspectPermission {
                return AtlasL10n.string("smartclean.support.inspectPermission")
            }
            return AtlasL10n.string("smartclean.support.reviewOnly")
        }
    }

    private func executionBoundaryTitle(for boundary: ActionItem.ExecutionBoundary) -> String {
        switch boundary {
        case .direct:
            return AtlasL10n.string("smartclean.execution.real")
        case .helper:
            return AtlasL10n.string("smartclean.execution.helper")
        case .reviewOnly:
            return AtlasL10n.string("smartclean.execution.reviewOnly")
        }
    }

    private func sectionDetail(for risk: RiskLevel) -> String {
        switch risk {
        case .safe:
            return AtlasL10n.string("smartclean.section.safe")
        case .review:
            return AtlasL10n.string("smartclean.section.review")
        case .advanced:
            return AtlasL10n.string("smartclean.section.advanced")
        }
    }

    private func actionExpectation(for risk: RiskLevel) -> String {
        switch risk {
        case .safe:
            return AtlasL10n.string("smartclean.expectation.safe")
        case .review:
            return AtlasL10n.string("smartclean.expectation.review")
        case .advanced:
            return AtlasL10n.string("smartclean.expectation.advanced")
        }
    }

}

private enum SmartCleanPrimaryAction: Equatable {
    case scan
    case refresh
    case execute

    var title: String {
        switch self {
        case .scan:
            return AtlasL10n.string("smartclean.primary.scan.title")
        case .refresh:
            return AtlasL10n.string("smartclean.primary.refresh.title")
        case .execute:
            return AtlasL10n.string("smartclean.primary.execute.title")
        }
    }

    var detail: String {
        switch self {
        case .scan:
            return AtlasL10n.string("smartclean.primary.scan.detail")
        case .refresh:
            return AtlasL10n.string("smartclean.primary.refresh.detail")
        case .execute:
            return AtlasL10n.string("smartclean.primary.execute.detail")
        }
    }

    var tone: AtlasTone {
        switch self {
        case .scan, .refresh:
            return .neutral
        case .execute:
            return .warning
        }
    }

    var systemImage: String {
        switch self {
        case .scan:
            return "sparkles"
        case .refresh:
            return "arrow.clockwise"
        case .execute:
            return "play.circle.fill"
        }
    }

    var buttonTitle: String {
        switch self {
        case .scan:
            return AtlasL10n.string("smartclean.action.runScan")
        case .refresh:
            return AtlasL10n.string("smartclean.action.refreshPreview")
        case .execute:
            return AtlasL10n.string("smartclean.action.execute")
        }
    }

    var buttonSystemImage: String {
        switch self {
        case .scan:
            return "sparkles"
        case .refresh:
            return "arrow.clockwise"
        case .execute:
            return "play.fill"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .scan:
            return "smartclean.runScan"
        case .refresh:
            return "smartclean.refreshPreview"
        case .execute:
            return "smartclean.executePreview"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .scan:
            return AtlasL10n.string("smartclean.action.runScan.hint")
        case .refresh:
            return AtlasL10n.string("smartclean.action.refreshPreview.hint")
        case .execute:
            return AtlasL10n.string("smartclean.action.execute.hint")
        }
    }

    func isDisabled(canExecutePlan: Bool) -> Bool {
        switch self {
        case .execute:
            return !canExecutePlan
        case .scan, .refresh:
            return false
        }
    }

    func handler(
        startScan: @escaping () -> Void,
        refreshPreview: @escaping () -> Void,
        executePlan: @escaping () -> Void
    ) -> () -> Void {
        switch self {
        case .scan:
            return startScan
        case .refresh:
            return refreshPreview
        case .execute:
            return executePlan
        }
    }
}
