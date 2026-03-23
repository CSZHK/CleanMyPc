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
            return [
                homeDirectoryURL.appendingPathComponent("Library/Application Support/\(appName)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Application Support/\(bundleIdentifier)", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Containers/\(bundleIdentifier)/Data/Library/Application Support", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Saved Application State/\(bundleIdentifier).savedState", isDirectory: true),
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
