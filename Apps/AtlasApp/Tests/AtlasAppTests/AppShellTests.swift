import XCTest
@testable import AtlasApp
import AtlasDomain
import AtlasInfrastructure

/// Batch H shell tests: sidebar grouping contract (Calm Ledger §2.1), the
/// task-center № prefix mapping, and shell view smoke construction.
@MainActor
final class AppShellTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AtlasL10n.setCurrentLanguage(.zhHans)
    }

    // MARK: - Sidebar grouping (pure function on AtlasRoute.SidebarSection)

    func testSidebarGroupsMatchCalmLedgerSpec() {
        // 工作 work group — overview / smart clean / file organizer / apps.
        XCTAssertEqual(
            AtlasRoute.SidebarSection.core.routes,
            [.overview, .smartClean, .fileOrganizer, .apps]
        )
        // 记录 records group — ledger / permissions.
        XCTAssertEqual(
            AtlasRoute.SidebarSection.manage.routes,
            [.ledger, .permissions]
        )
        // Settings/About sink to the bottom, outside both sections.
        XCTAssertNil(AtlasRoute.settings.sidebarSection)
        XCTAssertNil(AtlasRoute.about.sidebarSection)
        XCTAssertFalse(AtlasRoute.settings.isSidebarRoute)
        XCTAssertFalse(AtlasRoute.about.isSidebarRoute)
        // Every sectioned route reports the section it lives in.
        for section in AtlasRoute.SidebarSection.allCases {
            for route in section.routes {
                XCTAssertEqual(route.sidebarSection, section)
            }
        }
    }

    func testSidebarSectionTitlesAreWorkAndRecords() {
        XCTAssertEqual(AtlasRoute.SidebarSection.core.title, "工作")
        XCTAssertEqual(AtlasRoute.SidebarSection.manage.title, "记录")
    }

    // MARK: - Task-center № prefix mapping

    func testWorkflowPlanNumberOnlyForActiveOwnedRuns() {
        let model = makeModel()
        model.assignPlanNumber(for: .smartClean)
        let number = model.workflowState(for: .smartClean).planNumber
        XCTAssertNotNil(number)

        let startedAt = Date(timeIntervalSince1970: 1_000)
        func run(_ kind: TaskKind, _ status: TaskStatus) -> TaskRun {
            TaskRun(kind: kind, status: status, summary: "fixture", startedAt: startedAt)
        }

        // Active smart-clean runs carry the №.
        XCTAssertEqual(model.workflowPlanNumber(for: run(.scan, .running)), number)
        XCTAssertEqual(model.workflowPlanNumber(for: run(.executePlan, .queued)), number)
        // Finished runs never get the prefix (ledger numbering is Batch J's job).
        XCTAssertNil(model.workflowPlanNumber(for: run(.scan, .completed)))
        // Workflows without an assigned № stay bare.
        XCTAssertNil(model.workflowPlanNumber(for: run(.organizeFiles, .running)))
        // Non-workflow kinds never get a №.
        XCTAssertNil(model.workflowPlanNumber(for: run(.uninstallApp, .running)))
        XCTAssertNil(model.workflowPlanNumber(for: run(.inspectPermissions, .running)))
        XCTAssertNil(model.workflowPlanNumber(for: run(.restore, .running)))
    }

    // MARK: - Shell smoke

    func testShellViewsConstructAndEvaluate() {
        let model = makeModel()

        let shell = AppShellView(model: model)
        _ = shell.body

        let taskCenter = TaskCenterView(
            taskRuns: [
                TaskRun(kind: .scan, status: .running, summary: "fixture", startedAt: Date(timeIntervalSince1970: 1_000))
            ],
            summary: "fixture",
            planNumber: { _ in 42 },
            onOpenLedger: {}
        )
        _ = taskCenter.body
    }

    // MARK: - Helpers

    private func makeModel() -> AtlasAppModel {
        AtlasAppModel(
            repository: AtlasWorkspaceRepository(
                stateFileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                    .appendingPathComponent("workspace-state.json")
            ),
            workerService: AtlasScaffoldWorkerService(allowStateOnlyCleanExecution: true),
            ledgerNumberStore: ShellTestLedgerStore()
        )
    }
}

private final class ShellTestLedgerStore: AtlasLedgerNumberStoring {
    private var counter = 0

    func next(fallbackBase: Int) -> Int {
        let number = counter > 0 ? counter : max(fallbackBase, 1)
        counter = number + 1
        return number
    }
}
