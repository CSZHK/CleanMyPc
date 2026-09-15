import AtlasApplication
import AtlasCoreAdapters
import AtlasDesignSystem
import AtlasDomain
import AtlasFeaturesFileOrganizer
import AtlasFeaturesSmartClean
import AtlasInfrastructure
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class AtlasAppModel: ObservableObject {
    @Published var selection: AtlasRoute? = .overview
    let snapshotFilter = AtlasSnapshotFilter()
    @Published var isTaskCenterPresented = false
    @Published private(set) var snapshot: AtlasWorkspaceSnapshot
    @Published private(set) var currentPlan: ActionPlan
    @Published private(set) var currentAppPreview: ActionPlan?
    @Published private(set) var currentPreviewedAppID: UUID?
    @Published private(set) var latestAppRestoreRefreshStatus: AtlasAppPostRestoreRefreshStatus?
    @Published private(set) var settings: AtlasSettings
    @Published private(set) var isHealthSnapshotRefreshing = false
    @Published private(set) var isScanRunning = false
    @Published private(set) var isPlanRunning = false
    /// `P1-9`：执行开始时刻。破坏性操作进行中，worker **只在完成时**上报进度
    /// （round-14 的注释已写明），因此「已处理计数 / 剩余时间估计」都没有真实数据；
    /// 唯一确定性且真实可得的是**已用时**。用它替掉「空弧 + 一句话」。
    @Published private(set) var planExecutionStartedAt: Date?
    @Published private(set) var isPermissionsRefreshing = false
    @Published private(set) var isAppActionRunning = false
    @Published private(set) var activePreviewAppID: UUID?
    @Published private(set) var activeUninstallAppID: UUID?
    @Published private(set) var restoringRecoveryItemID: UUID?
    /// Entry id tapped on the Overview ledger feed, threaded into the Ledger
    /// screen's initial selection so tapping №N lands on №N (round-4 back-link).
    /// Set by AppShellView.onSelectLedgerEntry; cleared once the Ledger consumes
    /// it on appear (a plain var — navigation's route change drives the redraw).
    var pendingLedgerEntryID: String?
    /// 契约一（规格 §1.2(1)）：**按 source 索引**的操作结果槽。写入必须指定 source，
    /// 跨屏泄漏在类型层面不可表达 —— `P0-1` 的根因正是台账恢复失败被写进了
    /// Smart Clean 的槽位（`String` 没有来源标识，无法路由）。
    @Published private(set) var sourceOutcomes: [AtlasActionSource: AtlasSourceOutcomes] = [:]
    /// 各 source 的**瞬时状态行**（就绪 / 扫描中 / 进度）。这是状态、不是结果，
    /// 故不参与 outcome 路由；名字即 source，且不再被其他模块写入。
    @Published private(set) var latestScanSummary: String
    @Published private(set) var latestAppsSummary: String
    @Published private(set) var latestPermissionsSummary: String
    @Published private(set) var latestScanProgress: Double = 0
    @Published private(set) var isCurrentSmartCleanPlanFresh: Bool
    // Smart-clean execution outcome (Batch I): drives the ④ receipt stage via
    // AtlasWorkflowStageMap resolve-on-render. Reset whenever a new scan starts
    // or the plan is superseded. The receipt holds only real execution facts
    // (recovery delta, retention at run time — spec §1.6 fail-closed).
    @Published private(set) var smartCleanExecutionCompleted = false
    @Published private(set) var smartCleanExecutionReceipt: SmartCleanExecutionReceipt?
    /// Transient per-call success flag set by `restoreRecoveryItemCore`
    /// (review fix #6); read by the undo path to decide whether to clear
    /// `smartCleanExecutionCompleted` or surface a failure toast instead.
    private var lastRestoreDidSucceed = false
    @Published private(set) var latestUpdateResult: AtlasAppUpdate?
    @Published private(set) var isCheckingForUpdate = false
    @Published private(set) var updateCheckNotice: String?
    @Published private(set) var updateCheckError: String?

    // Toast state — public setter needed for AtlasToastContainer Binding
    @Published var toasts: [AtlasToastItem] = []

    // Workflow ViewState per route (Calm Ledger §2.3) — hosted here, not in
    // feature @State: AppShellView rebuilds feature views with .id(route), so
    // stage/selection/filter must survive route switches (§7 red line).
    @Published private(set) var workflowStates: [AtlasRoute: AtlasWorkflowViewState] = [:]

    // File Organizer state
    @Published private(set) var fileOrganizerEntries: [FileOrganizerEntry] = []
    @Published private(set) var isFileOrganizerScanning = false
    @Published private(set) var isFileOrganizerClassifying = false
    @Published private(set) var isFileOrganizerExecuting = false
    @Published private(set) var fileOrganizerScanSummary: String
    @Published private(set) var fileOrganizerProgress: Double = 0
    @Published private(set) var currentFileOrganizerPlan: ActionPlan
    @Published private(set) var isFileOrganizerPlanFresh = false
    /// True only after a successful dry-run (③ preview). Distinct from
    /// isPlanFresh (② rules): a fresh plan lands on ② rules until the user
    /// explicitly previews, so hasPreviewResults gates ③ (round-4 — previously
    /// `isPlanFresh && !items.isEmpty` collapsed ② into ③, skipping rules).
    @Published private(set) var fileOrganizerHasPreviewResults = false
    @Published private(set) var scannedFolders: [String] = []
    /// FileOrganizer folder selection, persisted across route switches so an
    /// edited-but-not-yet-scanned selection is not lost on navigation (round-6
    /// §7 red line). nil ⇒ never edited ⇒ seed from scannedFolders/defaults.
    /// Set externally by AppShellView; a plain var — navigation drives the redraw.
    var fileOrganizerSelectedFolders: [String]?
    @Published private(set) var fileOrganizerRules: [FileOrganizerRule]
    @Published private(set) var fileOrganizerExecutionCompleted = false
    @Published private(set) var fileOrganizerMovedCount = 0
    /// Module receipt (spec §2.3 ⑤ / §1.6 fail-closed): populated from real
    /// execution output when `fileOrganizerExecutionCompleted` flips true;
    /// cleared by `supersedePlan(.fileOrganizer)` / new scan. Mirrors
    /// `smartCleanExecutionReceipt` shape. Rendered read-only by the receipt
    /// stage view; every field is backed by real execution data.
    @Published private(set) var fileOrganizerExecutionReceipt: FileOrganizerExecutionReceipt?

    private let repository: AtlasWorkspaceRepository
    private let workspaceController: AtlasWorkspaceController
    private let updateChecker = AtlasUpdateChecker()
    private let ledgerNumberStore: any AtlasLedgerNumberStoring
    /// `P1-16` 差分基线的存储域。**必须可注入**：默认是 `UserDefaults.standard`
    /// （SPM 测试进程里即 `com.apple.dt.xctest.tool`，是**仓库外的持久 OS 状态**）。
    private let userDefaults: UserDefaults

    /// `F-03` 的**默认域**：生产走 `.standard`，**测试进程走独立 suite**。
    ///
    /// 为什么需要这层：`init` 会调用 `surfaceExpiredRecoveryPruneIfNeeded()`，
    /// **写入**「见过的恢复项 id 集合」。若默认域是 `.standard`，则测试进程里
    /// 每一个构造 `AtlasAppModel` 的用例都会往 `com.apple.dt.xctest.tool`
    /// 这个**仓库外持久域**里写真实 UUID —— 于是用例的结论取决于跑过哪些用例、
    /// 顺序如何、乃至上一次跑留下了什么。这正是 `F-03` 的根因，且**不止影响
    /// 一个用例**：任何后来者（包括本机的上一次运行）留下的 id 都会成为
    /// 「上次会话」的基线。
    ///
    /// 只在测试进程内改变默认值，**生产行为完全不变**。
    ///
    /// 判据是 `Bundle.main.bundleIdentifier == "com.apple.dt.xctest.tool"` ——
    /// 这正是问题本身：xctest 宿主进程没有自己的 bundle id，于是 `.standard`
    /// 解析到那个**所有 SwiftPM 测试共享**的域。（实测本机 SPM 测试进程里
    /// `XCTestConfigurationFilePath` 并不存在，故不能靠它判断。）
    ///
    /// 两道收紧（审查 §8-3）：
    /// 1. **整段 `#if DEBUG`** —— 与本文件其它测试接缝（`applyUITestFixtureIfNeeded`、
    ///    `taskCenterTaskRuns`）一致。release 构建里这段**根本不参与编译**，
    ///    而不是「编进去再靠运行期判据返回 `.standard`」。
    /// 2. **一次性求值** —— 原实现是计算属性，`removePersistentDomain` 会**每次
    ///    访问都执行**，即每次 `AtlasAppModel` 构造都清空进程内共享的那个 suite。
    ///    对现有用例无碍（都在构造前播种），但对将来任何「需要在两次模型构造之间
    ///    保留基线」的用例是个静默陷阱。改为 `static let` 只构造一次。
    static var defaultUserDefaults: UserDefaults {
        #if DEBUG
        return testProcessDefaults ?? .standard
        #else
        return .standard
        #endif
    }

    #if DEBUG
    /// 测试进程的独立 suite，**只构造一次**。
    private static let testProcessDefaults: UserDefaults? = {
        guard Bundle.main.bundleIdentifier == "com.apple.dt.xctest.tool" else { return nil }
        // 每个测试进程一个 suite：进程内的一致基线由用例自行注入，未注入的用例
        // 也不必读别人的残留。进程结束即整域移除，不跨跑次残留。
        let suiteName = "atlas.app.model.tests.\(ProcessInfo.processInfo.processIdentifier)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }()
    #endif
    private let notificationPermissionRequester: @Sendable () async -> Bool
    private var filterCancellationToken: AnyCancellable?
    private var didRequestInitialHealthSnapshot = false
    private var didRequestInitialPermissionSnapshot = false
    private var pendingRestoreSnapshotCategoryCounts: [AtlasAppEvidenceCategory: Int]?

    init(
        repository: AtlasWorkspaceRepository = AtlasWorkspaceRepository(),
        workerService: (any AtlasWorkerServing)? = nil,
        preferXPCWorker: Bool? = nil,
        allowScaffoldFallback: Bool? = nil,
        xpcRequestConfiguration: AtlasXPCRequestConfiguration = AtlasXPCRequestConfiguration(),
        xpcRequestExecutor: AtlasXPCDataRequestExecutor? = nil,
        notificationPermissionRequester: (@Sendable () async -> Bool)? = nil,
        ledgerNumberStore: (any AtlasLedgerNumberStoring)? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        let state = repository.loadState()
        self.repository = repository
        self.ledgerNumberStore = ledgerNumberStore ?? AtlasUserDefaultsLedgerNumberStore()
        self.userDefaults = userDefaults ?? Self.defaultUserDefaults
        self.snapshot = state.snapshot
        self.currentPlan = state.currentPlan
        self.settings = state.settings
        AtlasL10n.setCurrentLanguage(state.settings.language)
        self.latestScanSummary = AtlasL10n.string("model.scan.ready")
        self.latestAppsSummary = AtlasL10n.string("model.apps.ready")
        self.latestAppRestoreRefreshStatus = nil
        self.latestPermissionsSummary = AtlasL10n.string("model.permissions.ready")
        self.isCurrentSmartCleanPlanFresh = false
        self.fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.ready")
        self.currentFileOrganizerPlan = ActionPlan(title: "", items: [], estimatedBytes: 0)
        self.fileOrganizerRules = state.settings.fileOrganizerCustomRules ?? AtlasScaffoldFixtures.fileOrganizerRules
        let directWorker = AtlasScaffoldWorkerService(
            repository: repository,
            healthSnapshotProvider: MoleHealthAdapter(),
            smartCleanScanProvider: MoleSmartCleanAdapter(),
            appsInventoryProvider: MacAppsInventoryAdapter(),
            helperExecutor: AtlasPrivilegedHelperClient(),
            fileOrganizerScanProvider: AtlasFileOrganizerScanner(),
            fileOrganizerClassifier: AtlasFileOrganizerClassifier()
        )
        let prefersXPCWorker = preferXPCWorker ?? (ProcessInfo.processInfo.environment["ATLAS_PREFER_XPC_WORKER"] == "1")
        let shouldAllowScaffoldFallback = allowScaffoldFallback
            ?? (ProcessInfo.processInfo.environment["ATLAS_ALLOW_SCAFFOLD_FALLBACK"] == "1")
        let defaultWorker: any AtlasWorkerServing = prefersXPCWorker
            ? AtlasPreferredWorkerService(
                requestConfiguration: xpcRequestConfiguration,
                requestExecutor: xpcRequestExecutor,
                fallbackWorker: directWorker,
                allowFallback: shouldAllowScaffoldFallback
            )
            : directWorker
        self.workspaceController = AtlasWorkspaceController(
            worker: workerService ?? defaultWorker
        )
        self.notificationPermissionRequester = notificationPermissionRequester ?? {
            // Bare executables (swift run) have no LaunchServices bundleProxy, and
            // UNUserNotificationCenter.current() throws an ObjC NSInternalInconsistencyException
            // that Swift cannot catch. Degrade to "not granted" outside a real .app bundle.
            guard Bundle.main.bundleIdentifier != nil else { return false }
            return await withCheckedContinuation { continuation in
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
        self.filterCancellationToken = snapshotFilter.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        syncAppearance()
        surfaceExpiredRecoveryPruneIfNeeded()
        #if DEBUG
        applyUITestFixtureIfNeeded()
        #endif
    }

    #if DEBUG
    // MARK: - 守卫基座：UI 测试的状态注入（规格 §9 波次纪律第 4 条）

    /// `I-2` / `I-3` 要断言的态是「**执行回执存在 + 无恢复项**」。
    ///
    /// 执行回执（`smartCleanExecutionReceipt` / `fileOrganizerExecutionReceipt`）是
    /// **内存态、不落盘** —— `ATLAS_STATE_FILE` 的冷启动快照造不出来；而自然走到该态
    /// 需要执行一次真实清理（破坏性操作）。故开一条**按启动环境变量驱动**的接缝。
    ///
    /// 只在 `#if DEBUG` 下编译：release 构建里不存在这个入口。
    static let uiTestFixtureEnvironmentKey = "ATLAS_UI_TEST_FIXTURE"

    /// 当前生效的 UI 测试 fixture。**只在读取侧消费**（见 `taskCenterTaskRuns`）——
    /// 不存在「重载后重新施加」的叠加层：写入侧施加不可行（`snapshot = output.snapshot`
    /// 有约 20 处，追着补是打地鼠），故改为在**消费点**按本值返回 fixture 内容，
    /// 对重载次数完全免疫。
    private var activeUITestFixture: String?

    private func applyUITestFixtureIfNeeded() {
        guard let fixture = ProcessInfo.processInfo.environment[Self.uiTestFixtureEnvironmentKey],
              !fixture.isEmpty else { return }
        activeUITestFixture = fixture
        applyUITestFixture(fixture)
    }
    #endif

    // MARK: - `P1-16`：过期恢复项被清理后不得静默消失
    //
    // ⚠️ **本段不得落在 `#if DEBUG` 内**（2026-09-15 修）：`P1-16` 是**产品功能**，
    // 由 `init`（`surfaceExpiredRecoveryPruneIfNeeded`）与 `restoreRecoveryItemCore`
    // （`forgetSeenRecoveryItem`）在 **release 可达路径**上调用。它此前被夹在上方
    // 的 fixture 接缝与下方的 `applyUITestFixture` 两块 `#if DEBUG` 之间一并吞掉，
    // 导致 **Release 构建编不过**（`cannot find 'forgetSeenRecoveryItem' in scope`）。
    // 之所以长期没被发现：`swift test` 与 `xcodebuild build-for-testing` **都是 Debug 配置**，
    // 全部验证路径都没碰过 Release。改动本文件时请确认 `#if DEBUG` 的配对边界。

    /// 上一会话「见过」的恢复项 id。worker 的 `pruneExpiredRecoveryItemsIfNeeded`
    /// 会在启动时把过期项直接删掉并落盘 —— 用户上次看到「即将到期」的记录会凭空
    /// 不见，没有任何解释，于是怀疑 Atlas 弄丢了数据。
    ///
    /// 语义层不给 worker 加墓碑（规格 §1.3 禁止改其恢复语义），改在 **app 层**做
    /// 差分：会话间比对 id 集合，消失的即为被清理的，据此给出提示。
    static let seenRecoveryItemIDsKey = "atlas.ledger.seenRecoveryItemIDs"

    /// `P1-16` 的**反面**：用户**主动恢复**的项同样会从 `recoveryItems` 里消失
    /// （worker 恢复成功后 `removeAll { requestedItemIDs.contains($0.id) }`）。
    /// 若不从「见过」集合里剔除，下次启动就会把它误报成「已被清理」——
    /// 即：**「不见了」≠「被清理了」**，这是差分法的固有盲点，必须在恢复侧补偿。
    private func forgetSeenRecoveryItem(_ itemID: UUID) {
        let defaults = userDefaults
        var seen = Set(defaults.stringArray(forKey: Self.seenRecoveryItemIDsKey) ?? [])
        guard seen.remove(itemID.uuidString) != nil else { return }
        defaults.set(Array(seen), forKey: Self.seenRecoveryItemIDsKey)
    }

    func surfaceExpiredRecoveryPruneIfNeeded() {
        let defaults = userDefaults
        let currentIDs = Set(snapshot.recoveryItems.map(\.id.uuidString))
        let seenIDs = Set(defaults.stringArray(forKey: Self.seenRecoveryItemIDsKey) ?? [])

        // 首次运行（seenIDs 为空）不报：那时没有「上次看到过」的记录可比。
        if !seenIDs.isEmpty {
            let disappeared = seenIDs.subtracting(currentIDs)
            if !disappeared.isEmpty {
                recordPlan(
                    .ledger,
                    kind: .advisory,
                    message: AtlasL10n.string("ledger.prune.notice.message", disappeared.count)
                )
            }
        }
        defaults.set(Array(currentIDs), forKey: Self.seenRecoveryItemIDsKey)
    }

    #if DEBUG
    /// internal（非 private）：单元测试可直接调用，把「fixture 是否真的产出目标态」
    /// 的排查从每次 ~60s 的 UI 运行降回秒级 —— 守卫基座自身的可调试性。
    func applyUITestFixture(_ fixture: String) {
        switch fixture {
        case "receipt-no-recovery":
            applyReceiptNoRecoveryFixture()
        case "review-executable":
            applyReviewExecutableFixture()
        case "taskcenter-many-runs":
            break   // 内容由 `taskCenterTaskRuns` 在读取侧施加
        default:
            assertionFailure("Unknown \(Self.uiTestFixtureEnvironmentKey): \(fixture)")
        }
    }

    /// 让 Smart Clean ④ 与 File Organizer ⑤ 同时落在「回执存在、**无**恢复项」的终态。
    private func applyReceiptNoRecoveryFixture() {
        let now = Date()

        smartCleanExecutionCompleted = true
        smartCleanExecutionReceipt = SmartCleanExecutionReceipt(
            planNumber: 1,
            receiptCode: "#A1F3",
            completedAt: now,
            executedItemCount: 1,
            estimatedFreedBytes: 4_096,
            summary: "UI test fixture receipt (no restore point)",
            recoveryItemIDs: [],   // ← 关键：无恢复项 ⇒ hasRestorePoint == false
            recoveryBytes: 0,
            retentionDays: settings.recoveryRetentionDays,
            failureReason: nil
        )

        fileOrganizerExecutionCompleted = true
        fileOrganizerExecutionReceipt = FileOrganizerExecutionReceipt(
            planNumber: 2,
            receiptCode: "#B2C4",
            completedAt: now,
            movedItemCount: 1,
            summary: "UI test fixture receipt (no restore point)",
            failureReason: nil,
            failedItemCount: 0
        )

        // `displayedStage` 必须显式落到回执段：`effectiveStage` 在 displayedStage 落后于
        // currentStage 时走的是 read-only 回看分支，不会渲染回执。
        updateWorkflowState(for: .smartClean) { $0.displayedStage = SmartCleanStage.receipt }
        updateWorkflowState(for: .fileOrganizer) { $0.displayedStage = FileOrganizerStage.receipt }
    }
    /// `taskcenter-many-runs` 的内容：7 条已完成任务，时间戳递减。
    ///
    /// **纯函数、不写 snapshot** —— 由 `taskCenterTaskRuns` 在读取时施加，
    /// 因而对 worker 的任何次快照重载都免疫。
    private static func uiTestFixtureTaskRuns() -> [TaskRun] {
        let now = Date()
        return (0..<7).map { index in
            TaskRun(
                id: UUID(),
                kind: .scan,
                status: .completed,
                summary: "UI test fixture run \(index)",
                startedAt: now.addingTimeInterval(TimeInterval(-600 * (index + 1))),
                finishedAt: now.addingTimeInterval(TimeInterval(-600 * (index + 1) + 30))
            )
        }
    }

    /// Smart Clean ② 复核页：可执行的新鲜计划 —— 用于打开破坏性确认弹窗（`I-4`）。
    ///
    /// 冷启动时计划一律是 cached（`isCurrentSmartCleanPlanFresh == false`），
    /// 主按钮因此置灰、弹窗不可达，故必须由接缝注入「新鲜 + 有可执行目标」。
    private func applyReviewExecutableFixture() {
        // **从当前快照里真实存在的 findings 派生**计划与选中集 —— 不要自造一条。
        //
        // 踩过的坑（保留了错误实现的教训）：首版自造了一条带 `targetPaths` 的 finding，
        // 在实机里按钮显示「执行已选 **0** 项」并置灰。原因是全新状态文件下 app 落到
        // **脚手架工作区**（`AtlasScaffoldWorkspace`），启动后的 reload 带回的是 4 条
        // 脚手架 findings；自造 finding 的 id 不在其中 ⇒
        // `selectedFindingIDs = state.selectedIDs ∩ findings.ids` 求交集后归零。
        // 从真实 findings 派生后，选中集与计划在任何 reload 之后都自洽。
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var findings = snapshot.findings
        if findings.isEmpty {
            let synthetic = Finding(
                id: UUID(uuidString: "40000000-0000-0000-0000-0000000000AA") ?? UUID(),
                title: "UI fixture cache",
                detail: "UI fixture",
                bytes: 2_048,
                risk: .safe,
                category: "Developer tools",
                targetPaths: ["\(home)/Library/Caches/atlas-ui-fixture/0.bin"]
            )
            findings = [synthetic]
        }

        let items = findings.enumerated().map { index, finding in
            // 目标路径显式给，且落在 home 内、不在 helperRoots 里 ⇒
            // `ActionItem.executionBoundary` 推导为 `.direct`（可执行）。
            let target = "\(home)/Library/Caches/atlas-ui-fixture/\(index).bin"
            return ActionItem(
                id: finding.id,
                title: finding.title,
                detail: finding.detail,
                kind: .removeCache,
                recoverable: true,
                targetPaths: [target],
                evidencePaths: [target]
            )
        }
        let plan = ActionPlan(
            title: "Review \(items.count) selected findings",
            items: items,
            estimatedBytes: findings.reduce(Int64(0)) { $0 + $1.bytes }
        )

        // 落到真相源：启动后的 snapshot/currentPlan reload 会整体换掉内存态。
        let fixtureState = AtlasWorkspaceState(
            snapshot: AtlasWorkspaceSnapshot(
                reclaimableSpaceBytes: snapshot.reclaimableSpaceBytes,
                findings: findings,
                apps: snapshot.apps,
                taskRuns: snapshot.taskRuns,
                recoveryItems: snapshot.recoveryItems,
                permissions: snapshot.permissions,
                healthSnapshot: snapshot.healthSnapshot
            ),
            currentPlan: plan,
            settings: settings
        )
        _ = try? repository.saveState(fixtureState)
        snapshot = fixtureState.snapshot
        currentPlan = plan
        isCurrentSmartCleanPlanFresh = true

        updateWorkflowState(for: .smartClean) { state in
            state.displayedStage = SmartCleanStage.review
            state.planNumber = 1
            state.receiptCode = "#C3D5"
            state.selectedIDs = Set(findings.map(\.id.uuidString))
        }
    }
    #endif

    var appLanguage: AtlasLanguage {
        settings.language
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.6"
    }

    var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "6"
    }

    func checkForUpdate() async {
        guard !isCheckingForUpdate else { return }

        isCheckingForUpdate = true
        defer { isCheckingForUpdate = false }

        updateCheckNotice = nil
        updateCheckError = nil

        do {
            let result = try await updateChecker.checkForUpdate(currentVersion: appVersion)
            withAnimation(.snappy(duration: 0.24)) {
                latestUpdateResult = result
            }
        } catch let error as AtlasUpdateCheckerError {
            withAnimation(.snappy(duration: 0.24)) {
                latestUpdateResult = nil
            }
            switch error {
            case .noPublishedRelease:
                updateCheckNotice = error.localizedDescription
            case .requestFailed:
                updateCheckError = error.localizedDescription
            }
        } catch {
            withAnimation(.snappy(duration: 0.24)) {
                latestUpdateResult = nil
            }
            updateCheckError = error.localizedDescription
        }
    }

    func searchText(for route: AtlasRoute) -> String {
        snapshotFilter.searchText(for: route)
    }

    func setSearchText(_ text: String, for route: AtlasRoute) {
        snapshotFilter.setSearchText(text, for: route)
    }

    var filteredSnapshot: AtlasWorkspaceSnapshot {
        snapshotFilter.filteredSnapshot(from: snapshot)
    }

    var filteredFindings: [Finding] {
        snapshotFilter.filteredFindings(from: snapshot)
    }

    var filteredApps: [AppFootprint] {
        snapshotFilter.filteredApps(from: snapshot)
    }

    var filteredTaskRuns: [TaskRun] {
        snapshotFilter.filteredTaskRuns(from: snapshot)
    }

    var filteredRecoveryItems: [RecoveryItem] {
        snapshotFilter.filteredRecoveryItems(from: snapshot)
    }

    var filteredPermissionStates: [PermissionState] {
        snapshotFilter.filteredPermissionStates(from: snapshot)
    }

    var filteredFileOrganizerEntries: [FileOrganizerEntry] {
        snapshotFilter.filteredFileOrganizerEntries(from: snapshot)
    }

    var taskCenterTaskRuns: [TaskRun] {
        #if DEBUG
        // 守卫基座：在**读取侧**施加 fixture。
        //
        // 写入侧施加不可行 —— `snapshot = output.snapshot` 在 worker 的 health /
        // permissions / scan / execute 等路径上共有约 20 处，追着补是打地鼠
        // （实测追 2 处后仍被冲掉）。在消费点施加则对重载次数完全免疫。
        if activeUITestFixture == "taskcenter-many-runs" {
            return Self.uiTestFixtureTaskRuns()
        }
        #endif
        return snapshot.taskRuns
    }

    var taskCenterSummary: String {
        let activeTaskCount = snapshot.taskRuns.filter { taskRun in
            taskRun.status == .queued || taskRun.status == .running
        }.count

        if activeTaskCount == 0 {
            return AtlasL10n.string("model.taskcenter.none")
        }

        let key = activeTaskCount == 1 ? "model.taskcenter.active.one" : "model.taskcenter.active.other"
        return AtlasL10n.string(key, activeTaskCount)
    }

    var isWorkflowBusy: Bool {
        isHealthSnapshotRefreshing
            || isScanRunning
            || isPlanRunning
            || isPermissionsRefreshing
            || isAppActionRunning
            || restoringRecoveryItemID != nil
            || isFileOrganizerScanning
            || isFileOrganizerClassifying
            || isFileOrganizerExecuting
    }

    var canExecuteCurrentSmartCleanPlan: Bool {
        !currentPlan.items.isEmpty && isCurrentSmartCleanPlanFresh && currentSmartCleanPlanHasExecutableTargets
    }

    var currentSmartCleanPlanHasExecutableTargets: Bool {
        let executableItems = currentPlan.items.filter { $0.effectiveExecutionBoundary(findings: snapshot.findings).isExecutable }
        guard !executableItems.isEmpty else {
            return false
        }
        return executableItems.allSatisfy { !$0.resolvedTargetPaths(findings: snapshot.findings).isEmpty }
    }

    var canExecuteFileOrganizerPlan: Bool {
        !currentFileOrganizerPlan.items.isEmpty && isFileOrganizerPlanFresh
    }

    func refreshHealthSnapshotIfNeeded() async {
        guard !didRequestInitialHealthSnapshot else {
            return
        }

        didRequestInitialHealthSnapshot = true
        await refreshHealthSnapshot()
    }

    func refreshPermissionsIfNeeded() async {
        guard !didRequestInitialPermissionSnapshot else {
            return
        }

        didRequestInitialPermissionSnapshot = true
        await inspectPermissions()
    }

    func refreshHealthSnapshot() async {
        guard !isHealthSnapshotRefreshing else {
            return
        }

        isHealthSnapshotRefreshing = true

        do {
            let output = try await workspaceController.healthSnapshot()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
            }
        } catch {
            latestScanSummary = error.localizedDescription
        }

        isHealthSnapshotRefreshing = false
    }

    func inspectPermissions() async {
        guard !isPermissionsRefreshing else {
            return
        }

        isPermissionsRefreshing = true
        latestPermissionsSummary = AtlasL10n.string("model.permissions.refreshing")

        do {
            let output = try await workspaceController.inspectPermissions()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
            }

            let grantedCount = output.snapshot.permissions.filter(\.isGranted).count
            latestPermissionsSummary = AtlasL10n.string(
                output.snapshot.permissions.count == 1 ? "model.permissions.summary.one" : "model.permissions.summary.other",
                grantedCount,
                output.snapshot.permissions.count
            )
        } catch {
            // `CT-07`：`.permissions` 此前**零生产零读取** —— 权限巡检失败只写进
            // `latestPermissionsSummary`（不带 source 标识的状态行），与 `P0-1`
            // 的根因同类：**失败信息挂在一个谁都可以覆盖的摘要串上**。
            // 权限屏**只订阅 `.permissions` 自己的结果**，跨屏泄漏在类型层面不可表达。
            latestPermissionsSummary = error.localizedDescription
            recordExecution(.permissions, kind: .failed, message: error.localizedDescription)
        }

        isPermissionsRefreshing = false
    }

    /// `CT-07`：权限屏自己的结果槽。
    var permissionsOutcome: AtlasActionOutcome? { outcome(for: .permissions) }

    /// File Organizer 的权限就绪判定 —— 与 `smartCleanRequiredPermissionsReady`
    /// **同判据**（`P2-8`：两个破坏性模块此前对同一件事规则不同）。
    private var fileOrganizerRequiredPermissionsReady: Bool { smartCleanRequiredPermissionsReady }

    /// 必需权限（完全磁盘访问等）是否就绪。未就绪时扫描会缓慢且范围受限
    /// （bug `limited-mode-scan-hang` 的环境诱因）。
    private var smartCleanRequiredPermissionsReady: Bool {
        let required = snapshot.permissions.filter { $0.kind.isRequiredForCurrentWorkflows }
        return required.isEmpty || required.allSatisfy(\.isGranted)
    }

    func runSmartCleanScan() async {
        guard !isScanRunning else {
            return
        }

        selection = .smartClean
        isScanRunning = true
        latestScanSummary = AtlasL10n.string("model.scan.submitting")
        latestScanProgress = 0
        clearExecution(.smartClean)
        // A new scan cycle supersedes the previous execution outcome (§2.3).
        smartCleanExecutionCompleted = false
        smartCleanExecutionReceipt = nil

        // 受限模式软提示（非阻断）：未授权完全磁盘访问时扫描可能缓慢且范围受限。
        // 此前用户在受限模式下只看到静态「正在开始…」文案并误判为卡死。
        if !smartCleanRequiredPermissionsReady {
            recordPlan(.smartClean, kind: .advisory, message: AtlasL10n.string("model.scan.limited.permissions"))
        }

        // 计时进度反馈（bug limited-mode-scan-hang）：clean.sh 是黑盒子子进程，
        // 无真实进度流；至少显示已运行时长，让用户知道扫描在进行而非卡死。
        let scanStartedAt = Date()
        let progressTicker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.isScanRunning else { break }
                let elapsed = Int(Date().timeIntervalSince(scanStartedAt))
                self.latestScanSummary = AtlasL10n.string("model.scan.progress", elapsed)
            }
        }

        do {
            let output = try await workspaceController.startScan()
            progressTicker.cancel()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentPlan = output.actionPlan ?? currentPlan
                latestScanSummary = output.summary
                latestScanProgress = output.progressFraction
                isCurrentSmartCleanPlanFresh = output.actionPlan != nil
                clearPlan(.smartClean)
                clearExecution(.smartClean)
            }
            if output.actionPlan != nil {
                // Scan produced a plan → assign ledger № + scan receipt (§2.3),
                // then seed the plan-scoped selection with every finding so the
                // default review state matches the legacy execute-all behavior.
                assignPlanNumber(for: .smartClean)
                updateWorkflowState(for: .smartClean) { state in
                    state.selectedIDs = Set(output.snapshot.findings.map(\.id.uuidString))
                }
            }
        } catch {
            latestScanSummary = error.localizedDescription
            latestScanProgress = 0
            recordPlan(.smartClean, kind: .failed, message: error.localizedDescription)
        }

        isScanRunning = false
    }

    /// Rebuilds the plan preview. `findingIDs == nil` keeps the legacy
    /// behavior (all current findings); the ② review screen passes the checked
    /// subset so the executed plan matches the selection (Batch I — same
    /// controller API, FileOrganizer-style optional parameter).
    @discardableResult
    func refreshPlanPreview(findingIDs: [UUID]? = nil) async -> Bool {
        clearExecution(.smartClean)
        do {
            let output = try await workspaceController.previewPlan(findingIDs: findingIDs ?? snapshot.findings.map(\.id))
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentPlan = output.actionPlan
                latestScanSummary = output.summary
                latestScanProgress = min(max(latestScanProgress, 1), 1)
                isCurrentSmartCleanPlanFresh = true
                clearPlan(.smartClean)
                clearExecution(.smartClean)
            }
            if workflowState(for: .smartClean).planNumber == nil, !output.actionPlan.items.isEmpty {
                // First numbered appearance of this plan (cached findings
                // revalidated without a scan): assign № + receipt so every
                // executable plan is ledger-addressable, then seed selection.
                assignPlanNumber(for: .smartClean)
                updateWorkflowState(for: .smartClean) { state in
                    state.selectedIDs = Set(output.actionPlan.items.map(\.id.uuidString))
                }
            }
            return true
        } catch {
            latestScanSummary = error.localizedDescription
            recordPlan(.smartClean, kind: .failed, message: error.localizedDescription)
            return false
        }
    }

    func executeCurrentPlan() async {
        guard !isPlanRunning, !currentPlan.items.isEmpty else {
            return
        }

        selection = .smartClean
        isPlanRunning = true
        planExecutionStartedAt = Date()
        clearExecution(.smartClean)
        // Narrow-layout drawer residue (review fix #12): collapse the evidence
        // drawer when execution starts so the progress/receipt view isn't
        // obscured by a stale evidence panel left open from ②.
        updateWorkflowState(for: .smartClean) { state in state.drawerPresented = false }
        // Receipt provenance (Batch I): plan facts + recovery baseline, so the
        // ④ receipt and the undo toast carry only real execution outcomes.
        let executedPlan = currentPlan
        let recoveryIDsBefore = Set(snapshot.recoveryItems.map(\.id))
        let workflowSnapshot = workflowState(for: .smartClean)

        do {
            let output = try await workspaceController.executePlan(planID: currentPlan.id)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                latestScanSummary = output.summary
                latestScanProgress = output.progressFraction
                clearPlan(.smartClean)
                clearExecution(.smartClean)
            }
            let newRecoveryItems = output.snapshot.recoveryItems.filter { !recoveryIDsBefore.contains($0.id) }
            let receipt = SmartCleanExecutionReceipt(
                planNumber: workflowSnapshot.planNumber,
                receiptCode: workflowSnapshot.receiptCode,
                completedAt: Date(),
                // Count only items that actually execute (round-15): the worker
                // skips .inspectPermission / .reviewEvidence (review-only) items,
                // so the full items.count would overstate 「Items Run」 for plans
                // that include review-only entries.
                executedItemCount: executedPlan.items.filter {
                    $0.kind != .inspectPermission && $0.kind != .reviewEvidence
                }.count,
                estimatedFreedBytes: executedPlan.estimatedBytes,
                summary: output.summary,
                recoveryItemIDs: newRecoveryItems.map(\.id),
                recoveryBytes: newRecoveryItems.reduce(Int64(0)) { $0 + $1.bytes },
                retentionDays: settings.recoveryRetentionDays
            )
            smartCleanExecutionReceipt = receipt
            smartCleanExecutionCompleted = true
            postSmartCleanExecutionToast(for: receipt)
            let didRefreshPlan = await refreshPlanPreview()
            if !didRefreshPlan {
                isCurrentSmartCleanPlanFresh = false
            }
        } catch {
            latestScanSummary = error.localizedDescription
            recordExecution(.smartClean, kind: .failed, message: error.localizedDescription)
            // Partial-completion receipt (③ error → 「查看回执」, spec §2.3):
            // failure reason only — no invented recovery facts (fail-closed).
            smartCleanExecutionReceipt = SmartCleanExecutionReceipt(
                planNumber: workflowSnapshot.planNumber,
                receiptCode: workflowSnapshot.receiptCode,
                completedAt: Date(),
                executedItemCount: executedPlan.items.count,
                estimatedFreedBytes: executedPlan.estimatedBytes,
                summary: error.localizedDescription,
                recoveryItemIDs: [],
                recoveryBytes: 0,
                retentionDays: settings.recoveryRetentionDays,
                failureReason: error.localizedDescription
            )
        }

        isPlanRunning = false
        planExecutionStartedAt = nil
    }

    /// 「已入账 №N · 撤销」 global toast (spec §2.3 Undo): tap opens the ledger
    /// (回链红线 §1.6); the undo action restores exactly the recovery items
    /// this run created — same items the ledger restore buttons target — and
    /// only renders when the run really produced recovery items (fail-closed).
    private func postSmartCleanExecutionToast(for receipt: SmartCleanExecutionReceipt) {
        let toastID = UUID()
        let message = receipt.planNumber.map { AtlasL10n.string("smartclean.toast.recorded", $0) } ?? receipt.summary
        // Undo gate aligned with the ④ receipt stamp (review fix #5): the same
        // `hasRestorePoint` predicate (IDs non-empty AND bytes > 0) decides
        // whether the undo action is offered. A run that recorded recovery
        // entries but zero bytes (e.g. metadata-only) can't meaningfully undo,
        // so the toast omits the action and the receipt hides its stamp too.
        let hasUndo = receipt.hasRestorePoint
        var undoAction: (@MainActor @Sendable () -> Void)?
        if hasUndo {
            undoAction = { [weak self] in
                self?.dismissToast(id: toastID)
                Task { await self?.undoSmartCleanExecution() }
            }
        }
        let toast = AtlasToastItem(
            id: toastID,
            message: message,
            tone: .success,
            systemImage: "checkmark.seal",
            actionTitle: hasUndo ? AtlasL10n.string("smartclean.undo.banner.action") : nil,
            onAction: undoAction,
            onTap: { [weak self] in
                self?.navigate(to: .ledger)
            }
        )
        withAnimation(AtlasMotion.standard) {
            toasts.append(toast)
        }
    }

    /// Undo of the latest smart-clean run: sequentially restores the recovery
    /// items recorded on the execution receipt through the existing
    /// `restoreRecoveryItem` chain (same recovery point as the ledger's
    /// restore entry points — 双入口一份真相, spec §2.3).
    ///
    /// Review fix #6: only clear `smartCleanExecutionCompleted` when at least one
    /// restore actually succeeded. If every restore failed (helper offline,
    /// files missing), the execution result stays recorded and a failure toast is
    /// surfaced — never silently clear state we could not reverse.
    func undoSmartCleanExecution() async {
        guard let receipt = smartCleanExecutionReceipt else {
            return
        }
        // Determine which recorded recovery items are still present and restorable.
        let restorableIDs = receipt.recoveryItemIDs.filter { itemID in
            snapshot.recoveryItems.contains { $0.id == itemID }
        }
        // Nothing recorded AND nothing restorable ⇒ no-op success: clear the
        // execution state as before (a run with no recovery delta has nothing to
        // reverse). This is distinct from #6's failure case below.
        if receipt.recoveryItemIDs.isEmpty && restorableIDs.isEmpty {
            smartCleanExecutionCompleted = false
            smartCleanExecutionReceipt = nil
            return
        }
        var anyRestored = false
        for itemID in restorableIDs {
            let didRestore = await restoreRecoveryItemReportingSuccess(itemID)
            if didRestore { anyRestored = true }
        }
        if anyRestored {
            smartCleanExecutionCompleted = false
            smartCleanExecutionReceipt = nil
        } else if !restorableIDs.isEmpty {
            // #6: items were present to restore but every restore failed — surface
            // it instead of silently clearing execution state we could not reverse.
            postSmartCleanUndoFailedToast()
        } else {
            // Items were recorded but none are currently restorable (already
            // consumed / evicted elsewhere): treat as no-op success and clear.
            smartCleanExecutionCompleted = false
            smartCleanExecutionReceipt = nil
        }
    }

    /// Failure toast for an undo that could not reverse any recovery item
    /// (review fix #6): the user tapped 「撤销」 and nothing came back. Tapping
    /// the toast opens the ledger where the recovery entries still live.
    private func postSmartCleanUndoFailedToast() {
        let toastID = UUID()
        let toast = AtlasToastItem(
            id: toastID,
            message: AtlasL10n.string("smartclean.undo.failed.message"),
            tone: .warning,
            systemImage: "exclamationmark.triangle",
            onTap: { [weak self] in
                self?.navigate(to: .ledger)
            }
        )
        withAnimation(AtlasMotion.standard) {
            toasts.append(toast)
        }
    }

    func refreshApps() async {
        await reloadAppsInventory(
            navigateToApps: true,
            resetPreview: true,
            restoreStatus: latestAppRestoreRefreshStatus
        )
    }

    func previewAppUninstall(appID: UUID) async {
        guard !isAppActionRunning else {
            return
        }

        selection = .apps
        isAppActionRunning = true
        activePreviewAppID = appID
        activeUninstallAppID = nil
        latestAppRestoreRefreshStatus = nil

        do {
            let output = try await workspaceController.previewAppUninstall(appID: appID)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentAppPreview = output.actionPlan
                currentPreviewedAppID = appID
                latestAppsSummary = output.summary
            }
        } catch {
            latestAppsSummary = error.localizedDescription
        }

        activePreviewAppID = nil
        isAppActionRunning = false
    }

    func rescanLeftovers(appID: UUID) async {
        guard !isAppActionRunning else {
            return
        }

        selection = .apps
        isAppActionRunning = true
        activePreviewAppID = appID
        activeUninstallAppID = nil
        // Clear stale snapshot counts from any prior restore cycle
        pendingRestoreSnapshotCategoryCounts = nil

        do {
            let output = try await workspaceController.previewAppUninstall(appID: appID)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentAppPreview = output.actionPlan
                currentPreviewedAppID = appID
                latestAppsSummary = output.summary
                // Clear divergence state after re-scan
                if var status = latestAppRestoreRefreshStatus {
                    status.evidenceDivergenceDetected = false
                    status.divergentCategories = []
                    latestAppRestoreRefreshStatus = status
                }
            }
        } catch {
            latestAppsSummary = error.localizedDescription
        }

        activePreviewAppID = nil
        isAppActionRunning = false
    }

    func executeAppUninstall(appID: UUID) async {
        guard !isAppActionRunning else {
            return
        }

        selection = .apps
        isAppActionRunning = true
        activePreviewAppID = nil
        activeUninstallAppID = appID
        latestAppRestoreRefreshStatus = nil

        do {
            let output = try await workspaceController.executeAppUninstall(appID: appID, planID: currentAppPreview?.id)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentAppPreview = nil
                currentPreviewedAppID = nil
                latestAppsSummary = output.summary
            }
        } catch {
            latestAppsSummary = error.localizedDescription
        }

        activeUninstallAppID = nil
        isAppActionRunning = false
    }

    // MARK: - 契约一：按 source 索引的结果写入（规格 §1.2(1)）

    /// 计划层结果写入。`source` 是必填参数 —— 没有“写到别的屏”这个形状。
    private func recordPlan(
        _ source: AtlasActionSource,
        kind: AtlasActionOutcomeKind,
        message: String,
        recovery: AtlasActionRecovery? = nil
    ) {
        var entry = sourceOutcomes[source] ?? AtlasSourceOutcomes()
        entry.plan = AtlasActionOutcome(source: source, kind: kind, message: message, recovery: recovery)
        sourceOutcomes[source] = entry
    }

    /// 执行层结果写入。
    private func recordExecution(
        _ source: AtlasActionSource,
        kind: AtlasActionOutcomeKind,
        message: String,
        recovery: AtlasActionRecovery? = nil
    ) {
        var entry = sourceOutcomes[source] ?? AtlasSourceOutcomes()
        entry.execution = AtlasActionOutcome(source: source, kind: kind, message: message, recovery: recovery)
        sourceOutcomes[source] = entry
    }

    private func clearPlan(_ source: AtlasActionSource) {
        guard var entry = sourceOutcomes[source] else { return }
        entry.plan = nil
        if entry.isEmpty { sourceOutcomes[source] = nil } else { sourceOutcomes[source] = entry }
    }

    private func clearExecution(_ source: AtlasActionSource) {
        guard var entry = sourceOutcomes[source] else { return }
        entry.execution = nil
        if entry.isEmpty { sourceOutcomes[source] = nil } else { sourceOutcomes[source] = entry }
    }

    /// 某 source 的最近一次结果（执行层优先）。
    func outcome(for source: AtlasActionSource) -> AtlasActionOutcome? {
        sourceOutcomes[source]?.latest
    }

    /// Smart Clean 计划层结果。**视图必须按 kind 分流**：
    /// `.advisory` 走 `AtlasCallout(tone: .warning)`，只有 `.failed` 走 `AtlasErrorState`
    /// （`NEW-1`：受限模式软提示曾被一律渲染成失败标题）。
    var smartCleanPlanOutcome: AtlasActionOutcome? { sourceOutcomes[.smartClean]?.plan }
    var fileOrganizerPlanOutcome: AtlasActionOutcome? { sourceOutcomes[.fileOrganizer]?.plan }
    /// 台账自己的结果槽（`P0-1`：此前台账恢复失败没有任何槽位可写）。
    var ledgerOutcome: AtlasActionOutcome? { outcome(for: .ledger) }
    /// Apps 自己的结果槽（`F-07`：`recordExecution(.apps, …)` 此前只写不读）。
    var appsOutcome: AtlasActionOutcome? { outcome(for: .apps) }

    /// `F-08`：`P1-16` 的台账过期清理 advisory 此前**只写不出清** ——
    /// `clearPlan(.ledger)` 全仓零命中，用户进过一次台账后，那条横幅会
    /// 一直挂在台账屏上，跨导航、跨会话都不消失。
    ///
    /// **出清时机 = 用户在台账屏上真正看到过它。** 判据放在**视图的
    /// `onAppear`**，而不是「写入后 N 秒」或「下一次启动」：
    /// 契约五 §5.2 第 10 条要求的是「不静默消失」（保留可见性），
    /// 不是「永远可见」。一次性提示在**已读**后出清，既满足可见性，
    /// 又不制造粘性噪音 —— 与 `AtlasToast` 的「自动消失不适合持久信息，
    /// 只适合 `.succeeded`」的分工一致（规格 §1.3）：本 advisory 之所以
    /// 不能用 toast，正因为它**语义上必须持续到用户看见**。
    ///
    /// 只清 `.advisory` 的 **plan 槽**：同一槽位后来若被写成 `.failed`
    /// （恢复失败），那是**新结果**，不得被这次「已读」一并抹掉。
    func acknowledgeLedgerPruneNotice() {
        guard sourceOutcomes[.ledger]?.plan?.isAdvisory == true else { return }
        clearPlan(.ledger)
    }

    // 下两条是**只读投影**（不再是可写状态）：写入只经 `recordExecution(_:kind:message:)`，
    // 因而不存在“把 A 屏的错误写进 B 屏”的形状。保留原名以收敛调用点。
    var smartCleanExecutionIssue: String? { sourceOutcomes[.smartClean]?.execution?.message }
    var fileOrganizerExecutionIssue: String? { sourceOutcomes[.fileOrganizer]?.execution?.message }

    /// 回执「撤销」三态（规格 §1.2(2)）。
    /// 判定规则：「条件不满足」≠「控件不适用」——凡动作可恢复但本次无可恢复项，
    /// 一律 `.unavailable(reason)`（禁用 + 理由），**不得隐藏**。
    func undoAvailability(hasRestorePoint: Bool) -> AtlasUndoAvailability {
        hasRestorePoint
            ? .available
            : .unavailable(reason: AtlasL10n.string("action.undo.unavailable.noRecoverableItem"))
    }

    /// File Organizer 回执「撤销」的三态（`P0-2`）。
    /// 判据与 `undoFileOrganizerExecution()` 的首步 guard **同源**：快照里是否
    /// 还有一条 `.fileOrganizer` 的恢复项。此前该控件**无任何门控**（总是可点），
    /// 点了找不到恢复项就静默 return —— 全产品唯一承诺「把文件搬回来」的控件在说谎。
    var fileOrganizerUndoAvailability: AtlasUndoAvailability {
        hasFileOrganizerRecoveryItem
            ? .available
            : .unavailable(reason: AtlasL10n.string("action.undo.unavailable.noRecoverableItem"))
    }

    private var hasFileOrganizerRecoveryItem: Bool {
        snapshot.recoveryItems.contains { item in
            if case .fileOrganizer = item.payload { return true }
            return false
        }
    }

    func restoreRecoveryItem(_ itemID: UUID) async {
        guard restoringRecoveryItemID == nil else {
            return
        }

        // 台账详情面板的「恢复」——结果归属 .ledger。
        await restoreRecoveryItemCore(itemID, source: .ledger)
    }

    /// Core restore that reports per-call success (review fix #6): the undo path
    /// needs to know whether at least one item really came back before it is safe
    /// to clear `smartCleanExecutionCompleted`. Existing callers (apps restore,
    /// ledger) still use `restoreRecoveryItem` which ignores the result.
    @discardableResult
    func restoreRecoveryItemReportingSuccess(_ itemID: UUID) async -> Bool {
        guard restoringRecoveryItemID == nil else {
            return false
        }
        // Smart Clean 回执的「撤销」——结果归属 .smartClean。
        await restoreRecoveryItemCore(itemID, source: .smartClean)
        return lastRestoreDidSucceed
    }

    /// Shared restore body; sets `lastRestoreDidSucceed` so callers can branch.
    private func restoreRecoveryItemCore(_ itemID: UUID, source restoreSource: AtlasActionSource = .ledger) async {
        lastRestoreDidSucceed = false

        let restoredItem = snapshot.recoveryItems.first(where: { $0.id == itemID })
        // Capture snapshot category counts for divergence detection after reload
        pendingRestoreSnapshotCategoryCounts = restoredItem?.appRecoveryPayload.flatMap {
            Self.categoryCountsFromSnapshot($0.uninstallSnapshot)
        }
        let restoreStatus = restoredItem?.appRecoveryPayload.map { payload in
            // Prefer snapshot reviewOnlyItemCount over legacy evidence count:
            // legacy mapping (AtlasAppFootprintEvidenceCategory) drops 4 categories
            // (savedState, containers, groupContainers, miscLeftovers), so
            // uninstallEvidence.reviewOnlyItemCount undercounts when a snapshot exists.
            let snapshotItemCount = payload.uninstallSnapshot?.reviewOnlyItemCount
            let legacyItemCount = payload.uninstallEvidence.reviewOnlyItemCount
            let bestItemCount = snapshotItemCount ?? legacyItemCount
            return AtlasAppPostRestoreRefreshStatus(
                appName: payload.app.name,
                bundleIdentifier: payload.app.bundleIdentifier,
                bundlePath: payload.app.bundlePath,
                state: .refreshing,
                recordedLeftoverItems: max(bestItemCount, payload.app.leftoverItems)
            )
        }
        let shouldRefreshAppsAfterRestore = restoreStatus != nil
        restoringRecoveryItemID = itemID
        if let restoreStatus {
            latestAppRestoreRefreshStatus = restoreStatus
        }

        do {
            let output = try await workspaceController.restoreItems(itemIDs: [itemID])
            // 契约一 §1.2(4)：磁盘还原（restoreMappings 非空）与仅状态还原必须
            // 映射到**不同的 recovery 载荷**，而不是仅文案不同。判据与 worker 侧
            // 一致（AtlasScaffoldWorkerService 的 `restoreMappings 非空` 分支）。
            let restoreScope: AtlasActionRestoreScope =
                (restoredItem?.restoreMappings?.isEmpty == false) ? .onDisk : .atlasOnly
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                // P0-1：结果写进**发起恢复的那个 source 的槽位**，不再落到
                // latestScanSummary（那是 Smart Clean 的状态行 —— 台账失败此前
                // 只在智能清理页可见，台账屏零呈现）。
                recordExecution(
                    restoreSource,
                    kind: .succeeded,
                    message: output.summary,
                    recovery: AtlasActionRecovery(
                        scope: restoreScope,
                        itemCount: 1,
                        retentionDays: settings.recoveryRetentionDays
                    )
                )
                // `TS-01`：这里原先是**无条件** `clearExecution(.smartClean)`，
                // 现已**整条删除**。追溯其语义来源（HEAD 的
                // `smartCleanExecutionIssue = nil`）：旧模型里那是**不带 source
                // 标识**的单一 `String?`，`= nil` 的真实意图是「本次恢复的结果
                // 覆盖掉本屏上一条结果」—— 先清旧值、再写新值。
                //
                // 新模型下这一步既是多余的、又是有害的：
                // · **多余**：`recordExecution(restoreSource, …)` 内部是
                //   `entry.execution = AtlasActionOutcome(...)`（赋值，非追加），
                //   对本 source 已经完成了覆盖。
                // · **有害**：它固定写死 `.smartClean`，成了**跨 source 误伤** ——
                //   从台账恢复一条记录，会把 Smart Clean 自己那条执行结果一并抹掉
                //   （`smartCleanExecutionIssue` 是它的消费点，Smart Clean 屏上的
                //   错误横幅会无声消失）。`I-1` 只钉了写入方向，清除方向无人守。
                //
                // 两个错误版本已排除，留档以免回退：
                // ① `clearExecution(restoreSource)` —— 会立刻清掉上一行刚写入的
                //    成功记录（`.smartClean` 来源的恢复永远看不到自己的结果）；
                // ② `if restoreSource != .smartClean { clearExecution(.smartClean) }`
                //    —— 从台账恢复仍会误伤，只是把 bug 收窄了一点。
                if shouldRefreshAppsAfterRestore {
                    currentAppPreview = nil
                    currentPreviewedAppID = nil
                    recordExecution(.apps, kind: .succeeded, message: output.summary)
                }
            }
            lastRestoreDidSucceed = true
            // `P1-16` 补偿：这一项是被**恢复**的，不是被清理的 —— 从「见过」集合剔除。
            forgetSeenRecoveryItem(itemID)
            if shouldRefreshAppsAfterRestore {
                await reloadAppsInventory(
                    navigateToApps: false,
                    resetPreview: true,
                    loadingSummary: output.summary,
                    restoreStatus: restoreStatus
                )
            } else {
                await refreshPlanPreview()
            }
        } catch {
            // Clear transient restore state to prevent stale data from leaking
            // into the next refreshApps() call, which would produce false divergence.
            pendingRestoreSnapshotCategoryCounts = nil
            latestAppRestoreRefreshStatus = nil

            let persistedState = repository.loadState()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = persistedState.snapshot
                currentPlan = persistedState.currentPlan
                settings = persistedState.settings
            }
            syncAppearance()
            // P0-1 的直接修复：失败写进**台账自己的槽位**，台账屏据它渲染。
            recordExecution(restoreSource, kind: .failed, message: error.localizedDescription)
        }

        restoringRecoveryItemID = nil
    }

    /// `P2-12`：排除项此前**没有任何写回调** —— 视图只能只读渲染。
    func addExcludedPath(_ path: String) async {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !settings.excludedPaths.contains(trimmed) else { return }
        await updateSettings { $0.excludedPaths.append(trimmed) }
    }

    func removeExcludedPath(_ path: String) async {
        await updateSettings { $0.excludedPaths.removeAll { $0 == path } }
    }

    func setRecoveryRetentionDays(_ days: Int) async {
        await updateSettings { settings in
            settings.recoveryRetentionDays = days
        }
    }

    func setNotificationsEnabled(_ isEnabled: Bool) async {
        if isEnabled, snapshot.permissions.first(where: { $0.kind == .notifications })?.isGranted != true {
            _ = await notificationPermissionRequester()
        }
        await updateSettings { settings in
            settings.notificationsEnabled = isEnabled
        }
        await inspectPermissions()
    }

    func requestNotificationPermission() async {
        _ = await notificationPermissionRequester()
        await inspectPermissions()
    }

    func setLanguage(_ language: AtlasLanguage) async {
        // Always apply — even if settings already match, UI may be stale
        AtlasL10n.setCurrentLanguage(language)
        withAnimation(.snappy(duration: 0.2)) {
            settings.language = language
        }
        refreshLocalizedReadySummaries()

        // Persist in background
        await updateSettings { _ in }

        if !snapshot.findings.isEmpty {
            await refreshPlanPreview()
        }
        currentAppPreview = nil
        currentPreviewedAppID = nil
        latestAppRestoreRefreshStatus = nil
    }

    func setTheme(_ theme: AtlasTheme) async {
        withAnimation(.snappy(duration: 0.2)) {
            settings.theme = theme
        }
        NSApp.appearance = theme.nsAppearance
        await updateSettings { _ in }
    }

    func refreshCurrentRoute() async {
        switch selection ?? .overview {
        case .overview:
            await refreshHealthSnapshot()
        case .smartClean:
            await runSmartCleanScan()
        case .fileOrganizer:
            break  // File Organizer requires user to select folders and tap scan; no auto-scan on route change
        case .apps:
            await refreshApps()
        case .ledger:
            break
        case .permissions:
            await inspectPermissions()
        case .settings, .about:
            break
        }
    }

    func navigate(to route: AtlasRoute) {
        withAnimation(.snappy(duration: 0.2)) {
            selection = route
        }
    }

    func openTaskCenter() {
        withAnimation(.snappy(duration: 0.2)) {
            isTaskCenterPresented = true
        }
    }

    func closeTaskCenter() {
        withAnimation(.snappy(duration: 0.2)) {
            isTaskCenterPresented = false
        }
    }

    func toggleTaskCenter() {
        withAnimation(.snappy(duration: 0.2)) {
            isTaskCenterPresented.toggle()
        }
    }

    // MARK: - Workflow ViewState (Calm Ledger §2.3)

    /// Read accessor — returns a default-initialized state for routes that have
    /// no stored state yet (no dictionary write on read).
    func workflowState(for route: AtlasRoute) -> AtlasWorkflowViewState {
        workflowStates[route] ?? AtlasWorkflowViewState()
    }

    func updateWorkflowState(for route: AtlasRoute, _ mutate: (inout AtlasWorkflowViewState) -> Void) {
        var state = workflowStates[route] ?? AtlasWorkflowViewState()
        mutate(&state)
        workflowStates[route] = state
    }

    /// Assigns the next ledger № and derives the scan receipt for a freshly
    /// produced plan (called on scan completion). № change clears the
    /// plan-scoped selection/filter (spec §2.3 selection scope = single plan).
    func assignPlanNumber(for route: AtlasRoute, scanDate: Date = Date()) {
        let number = nextLedgerNumber()
        let receipt = AtlasLedgerReceipt.code(findings: snapshot.findings, scanDate: scanDate)
        updateWorkflowState(for: route) { state in
            if state.planNumber != number {
                state.selectedIDs = []
                state.riskFilter = nil
            }
            state.planNumber = number
            state.receiptCode = receipt
            state.currentStage = AtlasWorkflowStageMap.reviewStage
            state.displayedStage = AtlasWorkflowStageMap.reviewStage
            state.rescanConfirmationPending = false
        }
    }

    /// Rescan confirmed: the old № is void (its task runs stay in the ledger;
    /// Batch J renders the superseded status), the workflow returns to ① scan.
    func supersedePlan(for route: AtlasRoute) {
        if route == .smartClean {
            // The superseded plan is void: its execution outcome and freshness
            // go with it, so resolve-on-render lands on ① (无计划/已失效) and
            // can never get stuck on ② or ④ between confirm and the new scan.
            smartCleanExecutionCompleted = false
            smartCleanExecutionReceipt = nil
            isCurrentSmartCleanPlanFresh = false
        }
        updateWorkflowState(for: route) { state in
            state.planNumber = nil
            state.receiptCode = nil
            state.selectedIDs = []
            state.riskFilter = nil
            state.evidenceSelectionID = nil
            state.drawerPresented = false
            state.currentStage = AtlasWorkflowStageMap.scanStage
            state.displayedStage = AtlasWorkflowStageMap.scanStage
            state.rescanConfirmationPending = false
        }
    }

    /// Cmd+Shift+R intent — only raises the flag; the confirmation dialog
    /// („当前计划 №N 将作废") is presented by the feature screen (Batch I),
    /// which calls `supersedePlan(for:)` on confirm.
    func requestRescanConfirmation(for route: AtlasRoute) {
        updateWorkflowState(for: route) { state in
            state.rescanConfirmationPending = true
        }
    }

    private func nextLedgerNumber() -> Int {
        // First use seeds from the existing task-run count + 1 (PER da8c42f).
        ledgerNumberStore.next(fallbackBase: snapshot.taskRuns.count + 1)
    }

    /// Ledger № prefix for an ACTIVE task-center row (spec §3.1): only
    /// queued/running runs of a workflow that currently holds a plan №.
    func workflowPlanNumber(for taskRun: TaskRun) -> Int? {
        guard taskRun.status == .running || taskRun.status == .queued else {
            return nil
        }
        switch taskRun.kind {
        case .scan, .executePlan:
            return workflowStates[.smartClean]?.planNumber
        case .organizeFiles:
            return workflowStates[.fileOrganizer]?.planNumber
        case .uninstallApp, .restore, .inspectPermissions:
            return nil
        }
    }

    /// Ledger entry id ("run.<uuid>") of the most recent task run of the given
    /// kinds, so a receipt's 「在台账中查看」back-link opens the Ledger on the
    /// matching run instead of the default first entry (round-5 回链红线 §1.6).
    func ledgerEntryIDForLatestRun(matching kinds: Set<TaskKind>) -> String? {
        guard let run = snapshot.taskRuns
            .filter({ kinds.contains($0.kind) })
            .max(by: { ($0.finishedAt ?? $0.startedAt) < ($1.finishedAt ?? $1.startedAt) })
        else { return nil }
        return "run.\(run.id.uuidString)"
    }

    // MARK: - Toast Management

    func showToast(_ message: String, tone: AtlasTone = .neutral, systemImage: String? = nil) {
        let toast = AtlasToastItem(message: message, tone: tone, systemImage: systemImage)
        withAnimation(AtlasMotion.standard) {
            toasts.append(toast)
        }
    }

    func dismissToast(id: UUID) {
        withAnimation(AtlasMotion.standard) {
            toasts.removeAll { $0.id == id }
        }
    }

    private func updateSettings(_ mutate: (inout AtlasSettings) -> Void) async {
        var updated = settings
        mutate(&updated)

        do {
            let output = try await workspaceController.updateSettings(updated)
            AtlasL10n.setCurrentLanguage(output.settings.language)
            withAnimation(.snappy(duration: 0.2)) {
                settings = output.settings
            }
            syncAppearance()
        } catch {
            latestAppsSummary = error.localizedDescription
        }
    }

    private func syncAppearance() {
        // Optional-chain: bare `swift test` runs have no NSApplication (NSApp is nil).
        // With a real app instance the assignment behaves exactly as before.
        NSApp?.appearance = settings.theme.nsAppearance
    }

    private func refreshLocalizedReadySummaries() {
        if !isScanRunning && !isPlanRunning {
            latestScanSummary = AtlasL10n.string("model.scan.ready")
        }
        if !isAppActionRunning {
            latestAppsSummary = AtlasL10n.string("model.apps.ready")
        }
        if !isPermissionsRefreshing {
            latestPermissionsSummary = AtlasL10n.string("model.permissions.ready")
        }
        if !isFileOrganizerScanning && !isFileOrganizerExecuting {
            fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.ready")
        }
    }

    // MARK: - File Organizer

    /// 契约三 §3.2(3) / `I-5`（降级形式）：系统级授权前的 app 内作用域说明。
    ///
    /// 规格 §7.1 把 `I-5` 拆成两半：可自动化的那一半要求「凡是能发起扫描的调用
    /// 路径，必然先写入 preamble 状态」；不可自动化的那一半（真实时序：TCC 弹窗
    /// 出现时 app 内已渲染说明）列为 `macos-gui-acceptance` 的人工验收项。
    ///
    /// 视图在 `false` 时渲染 `fileorganizer.scan.preamble.*`；本函数一进入就置位，
    /// 因此作用域说明**必然先于**触发 TCC 的那次调用出现在屏幕上。
    @Published private(set) var fileOrganizerScanPreambleShown = false

    func runFileOrganizerScan(folderPaths: [String]) async {
        fileOrganizerScanPreambleShown = true
        guard !isFileOrganizerScanning else { return }

        isFileOrganizerScanning = true
        fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.scanning")
        // `P2-8`（契约三 §3.2(6)）：与 SmartClean 的权限分支对齐。此前 FO **没有任何
        // 权限分支**，权限受限会直接落到 catch 并被渲染成
        // `fileorganizer.status.executionFailed`（「文件整理未能完成」）—— 用户不知道
        // 该去「权限」页授权，只会反复重试或以为 App 坏了。现为 `.advisory`，
        // 走 `AtlasCallout(tone: .warning)` 的非错误渲染路径。
        if !fileOrganizerRequiredPermissionsReady {
            recordPlan(
                .fileOrganizer,
                kind: .advisory,
                message: AtlasL10n.string("model.scan.limited.permissions")
            )
        }
        fileOrganizerProgress = 0
        scannedFolders = folderPaths
        clearExecution(.fileOrganizer)
        fileOrganizerExecutionCompleted = false
        fileOrganizerMovedCount = 0
        fileOrganizerExecutionReceipt = nil
        // Clear residual entries so a failed scan can't leave a stale plan
        // marked fresh (audit verify gap): regenerateFileOrganizerPlan is a
        // no-op on empty entries, preserving the scan-failure issue below.
        fileOrganizerEntries = []
        // Round-21: a new scan supersedes the previous plan's №/receipt — clear
        // them so `refreshFileOrganizerPreview` assigns a FRESH №/#XXXX over the
        // new plan (parity with SmartClean, which re-numbers on every plan-
        // producing scan via assignPlanNumber). Previously the
        // `planNumber == nil` guard left the FIRST scan's stale №/#XXXX on the
        // toolbar chip and later execute receipt even after scanning different
        // folders. Only the two stale identity fields are cleared — FileOrganizer
        // deliberately decouples numbering from selection-clearing (unlike the
        // shared assignPlanNumber), so entry selection is left untouched.
        updateWorkflowState(for: .fileOrganizer) { state in
            state.planNumber = nil
            state.receiptCode = nil
        }

        if folderPaths.count > 1 {
            // Multiple folders — surface the combined set early; the worker
            // still takes all paths in a single call.
            let folderNames = folderPaths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
            fileOrganizerScanSummary = AtlasL10n.string("fileorganizer.progress.scanningFolder", folderNames, 1, 1)
            fileOrganizerProgress = 0.1
        }

        do {
            let output = try await workspaceController.fileOrganizerScan(folderPaths: folderPaths)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                fileOrganizerEntries = output.entries
                fileOrganizerScanSummary = output.summary
                fileOrganizerProgress = output.progressFraction
                isFileOrganizerPlanFresh = false
                fileOrganizerHasPreviewResults = false
                clearPlan(.fileOrganizer)
            }
        } catch {
            fileOrganizerScanSummary = error.localizedDescription
            fileOrganizerProgress = 0
            // `P2-8`：权限受限**不是**「文件整理未能完成」。未授权时保持 `.advisory`
            // （非错误态），不得渲染成执行失败。
            if fileOrganizerRequiredPermissionsReady {
                recordPlan(.fileOrganizer, kind: .failed, message: error.localizedDescription)
            } else {
                recordPlan(
                    .fileOrganizer,
                    kind: .advisory,
                    message: AtlasL10n.string("model.scan.limited.permissions")
                )
            }
        }

        // Pipeline trigger restored (audit P0 #7 + P1 #19): the Calm Ledger
        // refactor (commit 62f30d7) dropped the only call sites of
        // `onRefreshPreview`/`onClassify`, so after a scan the plan was never
        // generated (`isFileOrganizerPlanFresh` stayed false) and custom rules
        // never ran — the workflow was stranded on ①scan. Classify the fresh
        // entries against the current rules, then generate the plan so the
        // stage advances ①scan → ②rules.
        //
        // Run classify→preview BEFORE clearing the scan flag so the flag covers
        // the whole scan→classify→preview chain (final-audit state race):
        // otherwise a second scan or a rule/destination edit could interleave
        // during the two worker round-trips and clobber the in-flight pipeline.
        await regenerateFileOrganizerPlan()

        isFileOrganizerScanning = false
    }

    /// Reclassify all current entries against the latest rules + destination,
    /// then regenerate the preview plan and mark it fresh. The single pipeline
    /// trigger for scan completion, rule edits, and destination/recursive
    /// changes (audit P0 #7 + P1 #19 + P2 #15) — keeps the plan and every
    /// `proposedDestination` in sync with live settings. No-op when nothing has
    /// been scanned yet.
    private func regenerateFileOrganizerPlan() async {
        guard !fileOrganizerEntries.isEmpty else { return }
        // Don't reclassify while an execute is mid-flight (final-audit state
        // race): an edit during execute would clobber the entries/plan the
        // worker is moving against. The new rules take effect on the next
        // scan/preview.
        guard !isFileOrganizerExecuting else { return }
        await classifyFileOrganizerEntries(entryIDs: [])
        await refreshFileOrganizerPreview(entryIDs: [])
    }

    func classifyFileOrganizerEntries(entryIDs: [UUID]) async {
        guard !isFileOrganizerClassifying else { return }

        isFileOrganizerClassifying = true
        fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.classifying")

        do {
            let output = try await workspaceController.fileOrganizerClassify(entryIDs: entryIDs)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                fileOrganizerEntries = output.entries
                fileOrganizerScanSummary = output.summary
            }
        } catch {
            fileOrganizerScanSummary = error.localizedDescription
        }

        isFileOrganizerClassifying = false
    }

    func refreshFileOrganizerPreview(entryIDs: [UUID]) async {
        clearExecution(.fileOrganizer)
        do {
            let output = try await workspaceController.fileOrganizerPreviewPlan(entryIDs: entryIDs)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentFileOrganizerPlan = output.actionPlan
                fileOrganizerScanSummary = output.summary
                isFileOrganizerPlanFresh = true
                fileOrganizerHasPreviewResults = false
                clearPlan(.fileOrganizer)
                clearExecution(.fileOrganizer)
            }
            // Calm Ledger §2.3: every executable plan is ledger-addressable.
            // Assign № + receipt on the plan's first fresh appearance — WITHOUT
            // the SmartClean-specific side effects (the shared assignPlanNumber
            // also clears selectedIDs/riskFilter and forces stage; FileOrganizer
            // owns its own entry selection and stage is resolve-on-render
            // anyway). (review round-1: FileOrganizer plans were never numbered,
            // so the receipt chip / №N markers / task-center row stayed empty.)
            if workflowState(for: .fileOrganizer).planNumber == nil, !output.actionPlan.items.isEmpty {
                let number = nextLedgerNumber()
                let receipt = AtlasLedgerReceipt.code(forPlan: output.actionPlan, scanDate: Date())
                updateWorkflowState(for: .fileOrganizer) { state in
                    state.planNumber = number
                    state.receiptCode = receipt
                }
            }
        } catch {
            fileOrganizerScanSummary = error.localizedDescription
            recordPlan(.fileOrganizer, kind: .failed, message: error.localizedDescription)
        }
    }

    func updateFileOrganizerDestination(_ path: String) async {
        // FileOrganizer destinations are confined to the user's home (audit
        // security #22): reject bases that resolve outside home so files can
        // never be moved into /Applications, /Library, etc. The worker also
        // enforces this as a hard backstop at execute time.
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        // Resolve symlinks (final-audit security parity) so a base like
        // ~/Organized that symlinks to /Applications is rejected here too, not
        // only by the worker backstop.
        let resolved = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .resolvingSymlinksInPath().path
        let accepted = resolved == home || resolved.hasPrefix(home + "/")
        await updateSettings { settings in
            if accepted {
                settings.fileOrganizerDestinationBasePath = path
            }
        }
        if accepted {
            // Re-derive destinations for already-scanned entries so files land
            // in the new base, not the stale one (audit P2 #15).
            await regenerateFileOrganizerPlan()
        }
    }

    func updateFileOrganizerRecursiveScan(_ recursive: Bool) async {
        await updateSettings { settings in
            settings.fileOrganizerRecursiveScan = recursive
        }
    }

    func updateFileOrganizerRules(_ rules: [FileOrganizerRule]) async {
        await updateSettings { settings in
            settings.fileOrganizerCustomRules = rules
        }
        fileOrganizerRules = rules
        // Rule edits must take effect immediately for already-scanned entries
        // (audit P1 #19 + P2 #15) — reclassify so preview/execute honor them.
        await regenerateFileOrganizerPlan()
    }

    func undoFileOrganizerExecution() async {
        guard let recoveryItem = snapshot.recoveryItems.first(where: { item in
            if case .fileOrganizer = item.payload { return true }
            return false
        }) else {
            // 契约一 §1.2(2)（`CT-04` 的落点）：**「条件不满足」≠「控件不适用」**。
            // 撤销对文件整理**是可恢复动作**，只是本次没有对应恢复项 —— 按规格
            // 「凡动作可恢复但本次无可恢复项，**一律落 `.unavailable(reason)`**，
            // 不得隐藏」，这是**默认态**。
            //
            // 此前这里是**裸 `return`**：用户点了「撤销」，画面毫无变化，
            // 也无从知道为什么 —— 正是审计 `P0-2` 说的「无门控渲染」的孪生缺陷
            // （控件在，点了不动）。现写入本 source 的结果槽，由文件整理屏
            // 按 kind 分流渲染（`FileOrganizerStageViews.swift:63-83` 的
            // 非 `.failed` 分支走 `AtlasCallout`）。
            //
            // 写 **plan 槽**而非 execution 槽：这不是一次执行的结果（压根没执行），
            // 而是「这个动作现在不可用」的前置条件陈述。
            recordPlan(
                .fileOrganizer,
                kind: .unavailable(reason: AtlasL10n.string("action.undo.unavailable.noRecoverableItem")),
                message: AtlasL10n.string("action.undo.unavailable.noRecoverableItem")
            )
            return
        }

        restoringRecoveryItemID = recoveryItem.id
        do {
            let output = try await workspaceController.restoreItems(itemIDs: [recoveryItem.id])
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                fileOrganizerEntries = []
                currentFileOrganizerPlan = ActionPlan(title: "", items: [], estimatedBytes: 0)
                isFileOrganizerPlanFresh = false
                fileOrganizerHasPreviewResults = false
                fileOrganizerExecutionCompleted = false
                fileOrganizerMovedCount = 0
                fileOrganizerExecutionReceipt = nil
                fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.ready")
            }
        } catch {
            // Worker may have partially succeeded — verify files actually returned to original locations
            let allRestored = recoveryItem.restoreMappings?.allSatisfy { mapping in
                let restored = FileManager.default.fileExists(atPath: (mapping.originalPath as NSString).expandingTildeInPath)
                let sourceGone = !FileManager.default.fileExists(atPath: (mapping.trashedPath as NSString).expandingTildeInPath)
                return restored && sourceGone
            } ?? false
            if allRestored {
                withAnimation(.snappy(duration: 0.24)) {
                    snapshot.recoveryItems.removeAll { $0.id == recoveryItem.id }
                    snapshot.fileOrganizerEntries = []
                    fileOrganizerEntries = []
                    currentFileOrganizerPlan = ActionPlan(title: "", items: [], estimatedBytes: 0)
                    isFileOrganizerPlanFresh = false
                    fileOrganizerHasPreviewResults = false
                    fileOrganizerExecutionCompleted = false
                    fileOrganizerMovedCount = 0
                    fileOrganizerExecutionReceipt = nil
                    fileOrganizerScanSummary = AtlasL10n.string("model.fileorganizer.ready")
                }
            } else {
                recordExecution(.fileOrganizer, kind: .failed, message: error.localizedDescription)
            }
        }
        restoringRecoveryItemID = nil
    }

    func executeFileOrganizerPlan() async {
        guard !isFileOrganizerExecuting, !currentFileOrganizerPlan.items.isEmpty else { return }

        isFileOrganizerExecuting = true
        clearExecution(.fileOrganizer)

        do {
            let output = try await workspaceController.fileOrganizerExecutePlan(planID: currentFileOrganizerPlan.id)
            let movedCount = output.movedCount
            let failedCount = output.failedCount
            // Total failure (audit #8): the worker accepted but moved nothing.
            // Surface it as a failure with entries retained for retry — never
            // a silent "0 files organized" success.
            let allFailed = movedCount == 0 && failedCount > 0
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                fileOrganizerEntries = output.snapshot.fileOrganizerEntries
                fileOrganizerMovedCount = movedCount
                fileOrganizerProgress = output.progressFraction
                isFileOrganizerPlanFresh = false
                fileOrganizerHasPreviewResults = false
                clearPlan(.fileOrganizer)
                let foStored = workflowState(for: .fileOrganizer)
                if allFailed {
                    fileOrganizerExecutionCompleted = false
                    let reason = AtlasL10n.string("fileorganizer.status.executionFailed")
                    recordExecution(.fileOrganizer, kind: .failed, message: reason)
                    fileOrganizerScanSummary = reason
                    fileOrganizerExecutionReceipt = FileOrganizerExecutionReceipt(
                        planNumber: foStored.planNumber,
                        receiptCode: foStored.receiptCode,
                        completedAt: Date(),
                        movedItemCount: 0,
                        summary: reason,
                        failureReason: reason
                    )
                } else {
                    clearExecution(.fileOrganizer)
                    fileOrganizerExecutionCompleted = true
                    fileOrganizerScanSummary = AtlasL10n.string("fileorganizer.callout.executionComplete.detail", movedCount)
                    // Receipt (§1.6 fail-closed): every field from real
                    // execution output. planNumber/receiptCode come from the
                    // workflow state (assigned at scan completion).
                    fileOrganizerExecutionReceipt = FileOrganizerExecutionReceipt(
                        planNumber: foStored.planNumber,
                        receiptCode: foStored.receiptCode,
                        completedAt: Date(),
                        movedItemCount: movedCount,
                        summary: fileOrganizerScanSummary,
                        failureReason: nil,
                        failedItemCount: failedCount
                    )
                }
            }
        } catch {
            fileOrganizerScanSummary = error.localizedDescription
            recordExecution(.fileOrganizer, kind: .failed, message: error.localizedDescription)
            // Partial-completion receipt (spec §2.3 ④ error → 「查看回执」):
            // fail-closed §1.6 — on failure we cannot confirm how many files
            // moved before the error, so movedItemCount is 0 (never the stale
            // count left over from a prior successful run, which previously made
            // the receipt falsely claim moves that did not happen — round-3).
            // The receipt view suppresses the moved-items row when
            // failureReason != nil (mirrors SmartCleanReceiptView).
            let foStored = workflowState(for: .fileOrganizer)
            fileOrganizerExecutionReceipt = FileOrganizerExecutionReceipt(
                planNumber: foStored.planNumber,
                receiptCode: foStored.receiptCode,
                completedAt: Date(),
                movedItemCount: 0,
                summary: fileOrganizerScanSummary,
                failureReason: error.localizedDescription
            )
        }

        isFileOrganizerExecuting = false
    }

    func dryRunFileOrganizerPlan() async {
        guard !currentFileOrganizerPlan.items.isEmpty else { return }
        let itemCount = currentFileOrganizerPlan.items.count
        let estimatedBytes = currentFileOrganizerPlan.estimatedBytes
        do {
            let output = try await workspaceController.fileOrganizerDryRun(planID: currentFileOrganizerPlan.id)
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                currentFileOrganizerPlan = output.actionPlan
                fileOrganizerScanSummary = output.summary
                // Dry-run success advances ② rules → ③ preview (round-4).
                fileOrganizerHasPreviewResults = true
            }
            let sizeStr = ByteCountFormatter.string(fromByteCount: estimatedBytes, countStyle: .file)
            let msg = AtlasL10n.string(
                itemCount == 1
                    ? "fileorganizer.dryRun.success.one"
                    : "fileorganizer.dryRun.success.other",
                "\(itemCount)", sizeStr
            )
            showToast(msg, tone: .success, systemImage: "checkmark.circle")
        } catch {
            showToast(
                AtlasL10n.string("fileorganizer.dryRun.error", error.localizedDescription),
                tone: .danger,
                systemImage: "exclamationmark.triangle"
            )
        }
    }

    private func reloadAppsInventory(
        navigateToApps: Bool,
        resetPreview: Bool,
        loadingSummary: String? = nil,
        restoreStatus: AtlasAppPostRestoreRefreshStatus? = nil
    ) async {
        guard !isAppActionRunning else {
            return
        }

        if navigateToApps {
            selection = .apps
        }
        isAppActionRunning = true
        activePreviewAppID = nil
        activeUninstallAppID = nil
        if resetPreview {
            currentAppPreview = nil
            currentPreviewedAppID = nil
        }
        latestAppsSummary = loadingSummary ?? AtlasL10n.string("model.apps.refreshing")

        do {
            let output = try await workspaceController.listApps()
            withAnimation(.snappy(duration: 0.24)) {
                snapshot = output.snapshot
                latestAppsSummary = output.summary
                latestAppRestoreRefreshStatus = refreshedAppRestoreStatus(
                    from: restoreStatus ?? latestAppRestoreRefreshStatus,
                    apps: output.apps
                )
            }
        } catch {
            latestAppsSummary = error.localizedDescription
            // Clear stale snapshot counts — the refresh failed so we can't compare
            pendingRestoreSnapshotCategoryCounts = nil
            if let existingStatus = restoreStatus ?? latestAppRestoreRefreshStatus {
                latestAppRestoreRefreshStatus = AtlasAppPostRestoreRefreshStatus(
                    appName: existingStatus.appName,
                    bundleIdentifier: existingStatus.bundleIdentifier,
                    bundlePath: existingStatus.bundlePath,
                    state: .stale,
                    recordedLeftoverItems: existingStatus.recordedLeftoverItems,
                    refreshedLeftoverItems: nil,
                    issueDescription: error.localizedDescription
                )
            }
        }

        isAppActionRunning = false
    }

}

private extension RecoveryItem {
    var appRecoveryPayload: AtlasAppRecoveryPayload? {
        guard case let .app(payload)? = payload else {
            return nil
        }
        return payload
    }
}

private extension AtlasAppModel {
    func refreshedAppRestoreStatus(
        from status: AtlasAppPostRestoreRefreshStatus?,
        apps: [AppFootprint]
    ) -> AtlasAppPostRestoreRefreshStatus? {
        guard let status else {
            return nil
        }

        guard let refreshedApp = apps.first(where: {
            $0.bundlePath == status.bundlePath || $0.bundleIdentifier == status.bundleIdentifier
        }) else {
            return AtlasAppPostRestoreRefreshStatus(
                appName: status.appName,
                bundleIdentifier: status.bundleIdentifier,
                bundlePath: status.bundlePath,
                state: .stale,
                recordedLeftoverItems: status.recordedLeftoverItems,
                refreshedLeftoverItems: nil,
                issueDescription: status.issueDescription
            )
        }

        // Detect evidence divergence: compare fresh scan evidenceSummary against snapshot group counts
        let snapshotCounts = pendingRestoreSnapshotCategoryCounts
        let freshSummary = refreshedApp.evidenceSummary
        var divergentCategories: [AtlasAppEvidenceCategory] = []
        var divergenceDetected = false

        if let snapshotCounts, let freshSummary {
            for category in AtlasAppEvidenceCategory.allCases {
                let snapshotCount = snapshotCounts[category] ?? 0
                let freshCount = freshSummary[category] ?? 0
                if snapshotCount != freshCount {
                    divergentCategories.append(category)
                }
            }
            divergenceDetected = !divergentCategories.isEmpty
        }

        // Clear the pending snapshot counts after use
        pendingRestoreSnapshotCategoryCounts = nil

        return AtlasAppPostRestoreRefreshStatus(
            appName: refreshedApp.name,
            bundleIdentifier: refreshedApp.bundleIdentifier,
            bundlePath: refreshedApp.bundlePath,
            state: .refreshed,
            recordedLeftoverItems: status.recordedLeftoverItems,
            refreshedLeftoverItems: refreshedApp.leftoverItems,
            issueDescription: nil,
            evidenceDivergenceDetected: divergenceDetected,
            divergentCategories: divergentCategories
        )
    }

    /// Extract per-category counts from a snapshot, using path-level granularity to match
    /// `MacAppsInventoryAdapter.computeEvidenceSummary` which counts individual existing paths
    /// per category (e.g., supportFiles may count 2 if both `{appName}` and `{bundleID}` paths
    /// exist). Using `group.items.count` (number of candidate URLs that existed on disk at
    /// capture time) aligns with the adapter's path-level counting.
    static func categoryCountsFromSnapshot(_ snapshot: AtlasAppUninstallEvidenceSnapshot?) -> [AtlasAppEvidenceCategory: Int]? {
        guard let snapshot else { return nil }
        var counts: [AtlasAppEvidenceCategory: Int] = [:]
        for group in snapshot.reviewOnlyGroups {
            counts[group.category] = group.items.count
        }
        return counts
    }
}
