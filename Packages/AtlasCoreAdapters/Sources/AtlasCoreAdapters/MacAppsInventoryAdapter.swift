import AtlasApplication
import AtlasDomain
import Foundation

public struct MacAppsInventoryAdapter: AtlasAppInventoryProviding {
    private let searchRoots: [URL]
    private let homeDirectoryURL: URL

    public init(
        searchRoots: [URL]? = nil,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.homeDirectoryURL = homeDirectoryURL
        self.searchRoots = searchRoots ?? [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    public func collectInstalledApps() async throws -> [AppFootprint] {
        var apps: [AppFootprint] = []
        var seenPaths = Set<String>()

        for root in searchRoots where FileManager.default.fileExists(atPath: root.path) {
            let entries = (try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for entry in entries where entry.pathExtension == "app" {
                let standardizedPath = entry.resolvingSymlinksInPath().path
                guard seenPaths.insert(standardizedPath).inserted else { continue }
                if let app = makeAppFootprint(for: entry) {
                    apps.append(app)
                }
            }
        }

        return apps.sorted { lhs, rhs in
            if lhs.bytes == rhs.bytes {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.bytes > rhs.bytes
        }
    }

    private func makeAppFootprint(for appURL: URL) -> AppFootprint? {
        guard let bundle = Bundle(url: appURL) else { return nil }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        let bundleIdentifier = bundle.bundleIdentifier ?? "unknown.\(name.replacingOccurrences(of: " ", with: "-").lowercased())"
        let bytes = allocatedSize(for: appURL)

        let evidenceSummary = computeEvidenceSummary(for: name, bundleIdentifier: bundleIdentifier)
        let leftoverItems = evidenceSummary.values.reduce(0, +)

        return AppFootprint(
            name: name,
            bundleIdentifier: bundleIdentifier,
            bundlePath: appURL.path,
            bytes: bytes,
            leftoverItems: leftoverItems,
            evidenceSummary: evidenceSummary
        )
    }

    // MARK: - Lightweight Evidence Summary (path-existence only, no size computation)

    private func computeEvidenceSummary(
        for appName: String,
        bundleIdentifier: String
    ) -> [AtlasAppEvidenceCategory: Int] {
        var summary: [AtlasAppEvidenceCategory: Int] = [:]
        let fm = FileManager.default

        // supportFiles
        let supportPaths = [
            homeDirectoryURL.appendingPathComponent("Library/Application Support/\(appName)").path,
            homeDirectoryURL.appendingPathComponent("Library/Application Support/\(bundleIdentifier)").path,
        ]
        summary[.supportFiles] = supportPaths.filter { fm.fileExists(atPath: $0) }.count

        // caches
        let cachePath = homeDirectoryURL.appendingPathComponent("Library/Caches/\(bundleIdentifier)").path
        summary[.caches] = fm.fileExists(atPath: cachePath) ? 1 : 0

        // preferences
        let prefsPath = homeDirectoryURL.appendingPathComponent("Library/Preferences/\(bundleIdentifier).plist").path
        summary[.preferences] = fm.fileExists(atPath: prefsPath) ? 1 : 0

        // logs — align with analyzer: check both appName and bundleIdentifier paths
        let logsPaths = [
            homeDirectoryURL.appendingPathComponent("Library/Logs/\(appName)").path,
            homeDirectoryURL.appendingPathComponent("Library/Logs/\(bundleIdentifier)").path,
        ]
        summary[.logs] = logsPaths.filter { fm.fileExists(atPath: $0) }.count

        // launchItems — align with analyzer: check both LaunchAgents and LaunchDaemons
        let launchPaths = [
            homeDirectoryURL.appendingPathComponent("Library/LaunchAgents/\(bundleIdentifier).plist").path,
            homeDirectoryURL.appendingPathComponent("Library/LaunchDaemons/\(bundleIdentifier).plist").path,
        ]
        summary[.launchItems] = launchPaths.filter { fm.fileExists(atPath: $0) }.count

        // savedState
        let savedStatePath = homeDirectoryURL.appendingPathComponent("Library/Saved Application State/\(bundleIdentifier).savedState").path
        summary[.savedState] = fm.fileExists(atPath: savedStatePath) ? 1 : 0

        // containers
        let containerPath = homeDirectoryURL.appendingPathComponent("Library/Containers/\(bundleIdentifier)").path
        summary[.containers] = fm.fileExists(atPath: containerPath) ? 1 : 0

        // groupContainers — scan for directories related to bundleIdentifier.
        // Use suffix/component matching to avoid overly broad matches (e.g., "com.apple" matching everything).
        // Guard: empty bundleIdentifier would cause hasSuffix("") → always true
        let groupContainersDir = homeDirectoryURL.appendingPathComponent("Library/Group Containers").path
        var groupCount = 0
        if !bundleIdentifier.isEmpty,
           let contents = try? fm.contentsOfDirectory(atPath: groupContainersDir) {
            for item in contents {
                let matchesSuffix = item.hasSuffix(bundleIdentifier)
                let containsAsComponent = item.contains(".\(bundleIdentifier).") || item.hasSuffix(".\(bundleIdentifier)")
                if matchesSuffix || containsAsComponent {
                    let fullPath = (groupContainersDir as NSString).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                        groupCount += 1
                    }
                }
            }
        }
        summary[.groupContainers] = groupCount

        // miscLeftovers — align with analyzer snapshotCandidateURLs (Cookies + WebKit + HTTPStorages)
        let miscLeftoversPaths = [
            homeDirectoryURL.appendingPathComponent("Library/Cookies/\(bundleIdentifier).binarycookies").path,
            homeDirectoryURL.appendingPathComponent("Library/WebKit/\(bundleIdentifier)").path,
            homeDirectoryURL.appendingPathComponent("Library/HTTPStorages/\(bundleIdentifier)").path,
        ]
        summary[.miscLeftovers] = miscLeftoversPaths.filter { fm.fileExists(atPath: $0) }.count

        return summary
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
                guard values?.isRegularFile == true else { continue }
                let size = values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0
                total += Int64(size)
            }
        }
        return total
    }
}
