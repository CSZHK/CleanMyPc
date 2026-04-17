import AtlasApplication
import AtlasDomain
import Foundation

public enum AtlasWorkspaceRepositoryError: LocalizedError, Sendable, Equatable {
    case readFailed(String)
    case decodeFailed(String)
    case createDirectoryFailed(String)
    case encodeFailed(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .readFailed(reason):
            return "Failed to read workspace state: \(reason)"
        case let .decodeFailed(reason):
            return "Failed to decode workspace state: \(reason)"
        case let .createDirectoryFailed(reason):
            return "Failed to prepare workspace state directory: \(reason)"
        case let .encodeFailed(reason):
            return "Failed to encode workspace state: \(reason)"
        case let .writeFailed(reason):
            return "Failed to write workspace state: \(reason)"
        }
    }
}

public struct AtlasWorkspaceRepository: Sendable {
    private let stateFileURL: URL
    private let nowProvider: @Sendable () -> Date

    public init(
        stateFileURL: URL? = nil,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.stateFileURL = stateFileURL ?? Self.defaultStateFileURL
        self.nowProvider = nowProvider
    }

    public func loadState() -> AtlasWorkspaceState {
        let decoder = JSONDecoder()

        if FileManager.default.fileExists(atPath: stateFileURL.path) {
            do {
                let data = try Data(contentsOf: stateFileURL)
                let decodedResult = try decodePersistedState(from: data, using: decoder)
                let decoded = decodedResult.state
                let normalized = normalizedState(decoded)
                if decodedResult.usedLegacyShape || normalized != decoded {
                    _ = try? saveState(normalized)
                }
                return normalized
            } catch let repositoryError as AtlasWorkspaceRepositoryError {
                reportFailure(repositoryError, operation: "load existing workspace state from \(stateFileURL.path)")
            } catch {
                reportFailure(
                    AtlasWorkspaceRepositoryError.decodeFailed(error.localizedDescription),
                    operation: "decode workspace state from \(stateFileURL.path)"
                )
            }
        }

        let state = AtlasScaffoldWorkspace.state()
        do {
            _ = try saveState(state)
        } catch {
            reportFailure(error, operation: "seed initial workspace state at \(stateFileURL.path)")
        }
        return state
    }

    @discardableResult
    public func saveState(_ state: AtlasWorkspaceState) throws -> AtlasWorkspaceState {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let normalizedState = normalizedState(state)

        do {
            try FileManager.default.createDirectory(
                at: stateFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            throw AtlasWorkspaceRepositoryError.createDirectoryFailed(error.localizedDescription)
        }

        let data: Data
        do {
            data = try encoder.encode(
                AtlasPersistedWorkspaceState(
                    savedAt: nowProvider(),
                    state: normalizedState
                )
            )
        } catch {
            throw AtlasWorkspaceRepositoryError.encodeFailed(error.localizedDescription)
        }

        do {
            try data.write(to: stateFileURL, options: .atomic)
        } catch {
            throw AtlasWorkspaceRepositoryError.writeFailed(error.localizedDescription)
        }

        return normalizedState
    }

    public func loadScaffoldSnapshot() -> AtlasWorkspaceSnapshot {
        loadState().snapshot
    }

    public func loadCurrentPlan() -> ActionPlan {
        loadState().currentPlan
    }

    public func loadSettings() -> AtlasSettings {
        loadState().settings
    }

    private func reportFailure(_ error: Error, operation: String) {
        let message = "[AtlasWorkspaceRepository] Failed to \(operation): \(error.localizedDescription)\n"
        if let data = message.data(using: .utf8) {
            try? FileHandle.standardError.write(contentsOf: data)
        }
    }

    private func normalizedState(_ state: AtlasWorkspaceState) -> AtlasWorkspaceState {
        var normalized = state
        let now = nowProvider()
        normalized.snapshot.recoveryItems.removeAll { item in
            item.isExpired(asOf: now)
        }
        return normalized
    }

    private func decodePersistedState(from data: Data, using decoder: JSONDecoder) throws -> (state: AtlasWorkspaceState, usedLegacyShape: Bool) {
        if let persisted = try? decoder.decode(AtlasPersistedWorkspaceState.self, from: data) {
            return (persisted.workspaceState, false)
        }

        return (try decoder.decode(AtlasWorkspaceState.self, from: data), true)
    }

    private static var defaultStateFileURL: URL {
        if let explicit = ProcessInfo.processInfo.environment["ATLAS_STATE_FILE"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit)
        }

        let baseDirectory: URL
        if let explicitDirectory = ProcessInfo.processInfo.environment["ATLAS_STATE_DIR"], !explicitDirectory.isEmpty {
            baseDirectory = URL(fileURLWithPath: explicitDirectory, isDirectory: true)
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
            baseDirectory = applicationSupport.appendingPathComponent("AtlasForMac", isDirectory: true)
        }

        return baseDirectory.appendingPathComponent("workspace-state.json")
    }
}
