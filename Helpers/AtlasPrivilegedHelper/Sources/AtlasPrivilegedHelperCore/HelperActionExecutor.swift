import AtlasProtocol
import Foundation
import Darwin

public struct AtlasPrivilegedHelperActionExecutor {
    private let fileManager: FileManager
    private let allowedRoots: [String]
    private let currentUserID: UInt32
    private let currentGroupID: UInt32
    private let homeDirectoryURL: URL

    public init(
        fileManager: FileManager = .default,
        allowedRoots: [String]? = nil,
        currentUserID: UInt32 = getuid(),
        currentGroupID: UInt32 = getgid(),
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.currentUserID = currentUserID
        self.currentGroupID = currentGroupID
        self.homeDirectoryURL = homeDirectoryURL
        self.allowedRoots = allowedRoots ?? [
            URL(fileURLWithPath: "/Applications", isDirectory: true).path,
            homeDirectoryURL.appendingPathComponent("Applications", isDirectory: true).path,
            homeDirectoryURL.appendingPathComponent("Library/LaunchAgents", isDirectory: true).path,
            URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true).path,
            URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true).path,
        ]
    }

    public func perform(_ action: AtlasHelperAction) throws -> AtlasHelperActionResult {
        let targetURL = URL(fileURLWithPath: action.targetPath).resolvingSymlinksInPath()
        let destinationURL = action.destinationPath.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath() }
        try validate(action: action, targetURL: targetURL, destinationURL: destinationURL)

        switch action.kind {
        case .trashItems:
            var trashedURL: NSURL?
            try fileManager.trashItem(at: targetURL, resultingItemURL: &trashedURL)
            return AtlasHelperActionResult(
                action: action,
                success: true,
                message: "Moved item to Trash.",
                resolvedPath: (trashedURL as URL?)?.path
            )
        case .restoreItem:
            guard let destinationURL else {
                throw HelperValidationError.invalidRestoreDestination(nil)
            }
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: targetURL, to: destinationURL)
            return AtlasHelperActionResult(
                action: action,
                success: true,
                message: "Restored item from Trash.",
                resolvedPath: destinationURL.path
            )
        case .removeLaunchService:
            try fileManager.removeItem(at: targetURL)
            return AtlasHelperActionResult(
                action: action,
                success: true,
                message: "Removed launch service file.",
                resolvedPath: targetURL.path
            )
        case .repairOwnership:
            return try repairOwnership(for: action, targetURL: targetURL)
        }
    }

    private func repairOwnership(for action: AtlasHelperAction, targetURL: URL) throws -> AtlasHelperActionResult {
        let targets = try ownershipTargets(for: targetURL)
        var updatedCount = 0
        var failedPaths: [String] = []

        for url in targets {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let ownerID = attributes[.ownerAccountID] as? NSNumber
                let groupID = attributes[.groupOwnerAccountID] as? NSNumber
                let alreadyOwned = ownerID?.uint32Value == currentUserID && groupID?.uint32Value == currentGroupID

                if !alreadyOwned {
                    try fileManager.setAttributes([
                        .ownerAccountID: NSNumber(value: currentUserID),
                        .groupOwnerAccountID: NSNumber(value: currentGroupID),
                    ], ofItemAtPath: url.path)
                    updatedCount += 1
                }
            } catch {
                failedPaths.append(url.path)
            }
        }

        if !failedPaths.isEmpty {
            throw HelperValidationError.repairOwnershipFailed(failedPaths)
        }

        let message: String
        if updatedCount == 0 {
            message = "Ownership already matched the current user."
        } else {
            message = "Repaired ownership for \(updatedCount) item\(updatedCount == 1 ? "" : "s")."
        }

        return AtlasHelperActionResult(
            action: action,
            success: true,
            message: message,
            resolvedPath: targetURL.path
        )
    }

    private func ownershipTargets(for rootURL: URL) throws -> [URL] {
        var urls: [URL] = [rootURL]

        let values = try rootURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            return urls
        }

        if let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                let resourceValues = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
                if resourceValues?.isSymbolicLink == true {
                    continue
                }
                urls.append(url)
            }
        }

        return urls
    }

    private func validate(action: AtlasHelperAction, targetURL: URL, destinationURL: URL?) throws {
        guard fileManager.fileExists(atPath: targetURL.path) else {
            throw HelperValidationError.pathNotFound(targetURL.path)
        }

        let isAllowed = { (url: URL) in
            allowedRoots.contains { root in
                url.path == root || url.path.hasPrefix(root + "/")
            }
        }

        switch action.kind {
        case .trashItems, .removeLaunchService, .repairOwnership:
            guard isAllowed(targetURL) else {
                throw HelperValidationError.pathNotAllowed(targetURL.path)
            }
        case .restoreItem:
            let trashRoot = homeDirectoryURL.appendingPathComponent(".Trash", isDirectory: true).path
            guard targetURL.path == trashRoot || targetURL.path.hasPrefix(trashRoot + "/") else {
                throw HelperValidationError.pathNotAllowed(targetURL.path)
            }
            guard let destinationURL else {
                throw HelperValidationError.invalidRestoreDestination(nil)
            }
            guard isAllowed(destinationURL) else {
                throw HelperValidationError.invalidRestoreDestination(destinationURL.path)
            }
            if fileManager.fileExists(atPath: destinationURL.path) {
                throw HelperValidationError.restoreDestinationExists(destinationURL.path)
            }
        }

        if action.kind == .removeLaunchService {
            guard targetURL.pathExtension == "plist" else {
                throw HelperValidationError.invalidLaunchServicePath(targetURL.path)
            }
        }
    }
}

enum HelperValidationError: LocalizedError {
    case pathNotFound(String)
    case pathNotAllowed(String)
    case invalidLaunchServicePath(String)
    case invalidRestoreDestination(String?)
    case restoreDestinationExists(String)
    case repairOwnershipFailed([String])

    var errorDescription: String? {
        switch self {
        case let .pathNotFound(path):
            return "Target path not found: \(path)"
        case let .pathNotAllowed(path):
            return "Target path is outside the helper allowlist: \(path)"
        case let .invalidLaunchServicePath(path):
            return "Launch service removal requires a plist path: \(path)"
        case let .invalidRestoreDestination(path):
            return "Restore destination is invalid: \(path ?? "<missing>")"
        case let .restoreDestinationExists(path):
            return "Restore destination already exists: \(path)"
        case let .repairOwnershipFailed(paths):
            return "Failed to repair ownership for: \(paths.joined(separator: ", "))"
        }
    }
}
