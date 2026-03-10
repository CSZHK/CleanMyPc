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
        let leftoverItems = leftoverPaths(for: name, bundleIdentifier: bundleIdentifier).filter {
            FileManager.default.fileExists(atPath: $0.path)
        }.count

        return AppFootprint(
            name: name,
            bundleIdentifier: bundleIdentifier,
            bundlePath: appURL.path,
            bytes: bytes,
            leftoverItems: leftoverItems
        )
    }

    private func leftoverPaths(for appName: String, bundleIdentifier: String) -> [URL] {
        [
            homeDirectoryURL.appendingPathComponent("Library/Application Support/\(appName)", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Application Support/\(bundleIdentifier)", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Caches/\(bundleIdentifier)", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Containers/\(bundleIdentifier)", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Preferences/\(bundleIdentifier).plist"),
            homeDirectoryURL.appendingPathComponent("Library/Saved Application State/\(bundleIdentifier).savedState", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/LaunchAgents/\(bundleIdentifier).plist"),
        ]
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
