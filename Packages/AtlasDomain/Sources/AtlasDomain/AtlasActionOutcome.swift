import Foundation

// MARK: - 契约一 —— 操作结果契约（实现规格 §1.2）

/// 操作结果的来源标识。
///
/// 规格 §1.2(1)：各屏**只订阅自己 source 的结果**，跨屏泄漏在类型层面变得不可表达。
/// 现状的 `String` 没有来源标识，所以台账恢复失败时错误被写进隔壁模块的
/// `latestScanSummary`（`P0-1`）——该形状在本类型下无法表达。
public enum AtlasActionSource: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case smartClean
    case fileOrganizer
    case ledger
    case apps
    case permissions

    public var id: String { rawValue }
}

/// 结果的种类。
///
/// `.failed` 与 `.advisory` 必须分开——`NEW-1` 的直接修复就是把受限模式软提示
/// 归入 `.advisory`，并为它走**非错误态**渲染（`AtlasCallout(tone: .warning)`），
/// 而不是 `AtlasErrorState`。
public enum AtlasActionOutcomeKind: Hashable, Sendable {
    case succeeded
    case failed
    /// 非阻断提示。渲染走 `AtlasCallout(tone: .warning)`。
    case advisory
    /// 动作可恢复，但本次无可恢复项 → 禁用控件 + 理由（规格 §1.2(2) 的默认态）。
    case unavailable(reason: String)
}

/// 恢复载荷：区分「文件回到了磁盘」与「Atlas 只是标记了状态」。
///
/// 规格 §1.2(4)：两者必须映射到**不同的 kind 或不同的 recovery 载荷**，
/// 而非仅文案不同。
public enum AtlasActionRestoreScope: String, Codable, Hashable, Sendable {
    /// 磁盘还原（`restoreMappings` 非空）——文件被移回原位置。
    case onDisk
    /// 仅状态还原（`atlasOnly`）——只在 Atlas 内标记，磁盘上的文件未被移动。
    case atlasOnly
}

public struct AtlasActionRecovery: Hashable, Sendable {
    public let scope: AtlasActionRestoreScope
    public let itemCount: Int
    /// 恢复保留窗口（天）。nil ⇒ 该结果不承诺恢复窗口。
    public let retentionDays: Int?

    public init(scope: AtlasActionRestoreScope, itemCount: Int, retentionDays: Int? = nil) {
        self.scope = scope
        self.itemCount = itemCount
        self.retentionDays = retentionDays
    }
}

/// 一条带来源标识的操作结果。
public struct AtlasActionOutcome: Identifiable, Hashable, Sendable {
    public let source: AtlasActionSource
    public let kind: AtlasActionOutcomeKind
    public let message: String
    public let recovery: AtlasActionRecovery?

    public init(
        source: AtlasActionSource,
        kind: AtlasActionOutcomeKind,
        message: String,
        recovery: AtlasActionRecovery? = nil
    ) {
        self.source = source
        self.kind = kind
        self.message = message
        self.recovery = recovery
    }

    public var id: String { "\(source.rawValue)::\(message)" }

    /// 规格 §1.2：只有 `.failed` 走错误态渲染。
    public var isError: Bool {
        if case .failed = kind { return true }
        return false
    }

    /// 规格 §1.2：`.advisory` 走非错误渲染路径。
    public var isAdvisory: Bool {
        if case .advisory = kind { return true }
        return false
    }

    /// `F-07`：`.succeeded` 的摘要本身就与各屏的**状态行**同文（apps 恢复成功写
    /// `output.summary`，紧接着 `refreshApps` 又把同一句写进 `latestAppsSummary`），
    /// 同屏渲染两遍是噪音。故渲染侧按「是否需要用户注意」分流，成功态交回状态行。
    public var isSuccess: Bool {
        if case .succeeded = kind { return true }
        return false
    }

    public var unavailableReason: String? {
        if case .unavailable(let reason) = kind { return reason }
        return nil
    }
}

// MARK: - 可撤销性三态（规格 §1.2(2)）

/// 任何撤销/恢复控件在**执行前**即处于以下三态之一，且**三态都可读**。
///
/// 判定规则（规格 §1.2(2)）：
/// - 「条件不满足」≠「控件不适用」
/// - 凡「动作可恢复但本次无可恢复项」，**一律落 `.unavailable(reason)`**（禁用 + 理由），
///   **不得隐藏**。这是**默认态**。
/// - 只有动作类型**根本不适用**时才允许 `.notApplicable`，且此时必须渲染缺席说明。
///
/// 明确禁止的两种现状：**无门控渲染**（FO 现状，`P0-2`）与**静默消失**
/// （Smart Clean 现状，`P1-8`）。
public enum AtlasUndoAvailability: Hashable, Sendable {
    /// 前置条件满足 → 渲染可点按钮。
    case available
    /// 动作可恢复，但本次无可恢复项 → 渲染**禁用控件 + 理由**。
    case unavailable(reason: String)
    /// 该控件对本屏的动作类型根本不适用 → 渲染**缺席说明**。
    case notApplicable(absenceNote: String)

    /// 控件是否应当在屏幕上**存在**（`.available` 与 `.unavailable` 都必须存在）。
    public var isPresent: Bool {
        switch self {
        case .available, .unavailable: return true
        case .notApplicable: return false
        }
    }

    public var isEnabled: Bool {
        if case .available = self { return true }
        return false
    }

    /// 同屏必须渲染的说明文案（`.unavailable` 的理由 / `.notApplicable` 的缺席说明）。
    public var explanation: String? {
        switch self {
        case .available: return nil
        case .unavailable(let reason): return reason
        case .notApplicable(let note): return note
        }
    }
}

// MARK: - 每个来源的状态槽（规格 §1.2(1)）

/// 模型层按 **source** 索引的状态槽。写入必须指定 source ——
/// 跨屏泄漏（把 A 屏的失败写进 B 屏的槽位）在本类型下不可表达。
///
/// 取代：`smartCleanPlanIssue` / `smartCleanExecutionIssue` /
/// `fileOrganizerPlanIssue` / `fileOrganizerExecutionIssue` 四个不带来源标识的 `String?`。
public struct AtlasSourceOutcomes: Hashable, Sendable {
    /// 计划层问题：`.failed` / `.advisory` / `.unavailable(reason)`。
    public var plan: AtlasActionOutcome?
    /// 执行层结果：承载「磁盘还原 vs 仅状态还原」的区分（§1.2(4)）。
    public var execution: AtlasActionOutcome?

    public init(plan: AtlasActionOutcome? = nil, execution: AtlasActionOutcome? = nil) {
        self.plan = plan
        self.execution = execution
    }

    /// 最近一次写入的结果（执行层优先——执行晚于计划）。
    public var latest: AtlasActionOutcome? { execution ?? plan }

    public var isEmpty: Bool { plan == nil && execution == nil }
}
