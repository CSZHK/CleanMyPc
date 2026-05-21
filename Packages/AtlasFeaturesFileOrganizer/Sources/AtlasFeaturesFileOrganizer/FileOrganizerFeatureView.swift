import AtlasDesignSystem
import AtlasDomain
import SwiftUI
import UniformTypeIdentifiers

private final class ThumbnailCache {
    static let shared = ThumbnailCache()
    let cache = NSCache<NSString, NSImage>()

    func image(for path: String) -> NSImage? {
        cache.object(forKey: path as NSString)
    }

    func setImage(_ image: NSImage, for path: String) {
        cache.setObject(image, forKey: path as NSString)
    }
}

private struct FileThumbnailView: View {
    let path: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(AtlasColor.textTertiary)
            }
        }
        .frame(width: 32, height: 32)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                .fill(AtlasColor.cardRaised)
        )
        .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous))
        .task(id: path) {
            let expandedPath = (path as NSString).expandingTildeInPath
            if let cached = ThumbnailCache.shared.image(for: expandedPath) {
                image = cached
                return
            }
            guard let nsImage = NSImage(contentsOf: URL(fileURLWithPath: expandedPath)) else { return }
            let size = NSSize(width: 64, height: 64)
            let resized = NSImage(size: size)
            resized.lockFocus()
            nsImage.draw(in: NSRect(origin: .zero, size: size))
            resized.unlockFocus()
            ThumbnailCache.shared.setImage(resized, for: expandedPath)
            image = resized
        }
    }
}

public struct FileOrganizerFeatureView: View {
    // Data
    let entries: [FileOrganizerEntry]
    let plan: ActionPlan
    let scanSummary: String
    let scanProgress: Double
    let isScanning: Bool
    let isClassifying: Bool
    let isExecutingPlan: Bool
    let isPlanFresh: Bool
    let canExecutePlan: Bool
    let planIssue: String?
    let executionIssue: String?
    let executionCompleted: Bool
    let movedCount: Int
    let scannedFolders: [String]
    let rules: [FileOrganizerRule]
    let destinationBasePath: String
    let isRecursiveScan: Bool

    @Environment(\.atlasContentWidth) private var contentWidth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedFolders: [String] = ["~/Desktop", "~/Downloads"]
    @State private var isFolderPickerPresented = false
    @State private var showExecuteConfirmation = false
    @State private var selectedEntryIDs: Set<UUID> = []
    @State private var isDestinationPickerPresented = false
    @State private var isRuleEditorPresented = false

    // Callbacks
    let onStartScan: ([String]) -> Void
    let onClassify: ([UUID]) -> Void
    let onRefreshPreview: ([UUID]) -> Void
    let onExecutePlan: () -> Void
    let onDryRun: () -> Void
    let onEditRules: () -> Void
    let onUpdateDestination: (String) -> Void
    let onUpdateRecursiveScan: (Bool) -> Void
    let onUpdateRules: ([FileOrganizerRule]) -> Void
    let onUndoExecution: () -> Void

    public init(
        entries: [FileOrganizerEntry],
        plan: ActionPlan,
        scanSummary: String,
        scanProgress: Double,
        isScanning: Bool,
        isClassifying: Bool,
        isExecutingPlan: Bool,
        isPlanFresh: Bool,
        canExecutePlan: Bool,
        planIssue: String?,
        executionIssue: String?,
        executionCompleted: Bool,
        movedCount: Int,
        scannedFolders: [String],
        rules: [FileOrganizerRule],
        destinationBasePath: String,
        isRecursiveScan: Bool,
        onStartScan: @escaping ([String]) -> Void,
        onClassify: @escaping ([UUID]) -> Void,
        onRefreshPreview: @escaping ([UUID]) -> Void,
        onExecutePlan: @escaping () -> Void,
        onDryRun: @escaping () -> Void,
        onEditRules: @escaping () -> Void,
        onUpdateDestination: @escaping (String) -> Void,
        onUpdateRecursiveScan: @escaping (Bool) -> Void,
        onUpdateRules: @escaping ([FileOrganizerRule]) -> Void,
        onUndoExecution: @escaping () -> Void
    ) {
        self.entries = entries
        self.plan = plan
        self.scanSummary = scanSummary
        self.scanProgress = scanProgress
        self.isScanning = isScanning
        self.isClassifying = isClassifying
        self.isExecutingPlan = isExecutingPlan
        self.isPlanFresh = isPlanFresh
        self.canExecutePlan = canExecutePlan
        self.planIssue = planIssue
        self.executionIssue = executionIssue
        self.executionCompleted = executionCompleted
        self.movedCount = movedCount
        self.scannedFolders = scannedFolders
        self.rules = rules
        self.destinationBasePath = destinationBasePath
        self.isRecursiveScan = isRecursiveScan
        self.onStartScan = onStartScan
        self.onClassify = onClassify
        self.onRefreshPreview = onRefreshPreview
        self.onExecutePlan = onExecutePlan
        self.onDryRun = onDryRun
        self.onEditRules = onEditRules
        self.onUpdateDestination = onUpdateDestination
        self.onUpdateRecursiveScan = onUpdateRecursiveScan
        self.onUpdateRules = onUpdateRules
        self.onUndoExecution = onUndoExecution
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("fileorganizer.screen.title"),
            subtitle: AtlasL10n.string("fileorganizer.screen.subtitle")
        ) {
            VStack(spacing: AtlasSpacing.md) {
                statusCallout

                if executionCompleted && movedCount > 0 {
                    undoBanner
                }

                configurationSection

                actionSection

                if !entries.isEmpty {
                    metricCards

                    insightsSection
                } else if !isScanning && !isClassifying {
                    AtlasEmptyState(
                        title: AtlasL10n.string("fileorganizer.empty.title"),
                        detail: AtlasL10n.string("fileorganizer.empty.detail"),
                        systemImage: "folder.badge.gearshape",
                        tone: .neutral
                    )
                }

                if !entries.isEmpty {
                    categorySections
                }

                if !plan.items.isEmpty && !executionCompleted {
                    planPreviewSection
                }
            }
        }
        .onChange(of: entries) { oldEntries, newEntries in
            let oldIDs = Set(oldEntries.map(\.id))
            let addedIDs = Set(newEntries.map(\.id)).subtracting(oldIDs)
            selectedEntryIDs.formUnion(addedIDs)
            let validIDs = Set(newEntries.map(\.id))
            selectedEntryIDs = selectedEntryIDs.intersection(validIDs)
        }
        .onChange(of: executionCompleted) { _, completed in
            if completed {
                selectedEntryIDs = []
            }
        }
        .confirmationDialog(
            AtlasL10n.string("fileorganizer.confirm.execute.title"),
            isPresented: $showExecuteConfirmation,
            titleVisibility: .visible
        ) {
            Button(AtlasL10n.string("fileorganizer.action.execute"), role: .destructive) {
                onExecutePlan()
            }
            Button(AtlasL10n.string("confirm.cancel"), role: .cancel) {}
        } message: {
            Text(AtlasL10n.string("fileorganizer.confirm.execute.message"))
        }
        .sheet(isPresented: $isRuleEditorPresented) {
            FileOrganizerRuleEditorView(rules: rules) { updatedRules in
                onUpdateRules(updatedRules)
                isRuleEditorPresented = false
            }
        }
    }

    // MARK: - Pre-computed Values

    private var totalEntryBytes: Int64 {
        entries.reduce(Int64(0)) { $0 + $1.bytes }
    }

    private var entriesByCategory: [FileOrganizerCategory: [FileOrganizerEntry]] {
        Dictionary(grouping: entries, by: \.category)
    }

    private var conflictingEntryIDs: Set<UUID> {
        let fm = FileManager.default
        return Set(entries.compactMap { entry in
            let destPath = (entry.proposedDestination as NSString).expandingTildeInPath
            return fm.fileExists(atPath: destPath) ? entry.id : nil
        })
    }

    private static let largeFileThreshold: Int64 = 100 * 1024 * 1024 // 100 MB

    private var largeFileIDs: Set<UUID> {
        Set(entries.filter { $0.bytes >= Self.largeFileThreshold }.map(\.id))
    }

    private struct FileNameBytesKey: Hashable {
        let name: String
        let bytes: Int64
    }

    private var duplicateFileIDs: Set<UUID> {
        let groups = Dictionary(grouping: entries, by: { FileNameBytesKey(name: $0.fileName, bytes: $0.bytes) })
        return Set(groups.values.filter { $0.count > 1 }.flatMap { $0.map(\.id) })
    }

    // MARK: - Status Callout Computed Properties

    private enum WorkflowPhase {
        case scanning, classifying, executing
        case executionFailed, planFailed
        case executionComplete
        case ready, empty
    }

    private var currentPhase: WorkflowPhase {
        if isScanning { return .scanning }
        if isClassifying { return .classifying }
        if isExecutingPlan { return .executing }
        if executionIssue != nil { return .executionFailed }
        if planIssue != nil && entries.isEmpty { return .planFailed }
        if executionCompleted { return .executionComplete }
        if !entries.isEmpty { return .ready }
        return .empty
    }

    private var statusTitle: String {
        switch currentPhase {
        case .scanning: return AtlasL10n.string("fileorganizer.callout.scanning.title")
        case .classifying: return AtlasL10n.string("fileorganizer.status.classifying")
        case .executing: return AtlasL10n.string("fileorganizer.status.executing")
        case .executionFailed: return AtlasL10n.string("fileorganizer.status.executionFailed")
        case .planFailed: return planIssue ?? AtlasL10n.string("fileorganizer.status.executionFailed")
        case .executionComplete: return AtlasL10n.string("fileorganizer.callout.executionComplete.title")
        case .ready: return AtlasL10n.string("fileorganizer.callout.complete.title")
        case .empty: return AtlasL10n.string("fileorganizer.callout.ready.title")
        }
    }

    private var statusDetail: String {
        switch currentPhase {
        case .scanning: return AtlasL10n.string("fileorganizer.callout.scanning.detail")
        case .classifying: return AtlasL10n.string("fileorganizer.status.classifying")
        case .executing: return AtlasL10n.string("fileorganizer.status.executing")
        case .executionFailed: return executionIssue ?? ""
        case .planFailed: return planIssue ?? ""
        case .executionComplete: return AtlasL10n.string("fileorganizer.callout.executionComplete.detail", movedCount)
        case .ready:
            let totalSize = ByteCountFormatter.string(fromByteCount: totalEntryBytes, countStyle: .file)
            return AtlasL10n.string("fileorganizer.callout.complete.detail", entries.count, totalSize)
        case .empty: return AtlasL10n.string("fileorganizer.callout.empty.detail")
        }
    }

    private var statusTone: AtlasTone {
        switch currentPhase {
        case .scanning, .classifying, .empty: return .neutral
        case .executing: return .warning
        case .executionFailed, .planFailed: return .danger
        case .executionComplete, .ready: return .success
        }
    }

    private var statusSymbol: String {
        switch currentPhase {
        case .scanning, .classifying: return "arrow.triangle.2.circlepath"
        case .executing: return "gearshape.2"
        case .executionFailed, .planFailed: return "exclamationmark.triangle"
        case .executionComplete: return "checkmark.circle.fill"
        case .ready: return "checkmark.circle"
        case .empty: return "folder.badge.gearshape"
        }
    }

    // MARK: - Status Callout

    @ViewBuilder
    private var statusCallout: some View {
        if isScanning || isClassifying || isExecutingPlan {
            VStack(spacing: AtlasSpacing.lg) {
                AtlasCircularProgress(
                    progress: scanProgress == 0 ? (isScanning ? 0.15 : 0.5) : scanProgress,
                    tone: isExecutingPlan ? .warning : .neutral,
                    lineWidth: 8,
                    icon: isScanning ? "sparkles" : (isExecutingPlan ? "play.circle.fill" : "doc.text.magnifyingglass")
                )
                .frame(width: 80, height: 80)

                AtlasLoadingState(
                    title: statusTitle,
                    detail: scanSummary,
                    progress: scanProgress == 0 ? nil : scanProgress
                )
            }
        } else {
            AtlasCallout(
                title: statusTitle,
                detail: statusDetail,
                tone: statusTone,
                systemImage: statusSymbol
            )
        }
    }

    // MARK: - Undo Banner

    private var undoBanner: some View {
        HStack(spacing: AtlasSpacing.sm) {
            Image(systemName: "arrow.uturn.backward.circle")
                .foregroundStyle(AtlasColor.brand)
                .font(.system(size: 20))

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(AtlasL10n.string("fileorganizer.undo.title", movedCount))
                    .font(AtlasTypography.body)
                    .foregroundStyle(AtlasColor.textPrimary)
                Text(AtlasL10n.string("fileorganizer.undo.detail"))
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
            }

            Spacer()

            Button {
                onUndoExecution()
            } label: {
                Label(AtlasL10n.string("fileorganizer.undo.action"), systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.atlasSecondary)
        }
        .padding(AtlasSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md)
                .fill(AtlasColor.brand.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.md)
                .stroke(AtlasColor.brand.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Metric Cards

    private var metricCards: some View {
        LazyVGrid(columns: AtlasLayout.adaptiveMetricColumns(for: contentWidth), spacing: AtlasSpacing.lg) {
            AtlasMetricCard(
                title: AtlasL10n.string("fileorganizer.metric.totalFiles.title"),
                value: "\(entries.count)",
                detail: AtlasL10n.string("fileorganizer.metric.totalFiles.detail"),
                tone: .neutral,
                systemImage: "doc"
            )
            AtlasMetricCard(
                title: AtlasL10n.string("fileorganizer.metric.totalSize.title"),
                value: ByteCountFormatter.string(fromByteCount: totalEntryBytes, countStyle: .file),
                detail: AtlasL10n.string("fileorganizer.metric.totalSize.detail"),
                tone: .neutral,
                systemImage: "internaldrive"
            )
            AtlasMetricCard(
                title: AtlasL10n.string("fileorganizer.metric.categories.title"),
                value: "\(Set(entries.map(\.category)).count)",
                detail: AtlasL10n.string("fileorganizer.metric.categories.detail"),
                tone: .neutral,
                systemImage: "folder"
            )
        }
    }

    // MARK: - Category Sections

    private var categorySections: some View {
        let grouped = entriesByCategory
        return AtlasInfoCard(title: AtlasL10n.string("fileorganizer.section.results.title")) {
            LazyVStack(spacing: AtlasSpacing.xs) {
                selectionControls

                ForEach(FileOrganizerCategory.allCases, id: \.rawValue) { category in
                    if let categoryEntries = grouped[category], !categoryEntries.isEmpty {
                        AtlasSectionDisclosure(
                            title: category.title,
                            count: categoryEntries.count
                        ) {
                            LazyVStack(spacing: AtlasSpacing.xxs) {
                                ForEach(categoryEntries) { entry in
                                    entryRow(entry, category: category)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: FileOrganizerEntry, category: FileOrganizerCategory) -> some View {
        let isSelected = selectedEntryIDs.contains(entry.id)
        let hasConflict = conflictingEntryIDs.contains(entry.id)
        let isLarge = largeFileIDs.contains(entry.id)
        let isDuplicate = duplicateFileIDs.contains(entry.id)
        let showThumbnail = category == .images && !hasConflict && !isLarge && !isDuplicate
        Button {
            if isSelected {
                selectedEntryIDs.remove(entry.id)
            } else {
                selectedEntryIDs.insert(entry.id)
            }
        } label: {
            HStack(spacing: 0) {
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
                        .font(.system(size: 18))

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
            }
            .padding(AtlasSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                    .fill(isSelected ? AtlasColor.brand.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : AtlasMotion.fast, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.fileName), \(ByteCountFormatter.string(fromByteCount: entry.bytes, countStyle: .file)), \(category.title), \(AtlasL10n.string("fileorganizer.preview.row.to")) \(entry.proposedDestination), \(isSelected ? AtlasL10n.string("fileorganizer.accessibility.selected") : AtlasL10n.string("fileorganizer.accessibility.notSelected"))")
        .accessibilityHint(AtlasL10n.string("fileorganizer.accessibility.toggleHint"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Insights

    @ViewBuilder
    private var insightsSection: some View {
        let largeCount = largeFileIDs.count
        let dupCount = duplicateFileIDs.count
        if largeCount > 0 || dupCount > 0 {
            let detail = Self.insightDetail(
                entries: entries,
                largeFileIDs: largeFileIDs,
                duplicateFileIDs: duplicateFileIDs
            )
            AtlasCallout(
                title: AtlasL10n.string("fileorganizer.insight.title"),
                detail: detail,
                tone: .warning,
                systemImage: "lightbulb"
            )
        }
    }

    private static func insightDetail(
        entries: [FileOrganizerEntry],
        largeFileIDs: Set<UUID>,
        duplicateFileIDs: Set<UUID>
    ) -> String {
        var items: [String] = []
        let largeCount = largeFileIDs.count
        let dupCount = duplicateFileIDs.count
        if largeCount > 0 {
            let totalLargeBytes = entries.filter { largeFileIDs.contains($0.id) }.reduce(Int64(0)) { $0 + $1.bytes }
            let formatted = ByteCountFormatter.string(fromByteCount: totalLargeBytes, countStyle: .file)
            items.append(AtlasL10n.string("fileorganizer.insight.large.summary", largeCount, formatted))
        }
        if dupCount > 0 {
            items.append(AtlasL10n.string("fileorganizer.insight.duplicate.summary", dupCount))
        }
        return items.joined(separator: "\n")
    }

    private var selectionControls: some View {
        HStack(spacing: AtlasSpacing.sm) {
            Text(AtlasL10n.string("fileorganizer.selection.count", selectedEntryIDs.count, entries.count))
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textSecondary)

            Spacer()

            Button {
                selectedEntryIDs = Set(entries.map(\.id))
            } label: {
                Text(AtlasL10n.string("fileorganizer.action.selectAll"))
            }
            .buttonStyle(.atlasGhost)
            .disabled(selectedEntryIDs.count == entries.count)

            Button {
                selectedEntryIDs.removeAll()
            } label: {
                Text(AtlasL10n.string("fileorganizer.action.deselectAll"))
            }
            .buttonStyle(.atlasGhost)
            .disabled(selectedEntryIDs.isEmpty)
        }
        .padding(.horizontal, AtlasSpacing.xs)
    }

    // MARK: - Plan Preview

    private var entryCategoryLookup: [UUID: FileOrganizerCategory] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.category) })
    }

    private var entryNameLookup: [UUID: String] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.fileName) })
    }

    private var entryLookups: (category: [UUID: FileOrganizerCategory], name: [UUID: String]) {
        (entryCategoryLookup, entryNameLookup)
    }

    private struct PlanGroup: Identifiable {
        let id: FileOrganizerCategory
        let category: FileOrganizerCategory
        let items: [ActionItem]
        let names: [UUID: String]
    }

    private func planItemsGroupedByCategory() -> [PlanGroup] {
        let lookups = entryLookups
        var groups: [FileOrganizerCategory: [ActionItem]] = [:]
        for item in plan.items {
            let cat = lookups.category[item.id] ?? .other
            groups[cat, default: []].append(item)
        }
        return FileOrganizerCategory.allCases.compactMap { cat in
            guard let items = groups[cat], !items.isEmpty else { return nil }
            return PlanGroup(id: cat, category: cat, items: items, names: lookups.name)
        }
    }

    private var planPreviewSection: some View {
        let groups = planItemsGroupedByCategory()
        let totalSize = ByteCountFormatter.string(
            fromByteCount: plan.estimatedBytes,
            countStyle: .file
        )

        return AtlasInfoCard(
            title: AtlasL10n.string("fileorganizer.section.plan.title"),
            subtitle: "\(plan.items.count) · \(totalSize)"
        ) {
            VStack(spacing: AtlasSpacing.sm) {
                if let issue = planIssue {
                    AtlasCallout(
                        title: issue,
                        detail: "",
                        tone: .warning,
                        systemImage: "exclamationmark.triangle"
                    )
                }

                let planConflicts = plan.items.filter { conflictingEntryIDs.contains($0.id) }
                if !planConflicts.isEmpty {
                    AtlasCallout(
                        title: AtlasL10n.string("fileorganizer.conflict.callout.title", planConflicts.count),
                        detail: AtlasL10n.string("fileorganizer.conflict.callout.detail"),
                        tone: .warning,
                        systemImage: "exclamationmark.triangle"
                    )
                }

                LazyVStack(spacing: AtlasSpacing.xs) {
                    ForEach(groups) { group in
                        AtlasSectionDisclosure(
                            title: group.category.title,
                            count: group.items.count,
                            defaultExpanded: groups.count <= 3 && group.items.count <= 5
                        ) {
                            LazyVStack(spacing: AtlasSpacing.xxs) {
                                ForEach(group.items) { item in
                                    let isConflict = conflictingEntryIDs.contains(item.id)
                                    AtlasDetailRow(
                                        title: isConflict ? "\(group.names[item.id] ?? item.title) ⚠" : (group.names[item.id] ?? item.title),
                                        subtitle: AtlasL10n.string("fileorganizer.preview.row.to"),
                                        footnote: shortenDestination(item.detail),
                                        systemImage: isConflict ? "exclamationmark.triangle" : group.category.systemImage
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func shortenDestination(_ detail: String) -> String {
        // "sourcePath → destPath" → just the dest folder name
        guard let dest = detail.components(separatedBy: " → ").last else { return detail }
        let parts = dest.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count >= 2 {
            return "~/" + parts.suffix(2).joined(separator: "/")
        }
        return dest
    }

    // MARK: - Action Buttons

    // MARK: - Configuration & Action Sections

    private var configurationSection: some View {
        AtlasSectionDisclosure(
            title: AtlasL10n.string("smartclean.controls.title"),
            defaultExpanded: false
        ) {
            VStack(spacing: AtlasSpacing.sm) {
                // Folder selector
                folderSelector

                // Destination selector
                destinationSelector

                // Recursive scan toggle
                recursiveScanToggle

                Button {
                    isRuleEditorPresented = true
                } label: {
                    Label(AtlasL10n.string("fileorganizer.action.editRules"), systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.atlasGhost)
                .disabled(isScanning || isClassifying || isExecutingPlan)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: AtlasSpacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AtlasSpacing.sm) {
                    scanAndPreviewButtons
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                    scanAndPreviewButtons
                }
            }

            if !plan.items.isEmpty && !executionCompleted {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AtlasSpacing.sm) {
                        dryRunAndExecuteButtons
                    }

                    VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                        dryRunAndExecuteButtons
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scanAndPreviewButtons: some View {
        Button {
            onStartScan(selectedFolders)
        } label: {
            Label(AtlasL10n.string("fileorganizer.action.scan"), systemImage: "magnifyingglass")
        }
        .buttonStyle(.atlasPrimary)
        .disabled(selectedFolders.isEmpty || isScanning || isClassifying || isExecutingPlan)

        if !entries.isEmpty && !executionCompleted {
            Button {
                onRefreshPreview(Array(selectedEntryIDs))
            } label: {
                Label(AtlasL10n.string("fileorganizer.action.preview"), systemImage: "eye")
            }
            .buttonStyle(.atlasSecondary)
            .disabled(isScanning || isClassifying || isExecutingPlan || selectedEntryIDs.isEmpty)
        }
    }

    @ViewBuilder
    private var dryRunAndExecuteButtons: some View {
        Button {
            onDryRun()
        } label: {
            Label(AtlasL10n.string("fileorganizer.action.dryRun"), systemImage: "play")
        }
        .buttonStyle(.atlasSecondary)
        .disabled(isScanning || isExecutingPlan || plan.items.isEmpty)

        Button {
            showExecuteConfirmation = true
        } label: {
            Label(AtlasL10n.string("fileorganizer.action.execute"), systemImage: "checkmark.circle")
        }
        .buttonStyle(.atlasPrimary)
        .disabled(!canExecutePlan || isScanning || isExecutingPlan)
    }

    // MARK: - Folder Selector

    private var folderSelector: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            HStack(spacing: AtlasSpacing.sm) {
                ForEach(presetFolders, id: \.self) { folder in
                    folderToggle(folder)
                }

                Button {
                    isFolderPickerPresented = true
                } label: {
                    Label(AtlasL10n.string("fileorganizer.folderpicker.title"), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.atlasGhost)
            }

            if !selectedFolders.filter({ !presetFolders.contains($0) }).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AtlasSpacing.xs) {
                        ForEach(selectedFolders.filter { !presetFolders.contains($0) }, id: \.self) { folder in
                            AtlasStatusChip(folder, tone: .neutral)
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                let newFolders = urls.map { url in
                    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                    let path = url.path
                    if path.hasPrefix(homeDir) {
                        return "~" + String(path.dropFirst(homeDir.count))
                    }
                    return path
                }
                for folder in newFolders where !selectedFolders.contains(folder) {
                    selectedFolders.append(folder)
                }
            case .failure:
                break
            }
        }
    }

    private var presetFolders: [String] {
        ["~/Desktop", "~/Downloads"]
    }

    // MARK: - Destination Selector

    private var destinationSelector: some View {
        HStack(spacing: AtlasSpacing.xs) {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(AtlasColor.textTertiary)
                .font(AtlasTypography.body)

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(AtlasL10n.string("fileorganizer.destination.title"))
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                Text(displayPath(destinationBasePath))
                    .font(AtlasTypography.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                isDestinationPickerPresented = true
            } label: {
                Text(AtlasL10n.string("fileorganizer.destination.change"))
            }
            .buttonStyle(.atlasGhost)
        }
        .fileImporter(
            isPresented: $isDestinationPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let path = url.path
            let displayPath = path.hasPrefix(homeDir)
                ? "~" + String(path.dropFirst(homeDir.count))
                : path
            onUpdateDestination(displayPath)
        }
    }

    private func displayPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if expanded.hasPrefix(homeDir) {
            return "~" + String(expanded.dropFirst(homeDir.count))
        }
        return path
    }

    // MARK: - Recursive Scan Toggle

    private var recursiveScanToggle: some View {
        HStack(spacing: AtlasSpacing.xs) {
            Image(systemName: isRecursiveScan ? "folder.fill" : "folder")
                .foregroundStyle(AtlasColor.textTertiary)
                .font(AtlasTypography.body)

            Text(AtlasL10n.string("fileorganizer.recursive.title"))
                .font(AtlasTypography.body)
                .foregroundStyle(AtlasColor.textPrimary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { isRecursiveScan },
                set: { onUpdateRecursiveScan($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private func folderToggle(_ folder: String) -> some View {
        let isSelected = selectedFolders.contains(folder)
        let label = folder == "~/Desktop"
            ? AtlasL10n.string("fileorganizer.folderpicker.default.desktop")
            : AtlasL10n.string("fileorganizer.folderpicker.default.downloads")
        return Button {
            if isSelected {
                selectedFolders.removeAll { $0 == folder }
            } else {
                selectedFolders.append(folder)
            }
        } label: {
            HStack(spacing: AtlasSpacing.xxs) {
                Image(systemName: isSelected ? "checkmark.square" : "square")
                Text(label)
            }
            .font(AtlasTypography.body)
        }
        .buttonStyle(.plain)
    }
}
