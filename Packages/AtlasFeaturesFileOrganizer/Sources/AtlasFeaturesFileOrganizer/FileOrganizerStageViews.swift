import AtlasDesignSystem
import AtlasDomain
import SwiftUI
import UniformTypeIdentifiers

// MARK: - ① Scan stage

/// Empty-state guidance + live scan progress (mono summary + percent). Mirrors
/// `SmartCleanScanStageView`; the folder picker + scan trigger live in the
/// configuration disclosure so the stage body stays focused on progress.
struct FileOrganizerScanStageView: View {
    let isScanning: Bool
    let isClassifying: Bool
    let scanSummary: String
    let scanProgress: Double
    let hasCachedEntries: Bool
    let planIssue: String?
    let onStartScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            if isScanning || isClassifying {
                VStack(spacing: AtlasSpacing.lg) {
                    AtlasCircularProgress(
                        progress: scanProgress == 0 ? 0.15 : scanProgress,
                        tone: .neutral,
                        lineWidth: 8,
                        icon: isScanning ? "sparkles" : "doc.text.magnifyingglass",
                        accessibilityLabel: AtlasL10n.string(isScanning ? "fileorganizer.status.scanning" : "fileorganizer.status.classifying")
                    )
                    .frame(width: 80, height: 80)

                    Text(isScanning
                        ? AtlasL10n.string("fileorganizer.status.scanning")
                        : AtlasL10n.string("fileorganizer.status.classifying"))
                        .font(AtlasTypography.label)

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
                        title: AtlasL10n.string("fileorganizer.status.executionFailed"),
                        message: planIssue,
                        layout: .inlineRow
                    )
                } else if hasCachedEntries {
                    AtlasCallout(
                        title: AtlasL10n.string("fileorganizer.cached.title"),
                        detail: AtlasL10n.string("fileorganizer.cached.detail"),
                        tone: .warning,
                        systemImage: "externaldrive.badge.exclamationmark"
                    )
                }

                AtlasEmptyState(
                    title: AtlasL10n.string("fileorganizer.callout.ready.title"),
                    detail: AtlasL10n.string("fileorganizer.callout.ready.detail"),
                    systemImage: "folder.badge.gearshape",
                    tone: .neutral,
                    actionTitle: AtlasL10n.string("fileorganizer.action.scan"),
                    onAction: onStartScan,
                    actionIdentifier: "fileorganizer.runScan"
                )
            }
        }
    }
}

// MARK: - ② Rules stage

/// Classified entries grouped by category with checkboxes, the rule-editor
/// entry (sheet, behaviour preserved), and the selection controls. Search
/// applies here (spec: search active on ②③, disabled on ①④⑤).
struct FileOrganizerRulesStageView: View {
    let entries: [FileOrganizerEntry]
    let searchQuery: String
    let rules: [FileOrganizerRule]
    let selectedIDs: Set<UUID>
    let evidenceSelectionID: UUID?
    let isReadOnly: Bool
    let showsEvidenceButton: Bool
    let isRulesEmpty: Bool
    let conflictingIDs: Set<UUID>
    let largeFileIDs: Set<UUID>
    let duplicateFileIDs: Set<UUID>
    let onToggle: (UUID) -> Void
    /// Batched select-all / deselect-all as a single state mutation. A per-entry
    /// `onToggle` loop reads a stale `selectedIDs` snapshot (SwiftUI refreshes
    /// the view's `let state` next render, not mid-synchronous-loop) and
    /// last-write-wins, so 全选 left only the final entry selected (round-2 P1).
    let onSelectAll: (Bool) -> Void
    let onSelectEvidence: (UUID) -> Void
    let onOpenEvidence: (UUID) -> Void
    let onOpenRuleEditor: () -> Void
    let onRequestRescan: () -> Void

    private var visibleEntries: [FileOrganizerEntry] {
        FileOrganizerEvidenceBuilder.searchFiltered(entries, query: searchQuery)
    }

    private var grouped: [FileOrganizerCategory: [FileOrganizerEntry]] {
        Dictionary(grouping: visibleEntries, by: \.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            if isRulesEmpty {
                AtlasEmptyState(
                    title: AtlasL10n.string("fileorganizer.callout.empty.title"),
                    detail: AtlasL10n.string("fileorganizer.callout.empty.detail"),
                    systemImage: "checkmark.seal",
                    tone: .success,
                    actionTitle: AtlasL10n.string("fileorganizer.stage.actionbar.rescan"),
                    onAction: onRequestRescan
                )
            } else {
                ruleEditorEntry
                selectionControls
                categoryList
            }
        }
        .disabled(isReadOnly)
    }

    private var ruleEditorEntry: some View {
        HStack(spacing: AtlasSpacing.sm) {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(AtlasColor.brand)
            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(AtlasL18nEditorTitle)
                    .font(AtlasTypography.label)
                    .foregroundStyle(AtlasColor.textPrimary)
                Text(AtlasL10n.string("fileorganizer.rules.count", rules.count))
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
            }
            Spacer(minLength: AtlasSpacing.sm)
            Button(action: onOpenRuleEditor) {
                Label(AtlasL10n.string("fileorganizer.action.editRules"), systemImage: "chevron.right")
            }
            .buttonStyle(.atlasGhost)
            .disabled(isReadOnly)
            .accessibilityIdentifier("fileorganizer.openRuleEditor")
        }
        .padding(AtlasSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                .fill(AtlasColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
    }

    private var AtlasL18nEditorTitle: String {
        AtlasL10n.string("fileorganizer.section.rules.title")
    }

    private var selectionControls: some View {
        HStack(spacing: AtlasSpacing.sm) {
            Text(AtlasL10n.string("fileorganizer.selection.count", selectedIDs.count, entries.count))
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textSecondary)
            Spacer()
            Button {
                onToggleAll(true)
            } label: {
                Text(AtlasL10n.string("fileorganizer.action.selectAll"))
            }
            .buttonStyle(.atlasGhost)
            .disabled(selectedIDs.count == entries.count || isReadOnly)
            Button {
                onToggleAll(false)
            } label: {
                Text(AtlasL10n.string("fileorganizer.action.deselectAll"))
            }
            .buttonStyle(.atlasGhost)
            .disabled(selectedIDs.isEmpty || isReadOnly)
        }
    }

    private func onToggleAll(_ select: Bool) {
        // Single batched mutation via onSelectAll — see the property doc. The
        // old per-entry onToggle loop clobbered selection (round-2 P1).
        onSelectAll(select)
    }

    @ViewBuilder
    private var categoryList: some View {
        AtlasInfoCard(title: AtlasL10n.string("fileorganizer.section.results.title")) {
            LazyVStack(spacing: AtlasSpacing.xxs) {
                ForEach(FileOrganizerCategory.allCases, id: \.rawValue) { category in
                    if let group = grouped[category], !group.isEmpty {
                        AtlasSectionDisclosure(title: category.title, count: group.count) {
                            LazyVStack(spacing: AtlasSpacing.xxs) {
                                ForEach(group) { entry in
                                    FileOrganizerEntryRow(
                                        entry: entry,
                                        category: category,
                                        isSelected: selectedIDs.contains(entry.id),
                                        hasConflict: conflictingIDs.contains(entry.id),
                                        isLarge: largeFileIDs.contains(entry.id),
                                        isDuplicate: duplicateFileIDs.contains(entry.id),
                                        isHighlighted: evidenceSelectionID == entry.id,
                                        isReadOnly: isReadOnly,
                                        showsEvidenceButton: showsEvidenceButton,
                                        onToggle: { onToggle(entry.id) },
                                        onSelectEvidence: { onSelectEvidence(entry.id) },
                                        onOpenEvidence: { onOpenEvidence(entry.id) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Entry row (shared by ② rules and ③ preview)

/// One entry row: checkbox · thumbnail/images · name · mono size · destination ·
/// conflict/large/duplicate badges · ⓘ evidence trigger (drawer widths only).
struct FileOrganizerEntryRow: View {
    let entry: FileOrganizerEntry
    let category: FileOrganizerCategory
    let isSelected: Bool
    let hasConflict: Bool
    let isLarge: Bool
    let isDuplicate: Bool
    let isHighlighted: Bool
    let isReadOnly: Bool
    let showsEvidenceButton: Bool
    let onToggle: () -> Void
    let onSelectEvidence: () -> Void
    let onOpenEvidence: () -> Void

    private var showThumbnail: Bool {
        category == .images && !hasConflict && !isLarge && !isDuplicate
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if isSelected {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(AtlasColor.brand.opacity(0.6))
                    .frame(width: 4)
                    .padding(.trailing, AtlasSpacing.xs)
            } else {
                Color.clear.frame(width: 4 + AtlasSpacing.xs)
            }

            HStack(spacing: AtlasSpacing.xs) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AtlasColor.brand : AtlasColor.textTertiary)
                    .font(.system(size: AtlasLayout.iconLG))

                if showThumbnail {
                    FileThumbnailView(path: entry.path)
                }

                AtlasDetailRow(
                    title: {
                        var name = entry.fileName
                        if hasConflict { name += " ⚠" }
                        return name
                    }(),
                    subtitle: ByteCountFormatter.string(fromByteCount: entry.bytes, countStyle: .file),
                    footnote: {
                        if hasConflict {
                            return AtlasL10n.string("fileorganizer.conflict.exists", entry.proposedDestination)
                        }
                        var parts = [entry.proposedDestination]
                        if isLarge {
                            parts.append(AtlasL10n.string("fileorganizer.insight.large.badge"))
                        }
                        if isDuplicate {
                            parts.append(AtlasL10n.string("fileorganizer.insight.duplicate.badge"))
                        }
                        return parts.joined(separator: " · ")
                    }(),
                    systemImage: showThumbnail ? nil : {
                        if hasConflict { return "exclamationmark.triangle" }
                        if isLarge { return "exclamationmark.circle" }
                        if isDuplicate { return "doc.on.doc" }
                        return category.systemImage
                    }()
                )
            }

            if showsEvidenceButton {
                Button(action: onOpenEvidence) {
                    Image(systemName: "info.circle")
                        .font(AtlasTypography.caption)
                        .foregroundStyle(AtlasColor.brand)
                        // 44pt hit target — the visible glyph stays at caption
                        // (round-4 a11y; matches the Toast/SmartClean pattern).
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AtlasL10n.string("fileorganizer.evidence.open")))
            }
        }
        .padding(AtlasSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                .fill(isHighlighted ? AtlasColor.surfaceSubdued : (isSelected ? AtlasColor.brand.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if showsEvidenceButton {
                onSelectEvidence()
            } else {
                if !isReadOnly { onToggle() }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(AtlasL10n.string(isSelected ? "fileorganizer.entry.selected.a11y" : "fileorganizer.entry.unselected.a11y")))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("fileorganizer.entry.row.\(entry.id.uuidString)")
    }
}

// MARK: - ③ Preview stage (dry-run move manifest + conflict marks)

/// The dry-run results: a move manifest (source → destination) grouped by
/// category, with conflict rows marked red. The action bar's primary action
/// here is 「执行整理」 (execute). Search applies.
struct FileOrganizerPreviewStageView: View {
    let entries: [FileOrganizerEntry]
    let plan: ActionPlan
    let searchQuery: String
    let selectedIDs: Set<UUID>
    let conflictingIDs: Set<UUID>
    let planIssue: String?
    let isReadOnly: Bool

    private var entryNameLookup: [UUID: String] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.fileName) })
    }

    private var entryCategoryLookup: [UUID: FileOrganizerCategory] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.category) })
    }

    private struct PlanGroup: Identifiable {
        let id: FileOrganizerCategory
        let category: FileOrganizerCategory
        let items: [ActionItem]
        let names: [UUID: String]
    }

    private var groups: [PlanGroup] {
        var bucket: [FileOrganizerCategory: [ActionItem]] = [:]
        for item in plan.items {
            let cat = entryCategoryLookup[item.id] ?? .other
            bucket[cat, default: []].append(item)
        }
        return FileOrganizerCategory.allCases.compactMap { cat in
            guard let items = bucket[cat], !items.isEmpty else { return nil }
            return PlanGroup(id: cat, category: cat, items: items, names: entryNameLookup)
        }
    }

    private var visibleItems: [ActionItem] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return plan.items }
        let nameLookup = entryNameLookup
        return plan.items.filter { item in
            (nameLookup[item.id] ?? item.title).lowercased().contains(trimmed)
        }
    }

    private var visibleGrouped: [PlanGroup] {
        let visibleSet = Set(visibleItems.map(\.id))
        return groups.map { group in
            PlanGroup(
                id: group.id,
                category: group.category,
                items: group.items.filter { visibleSet.contains($0.id) },
                names: group.names
            )
        }.filter { !$0.items.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            if let planIssue {
                AtlasCallout(
                    title: planIssue,
                    detail: "",
                    tone: .warning,
                    systemImage: "exclamationmark.triangle"
                )
            }

            let planConflicts = plan.items.filter { conflictingIDs.contains($0.id) }
            if !planConflicts.isEmpty {
                AtlasCallout(
                    title: AtlasL10n.string("fileorganizer.conflict.callout.title", planConflicts.count),
                    detail: AtlasL10n.string("fileorganizer.conflict.callout.detail"),
                    tone: .warning,
                    systemImage: "exclamationmark.triangle"
                )
            }

            AtlasInfoCard(
                title: AtlasL10n.string("fileorganizer.section.plan.title"),
                subtitle: "\(plan.items.count) · \(ByteCountFormatter.string(fromByteCount: plan.estimatedBytes, countStyle: .file))"
            ) {
                LazyVStack(spacing: AtlasSpacing.xs) {
                    ForEach(visibleGrouped) { group in
                        AtlasSectionDisclosure(
                            title: group.category.title,
                            count: group.items.count,
                            defaultExpanded: visibleGrouped.count <= 3 && group.items.count <= 5
                        ) {
                            LazyVStack(spacing: AtlasSpacing.xxs) {
                                ForEach(group.items) { item in
                                    let isConflict = conflictingIDs.contains(item.id)
                                    AtlasDetailRow(
                                        title: isConflict ? "\(group.names[item.id] ?? item.title) ⚠" : (group.names[item.id] ?? item.title),
                                        subtitle: AtlasL10n.string("fileorganizer.preview.row.to"),
                                        footnote: FileOrganizerEvidenceBuilder.shortenDestination(item.detail),
                                        systemImage: isConflict ? "exclamationmark.triangle" : group.category.systemImage
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .disabled(isReadOnly)
    }
}

// MARK: - ④ Execute stage (live execution / error state)

/// Live execution view: progress block while running; on failure an inline
/// `AtlasErrorState` row with the real failure reason (spec §2.3 row 7).
struct FileOrganizerExecuteStageView: View {
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
                    title: AtlasL10n.string("fileorganizer.status.executionFailed"),
                    message: executionIssue,
                    suggestion: AtlasL10n.string("fileorganizer.stage.execute.failure.suggestion"),
                    actionTitle: AtlasL10n.string("fileorganizer.stage.actionbar.viewReceipt"),
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
                        accessibilityLabel: AtlasL10n.string("fileorganizer.status.executing")
                    )
                    .frame(width: 80, height: 80)

                    Text(AtlasL10n.string("fileorganizer.status.executing"))
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
                }
            }
        }
    }
}

// MARK: - ⑤ Receipt view (warm ledger surface)

/// Stage-⑤ module receipt (spec §2.3): the single plan's outcome on warm
/// ledger paper — result summary, mono facts, and the 「在台账中查看 →」
/// back-link. The restore-point stamp is omitted for FileOrganizer because
/// its recovery payload is a move-mapping set (not byte-sized recovery); the
/// undo entry points to `undoFileOrganizerExecution` (same recovery point as
/// the ledger's restore action — 双入口一份真相).
struct FileOrganizerReceiptView: View {
    let receipt: FileOrganizerExecutionReceipt
    /// Undo entry that outlives the 8s toast (spec §2.3: 超时后仍可还原);
    /// nil hides the button (fail-closed).
    var onUndo: (() -> Void)?
    let onNavigateToLedger: () -> Void

    var body: some View {
        AtlasLedgerSurface(title: AtlasL10n.string("fileorganizer.receipt.title")) {
            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                if let failureReason = receipt.failureReason {
                    AtlasErrorState(
                        title: AtlasL10n.string("fileorganizer.status.executionFailed"),
                        message: failureReason,
                        layout: .inlineRow
                    )
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                    if let number = receipt.planNumber {
                        Text(AtlasL10n.string("fileorganizer.stage.plan.number", number))
                            .font(AtlasTypography.ledgerNumber)
                            .foregroundStyle(AtlasColor.ledgerInk)
                            .accessibilityLabel(AtlasL10n.string("fileorganizer.stage.plan.number.a11y", number))
                    }

                    Text(receipt.summary)
                        .font(AtlasTypography.body)
                        .foregroundStyle(AtlasColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    factRows
                }

                HStack(spacing: AtlasSpacing.lg) {
                    Button(action: onNavigateToLedger) {
                        Text(AtlasL10n.string("fileorganizer.receipt.viewInLedger"))
                            .font(AtlasTypography.label)
                            .foregroundStyle(AtlasColor.brand)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("fileorganizer.receipt.viewInLedger")

                    if let onUndo {
                        Button(AtlasL10n.string("fileorganizer.undo.action"), action: onUndo)
                            .buttonStyle(.atlasGhost)
                            .accessibilityIdentifier("fileorganizer.receipt.undo")
                    }
                }
            }
        }
    }

    private var factRows: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
            // Fail-closed (round-3, mirrors SmartCleanReceiptView): suppress the
            // moved-items row on the failure path — we cannot confirm how many
            // files moved before the error, so claiming a count would mislead.
            // The AtlasErrorState already conveys the failure.
            if receipt.failureReason == nil {
                factRow(
                    label: AtlasL10n.string("fileorganizer.receipt.items.label"),
                    value: AtlasL10n.string("fileorganizer.receipt.items.value", receipt.movedItemCount)
                )
            }
            factRow(
                label: AtlasL10n.string("fileorganizer.receipt.completed.label"),
                value: AtlasFormatters.shortDate(receipt.completedAt)
            )
            if let code = receipt.receiptCode {
                factRow(label: AtlasL10n.string("fileorganizer.receipt.code.label"), value: "#\(code)")
            }
        }
    }

    private func factRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AtlasSpacing.md) {
            Text(label)
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textSecondary)
                .frame(minWidth: 72, alignment: .leading)
            Text(value)
                .font(AtlasTypography.dataBody)
                .monospacedDigit()
                .foregroundStyle(AtlasColor.ledgerInk)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}
