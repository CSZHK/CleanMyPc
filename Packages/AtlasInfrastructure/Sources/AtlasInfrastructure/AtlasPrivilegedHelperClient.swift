import AtlasProtocol
import Foundation

public protocol AtlasPrivilegedActionExecuting: Sendable {
    func perform(_ action: AtlasHelperAction) async throws -> AtlasHelperActionResult
}

public enum AtlasHelperClientError: LocalizedError, Sendable {
    case helperUnavailable(attemptedPaths: [String])
    case encodingFailed(String)
    case decodingFailed(String)
    case invocationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .helperUnavailable(attemptedPaths):
            let joined = attemptedPaths.isEmpty ? "<no candidate paths recorded>" : attemptedPaths.joined(separator: ", ")
            return "Bundled privileged helper is unavailable. Attempted: \(joined)"
        case let .encodingFailed(reason):
            return "Failed to encode helper action: \(reason)"
        case let .decodingFailed(reason):
            return "Failed to decode helper response: \(reason)"
        case let .invocationFailed(reason):
            return "Privileged helper failed: \(reason)"
        }
    }
}

public actor AtlasPrivilegedHelperClient: AtlasPrivilegedActionExecuting {
    private let explicitExecutableURL: URL?
    private let timeoutSeconds: TimeInterval
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(executableURL: URL? = nil, timeoutSeconds: TimeInterval = 30) {
        self.explicitExecutableURL = executableURL
        self.timeoutSeconds = timeoutSeconds
    }

    public func perform(_ action: AtlasHelperAction) async throws -> AtlasHelperActionResult {
        let resolution = resolveExecutableURL()
        guard let executableURL = resolution.url else {
            throw AtlasHelperClientError.helperUnavailable(attemptedPaths: resolution.attemptedPaths)
        }

        let requestData: Data
        do {
            requestData = try encoder.encode(action)
        } catch {
            throw AtlasHelperClientError.encodingFailed(error.localizedDescription)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["--action-json"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        stdinPipe.fileHandleForWriting.write(requestData)
        stdinPipe.fileHandleForWriting.closeFile()

        let timedOut = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                // True if the process terminates before timeout
                await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                    process.terminationHandler = { _ in
                        continuation.resume(returning: true)
                    }
                }
            }
            group.addTask {
                // False if timeout fires first
                try? await Task.sleep(nanoseconds: UInt64(self.timeoutSeconds * 1_000_000_000))
                return false
            }
            let first = await group.next()!
            group.cancelAll()
            return !first
        }

        if timedOut {
            process.terminate()
            throw AtlasHelperClientError.invocationFailed("Helper process timed out after \(Int(timeoutSeconds))s")
        }

        let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "unknown helper error"
            throw AtlasHelperClientError.invocationFailed(errorMessage)
        }

        do {
            return try decoder.decode(AtlasHelperActionResult.self, from: outputData)
        } catch {
            let raw = String(data: outputData, encoding: .utf8) ?? "<empty>"
            throw AtlasHelperClientError.decodingFailed("\(error.localizedDescription). Output: \(raw)")
        }
    }

    private func resolveExecutableURL() -> (url: URL?, attemptedPaths: [String]) {
        var attemptedPaths: [String] = []

        if let explicitExecutableURL {
            attemptedPaths.append(explicitExecutableURL.path)
            if FileManager.default.isExecutableFile(atPath: explicitExecutableURL.path) {
                return (explicitExecutableURL, attemptedPaths)
            }
        }

        if let environmentPath = ProcessInfo.processInfo.environment["ATLAS_HELPER_EXECUTABLE"] {
            attemptedPaths.append(environmentPath)
            if FileManager.default.isExecutableFile(atPath: environmentPath) {
                return (URL(fileURLWithPath: environmentPath), attemptedPaths)
            }
        }

        let bundleCandidates = bundledHelperCandidates()
        attemptedPaths.append(contentsOf: bundleCandidates.map(\.path))
        for candidate in bundleCandidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return (candidate, attemptedPaths)
        }

        let devCandidates: [URL] = {
            guard let repoRoot = ProcessInfo.processInfo.environment["ATLAS_REPO_ROOT"] else {
                return []
            }
            let root = URL(fileURLWithPath: repoRoot, isDirectory: true)
            return [
                root.appendingPathComponent("Helpers/.build/debug/AtlasPrivilegedHelper"),
                root.appendingPathComponent("Helpers/.build/release/AtlasPrivilegedHelper"),
            ]
        }()
        attemptedPaths.append(contentsOf: devCandidates.map(\.path))

        for candidate in devCandidates where FileManager.default.isExecutableFile(atPath: candidate.path) {
            return (candidate, attemptedPaths)
        }

        return (nil, attemptedPaths)
    }

    private func bundledHelperCandidates() -> [URL] {
        let mainBundleURL = Bundle.main.bundleURL
        let appHelper = mainBundleURL.appendingPathComponent("Contents/Helpers/AtlasPrivilegedHelper")
        let xpcHelper = mainBundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Helpers/AtlasPrivilegedHelper")
        return [appHelper, xpcHelper]
    }
}
