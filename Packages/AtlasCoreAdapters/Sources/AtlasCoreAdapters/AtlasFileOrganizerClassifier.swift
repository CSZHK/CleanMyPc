import AtlasApplication
import AtlasDomain
import UniformTypeIdentifiers

public struct AtlasFileOrganizerClassifier: AtlasFileOrganizerClassifying, Sendable {
    public init() {}

    public func classify(_ entries: [FileOrganizerEntry], rules: [FileOrganizerRule], destinationBasePath: String = "~/Organized") async -> [FileOrganizerEntry] {
        let basePath = destinationBasePath.hasSuffix("/") ? String(destinationBasePath.dropLast()) : destinationBasePath
        return entries.map { entry in
            var classified = entry
            let result = classifyEntry(entry, rules: rules)
            classified.category = result.category
            let safeFileName = (entry.fileName as NSString).lastPathComponent
            if let subfolder = result.subfolder, !subfolder.isEmpty {
                classified.proposedDestination = "\(basePath)/\(result.category.folderName)/\(subfolder)/\(safeFileName)"
            } else {
                classified.proposedDestination = "\(basePath)/\(result.category.folderName)/\(safeFileName)"
            }
            return classified
        }
    }

    private struct ClassificationResult {
        let category: FileOrganizerCategory
        let subfolder: String?
    }

    private func classifyEntry(_ entry: FileOrganizerEntry, rules: [FileOrganizerRule]) -> ClassificationResult {
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
            return ClassificationResult(category: rule.category, subfolder: rule.destinationSubfolder)
        }

        // Priority 2: UTType fallback
        if let utt = UTType(filenameExtension: ext) {
            if utt.conforms(to: .image) { return ClassificationResult(category: .images, subfolder: nil) }
            if utt.conforms(to: .movie) { return ClassificationResult(category: .videos, subfolder: nil) }
            if utt.conforms(to: .audio) { return ClassificationResult(category: .audio, subfolder: nil) }
            if utt.conforms(to: .pdf) || utt.conforms(to: .spreadsheet) || utt.conforms(to: .presentation) { return ClassificationResult(category: .documents, subfolder: nil) }
            if utt.conforms(to: .sourceCode) { return ClassificationResult(category: .code, subfolder: nil) }
            if utt.conforms(to: .archive) { return ClassificationResult(category: .archives, subfolder: nil) }
            if utt.conforms(to: .diskImage) { return ClassificationResult(category: .installers, subfolder: nil) }
        }

        // Priority 3: Fallback to existing category
        return ClassificationResult(category: entry.category, subfolder: nil)
    }
}
