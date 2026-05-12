import AtlasDesignSystem
import AtlasDomain
import SwiftUI
import UniformTypeIdentifiers

struct FileOrganizerRuleEditorView: View {
    @State private var rules: [FileOrganizerRule]
    @State private var editingRule: FileOrganizerRule?
    @State private var isEditSheetPresented = false
    @State private var isNewRule = false
    @State private var isExportPresented = false
    @State private var isImportPresented = false

    let onSave: ([FileOrganizerRule]) -> Void

    init(rules: [FileOrganizerRule], onSave: @escaping ([FileOrganizerRule]) -> Void) {
        self._rules = State(initialValue: rules)
        self.onSave = onSave
    }

    var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("fileorganizer.ruleeditor.title"),
            subtitle: AtlasL10n.string("fileorganizer.ruleeditor.subtitle")
        ) {
            VStack(spacing: AtlasSpacing.md) {
                rulesList

                HStack(spacing: AtlasSpacing.sm) {
                    Button {
                        onSave(rules)
                    } label: {
                        Label(AtlasL10n.string("fileorganizer.ruleeditor.save"), systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)

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
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        isImportPresented = true
                    } label: {
                        Label(AtlasL10n.string("fileorganizer.ruleeditor.import.title"), systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        isExportPresented = true
                    } label: {
                        Label(AtlasL10n.string("fileorganizer.ruleeditor.export.title"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(rules.isEmpty)
                }
            }
        }
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
        .fileExporter(
            isPresented: $isExportPresented,
            documents: [RulesDocument(rules: rules)],
            contentType: .json
        ) { result in
            // Export completed — no further action needed
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
            guard let data = try? Data(contentsOf: url),
                  let imported = try? JSONDecoder().decode([FileOrganizerRule].self, from: data) else { return }
            rules = imported
        }
    }

    private var rulesList: some View {
        AtlasInfoCard(
            title: AtlasL10n.string("fileorganizer.ruleeditor.rules.title"),
            subtitle: rules.count > 1 ? AtlasL10n.string("fileorganizer.ruleeditor.priority.hint") : nil
        ) {
            if rules.isEmpty {
                Text(AtlasL10n.string("fileorganizer.ruleeditor.empty"))
                    .font(AtlasTypography.body)
                    .foregroundStyle(AtlasColor.textSecondary)
                    .padding(AtlasSpacing.sm)
            } else {
                LazyVStack(spacing: AtlasSpacing.xs) {
                    ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                        ruleRow(rule, at: index)
                    }
                    .onDelete { offsets in
                        rules.remove(atOffsets: offsets)
                    }
                }
            }
        }
    }

    private func ruleRow(_ rule: FileOrganizerRule, at index: Int) -> some View {
        Button {
            editingRule = rule
            isNewRule = false
            isEditSheetPresented = true
        } label: {
            HStack(spacing: AtlasSpacing.xs) {
                // Priority badge
                Text("\(index + 1)")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
                    .frame(width: 20)

                Image(systemName: rule.category.systemImage)
                    .foregroundStyle(AtlasColor.brand)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
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

                // Move buttons
                HStack(spacing: 2) {
                    Button {
                        withAnimation { rules.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1) }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(index > 0 ? AtlasColor.brand : AtlasColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)

                    Button {
                        withAnimation { rules.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2) }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(index < rules.count - 1 ? AtlasColor.brand : AtlasColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(index >= rules.count - 1)
                }

                Image(systemName: "chevron.right")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.textTertiary)
            }
            .padding(.vertical, AtlasSpacing.xxs)
        }
        .buttonStyle(.plain)
    }
}

private struct RuleEditForm: View {
    @State private var name: String
    @State private var extensionText: String
    @State private var category: FileOrganizerCategory
    @State private var subfolder: String
    @State private var hasMinSize = false
    @State private var minSizeText: String
    @State private var hasMaxSize = false
    @State private var maxSizeText: String

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
        self._category = State(initialValue: rule.category)
        self._subfolder = State(initialValue: rule.destinationSubfolder ?? "")
        let minSize = rule.minSizeBytes
        self._hasMinSize = State(initialValue: minSize != nil)
        self._minSizeText = State(initialValue: minSize.map { String($0) } ?? "")
        let maxSize = rule.maxSizeBytes
        self._hasMaxSize = State(initialValue: maxSize != nil)
        self._maxSizeText = State(initialValue: maxSize.map { String($0) } ?? "")
    }

    var body: some View {
        AtlasScreen(
            title: isNew
                ? AtlasL10n.string("fileorganizer.ruleeditor.new.title")
                : AtlasL10n.string("fileorganizer.ruleeditor.edit.title"),
            subtitle: AtlasL10n.string("fileorganizer.ruleeditor.edit.subtitle")
        ) {
            VStack(spacing: AtlasSpacing.md) {
                AtlasInfoCard(title: AtlasL10n.string("fileorganizer.ruleeditor.section.general")) {
                    VStack(spacing: AtlasSpacing.sm) {
                        LabeledContent(AtlasL10n.string("fileorganizer.ruleeditor.field.name")) {
                            TextField("", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        }

                        LabeledContent(AtlasL10n.string("fileorganizer.ruleeditor.field.extensions")) {
                            TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.extensions.hint"), text: $extensionText)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        }

                        LabeledContent(AtlasL10n.string("fileorganizer.ruleeditor.field.category")) {
                            Picker("", selection: $category) {
                                ForEach(FileOrganizerCategory.allCases, id: \.rawValue) { cat in
                                    Text(cat.title).tag(cat)
                                }
                            }
                            .frame(maxWidth: 200)
                        }

                        LabeledContent(AtlasL10n.string("fileorganizer.ruleeditor.field.subfolder")) {
                            TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.optional"), text: $subfolder)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 200)
                        }
                    }
                }

                AtlasInfoCard(title: AtlasL10n.string("fileorganizer.ruleeditor.section.size")) {
                    VStack(spacing: AtlasSpacing.sm) {
                        HStack {
                            Toggle(AtlasL10n.string("fileorganizer.ruleeditor.field.minsize"), isOn: $hasMinSize)
                            if hasMinSize {
                                TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.bytes"), text: $minSizeText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }

                        HStack {
                            Toggle(AtlasL10n.string("fileorganizer.ruleeditor.field.maxsize"), isOn: $hasMaxSize)
                            if hasMaxSize {
                                TextField(AtlasL10n.string("fileorganizer.ruleeditor.field.bytes"), text: $maxSizeText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }
                    }
                }

                HStack(spacing: AtlasSpacing.sm) {
                    Button {
                        saveRule()
                    } label: {
                        Label(AtlasL10n.string("fileorganizer.ruleeditor.save"), systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty && extensionText.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        onCancel()
                    } label: {
                        Label(AtlasL10n.string("confirm.cancel"), systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func saveRule() {
        let exts = extensionText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        let minSize: Int64? = hasMinSize ? Int64(minSizeText) : nil
        let maxSize: Int64? = hasMaxSize ? Int64(maxSizeText) : nil
        let folder = subfolder.trimmingCharacters(in: .whitespaces)
        let ruleName = name.trimmingCharacters(in: .whitespaces)

        let rule = FileOrganizerRule(
            id: ruleId,
            name: ruleName.isEmpty ? exts.joined(separator: ", ") : ruleName,
            extensionPatterns: exts,
            category: category,
            destinationSubfolder: folder.isEmpty ? nil : folder,
            minSizeBytes: minSize,
            maxSizeBytes: maxSize
        )
        onSave(rule)
    }
}

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
