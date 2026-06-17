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
            // Sanitize the rule's subfolder before it touches the path (audit
            // security #22): a subfolder like "../../Library/LaunchDaemons"
            // must never let a file escape its category folder.
            let sanitizedSub = Self.sanitizedSubfolder(result.subfolder)
            if !sanitizedSub.isEmpty {
                classified.proposedDestination = "\(basePath)/\(result.category.folderName)/\(sanitizedSub)/\(safeFileName)"
            } else {
                classified.proposedDestination = "\(basePath)/\(result.category.folderName)/\(safeFileName)"
            }
            return classified
        }
    }

    /// Reduces a rule `destinationSubfolder` to a safe relative path: drops
    /// traversal (`..`), absolute (`/`-leading), empty, null, and backslash
    /// components so it can only name a folder beneath the category directory.
    /// Returns "" when nothing safe remains (audit security #22).
    static func sanitizedSubfolder(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\0"), !trimmed.contains("\\") else { return "" }
        let safe = trimmed
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
        return safe.joined(separator: "/")
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

        // Priority 2: UTType fallback — ONLY for extensions the scanner could
        // not place (audit #20). Otherwise the scanner's extension-based
        // classification is authoritative: UTType conformances mis-classify
        // `.ts` (TypeScript code, but conforms to .movie) as videos and
        // `.dmg`/`.pkg` (conform to .archive) as archives instead of code and
        // installers. UTType is reserved for genuinely unknown extensions.
        if entry.category == .other, let utt = UTType(filenameExtension: ext) {
            if utt.conforms(to: .image) { return ClassificationResult(category: .images, subfolder: nil) }
            if utt.conforms(to: .movie) { return ClassificationResult(category: .videos, subfolder: nil) }
            if utt.conforms(to: .audio) { return ClassificationResult(category: .audio, subfolder: nil) }
            if utt.conforms(to: .pdf) || utt.conforms(to: .spreadsheet) || utt.conforms(to: .presentation) { return ClassificationResult(category: .documents, subfolder: nil) }
            if utt.conforms(to: .sourceCode) { return ClassificationResult(category: .code, subfolder: nil) }
            if utt.conforms(to: .diskImage) { return ClassificationResult(category: .installers, subfolder: nil) }
            if utt.conforms(to: .archive) { return ClassificationResult(category: .archives, subfolder: nil) }
        }

        // Priority 3: Fallback to existing category
        return ClassificationResult(category: entry.category, subfolder: nil)
    }
}
