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

    func testPreviewResponseRoundTripsStructuredPlanTargets() throws {
        let plan = ActionPlan(
            title: "Review 1 selected finding",
            items: [
                ActionItem(
                    id: UUID(uuidString: "10000000-0000-0000-0000-000000000099") ?? UUID(),
                    title: "Move container cache to Trash",
                    detail: "Sandboxed cache path",
                    kind: .removeCache,
                    recoverable: true,
                    targetPaths: ["/Users/test/Library/Containers/com.example.sample/Data/Library/Caches/cache.db"]
                )
            ],
            estimatedBytes: 1_024
        )
        let envelope = AtlasResponseEnvelope(
            requestID: UUID(),
            response: .preview(plan)
        )
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(AtlasResponseEnvelope.self, from: data)

        XCTAssertEqual(decoded.response, envelope.response)
    }

    func testPreviewResponseRoundTripsReviewOnlyEvidencePaths() throws {
        let plan = ActionPlan(
            title: "Uninstall Example",
            items: [
                ActionItem(
                    title: "Review support files (2)",
                    detail: "Found 12 KB across 2 item(s).",
                    kind: .inspectPermission,
                    recoverable: false,
                    evidencePaths: [
                        "/Users/test/Library/Application Support/Example",
                        "/Users/test/Library/Saved Application State/com.example.savedState"
                    ]
                )
            ],
            estimatedBytes: 1_024
        )
        let envelope = AtlasResponseEnvelope(
            requestID: UUID(),
            response: .preview(plan)
        )
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(AtlasResponseEnvelope.self, from: data)

        XCTAssertEqual(decoded.response, envelope.response)
    }
}
