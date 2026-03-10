import XCTest
@testable import AtlasInfrastructure
import AtlasApplication
import AtlasDomain
import AtlasProtocol

final class AtlasXPCTransportTests: XCTestCase {
    func testXPCClientRetriesRecoverableFailureAndSucceeds() async throws {
        let attemptCounter = AttemptCounter()
        let request = AtlasRequestEnvelope(command: .healthSnapshot)
        let expected = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(
                requestID: request.id,
                response: .health(AtlasScaffoldWorkspace.state().snapshot.healthSnapshot ?? AtlasScaffoldWorkspace.snapshot().healthSnapshot!)
            ),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: nil
        )
        let responseData = try JSONEncoder().encode(expected)

        let client = AtlasXPCWorkerClient(
            requestConfiguration: AtlasXPCRequestConfiguration(timeout: 1, retryCount: 1, retryDelay: 0),
            requestExecutor: { _ in
                let attempt = await attemptCounter.next()
                if attempt == 1 {
                    throw AtlasXPCTransportError.connectionUnavailable("simulated drop")
                }
                return responseData
            }
        )

        let result = try await client.submit(request)

        let attempts = await attemptCounter.current()
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(result.snapshot.findings.count, expected.snapshot.findings.count)
    }

    func testPreferredWorkerServiceDoesNotFallbackByDefault() async {
        let service = AtlasPreferredWorkerService(
            requestConfiguration: AtlasXPCRequestConfiguration(timeout: 0.01, retryCount: 0, retryDelay: 0),
            fallbackWorker: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true),
            allowFallback: false
        )

        do {
            _ = try await service.submit(AtlasRequestEnvelope(command: .healthSnapshot))
            XCTFail("Expected XPC failure without fallback")
        } catch let error as AtlasXPCTransportError {
            switch error {
            case .connectionUnavailable, .timedOut:
                XCTAssertFalse(error.localizedDescription.isEmpty)
            default:
                XCTFail("Expected connectionUnavailable or timedOut, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }


    func testPreferredWorkerServiceFallsBackWhenXPCWorkerRejectsExecutionUnavailable() async throws {
        let request = AtlasRequestEnvelope(command: .healthSnapshot)
        let rejected = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(
                requestID: request.id,
                response: .rejected(code: .executionUnavailable, reason: "simulated packaged worker failure")
            ),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: nil
        )
        let responseData = try JSONEncoder().encode(rejected)
        let service = AtlasPreferredWorkerService(
            requestConfiguration: AtlasXPCRequestConfiguration(timeout: 1, retryCount: 0, retryDelay: 0),
            requestExecutor: { _ in responseData },
            fallbackWorker: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true),
            allowFallback: true
        )

        let result = try await service.submit(request)

        XCTAssertEqual(result.response.requestID, request.id)
        guard case .health = result.response.response else {
            return XCTFail("Expected fallback health response, got \(result.response.response)")
        }
    }

    func testXPCClientTimesOutSlowRequest() async {
        let client = AtlasXPCWorkerClient(
            requestConfiguration: AtlasXPCRequestConfiguration(timeout: 0.05, retryCount: 0, retryDelay: 0),
            requestExecutor: { _ in
                try await Task.sleep(nanoseconds: 300_000_000)
                return Data()
            }
        )

        do {
            _ = try await client.submit(AtlasRequestEnvelope(command: .healthSnapshot))
            XCTFail("Expected timeout")
        } catch let error as AtlasXPCTransportError {
            guard case let .timedOut(timeout) = error else {
                return XCTFail("Expected timedOut error, got \(error)")
            }
            XCTAssertEqual(timeout, 0.05, accuracy: 0.001)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private actor AttemptCounter {
    private var attempts = 0

    func next() -> Int {
        attempts += 1
        return attempts
    }

    func current() -> Int {
        attempts
    }
}
