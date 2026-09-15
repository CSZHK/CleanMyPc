import SwiftUI

// MARK: - 契约二 —— 破坏性确认四问（实现规格 §2.2(1)）

/// 破坏性确认弹窗的 ①②③ —— **全部非可选**，缺项编译不过。
///
/// 规格 §2.2(1) 的原话：**这不是文案模板，是弹窗构造的字段约束**。
/// 三条 `role: .destructive` 的最终确认此前都用一句自由文本拼后果，
/// 于是三条弹窗各自漏掉了不同的关键信息（`P0-3` 漏「能不能找回」、
/// `P0-4` 漏「移到哪」、`P0-5` 漏「这次有几项可恢复」）。
/// 把三问立成构造器参数后，「漏问」在编译期就不成立。
public struct AtlasDestructiveFacts: Equatable, Sendable {
    /// ① **会动什么** —— 作用对象（哪些应用 / 哪些文件 / 哪些项）。
    public let object: String
    /// ② **动到哪去** —— 目标位置（`P0-4` 的 `~/Organized` 必须出现在弹窗里）。
    public let destination: String
    /// ③ **能不能撤回 / 多久内 / 从哪撤** —— 恢复窗口与入口（`P0-3` 的缺失项）。
    public let recovery: String

    public init(object: String, destination: String, recovery: String) {
        self.object = object
        self.destination = destination
        self.recovery = recovery
    }
}

/// ④ **这次有几项可恢复** —— 条件性必需，**由类型区分**保证。
///
/// 规格 §7.1：`String?` 与 required init 都表达不了「当且仅当」。故按动作类型
/// 分两个构造：`.recoverable(...)` 携带 ④，`.plain(...)` 不携带 —— 作用于
/// 可恢复项集合的动作**无法**构造出缺 ④ 的弹窗。
public enum AtlasDestructiveConfirmation: Equatable, Sendable {
    /// 动作作用于**可恢复项集合** → ④ 必需。
    case recoverable(AtlasDestructiveFacts, recoverableCount: String)
    /// 动作类型**不**作用于可恢复项集合 → 无 ④。
    ///
    /// **本轮零实例，属有意保留（`CT-06` 的处置 = (a) 保留，不接生产、不删）**。
    ///
    /// 判据与依据：
    /// - 规格 §7.1 明写「④ 需按动作类型分**两个构造** —— `.recoverable(...)`（含 ④）
    ///   与 `.plain(...)`（不含）—— **由类型而非评审来保证**」。这正是 `I-4` 的④
    ///   「当且仅当」能被编译期守住的原因本身。
    /// - 若为消除「零构造」告警而删掉本 case，④ 就从「类型强制」退化为
    ///   「所有动作都必须填四项」，**`I-4` 的④载体随之消失**（§7 明确排除用
    ///   optionality 表达 —— `String?` 与 required init 都表达不了「当且仅当」）。
    /// - 本轮三条 `.destructive` 弹窗（`P0-3` 卸载 / `P0-4` 文件整理 / `P0-5` 智能清理）
    ///   的动作者**都**作用于可恢复项集合，故全部落 `.recoverable`。
    ///   将来出现「作用于不可恢复项」的破坏性动作时，**必须**落到本 case ——
    ///   这正是它存在的意义，而不是死代码。
    ///
    /// 故**不**为本 case 硬造调用点（那会为本不存在的场景伪造一个弹窗）。
    case plain(AtlasDestructiveFacts)

    public var facts: AtlasDestructiveFacts {
        switch self {
        case .recoverable(let facts, _): return facts
        case .plain(let facts): return facts
        }
    }

    public var recoverableCount: String? {
        if case .recoverable(_, let count) = self { return count }
        return nil
    }
}

/// 弹窗正文的渲染体：四问逐行，每行带稳定 `accessibilityIdentifier`
/// （守卫基座的一部分 —— `I-4` 的渲染断言靠它枚举）。
public struct AtlasDestructiveConfirmationMessage: View {
    private let confirmation: AtlasDestructiveConfirmation

    public init(_ confirmation: AtlasDestructiveConfirmation) {
        self.confirmation = confirmation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            line(confirmation.facts.object, identifier: "confirm.destructive.object")
            line(confirmation.facts.destination, identifier: "confirm.destructive.destination")
            line(confirmation.facts.recovery, identifier: "confirm.destructive.recovery")
            if let count = confirmation.recoverableCount {
                line(count, identifier: "confirm.destructive.recoverableCount")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(AtlasTypography.bodySmall)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(identifier)
    }
}
