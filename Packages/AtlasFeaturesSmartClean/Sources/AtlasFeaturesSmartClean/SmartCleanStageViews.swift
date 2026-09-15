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
    let planOutcome: AtlasActionOutcome?
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
                if let planOutcome {
                    // NEW-1（规格 §1.2(1)）：`.failed` 才走错误态；`.advisory` 是
                    // 非阻断提示，必须走非错误渲染路径 —— 此前受限模式软提示被
                    // 一律渲染成「未能更新当前计划」的失败标题。
                    if planOutcome.isError {
                        AtlasErrorState(
                            title: AtlasL10n.string("smartclean.status.revalidationFailed"),
                            message: planOutcome.message,
                            layout: .inlineRow
                        )
                        .accessibilityIdentifier("smartclean.planOutcome.error")
                    } else {
                        AtlasCallout(
                            title: AtlasL10n.string("smartclean.scan.advisory.title"),
                            detail: planOutcome.message,
                            tone: .warning,
                            systemImage: "exclamationmark.shield"
                        )
                        .accessibilityIdentifier("smartclean.planOutcome.advisory")
                    }
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
    /// 契约二 §2.2(2) 标签—后果一致（`P1-10`）：有计划编号时，空态这个按钮
    /// 触达的是 `role: .destructive` 的「作废并重新扫描」对话框，标签必须描述
    /// **该对话框的后果**，而不是用户的上位意图（「再扫一遍」）。
    let hasPlanNumber: Bool
    let evidenceFocus: FocusState<String?>.Binding
    let onToggle: (String) -> Void
    /// `P1-7`：全选/取消全选。此前 ② 页只有逐条勾选 —— 用户的核心意图是
    /// 「把空间腾出来」，最自然的动作是「全选然后执行」；扫描出几十项时只能逐条点。
    let onSelectAll: (Bool) -> Void
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
                    actionTitle: AtlasL10n.string(
                        hasPlanNumber
                            ? "smartclean.stage.actionbar.rescan.destructive"
                            : "smartclean.stage.actionbar.rescan"
                    ),
                    onAction: onRequestRescan
                )
            } else {
                filterChips
                // `P1-7`：与 File Organizer 对齐的选择控件（FO 同阶段一直有）。
                selectionControls

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

    /// `P1-7`：全选作用于**当前可见（筛选 + 搜索后）**的条目 —— 与用户看到的列表一致。
    private var selectionControls: some View {
        HStack(spacing: AtlasSpacing.sm) {
            Text(AtlasL10n.string("smartclean.selection.count", selectedIDs.count, visibleFindings.count))
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textSecondary)
            Spacer()
            Button {
                onSelectAll(true)
            } label: {
                Text(AtlasL10n.string("smartclean.action.selectAll"))
            }
            .buttonStyle(.atlasGhost)
            .disabled(selectedIDs.count == visibleFindings.count || isReadOnly)
            .accessibilityIdentifier("smartclean.selectAll")
            Button {
                onSelectAll(false)
            } label: {
                Text(AtlasL10n.string("smartclean.action.deselectAll"))
            }
            .buttonStyle(.atlasGhost)
            .disabled(selectedIDs.isEmpty || isReadOnly)
            .accessibilityIdentifier("smartclean.deselectAll")
        }
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
    /// 「Xm Ys」/「Ys」—— 只为执行中的已用时显示，不引入格式化依赖。
    static func elapsedText(seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }

    let plan: ActionPlan
    let isExecuting: Bool
    /// `P1-9`：执行开始时刻 —— 执行中唯一确定性且真实可得的信息。
    let executionStartedAt: Date?
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
                    if isExecuting, let executionStartedAt {
                        // `P1-9`：**执行中不作无意义的不确定态** —— 用确定性信息
                        // （已用时）替掉「空弧 + 一句话」。worker 的 execute 是单次
                        // await、没有进度流（见下 Round-21 注），所以「已处理计数 /
                        // 剩余时间估计」都没有真实数据；已用时是唯一真实可得的量。
                        // 「空弧 + 一句话」会被读成「卡住了 / 死机了」。
                        TimelineView(.periodic(from: executionStartedAt, by: 1)) { context in
                            let elapsed = max(0, Int(context.date.timeIntervalSince(executionStartedAt)))
                            Text(AtlasL10n.string(
                                "smartclean.loading.execute.elapsed",
                                Self.elapsedText(seconds: elapsed)
                            ))
                            .font(AtlasTypography.label)
                            .monospacedDigit()
                            .foregroundStyle(AtlasColor.textSecondary)
                        }
                        .accessibilityIdentifier("smartclean.execute.elapsed")
                    } else {
                    AtlasCircularProgress(
                        // Round-21: `progress` (latestScanProgress) is stale (~1.0,
                        // clamped by refreshPlanPreview) during execute — the
                        // worker execute call is a single await with no progress
                        // stream, so the old `max(progress, 0.05)` froze the arc at
                        // ~100% and VoiceOver announced "100%" while still running.
                        // Execute has no determinate signal: empty arc + play icon,
                        // hidden from VoiceOver (status text + action bar carry it).
                        progress: isExecuting ? 0 : progress,
                        tone: .warning,
                        lineWidth: 8,
                        icon: "play.circle.fill",
                        accessibilityLabel: isExecuting ? nil : AtlasL10n.string("smartclean.loading.execute")
                    )
                    .frame(width: 80, height: 80)

                    Text(AtlasL10n.string("smartclean.loading.execute"))
                        .font(AtlasTypography.label)
                    }

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
                    // Collapse to one element so VoiceOver speaks the item title
                    // (round-19/20). No per-item status exists in the model, so do
                    // NOT couple a value to the plan-level executionIssue (that
                    // mis-announced every item as failed on a plan error). The
                    // run/failure state is conveyed by the AtlasErrorState block.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(item.title))
                }
            }
        }
    }
}
