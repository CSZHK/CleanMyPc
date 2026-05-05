import AtlasApplication
import AtlasDomain
import UniformTypeIdentifiers

public struct AtlasFileOrganizerClassifier: AtlasFileOrganizerClassifying, Sendable {
    public init() {}

    public func classify(_ entries: [FileOrganizerEntry], rules: [FileOrganizerRule]) async -> [FileOrganizerEntry] {
        entries.map { entry in
            var classified = entry
            let category = classifyEntry(entry, rules: rules)
            classified.category = category
            let safeFileName = (entry.fileName as NSString).lastPathComponent
            classified.proposedDestination = "~/Organized/\(category.folderName)/\(safeFileName)"
            return classified
        }
    }

    private func classifyEntry(_ entry: FileOrganizerEntry, rules: [FileOrganizerRule]) -> FileOrganizerCategory {
        let ext = (entry.fileName as NSString).pathExtension.lowercased()

        // Priority 1: Custom rules (extension or name patterns)
        for rule in rules {
            let matchesExtension = rule.extensionPatterns.contains(where: { $0.lowercased() == ext })
            let matchesName = !rule.namePatterns.isEmpty && rule.namePatterns.contains(where: { pattern in
                let lowered = pattern.lowercased()
                return entry.fileName.lowercased().contains(lowered)
            })
            guard matchesExtension || matchesName else { continue }
            if let minSize = rule.minSizeBytes, entry.bytes < minSize { continue }
            if let maxSize = rule.maxSizeBytes, entry.bytes > maxSize { continue }
            return rule.category
        }

        // Priority 2: UTType fallback
        if let utt = UTType(filenameExtension: ext) {
            if utt.conforms(to: .image) { return .images }
            if utt.conforms(to: .movie) { return .videos }
            if utt.conforms(to: .audio) { return .audio }
            if utt.conforms(to: .pdf) || utt.conforms(to: .spreadsheet) || utt.conforms(to: .presentation) { return .documents }
            if utt.conforms(to: .sourceCode) { return .code }
            if utt.conforms(to: .archive) { return .archives }
            if utt.conforms(to: .diskImage) { return .installers }
        }

        // Priority 3: Fallback to existing category
        return entry.category
    }
}
