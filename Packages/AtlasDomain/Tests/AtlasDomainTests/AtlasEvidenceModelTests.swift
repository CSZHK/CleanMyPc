import XCTest
@testable import AtlasDomain

final class AtlasEvidenceModelTests: XCTestCase {

    // MARK: - AtlasAppEvidenceCategory safety levels

    func testAppEvidenceCategory_safetyLevels() {
        // appBundle, caches, logs, savedState → safe
        XCTAssertEqual(AtlasAppEvidenceCategory.appBundle.safetyLevel, .safe)
        XCTAssertEqual(AtlasAppEvidenceCategory.caches.safetyLevel, .safe)
        XCTAssertEqual(AtlasAppEvidenceCategory.logs.safetyLevel, .safe)
        XCTAssertEqual(AtlasAppEvidenceCategory.savedState.safetyLevel, .safe)

        // supportFiles, preferences, containers, miscLeftovers → conditional
        XCTAssertEqual(AtlasAppEvidenceCategory.supportFiles.safetyLevel, .conditional)
        XCTAssertEqual(AtlasAppEvidenceCategory.preferences.safetyLevel, .conditional)
        XCTAssertEqual(AtlasAppEvidenceCategory.containers.safetyLevel, .conditional)
        XCTAssertEqual(AtlasAppEvidenceCategory.miscLeftovers.safetyLevel, .conditional)

        // launchItems, groupContainers → protected
        XCTAssertEqual(AtlasAppEvidenceCategory.launchItems.safetyLevel, .protected)
        XCTAssertEqual(AtlasAppEvidenceCategory.groupContainers.safetyLevel, .protected)
    }

    // MARK: - AtlasAppEvidenceGroup default safety level

    func testAppEvidenceGroup_defaultSafetyLevel() {
        // When safetyLevel is nil, group should inherit from category
        let group = AtlasAppEvidenceGroup(category: .caches, items: [])
        XCTAssertEqual(group.safetyLevel, .safe, "caches should default to safe")

        let protectedGroup = AtlasAppEvidenceGroup(category: .launchItems, items: [])
        XCTAssertEqual(protectedGroup.safetyLevel, .protected, "launchItems should default to protected")

        let conditionalGroup = AtlasAppEvidenceGroup(category: .preferences, items: [])
        XCTAssertEqual(conditionalGroup.safetyLevel, .conditional, "preferences should default to conditional")

        // Explicit override should work
        let overridden = AtlasAppEvidenceGroup(category: .caches, safetyLevel: .protected, items: [])
        XCTAssertEqual(overridden.safetyLevel, .protected, "explicit override should take precedence")
    }

    // MARK: - AtlasAppEvidenceItem defaults

    func testAppEvidenceItem_defaults() {
        let item = AtlasAppEvidenceItem(path: "/tmp/test.bin", bytes: 42)
        XCTAssertEqual(item.path, "/tmp/test.bin")
        XCTAssertEqual(item.bytes, 42)
        XCTAssertFalse(item.verified, "verified should default to false")
        XCTAssertEqual(item.fileType, .file, "fileType should default to .file")
    }

    // MARK: - AtlasAppEvidenceGroup computed properties

    func testAppEvidenceGroup_totalBytesAndItemCount() {
        let items = [
            AtlasAppEvidenceItem(path: "/a", bytes: 100),
            AtlasAppEvidenceItem(path: "/b", bytes: 200),
            AtlasAppEvidenceItem(path: "/c", bytes: 300),
        ]
        let group = AtlasAppEvidenceGroup(category: .caches, items: items)
        XCTAssertEqual(group.totalBytes, 600)
        XCTAssertEqual(group.itemCount, 3)
    }

    // MARK: - RecoveryPayload v2 round-trip

    func testRecoveryPayload_v2_roundTrip() throws {
        let app = AppFootprint(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            name: "TestApp",
            bundleIdentifier: "com.test.app",
            bundlePath: "/Applications/TestApp.app",
            bytes: 2048,
            leftoverItems: 3
        )
        let snapshot = AtlasAppUninstallEvidenceSnapshot(
            planID: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            bundlePath: "/Applications/TestApp.app",
            bundleBytes: 2048,
            groups: [
                AtlasAppEvidenceGroup(
                    category: .caches,
                    items: [AtlasAppEvidenceItem(path: "/Users/test/Library/Caches/com.test.app", bytes: 500, fileType: .directory, verified: true)]
                ),
                AtlasAppEvidenceGroup(
                    category: .preferences,
                    items: [AtlasAppEvidenceItem(path: "/Users/test/Library/Preferences/com.test.app.plist", bytes: 100, fileType: .plist, verified: true)]
                ),
            ],
            fingerprintHash: "abcdef0123456789"
        )
        let evidence = AtlasAppUninstallEvidence(
            bundlePath: "/Applications/TestApp.app",
            bundleBytes: 2048,
            reviewOnlyGroups: [
                AtlasAppFootprintEvidenceGroup(
                    category: .caches,
                    items: [AtlasAppFootprintEvidenceItem(path: "/Users/test/Library/Caches/com.test.app", bytes: 500)]
                ),
            ]
        )
        let payload = AtlasAppRecoveryPayload(
            schemaVersion: 1,
            app: app,
            uninstallEvidence: evidence,
            uninstallSnapshot: snapshot
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AtlasAppRecoveryPayload.self, from: data)

        XCTAssertEqual(decoded.app.name, "TestApp")
        XCTAssertEqual(decoded.app.bundleIdentifier, "com.test.app")
        XCTAssertEqual(decoded.uninstallEvidence.bundlePath, "/Applications/TestApp.app")
        XCTAssertEqual(decoded.uninstallEvidence.reviewOnlyGroups.count, 1)
        XCTAssertNotNil(decoded.uninstallSnapshot, "snapshot should survive round-trip")
        XCTAssertEqual(decoded.uninstallSnapshot?.fingerprintHash, "abcdef0123456789")
        XCTAssertEqual(decoded.uninstallSnapshot?.groups.count, 2)
        XCTAssertEqual(decoded.uninstallSnapshot?.groups.first?.category, .caches)
        XCTAssertEqual(decoded.uninstallSnapshot?.groups.first?.items.first?.fileType, .directory)
        XCTAssertTrue(decoded.uninstallSnapshot?.groups.first?.items.first?.verified ?? false)
    }

    // MARK: - RecoveryPayload v1 migration (no snapshot)

    func testRecoveryPayload_v1_migration() throws {
        let json = """
        {
            "schemaVersion": 1,
            "app": {
                "id": "20000000-0000-0000-0000-000000000010",
                "name": "V1App",
                "bundleIdentifier": "com.test.v1app",
                "bundlePath": "/Applications/V1App.app",
                "bytes": 1024,
                "leftoverItems": 2
            },
            "uninstallEvidence": {
                "bundlePath": "/Applications/V1App.app",
                "bundleBytes": 1024,
                "reviewOnlyGroups": [
                    {
                        "category": "caches",
                        "items": [
                            {"path": "/Users/test/Library/Caches/com.test.v1app", "bytes": 256}
                        ]
                    }
                ]
            }
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(AtlasAppRecoveryPayload.self, from: data)

        XCTAssertEqual(payload.schemaVersion, 1)
        XCTAssertEqual(payload.app.name, "V1App")
        XCTAssertEqual(payload.uninstallEvidence.reviewOnlyGroups.count, 1)
        XCTAssertNil(payload.uninstallSnapshot, "v1 payload should have nil uninstallSnapshot")
    }

    func testRecoveryPayload_v1_synthesizesFromOld() throws {
        // Verify the legacy RecoveryPayload path that synthesizes AtlasAppRecoveryPayload
        // from bare AppFootprint JSON (no uninstallEvidence field at all)
        let json = """
        {
            "app": {
                "id": "20000000-0000-0000-0000-000000000020",
                "name": "LegacyApp",
                "bundleIdentifier": "com.test.legacy",
                "bundlePath": "/Applications/LegacyApp.app",
                "bytes": 512,
                "leftoverItems": 1
            }
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(RecoveryPayload.self, from: data)

        guard case let .app(appPayload) = payload else {
            return XCTFail("Expected app recovery payload")
        }

        XCTAssertEqual(appPayload.app.name, "LegacyApp")
        XCTAssertEqual(appPayload.uninstallEvidence.bundlePath, "/Applications/LegacyApp.app")
        XCTAssertEqual(appPayload.uninstallEvidence.bundleBytes, 512)
        XCTAssertEqual(appPayload.uninstallEvidence.reviewOnlyGroups.count, 0)
        XCTAssertNil(appPayload.uninstallSnapshot)
    }

    // MARK: - ActionPlan optional evidence fields

    func testActionPlan_optionalEvidenceFields() {
        let plan = ActionPlan(
            title: "Test plan",
            items: [],
            estimatedBytes: 0
        )
        XCTAssertNil(plan.evidencePlanID, "evidencePlanID should default to nil")
        XCTAssertNil(plan.estimatedReviewOnlyBytes, "estimatedReviewOnlyBytes should default to nil")
        XCTAssertNil(plan.evidenceGroups, "evidenceGroups should default to nil")

        let planWithEvidence = ActionPlan(
            title: "Test plan with evidence",
            items: [],
            estimatedBytes: 1000,
            evidencePlanID: UUID(),
            estimatedReviewOnlyBytes: 500,
            evidenceGroups: [
                AtlasAppEvidenceGroup(category: .caches, items: [AtlasAppEvidenceItem(path: "/tmp/cache", bytes: 500)])
            ]
        )
        XCTAssertNotNil(planWithEvidence.evidencePlanID)
        XCTAssertEqual(planWithEvidence.estimatedReviewOnlyBytes, 500)
        XCTAssertEqual(planWithEvidence.evidenceGroups?.count, 1)
    }

    // MARK: - Schema migration test (v1 to v2)

    func testAppRecoveryPayload_schemaMigration_v1_to_v2() throws {
        // Hardcoded v1 JSON without uninstallSnapshot field
        let v1JSON = """
        {
            "schemaVersion": 1,
            "app": {
                "id": "20000000-0000-0000-0000-000000000099",
                "name": "MigrationTestApp",
                "bundleIdentifier": "com.test.migration",
                "bundlePath": "/Applications/MigrationTestApp.app",
                "bytes": 4096,
                "leftoverItems": 5
            },
            "uninstallEvidence": {
                "bundlePath": "/Applications/MigrationTestApp.app",
                "bundleBytes": 4096,
                "reviewOnlyGroups": [
                    {
                        "category": "supportFiles",
                        "items": [
                            {"path": "/Users/test/Library/Application Support/MigrationTestApp", "bytes": 1024}
                        ]
                    },
                    {
                        "category": "caches",
                        "items": [
                            {"path": "/Users/test/Library/Caches/com.test.migration", "bytes": 512}
                        ]
                    }
                ]
            }
        }
        """
        let data = Data(v1JSON.utf8)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(AtlasAppRecoveryPayload.self, from: data)

        // Verify app fields decode correctly
        XCTAssertEqual(payload.schemaVersion, 1)
        XCTAssertEqual(payload.app.name, "MigrationTestApp")
        XCTAssertEqual(payload.app.bundleIdentifier, "com.test.migration")
        XCTAssertEqual(payload.app.bundlePath, "/Applications/MigrationTestApp.app")
        XCTAssertEqual(payload.app.bytes, 4096)
        XCTAssertEqual(payload.app.leftoverItems, 5)

        // Verify uninstallEvidence fields decode correctly
        XCTAssertEqual(payload.uninstallEvidence.bundlePath, "/Applications/MigrationTestApp.app")
        XCTAssertEqual(payload.uninstallEvidence.bundleBytes, 4096)
        XCTAssertEqual(payload.uninstallEvidence.reviewOnlyGroups.count, 2)
        XCTAssertEqual(payload.uninstallEvidence.reviewOnlyGroups.first?.category, .supportFiles)
        XCTAssertEqual(payload.uninstallEvidence.reviewOnlyGroups.last?.category, .caches)

        // Verify uninstallSnapshot is nil (v1 has no snapshot)
        XCTAssertNil(payload.uninstallSnapshot, "v1 JSON should decode with nil uninstallSnapshot")

        // Verify divergence defaults to false for legacy payloads
        XCTAssertFalse(payload.evidenceDivergenceAtExecution,
                       "v1 JSON without evidenceDivergenceAtExecution should default to false")
    }

    // MARK: - evidenceDivergenceAtExecution field

    func testAppRecoveryPayload_divergenceField_roundTrip() throws {
        let app = AppFootprint(
            id: UUID(), name: "DivergenceTest", bundleIdentifier: "com.test.divergence",
            bundlePath: "/Applications/DivergenceTest.app", bytes: 2048, leftoverItems: 0
        )
        let evidence = AtlasAppUninstallEvidence(
            bundlePath: "/Applications/DivergenceTest.app", bundleBytes: 2048, reviewOnlyGroups: []
        )
        let payload = AtlasAppRecoveryPayload(
            app: app, uninstallEvidence: evidence, evidenceDivergenceAtExecution: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AtlasAppRecoveryPayload.self, from: data)

        XCTAssertTrue(decoded.evidenceDivergenceAtExecution,
                      "Divergence flag should survive round-trip")
    }

    func testAppRecoveryPayload_divergenceField_defaultsFalse() {
        let app = AppFootprint(
            id: UUID(), name: "DefaultTest", bundleIdentifier: "com.test.default",
            bundlePath: "/Applications/DefaultTest.app", bytes: 1024, leftoverItems: 0
        )
        let evidence = AtlasAppUninstallEvidence(
            bundlePath: "/Applications/DefaultTest.app", bundleBytes: 1024, reviewOnlyGroups: []
        )
        let payload = AtlasAppRecoveryPayload(app: app, uninstallEvidence: evidence)
        XCTAssertFalse(payload.evidenceDivergenceAtExecution,
                       "Default should be false")
    }

    func testAppRecoveryPayload_divergenceField_legacyJSON_defaultsFalse() throws {
        // JSON without evidenceDivergenceAtExecution field (legacy)
        let json = """
        {
            "schemaVersion": 1,
            "app": {
                "id": "20000000-0000-0000-0000-000000000050",
                "name": "LegacyDivTest",
                "bundleIdentifier": "com.test.legacydiv",
                "bundlePath": "/Applications/LegacyDivTest.app",
                "bytes": 1024,
                "leftoverItems": 0
            },
            "uninstallEvidence": {
                "bundlePath": "/Applications/LegacyDivTest.app",
                "bundleBytes": 1024,
                "reviewOnlyGroups": []
            }
        }
        """
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        let payload = try decoder.decode(AtlasAppRecoveryPayload.self, from: data)
        XCTAssertFalse(payload.evidenceDivergenceAtExecution,
                       "Legacy JSON without field should default to false")
    }
}
