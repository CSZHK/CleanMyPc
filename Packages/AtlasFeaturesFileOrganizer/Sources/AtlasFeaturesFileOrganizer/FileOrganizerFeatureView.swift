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
    let scannedFolders: [String]
    let rules: [FileOrganizerRule]

    @State private var selectedFolders: [String] = ["~/Desktop", "~/Downloads"]
    @State private var isFolderPickerPresented = false

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

                if !plan.items.isEmpty {
                    planPreviewSection
                }

                actionButtons
            }
        }
    }

    // MARK: - Status Callout

    @ViewBuilder
    private var statusCallout: some View {
        if isScanning || isClassifying {
            AtlasCallout(
                title: AtlasL10n.string("fileorganizer.callout.scanning.title"),
                detail: AtlasL10n.string("fileorganizer.callout.scanning.detail"),
                tone: .neutral,
                systemImage: "arrow.triangle.2.circlepath"
            )
        } else if !entries.isEmpty {
            let totalSize = ByteCountFormatter.string(fromByteCount: entries.map(\.bytes).reduce(0, +), countStyle: .file)
            AtlasCallout(
                title: AtlasL10n.string("fileorganizer.callout.complete.title"),
                detail: AtlasL10n.string("fileorganizer.callout.complete.detail", entries.count, totalSize),
                tone: .success,
                systemImage: "checkmark.circle"
            )
        } else {
            AtlasCallout(
                title: AtlasL10n.string("fileorganizer.callout.ready.title"),
                detail: AtlasL10n.string("fileorganizer.callout.ready.detail"),
                tone: .neutral,
                systemImage: "folder.badge.gearshape"
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

    private var planPreviewSection: some View {
        AtlasInfoCard(
            title: AtlasL10n.string("fileorganizer.section.plan.title"),
            subtitle: AtlasL10n.string("smartclean.preview.metric.space.detail.other", plan.items.count)
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
                    ForEach(plan.items) { item in
                        AtlasDetailRow(
                            title: item.title,
                            subtitle: AtlasL10n.string("fileorganizer.preview.row.to"),
                            footnote: item.detail,
                            systemImage: "arrow.right.circle"
                        )
                    }
                }
            }
        }
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

                    if !entries.isEmpty {
                        Button {
                            onRefreshPreview()
                        } label: {
                            Label(AtlasL10n.string("fileorganizer.action.preview"), systemImage: "eye")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isScanning || isClassifying || isExecutingPlan)
                    }
                }

                if !plan.items.isEmpty {
                    HStack(spacing: AtlasSpacing.sm) {
                        Button {
                            onDryRun()
                        } label: {
                            Label(AtlasL10n.string("fileorganizer.action.dryRun"), systemImage: "play")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isScanning || isExecutingPlan)

                        Button {
                            onExecutePlan()
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
