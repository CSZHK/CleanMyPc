import XCTest
@testable import AtlasDomain

/// `AtlasRenderClock` 与「fixture 是否真的走它」。
///
/// 为什么值得单测：README 截图的**可复现性**完全押在这个注入点上。不钉时钟时，
/// 重导 9 张里有 4 张会变（截图里烘焙了墙钟时间），而漂移守卫会在每次文案改动后
/// 要求重导 —— 于是每次改动都往 git 历史塞约 4 MB 新 blob。
///
/// 这些是**全局态**，所以每个用例都必须还原，否则会污染同进程里的其他测试。
final class AtlasRenderClockTests: XCTestCase {
    /// 与导出器 `ReadmeAssetExporter.renderInstant` 同一个瞬间。
    private let pinned = Date(timeIntervalSince1970: 1_760_000_000)

    override func tearDown() {
        AtlasRenderClock.setFixedInstant(nil)
        super.tearDown()
    }

    func testDefaultsToRealTimeAndIsNotPinned() {
        XCTAssertFalse(AtlasRenderClock.isPinned)
        XCTAssertEqual(
            AtlasRenderClock.now.timeIntervalSinceNow,
            0,
            accuracy: 5,
            "未钉死时必须跟随真实时间"
        )
    }

    func testPinnedInstantIsReturnedExactly() {
        AtlasRenderClock.setFixedInstant(pinned)
        defer { AtlasRenderClock.setFixedInstant(nil) }

        XCTAssertTrue(AtlasRenderClock.isPinned)
        XCTAssertEqual(AtlasRenderClock.now, pinned)
        // 连读两次也必须一模一样 —— 可复现性的最小要求。
        XCTAssertEqual(AtlasRenderClock.now, AtlasRenderClock.now)
    }

    func testUnpinningRestoresRealTime() {
        AtlasRenderClock.setFixedInstant(pinned)
        AtlasRenderClock.setFixedInstant(nil)

        XCTAssertFalse(AtlasRenderClock.isPinned)
        XCTAssertEqual(AtlasRenderClock.now.timeIntervalSinceNow, 0, accuracy: 5)
    }

    // MARK: - 机制守卫：fixture 必须**真的**走时钟

    /// 这条是本文件的核心。fixture 若被改回 `private static let now = Date()`，
    /// 它会立刻变红 —— 而那正是「截图不可复现」复发的方式。
    func testScaffoldFixturesTakeTheirTimestampsFromTheRenderClock() {
        AtlasRenderClock.setFixedInstant(pinned)
        defer { AtlasRenderClock.setFixedInstant(nil) }

        let runs = AtlasScaffoldFixtures.taskRuns(language: .en)
        let newest = try? XCTUnwrap(runs.map(\.startedAt).max())
        // fixture 里最新一条是 `now.addingTimeInterval(-300)`。
        XCTAssertEqual(
            newest,
            pinned.addingTimeInterval(-300),
            "fixture 的时间戳没有跟着 AtlasRenderClock 走 —— 截图将不可复现"
        )
    }

    /// 钉死之后，**连续两次取 fixture 必须产出完全相同的时间戳**。
    /// 这是「重导两次得到同样的图」在单元层面的等价物。
    func testFixtureTimestampsAreIdenticalAcrossCallsWhenPinned() {
        AtlasRenderClock.setFixedInstant(pinned)
        defer { AtlasRenderClock.setFixedInstant(nil) }

        let first = AtlasScaffoldFixtures.taskRuns(language: .en).map(\.startedAt)
        let second = AtlasScaffoldFixtures.taskRuns(language: .en).map(\.startedAt)

        XCTAssertFalse(first.isEmpty)
        XCTAssertEqual(first, second, "同一钉死时刻下两次生成的 fixture 必须一致")
    }

    /// 不钉死时两次调用**应当**不同（否则说明时钟根本没被 fixture 读到，
    /// 上一条会在「永远是同一个常量」的假象下通过）。
    ///
    /// 用两次 `state()` 之间夹一个极短等待来放大差异 —— fixture 的时间戳分辨率是秒，
    /// 不等待的话两次可能落在同一秒而误绿。
    func testFixtureTimestampsAdvanceWhenNotPinned() throws {
        AtlasRenderClock.setFixedInstant(nil)

        let first = try XCTUnwrap(AtlasScaffoldFixtures.taskRuns(language: .en).map(\.startedAt).max())
        Thread.sleep(forTimeInterval: 1.1)
        let second = try XCTUnwrap(AtlasScaffoldFixtures.taskRuns(language: .en).map(\.startedAt).max())

        XCTAssertGreaterThan(
            second,
            first,
            "未钉死时时间戳应当前进 —— 若相等，说明 fixture 其实没读时钟，"
                + "上一条「钉死后一致」就是假绿"
        )
    }
}
