import Foundation

/// 渲染参考时刻 —— 决定「现在」是几点。
///
/// 默认跟随真实时间。**只有 README 截图导出会钉死它**（`ATLAS_EXPORT_README_ASSETS_DIR`
/// 那条路径），正常交互运行的 app 从不碰 —— 所以引入本类型对产品行为零影响。
///
/// ## 为什么需要它
///
/// 截图里同时存在**两处**对「现在」的依赖，只钉一处仍不可复现：
///
/// 1. `AtlasScaffoldFixtures` 用 `now.addingTimeInterval(…)` 造任务时间戳 ——
///    于是**绝对时间**（`AtlasFormatters.shortDate`）每次渲染都不同。
/// 2. `AtlasFormatters.relativeDate` 的参考点原先是写死的 `Date()` ——
///    于是**相对时间**（"4 minutes ago"）就算日期钉死也随真实时间漂：
///    今天读作「11 个月前」，过几个月变成「1 年前」。
///
/// 两处必须走同一个注入点。实测：两处都不钉时，重导 9 张截图里有 4 张会变，
/// 每次给 git 历史增加约 4 MB blob —— 而漂移守卫会在每次文案改动后要求重导，
/// 于是这个代价是**每次改动都要付**。
///
/// ## 与 `AtlasL10n` 同款
///
/// `NSLock` 保护的进程级全局态：Swift 6 严格并发（Xcode/xcodegen 构建走
/// `SWIFT_VERSION: 6.0`）下也要能编过，所以不用裸 `static var`。
///
/// ## 调用方义务
///
/// 借了进程级状态就要还 —— 设了 `setFixedInstant` 的一方必须负责还原（用 `defer`）。
public enum AtlasRenderClock {
    private static let stateLock = NSLock()
    private static var storedInstant: Date?

    /// 当前的「现在」。未被钉死时返回真实时间。
    public static var now: Date {
        stateLock.withLock { storedInstant ?? Date() }
    }

    /// 是否已被钉死（供测试与导出器自检）。
    public static var isPinned: Bool {
        stateLock.withLock { storedInstant != nil }
    }

    /// 把「现在」钉死在 `instant`；传 `nil` 恢复跟随真实时间。
    public static func setFixedInstant(_ instant: Date?) {
        stateLock.withLock { storedInstant = instant }
    }
}
