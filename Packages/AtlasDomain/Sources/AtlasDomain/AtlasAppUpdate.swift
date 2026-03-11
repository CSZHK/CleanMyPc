import Foundation

public struct AtlasAppUpdate: Sendable, Equatable {
    public let currentVersion: String
    public let latestVersion: String
    public let releaseURL: URL?
    public let releaseNotes: String?
    public let isUpdateAvailable: Bool

    public init(
        currentVersion: String,
        latestVersion: String,
        releaseURL: URL?,
        releaseNotes: String?,
        isUpdateAvailable: Bool
    ) {
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.releaseURL = releaseURL
        self.releaseNotes = releaseNotes
        self.isUpdateAvailable = isUpdateAvailable
    }
}

public enum AtlasVersionComparator {
    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = parse(lhs)
        let rhsParts = parse(rhs)

        let maxCount = max(lhsParts.count, rhsParts.count)
        for index in 0..<maxCount {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }

    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(current, candidate) == .orderedAscending
    }

    private static func parse(_ version: String) -> [Int] {
        var cleaned = version
        if cleaned.hasPrefix("v") || cleaned.hasPrefix("V") {
            cleaned = String(cleaned.dropFirst())
        }
        return cleaned
            .split(separator: ".")
            .compactMap { Int($0) }
    }
}
