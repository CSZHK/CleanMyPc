import AtlasApplication
import AtlasDomain
import AtlasProtocol
import Foundation

public enum AtlasXPCWorkerConstants {
    public static let serviceName = "com.atlasformac.app.worker"
}

@objc public protocol AtlasXPCWorkerServiceProtocol: NSObjectProtocol {
    func sendRequestData(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void)
}

public struct AtlasXPCRequestConfiguration: Sendable {
    public var timeout: TimeInterval
    public var retryCount: Int
    public var retryDelay: TimeInterval

    public init(timeout: TimeInterval = 30, retryCount: Int = 1, retryDelay: TimeInterval = 0.25) {
        self.timeout = timeout
        self.retryCount = retryCount
        self.retryDelay = retryDelay
    }
}

public enum AtlasXPCTransportError: LocalizedError, Sendable, Equatable {
    case encodingFailed(String)
    case decodingFailed(String)
    case invalidResponse
    case connectionUnavailable(String)
    case timedOut(TimeInterval)

    public var errorDescription: String? {
        switch self {
        case let .encodingFailed(reason):
            return AtlasL10n.string("xpc.error.encodingFailed", reason)
        case let .decodingFailed(reason):
            return AtlasL10n.string("xpc.error.decodingFailed", reason)
        case .invalidResponse:
            return AtlasL10n.string("xpc.error.invalidResponse")
        case let .connectionUnavailable(reason):
            return AtlasL10n.string("xpc.error.connectionUnavailable", reason)
        case let .timedOut(seconds):
            return AtlasL10n.string("xpc.error.timedOut", seconds)
        }
    }
}

public final class AtlasXPCWorkerServiceHost: NSObject, AtlasXPCWorkerServiceProtocol {
    private let worker: AtlasScaffoldWorkerService
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(worker: AtlasScaffoldWorkerService = AtlasScaffoldWorkerService()) {
        self.worker = worker
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        super.init()
    }

    public func sendRequestData(_ requestData: Data, withReply reply: @escaping (Data?, NSError?) -> Void) {
        Task {
            do {
                let request = try decoder.decode(AtlasRequestEnvelope.self, from: requestData)
                let result = try await worker.submit(request)
                let payload = try encoder.encode(result)
                reply(payload, nil)
            } catch {
                reply(nil, error as NSError)
            }
        }
    }
}

public final class AtlasXPCListenerDelegate: NSObject, NSXPCListenerDelegate {
    private let host: AtlasXPCWorkerServiceHost

    public init(host: AtlasXPCWorkerServiceHost = AtlasXPCWorkerServiceHost()) {
        self.host = host
        super.init()
    }

    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: AtlasXPCWorkerServiceProtocol.self)
        newConnection.exportedObject = host
        newConnection.resume()
        return true
    }
}

public typealias AtlasXPCDataRequestExecutor = @Sendable (Data) async throws -> Data

private final class AtlasXPCConnectionBox: @unchecked Sendable {
    let connection: NSXPCConnection

    init(_ connection: NSXPCConnection) {
        self.connection = connection
    }
}

public actor AtlasXPCWorkerClient: AtlasWorkerServing {
    private let serviceName: String
    private let requestConfiguration: AtlasXPCRequestConfiguration
    private let requestExecutor: AtlasXPCDataRequestExecutor?
    private var connection: NSXPCConnection?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        serviceName: String = AtlasXPCWorkerConstants.serviceName,
        requestConfiguration: AtlasXPCRequestConfiguration = AtlasXPCRequestConfiguration(),
        requestExecutor: AtlasXPCDataRequestExecutor? = nil
    ) {
        self.serviceName = serviceName
        self.requestConfiguration = requestConfiguration
        self.requestExecutor = requestExecutor
    }

    public func submit(_ request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult {
        let requestData: Data

        do {
            requestData = try encoder.encode(request)
        } catch {
            throw AtlasXPCTransportError.encodingFailed(error.localizedDescription)
        }

        let responseData = try await submitRequestDataWithRetry(requestData)

        do {
            return try decoder.decode(AtlasWorkerCommandResult.self, from: responseData)
        } catch {
            throw AtlasXPCTransportError.decodingFailed(error.localizedDescription)
        }
    }

    private func submitRequestDataWithRetry(_ requestData: Data) async throws -> Data {
        var attempt = 0
        var lastError: Error = AtlasXPCTransportError.invalidResponse

        while attempt <= requestConfiguration.retryCount {
            do {
                return try await submitRequestDataOnce(requestData)
            } catch {
                lastError = error

                guard attempt < requestConfiguration.retryCount,
                      shouldRetry(after: error) else {
                    throw error
                }

                resetConnection()

                if requestConfiguration.retryDelay > 0 {
                    let delay = UInt64(requestConfiguration.retryDelay * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delay)
                }

                attempt += 1
            }
        }

        throw lastError
    }

    private func submitRequestDataOnce(_ requestData: Data) async throws -> Data {
        if let requestExecutor {
            return try await withTimeout {
                try await requestExecutor(requestData)
            }
        }

        let connectionBox = AtlasXPCConnectionBox(ensureConnection())
        return try await withTimeout {
            try await self.sendRequestData(requestData, over: connectionBox.connection)
        }
    }

    private func withTimeout(operation: @escaping @Sendable () async throws -> Data) async throws -> Data {
        guard requestConfiguration.timeout > 0 else {
            return try await operation()
        }

        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                let timeoutNanoseconds = UInt64(self.requestConfiguration.timeout * 1_000_000_000)
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw AtlasXPCTransportError.timedOut(self.requestConfiguration.timeout)
            }

            let result = try await group.next() ?? { throw AtlasXPCTransportError.invalidResponse }()
            group.cancelAll()
            return result
        }
    }

    private func sendRequestData(_ requestData: Data, over connection: NSXPCConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(throwing: AtlasXPCTransportError.connectionUnavailable(error.localizedDescription))
            }) as? AtlasXPCWorkerServiceProtocol else {
                continuation.resume(throwing: AtlasXPCTransportError.connectionUnavailable("Remote object proxy is unavailable."))
                return
            }

            proxy.sendRequestData(requestData) { responseData, responseError in
                if let responseError {
                    continuation.resume(throwing: AtlasXPCTransportError.connectionUnavailable(responseError.localizedDescription))
                    return
                }

                guard let responseData else {
                    continuation.resume(throwing: AtlasXPCTransportError.invalidResponse)
                    return
                }

                continuation.resume(returning: responseData)
            }
        }
    }

    private func shouldRetry(after error: Error) -> Bool {
        guard let transportError = error as? AtlasXPCTransportError else {
            return false
        }

        switch transportError {
        case .connectionUnavailable, .invalidResponse, .timedOut:
            return true
        case .encodingFailed, .decodingFailed:
            return false
        }
    }

    private func ensureConnection() -> NSXPCConnection {
        if let connection {
            return connection
        }

        let connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: AtlasXPCWorkerServiceProtocol.self)
        connection.invalidationHandler = { [weak connection] in
            Task { self.clearConnection(ifMatching: connection) }
        }
        connection.interruptionHandler = { [weak connection] in
            Task { self.clearConnection(ifMatching: connection) }
        }
        connection.resume()
        self.connection = connection
        return connection
    }

    private func clearConnection(ifMatching disconnectedConnection: NSXPCConnection?) {
        guard let disconnectedConnection else {
            connection = nil
            return
        }

        if connection === disconnectedConnection {
            connection = nil
        }
    }

    private func resetConnection() {
        connection?.invalidate()
        connection = nil
    }
}

public actor AtlasPreferredWorkerService: AtlasWorkerServing {
    private let xpcClient: AtlasXPCWorkerClient
    private let fallbackWorker: AtlasScaffoldWorkerService
    private let allowFallback: Bool

    public init(
        serviceName: String = AtlasXPCWorkerConstants.serviceName,
        requestConfiguration: AtlasXPCRequestConfiguration = AtlasXPCRequestConfiguration(),
        requestExecutor: AtlasXPCDataRequestExecutor? = nil,
        fallbackWorker: AtlasScaffoldWorkerService = AtlasScaffoldWorkerService(),
        allowFallback: Bool = ProcessInfo.processInfo.environment["ATLAS_ALLOW_SCAFFOLD_FALLBACK"] == "1"
    ) {
        self.xpcClient = AtlasXPCWorkerClient(
            serviceName: serviceName,
            requestConfiguration: requestConfiguration,
            requestExecutor: requestExecutor
        )
        self.fallbackWorker = fallbackWorker
        self.allowFallback = allowFallback
    }

    public func submit(_ request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult {
        do {
            let result = try await xpcClient.submit(request)
            if shouldFallback(from: result) {
                guard allowFallback else {
                    return result
                }
                return try await fallbackWorker.submit(request)
            }
            return result
        } catch {
            guard allowFallback else {
                throw error
            }
            return try await fallbackWorker.submit(request)
        }
    }

    private func shouldFallback(from result: AtlasWorkerCommandResult) -> Bool {
        guard case let .rejected(code, _) = result.response.response else {
            return false
        }

        switch code {
        case .executionUnavailable, .helperUnavailable:
            return true
        default:
            return false
        }
    }
}
