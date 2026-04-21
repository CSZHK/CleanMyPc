import AtlasDesignSystem
import AtlasDomain
import SwiftUI
import UniformTypeIdentifiers

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

    @State private var selectedFolders: [String] = ["~/Desktop", "~/Downloads"]
    @State private var isFolderPickerPresented = false
    @State private var showExecuteConfirmation = false

    // Callbacks
    let onStartScan: ([String]) -> Void
    let onClassify: ([UUID]) -> Void
    let onRefreshPreview: () -> Void
    let onExecutePlan: () -> Void
    let onDryRun: () -> Void
    let onEditRules: () -> Void

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
        onStartScan: @escaping ([String]) -> Void,
        onClassify: @escaping ([UUID]) -> Void,
        onRefreshPreview: @escaping () -> Void,
        onExecutePlan: @escaping () -> Void,
        onDryRun: @escaping () -> Void,
        onEditRules: @escaping () -> Void
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
        self.onStartScan = onStartScan
        self.onClassify = onClassify
        self.onRefreshPreview = onRefreshPreview
        self.onExecutePlan = onExecutePlan
        self.onDryRun = onDryRun
        self.onEditRules = onEditRules
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("fileorganizer.screen.title"),
            subtitle: AtlasL10n.string("fileorganizer.screen.subtitle")
        ) {
            VStack(spacing: AtlasSpacing.md) {
                statusCallout
                metricCards

                if !entries.isEmpty {
                    categorySections
                }

                if !plan.items.isEmpty && !executionCompleted {
                    planPreviewSection
                }

                actionButtons
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
            let totalSize = ByteCountFormatter.string(fromByteCount: entries.map(\.bytes).reduce(0, +), countStyle: .file)
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

    // MARK: - Metric Cards

    private var metricCards: some View {
        HStack(spacing: AtlasSpacing.md) {
            AtlasMetricCard(
                title: AtlasL10n.string("fileorganizer.metric.totalFiles.title"),
                value: "\(entries.count)",
                detail: AtlasL10n.string("fileorganizer.metric.totalFiles.detail"),
                tone: .neutral,
                systemImage: "doc"
            )
            AtlasMetricCard(
                title: AtlasL10n.string("fileorganizer.metric.totalSize.title"),
                value: ByteCountFormatter.string(fromByteCount: entries.map(\.bytes).reduce(0, +), countStyle: .file),
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
        AtlasInfoCard(title: AtlasL10n.string("fileorganizer.section.results.title")) {
            LazyVStack(spacing: AtlasSpacing.xs) {
                ForEach(FileOrganizerCategory.allCases, id: \.rawValue) { category in
                    let categoryEntries = entries.filter { $0.category == category }
                    if !categoryEntries.isEmpty {
                        AtlasSectionDisclosure(
                            title: category.title,
                            count: categoryEntries.count
                        ) {
                            LazyVStack(spacing: AtlasSpacing.xxs) {
                                ForEach(categoryEntries) { entry in
                                    AtlasDetailRow(
                                        title: entry.fileName,
                                        subtitle: ByteCountFormatter.string(fromByteCount: entry.bytes, countStyle: .file),
                                        footnote: entry.proposedDestination,
                                        systemImage: category.systemImage
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Plan Preview

    private var entryCategoryLookup: [UUID: FileOrganizerCategory] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.category) })
    }

    private var entryNameLookup: [UUID: String] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.fileName) })
    }

    private struct PlanGroup: Identifiable {
        let id: FileOrganizerCategory
        let category: FileOrganizerCategory
        let items: [ActionItem]
        let names: [UUID: String]
    }

    private func planItemsGroupedByCategory() -> [PlanGroup] {
        let catLookup = entryCategoryLookup
        let nameLookup = entryNameLookup
        var groups: [FileOrganizerCategory: [ActionItem]] = [:]
        for item in plan.items {
            let cat = catLookup[item.id] ?? .other
            groups[cat, default: []].append(item)
        }
        return FileOrganizerCategory.allCases.compactMap { cat in
            guard let items = groups[cat], !items.isEmpty else { return nil }
            return PlanGroup(id: cat, category: cat, items: items, names: nameLookup)
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

                LazyVStack(spacing: AtlasSpacing.xs) {
                    ForEach(groups) { group in
                        AtlasSectionDisclosure(
                            title: group.category.title,
                            count: group.items.count,
                            defaultExpanded: groups.count <= 3 && group.items.count <= 5
                        ) {
                            LazyVStack(spacing: AtlasSpacing.xxs) {
                                ForEach(group.items) { item in
                                    AtlasDetailRow(
                                        title: group.names[item.id] ?? item.title,
                                        subtitle: AtlasL10n.string("fileorganizer.preview.row.to"),
                                        footnote: shortenDestination(item.detail),
                                        systemImage: group.category.systemImage
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

    private var actionButtons: some View {
        AtlasInfoCard(title: AtlasL10n.string("smartclean.controls.title")) {
            VStack(spacing: AtlasSpacing.sm) {
                // Folder selector
                folderSelector

                HStack(spacing: AtlasSpacing.sm) {
                    Button {
                        onStartScan(selectedFolders)
                    } label: {
                        Label(AtlasL10n.string("fileorganizer.action.scan"), systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedFolders.isEmpty || isScanning || isClassifying || isExecutingPlan)

                    if !entries.isEmpty && !executionCompleted {
                        Button {
                            onRefreshPreview()
                        } label: {
                            Label(AtlasL10n.string("fileorganizer.action.preview"), systemImage: "eye")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isScanning || isClassifying || isExecutingPlan)
                    }
                }

                if !plan.items.isEmpty && !executionCompleted {
                    HStack(spacing: AtlasSpacing.sm) {
                        Button {
                            onDryRun()
                        } label: {
                            Label(AtlasL10n.string("fileorganizer.action.dryRun"), systemImage: "play")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isScanning || isExecutingPlan)

                        Button {
                            showExecuteConfirmation = true
                        } label: {
                            Label(AtlasL10n.string("fileorganizer.action.execute"), systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canExecutePlan || isScanning || isExecutingPlan)
                    }
                }
            }
        }
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
                .buttonStyle(.bordered)
                .controlSize(.small)
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
