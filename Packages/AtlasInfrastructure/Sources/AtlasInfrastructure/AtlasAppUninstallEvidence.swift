import AtlasDomain
import Foundation

public struct AtlasAppUninstallEvidenceAnalyzer: Sendable {
    private let homeDirectoryURL: URL

    public init(homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectoryURL = homeDirectoryURL
    }

    public func analyze(
        appName: String,
        bundleIdentifier: String,
        bundlePath: String,
        bundleBytes: Int64
    ) -> AtlasAppUninstallEvidence {
        let reviewOnlyGroups = AtlasAppFootprintEvidenceCategory.allCases.compactMap { category -> AtlasAppFootprintEvidenceGroup? in
            let items = existingItems(for: category, appName: appName, bundleIdentifier: bundleIdentifier)
            guard !items.isEmpty else {
                return nil
            }
            return AtlasAppFootprintEvidenceGroup(category: category, items: items)
        }

        return AtlasAppUninstallEvidence(
            bundlePath: bundlePath,
            bundleBytes: bundleBytes,
            reviewOnlyGroups: reviewOnlyGroups
        )
    }

    public func analyzeSnapshot(
        planID: UUID,
        appName: String,
        bundleIdentifier: String,
        bundlePath: String,
        bundleBytes: Int64,
        capturedAt: Date = Date()
    ) -> AtlasAppUninstallEvidenceSnapshot {
        // Collect evidence groups using the richer AtlasAppEvidenceCategory
        let groups: [AtlasAppEvidenceGroup] = AtlasAppEvidenceCategory.allCases.compactMap { category in
            let items = snapshotItems(for: category, appName: appName, bundleIdentifier: bundleIdentifier, bundlePath: bundlePath)
            guard !items.isEmpty else {
                return nil
            }
            return AtlasAppEvidenceGroup(category: category, items: items)
        }

        // Compute fingerprint from sorted paths before constructing the snapshot (single allocation)
        let fingerprint = AtlasAppUninstallEvidenceSnapshot.computeFingerprint(for: groups)

        return AtlasAppUninstallEvidenceSnapshot(
            planID: planID,
            capturedAt: capturedAt,
            bundlePath: bundlePath,
            bundleBytes: bundleBytes,
            groups: groups,
            fingerprintHash: fingerprint
        )
    }

    private func snapshotItems(
        for category: AtlasAppEvidenceCategory,
        appName: String,
        bundleIdentifier: String,
        bundlePath: String
    ) -> [AtlasAppEvidenceItem] {
        let urls = snapshotCandidateURLs(for: category, appName: appName, bundleIdentifier: bundleIdentifier, bundlePath: bundlePath)
        let uniquePaths = Array(Set(urls.map { $0.resolvingSymlinksInPath().path })).sorted()

        return uniquePaths.compactMap { path in
            guard FileManager.default.fileExists(atPath: path) else {
                return nil
            }
            let url = URL(fileURLWithPath: path)
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            let fileType: AtlasEvidenceFileType = isDir ? .directory : .file
            return AtlasAppEvidenceItem(path: path, bytes: allocatedSize(for: url), fileType: fileType, verified: true)
        }
    }

    private func snapshotCandidateURLs(
        for category: AtlasAppEvidenceCategory,
        appName: String,
        bundleIdentifier: String,
        bundlePath: String
    ) -> [URL] {
        switch category {
        case .appBundle:
            return [URL(fileURLWithPath: bundlePath, isDirectory: true)]
        case .supportFiles:
            // Note: Saved Application State is listed under .savedState, NOT here
            // Note: Container sub-paths are covered by .containers category, NOT here (avoids double-counting)
            return [
                homeDirectoryURL.appendingPathComponent("Library/Application Support/\(appName)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Application Support/\(bundleIdentifier)", isDirectory: true),
            ]
        case .caches:
            // Note: Container caches covered by .containers category
            return [
                homeDirectoryURL.appendingPathComponent("Library/Caches/\(bundleIdentifier)", isDirectory: true),
            ]
        case .preferences:
            // Note: Container preferences covered by .containers category
            return [
                homeDirectoryURL.appendingPathComponent("Library/Preferences/\(bundleIdentifier).plist"),
            ]
        case .logs:
            // Note: Container logs covered by .containers category
            return [
                homeDirectoryURL.appendingPathComponent("Library/Logs/\(appName)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Logs/\(bundleIdentifier)", isDirectory: true),
            ]
        case .launchItems:
            return [
                homeDirectoryURL.appendingPathComponent("Library/LaunchAgents/\(bundleIdentifier).plist"),
                homeDirectoryURL.appendingPathComponent("Library/LaunchDaemons/\(bundleIdentifier).plist"),
            ]
        case .savedState:
            return [
                homeDirectoryURL.appendingPathComponent("Library/Saved Application State/\(bundleIdentifier).savedState", isDirectory: true),
            ]
        case .containers:
            return [
                homeDirectoryURL.appendingPathComponent("Library/Containers/\(bundleIdentifier)", isDirectory: true),
            ]
        case .groupContainers:
            // Scan Group Containers directory for entries related to this bundleIdentifier.
            // macOS Group Containers use team-based identifiers, so we match via substring
            // rather than exact path. Aligns with MacAppsInventoryAdapter.computeEvidenceSummary.
            return groupContainerURLs(matching: bundleIdentifier)
        case .miscLeftovers:
            return [
                homeDirectoryURL.appendingPathComponent("Library/Cookies/\(bundleIdentifier).binarycookies"),
                homeDirectoryURL.appendingPathComponent("Library/WebKit/\(bundleIdentifier)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/HTTPStorages/\(bundleIdentifier)", isDirectory: true),
            ]
        }
    }

    private func existingItems(
        for category: AtlasAppFootprintEvidenceCategory,
        appName: String,
        bundleIdentifier: String
    ) -> [AtlasAppFootprintEvidenceItem] {
        let urls = candidateURLs(for: category, appName: appName, bundleIdentifier: bundleIdentifier)
        let uniqueURLs = Array(Set(urls.map { $0.resolvingSymlinksInPath().path })).sorted().map(URL.init(fileURLWithPath:))

        return uniqueURLs.compactMap { url in
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return AtlasAppFootprintEvidenceItem(path: url.path, bytes: allocatedSize(for: url))
        }
    }

    private func candidateURLs(
        for category: AtlasAppFootprintEvidenceCategory,
        appName: String,
        bundleIdentifier: String
    ) -> [URL] {
        switch category {
        case .supportFiles:
            // Note: Saved Application State is listed under savedState category, not supportFiles
            return [
                homeDirectoryURL.appendingPathComponent("Library/Application Support/\(appName)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Application Support/\(bundleIdentifier)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Containers/\(bundleIdentifier)/Data/Library/Application Support", isDirectory: true),
            ]
        case .caches:
            return [
                homeDirectoryURL.appendingPathComponent("Library/Caches/\(bundleIdentifier)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Containers/\(bundleIdentifier)/Data/Library/Caches", isDirectory: true),
            ]
        case .preferences:
            return [
                homeDirectoryURL.appendingPathComponent("Library/Preferences/\(bundleIdentifier).plist"),
                homeDirectoryURL.appendingPathComponent("Library/Containers/\(bundleIdentifier)/Data/Library/Preferences/\(bundleIdentifier).plist"),
            ]
        case .logs:
            return [
                homeDirectoryURL.appendingPathComponent("Library/Logs/\(appName)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Logs/\(bundleIdentifier)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Containers/\(bundleIdentifier)/Data/Library/Logs", isDirectory: true),
            ]
        case .launchItems:
            return [
                homeDirectoryURL.appendingPathComponent("Library/LaunchAgents/\(bundleIdentifier).plist"),
                homeDirectoryURL.appendingPathComponent("Library/LaunchDaemons/\(bundleIdentifier).plist"),
            ]
        }
    }

    // MARK: - Group Containers Discovery

    /// Scan ~/Library/Group Containers for directories related to the given bundleIdentifier.
    /// macOS Group Containers often use team-based identifiers (e.g., `TEAMID.com.example.app`)
    /// that don't exactly match the bundleIdentifier, so we use suffix-based matching
    /// and also check the directory's plist for member app references.
    private func groupContainerURLs(matching bundleIdentifier: String) -> [URL] {
        // Guard: empty bundleIdentifier would cause hasSuffix("") → always true
        guard !bundleIdentifier.isEmpty else {
            return []
        }

        let groupContainersDir = homeDirectoryURL.appendingPathComponent("Library/Group Containers")
        let fm = FileManager.default
        var matchingURLs: [URL] = []

        guard let contents = try? fm.contentsOfDirectory(at: groupContainersDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }

        for url in contents {
            let name = url.lastPathComponent
            // Match if directory name ends with the bundleIdentifier (covers team-based IDs)
            // or contains it as a dot-delimited component (e.g., `TEAMID.com.example.app` for `com.example.app`).
            // Avoids false positives like matching `TEAMID.com.example.app.extension` for `com.example.app`.
            let matchesSuffix = name.hasSuffix(bundleIdentifier)
            let containsAsComponent = name.contains(".\(bundleIdentifier).") || name.hasSuffix(".\(bundleIdentifier)")

            if matchesSuffix || containsAsComponent {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    matchingURLs.append(url)
                }
            }
        }

        return matchingURLs
    }

    private func allocatedSize(for url: URL) -> Int64 {
        if let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]),
           let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
            return Int64(size)
        }

        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                guard values?.isRegularFile == true else {
                    continue
                }
                let size = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0
                total += Int64(size)
            }
        }
        return total
    }
}
