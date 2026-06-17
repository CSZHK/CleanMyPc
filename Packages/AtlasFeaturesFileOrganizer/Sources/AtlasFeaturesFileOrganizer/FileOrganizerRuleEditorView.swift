import AtlasDesignSystem
import AtlasDomain
import SwiftUI
import UniformTypeIdentifiers

/// Pure MB→bytes parsing for rule size bands (audit #6 + final-audit test gap).
/// Internal so it can be unit-tested via `@testable`. Clamps to Int64 so huge
/// or pathological inputs neither trap nor silently exceed the type range;
/// non-numeric / non-positive input → nil (no limit).
enum FileOrganizerSizeParsing {
    static func bytes(fromMB text: String) -> Int64? {
        let mb = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard mb.isFinite, mb > 0 else { return nil }
        let parsed = mb * 1_048_576.0
        guard parsed.isFinite else { return Int64.max }
        return parsed >= Double(Int64.max) ? Int64.max : Int64(parsed)
    }
}

struct FileOrganizerRuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rules: [FileOrganizerRule]
    @State private var editingRule: FileOrganizerRule?
    @State private var isEditSheetPresented = false
    @State private var isNewRule = false
    @State private var isExportPresented = false
    @State private var isImportPresented = false
    @State private var importError: String?
    @State private var ruleToDelete: FileOrganizerRule?

    let onSave: ([FileOrganizerRule]) -> Void

    init(rules: [FileOrganizerRule], onSave: @escaping ([FileOrganizerRule]) -> Void) {
        self._rules = State(initialValue: rules)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AtlasSpacing.xl) {
                    rulesList
                    actionBar
                }
                .padding(AtlasSpacing.xl)
            }
            .navigationTitle(AtlasL10n.string("fileorganizer.ruleeditor.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AtlasL10n.string("confirm.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AtlasL10n.string("fileorganizer.ruleeditor.save")) {
                        onSave(rules)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .frame(minWidth: 580, minHeight: 480)
        .sheet(isPresented: $isEditSheetPresented) {
            if let rule = editingRule {
                RuleEditForm(rule: rule, isNew: isNewRule) { savedRule in
                    if isNewRule {
                        rules.append(savedRule)
                    } else if let idx = rules.firstIndex(where: { $0.id == savedRule.id }) {
                        rules[idx] = savedRule
                    }
                    editingRule = nil
                    isEditSheetPresented = false
                } onCancel: {
                    editingRule = nil
                    isEditSheetPresented = false
                }
            }
        }
        .alert(
            AtlasL10n.string("fileorganizer.ruleeditor.delete"),
            isPresented: Binding(
                get: { ruleToDelete != nil },
                set: { if !$0 { ruleToDelete = nil } }
            ),
            presenting: ruleToDelete
        ) { rule in
            Button(AtlasL10n.string("fileorganizer.ruleeditor.delete"), role: .destructive) {
                withAnimation { rules.removeAll { $0.id == rule.id } }
                ruleToDelete = nil
            }
            Button(AtlasL10n.string("confirm.cancel"), role: .cancel) {
                ruleToDelete = nil
            }
        } message: { _ in
            Text(AtlasL10n.string("fileorganizer.ruleeditor.delete.confirm"))
        }
        .fileExporter(
            isPresented: $isExportPresented,
            documents: [RulesDocument(rules: rules)],
            contentType: .json
        ) { result in
            if case .failure(let error) = result {
                print("Rule export failed: \(error)")
            }
        }
        .fileImporter(
            isPresented: $isImportPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let imported = try JSONDecoder().decode([FileOrganizerRule].self, from: data)
                // Validate + dedup (audit #4): drop rules that can never match
                // (no patterns), dedup by id, and refuse to wipe existing rules
                // with an empty/invalid import.
                var seen = Set<UUID>()
                let deduped = imported
                    .filter { !$0.extensionPatterns.isEmpty || !$0.namePatterns.isEmpty }
                    .filter { seen.insert($0.id).inserted }
                guard !deduped.isEmpty else {
                    importError = AtlasL10n.string("fileorganizer.ruleeditor.import.empty")
                    return
                }
                rules = deduped
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert(
            AtlasL10n.string("fileorganizer.ruleeditor.import.title"),
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            ),
            presenting: importError
        ) { _ in
            Button(AtlasL10n.string("confirm.cancel"), role: .cancel) { importError = nil }
        } message: { error in
            Text(error)
        }
    }

    // MARK: - Rules List

    private var rulesList: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text(AtlasL10n.string("fileorganizer.ruleeditor.rules.title"))
                    .font(AtlasTypography.sectionTitle)

                if rules.count > 1 {
                    Text(AtlasL10n.string("fileorganizer.ruleeditor.priority.hint"))
                        .font(AtlasTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }

            if rules.isEmpty {
                AtlasEmptyState(
                    title: AtlasL10n.string("fileorganizer.ruleeditor.empty"),
                    detail: AtlasL10n.string("fileorganizer.ruleeditor.empty.detail"),
                    systemImage: "slider.horizontal.3",
                    tone: .neutral
                )
            } else {
                VStack(spacing: AtlasSpacing.xs) {
                    ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                        ruleRow(rule, at: index)
                    }
                }
            }
        }
    }

    private func ruleRow(_ rule: FileOrganizerRule, at index: Int) -> some View {
        HStack(spacing: AtlasSpacing.sm) {
            Text("\(index + 1)")
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textTertiary)
                .frame(width: 20)

            Image(systemName: rule.category.systemImage)
                .foregroundStyle(AtlasColor.brand)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(rule.name.isEmpty ? AtlasL10n.string("fileorganizer.ruleeditor.untitled") : rule.name)
                    .font(AtlasTypography.body)
                    .foregroundStyle(AtlasColor.textPrimary)

                if !rule.extensionPatterns.isEmpty {
                    Text(rule.extensionPatterns.joined(separator: ", "))
                        .font(AtlasTypography.caption)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: AtlasSpacing.xxs) {
                Button {
                    withAnimation(AtlasMotion.fast) {
                        rules.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(AtlasTypography.captionSmall.weight(.semibold))
                        .foregroundStyle(index > 0 ? AtlasColor.brand : AtlasColor.textTertiary)
                        .frame(width: 44, height: 44) // round-21: ≥44pt tap target (branch floor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .accessibilityLabel(AtlasL10n.string("fileorganizer.ruleeditor.accessibility.moveUp"))

                Button {
                    withAnimation(AtlasMotion.fast) {
                        rules.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(AtlasTypography.captionSmall.weight(.semibold))
                        .foregroundStyle(index < rules.count - 1 ? AtlasColor.brand : AtlasColor.textTertiary)
                        .frame(width: 44, height: 44) // round-21: ≥44pt tap target (branch floor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index >= rules.count - 1)
                .accessibilityLabel(AtlasL10n.string("fileorganizer.ruleeditor.accessibility.moveDown"))

                Button {
                    ruleToDelete = rule
                } label: {
                    Image(systemName: "trash")
                        .font(AtlasTypography.captionSmall.weight(.semibold))
                        .foregroundStyle(AtlasColor.danger.opacity(0.7))
                        .frame(width: 44, height: 44) // round-21: ≥44pt tap target (branch floor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AtlasL10n.string("fileorganizer.ruleeditor.delete"))
            }

            Image(systemName: "chevron.right")
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textTertiary)
        }
        .padding(.vertical, AtlasSpacing.sm)
        .padding(.horizontal, AtlasSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                .fill(AtlasColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            editingRule = rule
            isNewRule = false
            isEditSheetPresented = true
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: AtlasSpacing.sm) {
            Button {
                let newRule = FileOrganizerRule(
                    name: "",
                    extensionPatterns: [],
                    category: .other
                )
                editingRule = newRule
                isNewRule = true
                isEditSheetPresented = true
            } label: {
                Label(AtlasL10n.string("fileorganizer.ruleeditor.add"), systemImage: "plus.circle")
            }
            .buttonStyle(.atlasSecondary)

            Spacer()

            Button {
                isImportPresented = true
            } label: {
                Label(AtlasL10n.string("fileorganizer.ruleeditor.import.title"), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.atlasGhost)

            Button {
                isExportPresented = true
            } label: {
                Label(AtlasL10n.string("fileorganizer.ruleeditor.export.title"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.atlasGhost)
            .disabled(rules.isEmpty)
        }
    }
}

// MARK: - Rule Edit Form

private struct RuleEditForm: View {
    @State private var name: String
    @State private var extensionText: String
    @State private var namePatternText: String
    @State private var category: FileOrganizerCategory
    @State private var subfolder: String
    @State private var hasMinSize = false
    @State private var minSizeMBText: String
    @State private var hasMaxSize = false
    @State private var maxSizeMBText: String

    private let ruleId: UUID
    let isNew: Bool
    let onSave: (FileOrganizerRule) -> Void
    let onCancel: () -> Void

    init(rule: FileOrganizerRule, isNew: Bool, onSave: @escaping (FileOrganizerRule) -> Void, onCancel: @escaping () -> Void) {
        self.ruleId = rule.id
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        self._name = State(initialValue: rule.name)
        self._extensionText = State(initialValue: rule.extensionPatterns.joined(separator: ", "))
        self._namePatternText = State(initialValue: rule.namePatterns.joined(separator: ", "))
        self._category = State(initialValue: rule.category)
        self._subfolder = State(initialValue: rule.destinationSubfolder ?? "")
        let minSize = rule.minSizeBytes
        self._hasMinSize = State(initialValue: minSize != nil)
        self._minSizeMBText = State(initialValue: minSize.map { String(format: "%.0f", Double($0) / 1_048_576.0) } ?? "")
        let maxSize = rule.maxSizeBytes
        self._hasMaxSize = State(initialValue: maxSize != nil)
        self._maxSizeMBText = State(initialValue: maxSize.map { String(format: "%.0f", Double($0) / 1_048_576.0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AtlasSpacing.xl) {
                    generalSection
                    sizeSection
                    saveButtons
                }
                .padding(AtlasSpacing.xl)
            }
            .navigationTitle(isNew
                ? AtlasL10n.string("fileorganizer.ruleeditor.new.title")
                : AtlasL10n.string("fileorganizer.ruleeditor.edit.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AtlasL10n.string("confirm.cancel")) {
                        onCancel()
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    // MARK: - General Section

    private var generalSection: some View {
        AtlasInfoCard(title: AtlasL10n.string("fileorganizer.ruleeditor.section.general")) {
            VStack(spacing: AtlasSpacing.lg) {
                fieldRow(AtlasL10n.string("fileorganizer.ruleeditor.field.name")) {
                    TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.name"), text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                fieldRow(AtlasL10n.string("fileorganizer.ruleeditor.field.extensions")) {
                    TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.extensions.hint"), text: $extensionText)
                        .textFieldStyle(.roundedBorder)
                }

                fieldRow(AtlasL10n.string("fileorganizer.ruleeditor.field.namePatterns")) {
                    TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.namePatterns.hint"), text: $namePatternText)
                        .textFieldStyle(.roundedBorder)
                }

                fieldRow(AtlasL10n.string("fileorganizer.ruleeditor.field.category")) {
                    Picker("", selection: $category) {
                        ForEach(FileOrganizerCategory.allCases, id: \.rawValue) { cat in
                            Label(cat.title, systemImage: cat.systemImage).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                fieldRow(AtlasL10n.string("fileorganizer.ruleeditor.field.subfolder")) {
                    HStack {
                        TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.optional"), text: $subfolder)
                            .textFieldStyle(.roundedBorder)
                        if !subfolder.isEmpty {
                            Text(AtlasL10n.string("fileorganizer.ruleeditor.field.subfolder.preview", category.folderName, subfolder))
                                .font(AtlasTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Size Section

    private var sizeSection: some View {
        AtlasInfoCard(title: AtlasL10n.string("fileorganizer.ruleeditor.section.size")) {
            VStack(spacing: AtlasSpacing.lg) {
                HStack {
                    Toggle(AtlasL10n.string("fileorganizer.ruleeditor.field.minsize"), isOn: $hasMinSize)
                    if hasMinSize {
                        TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.minsize.unit"), text: $minSizeMBText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text(AtlasL10n.string("fileorganizer.ruleeditor.field.minsize.unit"))
                            .font(AtlasTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Toggle(AtlasL10n.string("fileorganizer.ruleeditor.field.maxsize"), isOn: $hasMaxSize)
                    if hasMaxSize {
                        TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.maxsize.unit"), text: $maxSizeMBText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text(AtlasL10n.string("fileorganizer.ruleeditor.field.maxsize.unit"))
                            .font(AtlasTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Save Buttons

    /// A rule is only useful if it can match something (audit #5): a name-only
    /// rule with no extension/name patterns never matches and silently does
    /// nothing. Parsed through the same splitter as `saveRule` so a pure-
    /// separator input (e.g. ", ") does not enable save with empty patterns.
    private var hasAnyPattern: Bool {
        !parsedExtensions.isEmpty || !parsedNamePatterns.isEmpty
    }

    private var parsedExtensions: [String] {
        extensionText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }  // tolerate ".png" (audit #3)
            .filter { !$0.isEmpty }
    }

    private var parsedNamePatterns: [String] {
        namePatternText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var saveButtons: some View {
        HStack(spacing: AtlasSpacing.sm) {
            Button {
                saveRule()
            } label: {
                Label(AtlasL10n.string("fileorganizer.ruleeditor.save"), systemImage: "checkmark")
            }
            .buttonStyle(.atlasPrimary)
            .disabled(!hasAnyPattern)

            Button {
                onCancel()
            } label: {
                Label(AtlasL10n.string("confirm.cancel"), systemImage: "xmark")
            }
            .buttonStyle(.atlasGhost)
        }
    }

    // MARK: - Helpers

    private func fieldRow(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        LabeledContent(label) {
            content()
        }
    }

    private func saveRule() {
        let exts = parsedExtensions
        let namePatterns = parsedNamePatterns

        let minSizeBytes: Int64? = hasMinSize ? FileOrganizerSizeParsing.bytes(fromMB: minSizeMBText) : nil
        let maxSizeBytes: Int64? = hasMaxSize ? FileOrganizerSizeParsing.bytes(fromMB: maxSizeMBText) : nil
        let folder = subfolder.trimmingCharacters(in: .whitespaces)
        let ruleName = name.trimmingCharacters(in: .whitespaces)

        let rule = FileOrganizerRule(
            id: ruleId,
            name: ruleName.isEmpty ? exts.joined(separator: ", ") : ruleName,
            extensionPatterns: exts,
            namePatterns: namePatterns,
            category: category,
            destinationSubfolder: folder.isEmpty ? nil : folder,
            minSizeBytes: minSizeBytes,
            maxSizeBytes: maxSizeBytes
        )
        onSave(rule)
    }
}

// MARK: - Rules Document (export/import)

private struct RulesDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(rules: [FileOrganizerRule]) {
        self.data = (try? JSONEncoder().encode(rules)) ?? Data("[]".utf8)
    }

    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = fileData
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
