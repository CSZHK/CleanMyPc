import AtlasDomain
import Foundation

/// Validates file paths received from external sources (Worker scan results, XPC messages)
/// to prevent path traversal and ensure paths are within safe boundaries.
public enum AtlasPathValidator {
    /// Maximum allowed path length to prevent buffer-based attacks
    public static let maximumPathLength = 1024

    /// Validates that a raw path string is safe for file operations.
    /// - Parameters:
    ///   - rawPath: The path string to validate (from Worker/scan results)
    ///   - homeDirectoryURL: The user's home directory URL
    /// - Returns: The validated, resolved URL
    /// - Throws: `AtlasPathValidationError` if validation fails
    public static func validate(
        _ rawPath: String,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> URL {
        // 1. Length check
        guard rawPath.utf8.count <= maximumPathLength else {
            throw AtlasPathValidationError.pathTooLong(rawPath)
        }

        // 2. Must be absolute
        guard rawPath.hasPrefix("/") else {
            throw AtlasPathValidationError.relativePath(rawPath)
        }

        // 3. No null bytes
        guard !rawPath.contains("\0") else {
            throw AtlasPathValidationError.nullByte(rawPath)
        }

        // 4. Resolve symlinks and standardize
        let resolvedURL = URL(fileURLWithPath: rawPath).resolvingSymlinksInPath()
        let resolvedPath = resolvedURL.path

        // 5. No path traversal components after resolution
        let components = resolvedURL.pathComponents
        guard !components.contains("..") else {
            throw AtlasPathValidationError.pathTraversal(resolvedPath)
        }

        // 6. Must be within a recognized safe root (home dir or system paths that requireHelper covers)
        let home = homeDirectoryURL.path
        let safeRoots = [
            home,
            "/Applications",
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
        ]
        let isInSafeRoot = safeRoots.contains { root in
            resolvedPath == root || resolvedPath.hasPrefix(root + "/")
        }
        guard isInSafeRoot else {
            throw AtlasPathValidationError.outsideSafeRoots(resolvedPath)
        }

        return resolvedURL
    }

    /// Validates an array of target paths, returning validated URLs.
    /// - Returns: Array of successfully validated URLs
    /// - Throws: The first validation error encountered
    public static func validateAll(
        _ rawPaths: [String],
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> [URL] {
        try rawPaths.map { try validate($0, homeDirectoryURL: homeDirectoryURL) }
    }
}

/// Errors that can occur during path validation
public enum AtlasPathValidationError: LocalizedError, Sendable {
    case pathTooLong(String)
    case relativePath(String)
    case nullByte(String)
    case pathTraversal(String)
    case outsideSafeRoots(String)

    public var errorDescription: String? {
        switch self {
        case let .pathTooLong(path):
            return "Path exceeds maximum allowed length: \(path.prefix(50))..."
        case let .relativePath(path):
            return "Relative paths are not allowed: \(path)"
        case let .nullByte(path):
            return "Path contains null byte: \(path.prefix(50))..."
        case let .pathTraversal(path):
            return "Path contains traversal components after resolution: \(path)"
        case let .outsideSafeRoots(path):
            return "Path is outside recognized safe directories: \(path)"
        }
    }
}
