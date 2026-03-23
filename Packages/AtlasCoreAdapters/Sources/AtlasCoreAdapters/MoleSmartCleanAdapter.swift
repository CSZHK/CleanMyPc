import AtlasApplication
import AtlasDomain
import Foundation

public struct MoleSmartCleanAdapter: AtlasSmartCleanScanProviding {
    private let cleanScriptURL: URL

    public init(cleanScriptURL: URL? = nil) {
        self.cleanScriptURL = cleanScriptURL ?? Self.defaultCleanScriptURL
    }

    public func collectSmartCleanScan() async throws -> AtlasSmartCleanScanResult {
        let stateDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("atlas-smart-clean-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)

        let exportFileURL = stateDirectory.appendingPathComponent("clean-list.txt")
        let detailedExportFileURL = stateDirectory.appendingPathComponent("clean-list-detailed.tsv")
        let output = try runDryRun(stateDirectory: stateDirectory, exportFileURL: exportFileURL, detailedExportFileURL: detailedExportFileURL)
        let findings = Self.parseDetailedFindings(from: detailedExportFileURL).isEmpty
            ? Self.parseFindings(from: output)
            : Self.parseDetailedFindings(from: detailedExportFileURL)
        let summary = findings.isEmpty
            ? "Smart Clean dry run found no reclaimable items from the upstream clean workflow."
            : "Smart Clean dry run found \(findings.count) reclaimable item\(findings.count == 1 ? "" : "s")."
        return AtlasSmartCleanScanResult(findings: findings, summary: summary)
    }

    private func runDryRun(stateDirectory: URL, exportFileURL: URL, detailedExportFileURL: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [cleanScriptURL.path, "--dry-run"]

        var environment = ProcessInfo.processInfo.environment
        environment["MO_NO_OPLOG"] = "1"
        environment["MOLE_STATE_DIR"] = stateDirectory.path
        environment["MOLE_EXPORT_LIST_FILE"] = exportFileURL.path
        environment["MOLE_DETAILED_EXPORT_FILE"] = detailedExportFileURL.path
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? "unknown error"
            throw MoleSmartCleanAdapterError.commandFailed(message)
        }

        return output
    }

    static func parseDetailedFindings(from exportFileURL: URL) -> [Finding] {
        guard let content = try? String(contentsOf: exportFileURL), !content.isEmpty else {
            return []
        }

        struct Entry {
            let section: String
            let path: String
            let sizeKB: Int64
        }

        let entries: [Entry] = content
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine in
                let parts = rawLine.split(separator: "\t", omittingEmptySubsequences: false)
                guard parts.count == 3 else { return nil }
                guard let sizeKB = Int64(parts[2]) else { return nil }
                return Entry(section: String(parts[0]), path: String(parts[1]), sizeKB: sizeKB)
            }

        guard !entries.isEmpty else {
            return []
        }

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        var parentCounts: [String: Int] = [:]
        for entry in entries {
            let parentPath = URL(fileURLWithPath: entry.path).deletingLastPathComponent().path
            let key = entry.section + "\u{001F}" + parentPath
            parentCounts[key, default: 0] += 1
        }

        struct Group {
            var section: String
            var displayPath: String
            var bytes: Int64
            var targetPaths: [String]
            var childCount: Int
            var order: Int
        }

        var groups: [String: Group] = [:]
        var order = 0

        for entry in entries {
            let parentPath = URL(fileURLWithPath: entry.path).deletingLastPathComponent().path
            let parentKey = entry.section + "\u{001F}" + parentPath
            let shouldGroupByParent = parentCounts[parentKey, default: 0] > 1 && parentPath != homePath
            let displayPath = shouldGroupByParent ? parentPath : entry.path
            let groupKey = entry.section + "\u{001F}" + displayPath
            if groups[groupKey] == nil {
                groups[groupKey] = Group(
                    section: entry.section,
                    displayPath: displayPath,
                    bytes: 0,
                    targetPaths: [],
                    childCount: 0,
                    order: order
                )
                order += 1
            }
            groups[groupKey]!.bytes += entry.sizeKB * 1024
            groups[groupKey]!.targetPaths.append(entry.path)
            groups[groupKey]!.childCount += 1
        }

        return groups.values
            .sorted { lhs, rhs in
                if lhs.bytes == rhs.bytes { return lhs.order < rhs.order }
                return lhs.bytes > rhs.bytes
            }
            .map { group in
                Finding(
                    title: makeDetailedTitle(for: group.displayPath, section: group.section),
                    detail: makeDetailedDetail(for: group.displayPath, section: group.section, childCount: group.childCount),
                    bytes: group.bytes,
                    risk: riskLevel(for: group.section, title: group.displayPath),
                    category: group.section,
                    targetPaths: group.targetPaths
                )
            }
    }

    private static func makeDetailedTitle(for displayPath: String, section: String) -> String {
        let url = URL(fileURLWithPath: displayPath)
        let path = displayPath.lowercased()
        let last = url.lastPathComponent
        let parent = url.deletingLastPathComponent().lastPathComponent
        let containerIdentifier = appContainerIdentifier(from: url)

        if path.contains("/google/chrome/default") { return "Chrome cache" }
        if path.contains("component_crx_cache") { return "Chrome component cache" }
        if path.contains("googleupdater") { return "Google Updater cache" }
        if path.contains("deriveddata") { return "Xcode DerivedData" }
        if path.contains("/library/pnpm/store") { return "pnpm store" }
        if path.contains("/library/containers/"), let containerIdentifier {
            if path.contains("/data/library/caches") {
                return "\(containerIdentifier) container cache"
            }
            if path.contains("/data/tmp") || path.contains("/data/library/tmp") {
                return "\(containerIdentifier) container temp files"
            }
            if path.contains("/data/library/logs") || path.contains("/data/logs") {
                return "\(containerIdentifier) container logs"
            }
        }
        if path.contains("/__pycache__") || last == "__pycache__" { return "Python bytecode cache" }
        if path.contains("/.next/cache") { return "Next.js build cache" }
        if path.contains("/.npm/") || path.hasSuffix("/.npm") || path.contains("_cacache") { return "npm cache" }
        if path.contains("/.npm_cache/_npx") { return "npm npx cache" }
        if path.contains("/.npm_cache/_logs") { return "npm logs" }
        if path.contains("/.oh-my-zsh/cache") { return "Oh My Zsh cache" }
        if last == "Caches" { return section == "User essentials" ? "User app caches" : "Caches" }
        if last == "Logs" { return "App logs" }
        if last == "Attachments" { return "Messages attachment previews" }
        if last == FileManager.default.homeDirectoryForCurrentUser.lastPathComponent { return section }
        if last == "Default" && !parent.isEmpty { return parent }
        return last.replacingOccurrences(of: "_", with: " ")
    }

    private static func makeDetailedDetail(for displayPath: String, section: String, childCount: Int) -> String {
        if childCount > 1 {
            return "\(displayPath) • \(childCount) items from \(section)"
        }
        return "\(displayPath) • \(section)"
    }

    static func parseFindings(from output: String) -> [Finding] {
        let cleanedOutput = stripANSI(from: output)
        let lines = cleanedOutput
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var currentSection = "Smart Clean"
        var pendingRuntimeVolumeIndex: Int?
        var findings: [Finding] = []
        var seenKeys = Set<String>()

        for line in lines where !line.isEmpty {
            if line.hasPrefix("➤ ") {
                currentSection = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                pendingRuntimeVolumeIndex = nil
                continue
            }

            if line.hasPrefix("→ ") {
                if let finding = makeFinding(from: line, section: currentSection) {
                    let key = "\(finding.category)|\(finding.title)|\(finding.bytes)"
                    if seenKeys.insert(key).inserted {
                        findings.append(finding)
                        if finding.title == "Xcode runtime volumes" {
                            pendingRuntimeVolumeIndex = findings.indices.last
                        } else {
                            pendingRuntimeVolumeIndex = nil
                        }
                    }
                }
                continue
            }

            if line.hasPrefix("• Runtime volumes total:"), let index = pendingRuntimeVolumeIndex,
               let bytes = parseRuntimeVolumeUnusedBytes(from: line) {
                findings[index].bytes = bytes
                findings[index].detail = line
                pendingRuntimeVolumeIndex = nil
            }
        }

        return findings.sorted { lhs, rhs in
            if lhs.bytes == rhs.bytes { return lhs.title < rhs.title }
            return lhs.bytes > rhs.bytes
        }
    }

    private static func makeFinding(from line: String, section: String) -> Finding? {
        let content = line.replacingOccurrences(of: "→ ", with: "")
        let bytes = parseSize(from: content) ?? 0
        let title = normalizeTitle(parseTitle(from: content))
        guard !title.isEmpty else { return nil }
        let detail = parseDetail(from: content, fallbackSection: section)
        let risk = riskLevel(for: section, title: title)
        return Finding(title: title, detail: detail, bytes: bytes, risk: risk, category: section)
    }


    private static func normalizeTitle(_ title: String) -> String {
        if title.hasPrefix("Would remove ") {
            return String(title.dropFirst("Would remove ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return title
    }

    private static func parseTitle(from content: String) -> String {
        let separators = [" · ", ","]
        for separator in separators {
            if let range = content.range(of: separator) {
                return String(content[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDetail(from content: String, fallbackSection: String) -> String {
        if let range = content.range(of: " · ") {
            return String(content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = content.range(of: ",") {
            return String(content[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Detected from the upstream \(fallbackSection) dry-run preview."
    }

    private static func riskLevel(for section: String, title: String) -> RiskLevel {
        let normalized = "\(section) \(title)".lowercased()
        if normalized.contains("launch agent") || normalized.contains("system service") || normalized.contains("orphan") {
            return .advanced
        }
        if normalized.contains("application") || normalized.contains("large file") || normalized.contains("device backup") || normalized.contains("runtime") || normalized.contains("simulator") {
            return .review
        }
        return .safe
    }

    private static func parseRuntimeVolumeUnusedBytes(from line: String) -> Int64? {
        guard let match = line.range(of: #"unused\s+([0-9.]+(?:B|KB|MB|GB|TB))"#, options: .regularExpression) else {
            return nil
        }
        let token = String(line[match]).replacingOccurrences(of: "unused", with: "").trimmingCharacters(in: .whitespaces)
        return parseByteCount(token)
    }

    private static func parseSize(from content: String) -> Int64? {
        if let range = content.range(of: #"([0-9.]+(?:B|KB|MB|GB|TB))\s+dry"#, options: .regularExpression) {
            let token = String(content[range]).replacingOccurrences(of: "dry", with: "").trimmingCharacters(in: .whitespaces)
            return parseByteCount(token)
        }
        if let range = content.range(of: #"would clean\s+([0-9.]+(?:B|KB|MB|GB|TB))"#, options: .regularExpression) {
            let token = String(content[range]).replacingOccurrences(of: "would clean", with: "").trimmingCharacters(in: .whitespaces)
            return parseByteCount(token)
        }
        if let range = content.range(of: #",\s*([0-9.]+(?:B|KB|MB|GB|TB))(?:\s+dry)?$"#, options: .regularExpression) {
            let token = String(content[range]).replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "dry", with: "").trimmingCharacters(in: .whitespaces)
            return parseByteCount(token)
        }
        if let range = content.range(of: #"\(([0-9.]+(?:B|KB|MB|GB|TB))\)"#, options: .regularExpression) {
            let token = String(content[range]).trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            return parseByteCount(token)
        }
        return nil
    }

    private static func parseByteCount(_ token: String) -> Int64? {
        let cleaned = token.uppercased().replacingOccurrences(of: " ", with: "")
        let units: [(String, Double)] = [("TB", 1024 * 1024 * 1024 * 1024), ("GB", 1024 * 1024 * 1024), ("MB", 1024 * 1024), ("KB", 1024), ("B", 1)]
        for (suffix, multiplier) in units {
            if cleaned.hasSuffix(suffix) {
                let valueString = String(cleaned.dropLast(suffix.count))
                guard let value = Double(valueString) else { return nil }
                return Int64(value * multiplier)
            }
        }
        return nil
    }

    private static func stripANSI(from text: String) -> String {
        let pattern = String("\u{001B}") + "\\[[0-9;]*m"
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func appContainerIdentifier(from url: URL) -> String? {
        let components = url.pathComponents
        guard let containersIndex = components.firstIndex(of: "Containers"),
              containersIndex + 1 < components.count else {
            return nil
        }
        return components[containersIndex + 1]
    }

    private static var defaultCleanScriptURL: URL {
        MoleRuntimeLocator.url(for: "bin/clean.sh")
    }
}

private enum MoleSmartCleanAdapterError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(message):
            return "Mole Smart Clean adapter failed: \(message)"
        }
    }
}
