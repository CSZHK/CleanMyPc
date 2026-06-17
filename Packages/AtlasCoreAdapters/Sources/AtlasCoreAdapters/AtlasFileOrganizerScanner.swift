import AtlasApplication
import AtlasDomain
import Foundation

public struct AtlasFileOrganizerScanner: AtlasFileOrganizerScanning, Sendable {
    public init() {}

    public func scanFolders(_ paths: [String], destinationBasePath: String = "~/Organized", recursive: Bool = false) async throws -> FileOrganizerScanResult {
        let fm = FileManager.default
        var entries: [FileOrganizerEntry] = []

        let enumeratorOptions: FileManager.DirectoryEnumerationOptions = recursive
            ? [.skipsHiddenFiles]
            : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]

        // Dedup input roots (preserve order) so the same folder selected twice
        // is only enumerated once. A per-file seen-set below additionally
        // neutralizes overlapping/nested roots in recursive mode (audit #1):
        // without it a file under both ~/Desktop and ~/Desktop/Projects was
        // emitted twice, doubling counts and causing a false "source no longer
        // exists" failure when execute moved the first copy.
        var seenRoots: Set<String> = []
        let orderedPaths = paths.filter { p in
            let key = (p as NSString).expandingTildeInPath
            guard !seenRoots.contains(key) else { return false }
            seenRoots.insert(key)
            return true
        }
        var seenFiles: Set<String> = []

        for folderPath in orderedPaths {
            let expandedPath = (folderPath as NSString).expandingTildeInPath
            let baseURL = URL(fileURLWithPath: expandedPath)
            guard let enumerator = fm.enumerator(
                at: baseURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: enumeratorOptions
            ) else { continue }

            for case let url as URL in enumerator {
                // Skip symlinks pointing outside the scanned directory
                let resolvedPath = url.resolvingSymlinksInPath().path
                guard resolvedPath.hasPrefix(expandedPath + "/") || resolvedPath == expandedPath else {
                    continue
                }

                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])

                if let isDir = resourceValues?.isDirectory, isDir {
                    continue
                }

                // Skip a file already emitted from an overlapping root.
                if !seenFiles.insert(resolvedPath).inserted {
                    continue
                }

                let fileName = url.lastPathComponent

                let bytes: Int64 = Int64(resourceValues?.fileSize ?? 0)

                let ext = url.pathExtension.lowercased()
                let category = Self.classifyExtension(ext)

                let fullPath = url.path
                let homeDir = fm.homeDirectoryForCurrentUser.path
                let displayPath: String
                // Separator boundary (audit #2): require a "/" after home so a
                // sibling like /Users/<user>_backup is not mis-tilde'd into an
                // invalid ~_backup/... path.
                if fullPath.hasPrefix(homeDir + "/") {
                    displayPath = "~" + String(fullPath.dropFirst(homeDir.count))
                } else {
                    displayPath = fullPath
                }

                let safeFileName = (fileName as NSString).lastPathComponent
                let basePath = destinationBasePath.hasSuffix("/") ? String(destinationBasePath.dropLast()) : destinationBasePath
                let proposedDestination = "\(basePath)/\(category.folderName)/\(safeFileName)"

                entries.append(FileOrganizerEntry(
                    path: displayPath,
                    fileName: fileName,
                    bytes: bytes,
                    category: category,
                    proposedDestination: proposedDestination
                ))
            }
        }

        let categoryCounts = Dictionary(grouping: entries, by: \.category).mapValues(\.count)
        let totalBytes = entries.map(\.bytes).reduce(0, +)

        return FileOrganizerScanResult(
            entries: entries,
            totalFiles: entries.count,
            totalBytes: totalBytes,
            categoryCounts: categoryCounts
        )
    }

    private static func classifyExtension(_ ext: String) -> FileOrganizerCategory {
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "svg", "heic", "heif", "ico", "raw", "cr2", "nef"]
        let videoExts: Set<String> = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpg", "mpeg", "3gp"]
        let audioExts: Set<String> = ["mp3", "wav", "aac", "flac", "ogg", "m4a", "wma", "aiff", "alac"]
        let docExts: Set<String> = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv", "odt", "ods", "odp", "pages", "numbers", "key"]
        let archiveExts: Set<String> = ["zip", "tar", "gz", "bz2", "xz", "rar", "7z", "tgz", "iso"]
        let codeExts: Set<String> = ["swift", "py", "js", "ts", "tsx", "jsx", "go", "rs", "java", "c", "cpp", "h", "hpp", "html", "css", "json", "xml", "yaml", "yml", "sh", "bash", "rb", "php", "sql", "md", "toml"]
        let installerExts: Set<String> = ["dmg", "pkg", "deb", "rpm", "msi"]

        if imageExts.contains(ext) { return .images }
        if videoExts.contains(ext) { return .videos }
        if audioExts.contains(ext) { return .audio }
        if docExts.contains(ext) { return .documents }
        if archiveExts.contains(ext) { return .archives }
        if codeExts.contains(ext) { return .code }
        if installerExts.contains(ext) { return .installers }
        return .other
    }
}
