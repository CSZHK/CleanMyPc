import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - ① Scan stage

/// Empty-state guidance, live scan progress (mono summary + percent), and the
/// cached-plan note for stale plans (spec §2.3 rows 1–2).
struct SmartCleanScanStageView: View {
    let isScanning: Bool
    let scanSummary: String
    let scanProgress: Double
    let hasCachedFindings: Bool
    let planIssue: String?
    let onStartScan: () -> Void
    let onRefreshPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            if isScanning {
                VStack(spacing: AtlasSpacing.lg) {
                    AtlasCircularProgress(
                        progress: scanProgress == 0 ? 0.15 : scanProgress,
                        tone: .neutral,
                        lineWidth: 8,
                        icon: "sparkles",
                        accessibilityLabel: AtlasL10n.string("smartclean.loading.scan")
                    )
                    .frame(width: 80, height: 80)

                    Text(AtlasL10n.string("smartclean.loading.scan"))
                        .font(AtlasTypography.label)

                    // Live mono status line (real worker summary — no fabricated paths).
                    Text(scanSummary)
                        .font(AtlasTypography.dataBody)
                        .monospacedDigit()
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AtlasSpacing.section)
            } else {
                if let planIssue {
                    AtlasErrorState(
                        title: AtlasL10n.string("smartclean.status.revalidationFailed"),
                        message: planIssue,
                        layout: .inlineRow
                    )
                } else if hasCachedFindings {
                    AtlasCallout(
                        title: AtlasL10n.string("smartclean.cached.title"),
                        detail: AtlasL10n.string("smartclean.cached.detail"),
                        tone: .warning,
                        systemImage: "externaldrive.badge.exclamationmark"
                    )
                }

                AtlasEmptyState(
                    title: AtlasL10n.string("smartclean.preview.empty.title"),
                    detail: AtlasL10n.string("smartclean.status.empty.detail"),
                    systemImage: "sparkles",
                    tone: .neutral,
                    actionTitle: AtlasL10n.string("emptystate.action.startScan"),
                    onAction: onStartScan,
                    // UI-test contract (review fix I3): the scan empty-state action
                    // is the canonical `smartclean.runScan` entry — both this action
                    // and the action-bar primary on the scan stage carry the id.
                    actionIdentifier: "smartclean.runScan"
                )

                if hasCachedFindings {
                    Button(action: onRefreshPreview) {
                        Label(AtlasL10n.string("smartclean.action.refreshPreview"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.atlasSecondary)
                    .accessibilityIdentifier("smartclean.refreshPreview")
                    .accessibilityHint(AtlasL10n.string("smartclean.action.refreshPreview.hint"))
                }
            }
        }
    }
}

// MARK: - ② Review stage

/// Risk-grouped finding list with filter chips, checkboxes, and the row-end ⓘ
/// evidence trigger (drawer widths only). Row click selects evidence without
/// popping the drawer (spec §2.4); look-back renders the same list read-only.
struct SmartCleanReviewStageView: View {
    let findings: [Finding]
    let searchQuery: String
    let riskFilter: String?
    let selectedIDs: Set<String>
    let evidenceSelectionID: String?
    let isReadOnly: Bool
    let showsEvidenceButton: Bool
    let isReviewEmpty: Bool
    let evidenceFocus: FocusState<String?>.Binding
    let onToggle: (String) -> Void
    let onSetRiskFilter: (String?) -> Void
    let onSelectEvidence: (String) -> Void
    let onOpenEvidence: (String) -> Void
    let onRequestRescan: () -> Void

    private var searchedFindings: [Finding] {
        SmartCleanEvidenceBuilder.searchFiltered(findings, query: searchQuery)
    }

    private var visibleFindings: [Finding] {
        guard let riskFilter, let risk = RiskLevel(rawValue: riskFilter) else {
            return searchedFindings
        }
        return searchedFindings.filter { $0.risk == risk }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            if isReviewEmpty {
                AtlasEmptyState(
                    title: AtlasL10n.string("smartclean.stage.review.zero.title"),
                    detail: AtlasL10n.string("smartclean.stage.review.zero.detail"),
                    systemImage: "checkmark.seal",
                    tone: .success,
                    actionTitle: AtlasL10n.string("smartclean.stage.actionbar.rescan"),
                    onAction: onRequestRescan
                )
            } else {
                filterChips

                if visibleFindings.isEmpty {
                    AtlasEmptyState(
                        title: AtlasL10n.string("smartclean.empty.title"),
                        detail: AtlasL10n.string("smartclean.empty.detail"),
                        systemImage: "magnifyingglass",
                        tone: .neutral
                    )
                } else {
                    ForEach(RiskLevel.allCases, id: \.self) { risk in
                        riskSection(risk)
                    }
                }
            }
        }
        .disabled(isReadOnly)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AtlasSpacing.sm) {
                AtlasFilterChip(
                    title: AtlasL10n.string("smartclean.filter.all"),
                    isSelected: riskFilter == nil,
                    count: searchedFindings.count
                ) {
                    onSetRiskFilter(nil)
                }
                ForEach(RiskLevel.allCases, id: \.self) { risk in
                    AtlasFilterChip(
                        title: risk.title,
                        isSelected: riskFilter == risk.rawValue,
                        count: searchedFindings.filter { $0.risk == risk }.count
                    ) {
                        onSetRiskFilter(riskFilter == risk.rawValue ? nil : risk.rawValue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func riskSection(_ risk: RiskLevel) -> some View {
        let items = visibleFindings.filter { $0.risk == risk }
        if !items.isEmpty {
            AtlasSectionDisclosure(title: risk.title, count: items.count, defaultExpanded: true) {
                VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                    ForEach(items) { finding in
                        SmartCleanReviewRow(
                            finding: finding,
                            isSelected: selectedIDs.contains(finding.id.uuidString),
                            isHighlighted: evidenceSelectionID == finding.id.uuidString,
                            isReadOnly: isReadOnly,
                            showsEvidenceButton: showsEvidenceButton,
                            evidenceFocus: evidenceFocus,
                            onToggle: { onToggle(finding.id.uuidString) },
                            onSelect: { onSelectEvidence(finding.id.uuidString) },
                            onOpenEvidence: { onOpenEvidence(finding.id.uuidString) }
                        )
                    }
                }
            }
        }
    }
}

/// One review row: checkbox · title/detail · mono size · risk chip · ⓘ.
private struct SmartCleanReviewRow: View {
    let finding: Finding
    let isSelected: Bool
    let isHighlighted: Bool
    let isReadOnly: Bool
    let showsEvidenceButton: Bool
    let evidenceFocus: FocusState<String?>.Binding
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onOpenEvidence: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AtlasSpacing.md) {
            Toggle(isOn: Binding(get: { isSelected }, set: { _ in onToggle() })) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(isReadOnly)
            .accessibilityLabel(Text(finding.title))

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(finding.title)
                    .font(AtlasTypography.rowTitle)
                    .foregroundStyle(AtlasColor.textPrimary)
                    .lineLimit(1)
                Text(finding.detail)
                    .font(AtlasTypography.bodySmall)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: AtlasSpacing.sm)

            Text(AtlasFormatters.byteCount(finding.bytes))
                .font(AtlasTypography.dataBody)
                .monospacedDigit()
                .foregroundStyle(AtlasColor.textSecondary)

            AtlasStatusChip(finding.risk.title, tone: finding.risk.atlasTone)

            if showsEvidenceButton {
                Button(action: onOpenEvidence) {
                    Image(systemName: "info.circle")
                        .font(AtlasTypography.caption)
                        .foregroundStyle(AtlasColor.brand)
                        // 44pt hit target — the visible glyph stays at caption
                        // (round-4 a11y; matches the Toast close pattern).
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focused(evidenceFocus, equals: finding.id.uuidString)
                .accessibilityLabel(Text(AtlasL10n.string("smartclean.stage.evidence.open")))
            }
        }
        .padding(.horizontal, AtlasSpacing.md)
        .padding(.vertical, AtlasSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                .fill(isHighlighted ? AtlasColor.surfaceSubdued : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect) // row click = select evidence, no pop-out
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("smartclean.review.row.\(finding.id.uuidString)")
    }
}

// MARK: - ③ Execute stage

/// Live execution view: progress block while running; on failure an inline
/// `AtlasErrorState` row with the real failure reason (spec §2.3 row 7).
struct SmartCleanExecuteStageView: View {
    let plan: ActionPlan
    let isExecuting: Bool
    let progress: Double
    let summary: String
    let executionIssue: String?
    let onViewReceipt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            if let executionIssue {
                AtlasErrorState(
                    title: AtlasL10n.string("smartclean.status.executionFailed"),
                    message: executionIssue,
                    suggestion: AtlasL10n.string("smartclean.stage.execute.failure.suggestion"),
                    actionTitle: AtlasL10n.string("smartclean.stage.actionbar.viewReceipt"),
                    onAction: onViewReceipt,
                    layout: .inlineRow
                )
            } else {
                VStack(spacing: AtlasSpacing.lg) {
                    AtlasCircularProgress(
                        progress: isExecuting ? max(progress, 0.05) : progress,
                        tone: .warning,
                        lineWidth: 8,
                        icon: "play.circle.fill",
                        accessibilityLabel: AtlasL10n.string("smartclean.loading.execute")
                    )
                    .frame(width: 80, height: 80)

                    Text(AtlasL10n.string("smartclean.loading.execute"))
                        .font(AtlasTypography.label)

                    Text(summary)
                        .font(AtlasTypography.dataBody)
                        .monospacedDigit()
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AtlasSpacing.xl)
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                ForEach(plan.items) { item in
                    HStack(spacing: AtlasSpacing.sm) {
                        Image(systemName: executionIssue == nil ? "circle.dotted" : "questionmark.circle")
                            .font(AtlasTypography.caption)
                            .foregroundStyle(AtlasColor.textTertiary)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(AtlasTypography.body)
                            .foregroundStyle(AtlasColor.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: AtlasSpacing.sm)
                    }
                    // Expose per-item pending/failed status to VoiceOver (round-19):
                    // the glyph is icon-only and hidden, so without this a swipe
                    // hears only the title. Mirrors AtlasEvidencePanel.executingRow.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(item.title))
                    .accessibilityValue(Text(AtlasL10n.string(executionIssue == nil ? "taskstatus.running" : "taskstatus.failed")))
                }
            }
        }
    }
}
