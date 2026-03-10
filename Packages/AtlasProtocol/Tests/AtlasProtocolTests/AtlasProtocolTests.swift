import XCTest
@testable import AtlasProtocol
import AtlasDomain

final class AtlasProtocolTests: XCTestCase {
    func testRequestEnvelopeRoundTripsJSON() throws {
        let taskID = UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID()
        let envelope = AtlasRequestEnvelope(command: .startScan(taskID: taskID))
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(AtlasRequestEnvelope.self, from: data)

        XCTAssertEqual(decoded.id, envelope.id)
        XCTAssertEqual(decoded.command, envelope.command)
    }

    func testSettingsRequestRoundTripsJSON() throws {
        let envelope = AtlasRequestEnvelope(command: .settingsSet(AtlasScaffoldFixtures.settings))
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(AtlasRequestEnvelope.self, from: data)

        XCTAssertEqual(decoded.command, envelope.command)
    }

    func testAppsResponseRoundTripsJSON() throws {
        let envelope = AtlasResponseEnvelope(
            requestID: UUID(),
            response: .apps(AtlasScaffoldFixtures.apps)
        )
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(AtlasResponseEnvelope.self, from: data)

        XCTAssertEqual(decoded.response, envelope.response)
    }
}
