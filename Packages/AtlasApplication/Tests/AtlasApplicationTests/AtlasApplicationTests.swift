import XCTest
@testable import AtlasApplication
import AtlasDomain
import AtlasProtocol

final class AtlasApplicationTests: XCTestCase {
    func testStartScanUsesWorkerEventsToBuildProgressAndSummary() async throws {
        let taskID = UUID(uuidString: "20000000-0000-0000-0000-000000000001") ?? UUID()
        let request = AtlasRequestEnvelope(command: .startScan(taskID: taskID))
        let finishedRun = TaskRun(
            id: taskID,
            kind: .scan,
            status: .completed,
            summary: "Scanned 4 finding groups and prepared a Smart Clean preview.",
            startedAt: request.issuedAt,
            finishedAt: Date()
        )
        let result = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(
                requestID: request.id,
                response: .accepted(task: AtlasTaskDescriptor(taskID: taskID, kind: .scan))
            ),
            events: [
                AtlasEventEnvelope(event: .taskProgress(taskID: taskID, completed: 1, total: 4)),
                AtlasEventEnvelope(event: .taskProgress(taskID: taskID, completed: 4, total: 4)),
                AtlasEventEnvelope(event: .taskFinished(finishedRun)),
            ],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: AtlasScaffoldWorkspace.state().currentPlan
        )
        let controller = AtlasWorkspaceController(worker: FakeWorker(result: result))

        let output = try await controller.startScan(taskID: taskID)

        XCTAssertEqual(output.progressFraction, 1)
        XCTAssertEqual(output.summary, finishedRun.summary)
        XCTAssertEqual(output.actionPlan?.items.count, AtlasScaffoldWorkspace.state().currentPlan.items.count)
        XCTAssertEqual(output.snapshot.findings.count, AtlasScaffoldWorkspace.snapshot().findings.count)
    }

    func testPreviewPlanReturnsStructuredPlanFromWorkerResponse() async throws {
        let plan = AtlasScaffoldWorkspace.state().currentPlan
        let request = AtlasRequestEnvelope(command: .previewPlan(taskID: UUID(), findingIDs: AtlasScaffoldFixtures.findings.map(\.id)))
        let result = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(requestID: request.id, response: .preview(plan)),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: plan
        )
        let controller = AtlasWorkspaceController(worker: FakeWorker(result: result))

        let output = try await controller.previewPlan(findingIDs: AtlasScaffoldFixtures.findings.map(\.id))

        XCTAssertEqual(output.actionPlan.title, plan.title)
        XCTAssertEqual(output.actionPlan.estimatedBytes, plan.estimatedBytes)
        XCTAssertEqual(output.actionPlan.items.first?.targetPaths, plan.items.first?.targetPaths)
    }

    func testExecutePlanUsesWorkerEventsToBuildSummary() async throws {
        let plan = AtlasScaffoldWorkspace.state().currentPlan
        let taskID = UUID(uuidString: "20000000-0000-0000-0000-000000000002") ?? UUID()
        let request = AtlasRequestEnvelope(command: .executePlan(planID: plan.id))
        let finishedRun = TaskRun(
            id: taskID,
            kind: .executePlan,
            status: .completed,
            summary: "Moved 2 Smart Clean items into recovery.",
            startedAt: request.issuedAt,
            finishedAt: Date()
        )
        let result = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(
                requestID: request.id,
                response: .accepted(task: AtlasTaskDescriptor(taskID: taskID, kind: .executePlan))
            ),
            events: [
                AtlasEventEnvelope(event: .taskProgress(taskID: taskID, completed: 1, total: 3)),
                AtlasEventEnvelope(event: .taskProgress(taskID: taskID, completed: 3, total: 3)),
                AtlasEventEnvelope(event: .taskFinished(finishedRun)),
            ],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: nil
        )
        let controller = AtlasWorkspaceController(worker: FakeWorker(result: result))

        let output = try await controller.executePlan(planID: plan.id)

        XCTAssertEqual(output.progressFraction, 1)
        XCTAssertEqual(output.summary, finishedRun.summary)
    }

    func testListAppsReturnsStructuredAppFootprints() async throws {
        let apps = AtlasScaffoldFixtures.apps
        let request = AtlasRequestEnvelope(command: .appsList)
        let result = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(requestID: request.id, response: .apps(apps)),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: nil
        )
        let controller = AtlasWorkspaceController(worker: FakeWorker(result: result))

        let output = try await controller.listApps()

        XCTAssertEqual(output.apps.count, apps.count)
        XCTAssertEqual(output.snapshot.apps.count, apps.count)
    }

    func testSettingsUpdateReturnsStructuredSettings() async throws {
        var updated = AtlasScaffoldFixtures.settings
        updated.recoveryRetentionDays = 14
        let request = AtlasRequestEnvelope(command: .settingsSet(updated))
        let result = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(requestID: request.id, response: .settings(updated)),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: nil
        )
        let controller = AtlasWorkspaceController(worker: FakeWorker(result: result))

        let output = try await controller.updateSettings(updated)

        XCTAssertEqual(output.settings.recoveryRetentionDays, 14)
    }

    func testHealthSnapshotReturnsStructuredOverviewData() async throws {
        let healthSnapshot = AtlasScaffoldFixtures.healthSnapshot
        let request = AtlasRequestEnvelope(command: .healthSnapshot)
        let result = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(requestID: request.id, response: .health(healthSnapshot)),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: nil
        )
        let controller = AtlasWorkspaceController(worker: FakeWorker(result: result))

        let output = try await controller.healthSnapshot()

        XCTAssertEqual(output.healthSnapshot.optimizations.count, healthSnapshot.optimizations.count)
        XCTAssertEqual(output.healthSnapshot.diskUsedPercent, healthSnapshot.diskUsedPercent)
    }

    func testInspectPermissionsPropagatesUpdatedSnapshot() async throws {
        let permissions = AtlasScaffoldFixtures.permissions
        let request = AtlasRequestEnvelope(command: .inspectPermissions)
        let result = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(requestID: request.id, response: .permissions(permissions)),
            events: permissions.map { AtlasEventEnvelope(event: .permissionUpdated($0)) },
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: nil
        )
        let controller = AtlasWorkspaceController(worker: FakeWorker(result: result))

        let output = try await controller.inspectPermissions()

        XCTAssertEqual(output.snapshot.permissions.count, permissions.count)
        XCTAssertEqual(output.events.count, permissions.count)
    }

    func testExecutePlanMapsExecutionUnavailableToLocalizedError() async throws {
        let plan = AtlasScaffoldWorkspace.state().currentPlan
        let request = AtlasRequestEnvelope(command: .executePlan(planID: plan.id))
        let result = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(
                requestID: request.id,
                response: .rejected(code: .executionUnavailable, reason: "XPC worker offline")
            ),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: nil
        )
        let controller = AtlasWorkspaceController(worker: FakeWorker(result: result))

        do {
            _ = try await controller.executePlan(planID: plan.id)
            XCTFail("Expected executePlan to throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, AtlasL10n.string("application.error.executionUnavailable", "XPC worker offline"))
        }
    }

    func testRestoreItemsMapsHelperUnavailableToLocalizedError() async throws {
        let itemID = UUID()
        let request = AtlasRequestEnvelope(command: .restoreItems(taskID: UUID(), itemIDs: [itemID]))
        let result = AtlasWorkerCommandResult(
            request: request,
            response: AtlasResponseEnvelope(
                requestID: request.id,
                response: .rejected(code: .helperUnavailable, reason: "Privileged helper missing")
            ),
            events: [],
            snapshot: AtlasScaffoldWorkspace.snapshot(),
            previewPlan: nil
        )
        let controller = AtlasWorkspaceController(worker: FakeWorker(result: result))

        do {
            _ = try await controller.restoreItems(itemIDs: [itemID])
            XCTFail("Expected restoreItems to throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, AtlasL10n.string("application.error.helperUnavailable", "Privileged helper missing"))
        }
    }
}

private actor FakeWorker: AtlasWorkerServing {
    let result: AtlasWorkerCommandResult

    init(result: AtlasWorkerCommandResult) {
        self.result = result
    }

    func submit(_ request: AtlasRequestEnvelope) async throws -> AtlasWorkerCommandResult {
        result
    }
}
