import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Receipt record

/// Facts of one executed cleanup plan, captured by the app model at execution
/// time. Every field is real data from the execution output — the receipt view
/// never invents values (spec §1.6 fail-closed):
/// - `recoveryItemIDs/recoveryBytes` come from the snapshot delta of recovery
///   items the run actually created (empty ⇒ the stamp badge does not render);
/// - `retentionDays` is the retention setting at execution time;
/// - `summary` is the worker's localized result line (or failure reason).
public struct SmartCleanExecutionReceipt: Equatable, Sendable {
    public var planNumber: Int?
    public var receiptCode: String?
    public var completedAt: Date
    public var executedItemCount: Int
    public var estimatedFreedBytes: Int64
    public var summary: String
    public var recoveryItemIDs: [UUID]
    public var recoveryBytes: Int64
    public var retentionDays: Int
    /// Set when the run stopped mid-way (③ error → 「查看回执」 partial receipt).
    public var failureReason: String?

    public init(
        planNumber: Int?,
        receiptCode: String?,
        completedAt: Date,
        executedItemCount: Int,
        estimatedFreedBytes: Int64,
        summary: String,
        recoveryItemIDs: [UUID],
        recoveryBytes: Int64,
        retentionDays: Int,
        failureReason: String? = nil
    ) {
        self.planNumber = planNumber
        self.receiptCode = receiptCode
        self.completedAt = completedAt
        self.executedItemCount = executedItemCount
        self.estimatedFreedBytes = estimatedFreedBytes
        self.summary = summary
        self.recoveryItemIDs = recoveryItemIDs
        self.recoveryBytes = recoveryBytes
        self.retentionDays = retentionDays
        self.failureReason = failureReason
    }

    /// The restore-point badge renders only when the run really created
    /// recovery items (fail-closed, spec §1.6).
    public var hasRestorePoint: Bool {
        !recoveryItemIDs.isEmpty && recoveryBytes > 0
    }
}

// MARK: - ④ Receipt view (warm ledger surface)

/// Stage-④ module receipt (spec §2.3 更名「回执」): the single plan's outcome on
/// warm ledger paper — result summary, mono facts, the −11° restore-point stamp
/// (only with a real restore point), and the 「在台账中查看 →」 back-link
/// (回链红线 §1.6: every № is one click away from its ledger entry).
struct SmartCleanReceiptView: View {
    let receipt: SmartCleanExecutionReceipt
    /// Undo entry that outlives the 8s toast (spec §2.3: 超时后仍可还原);
    /// nil — or no real restore point — hides the button (fail-closed).
    var onUndo: (() -> Void)?
    let onNavigateToLedger: () -> Void

    /// 契约一 §1.2(2) 的可撤销性三态，在**执行前**即可读。
    var undoAvailability: AtlasUndoAvailability {
        guard onUndo != nil else {
            return .notApplicable(absenceNote: AtlasL10n.string("action.undo.notApplicable.note"))
        }
        return receipt.hasRestorePoint
            ? .available
            : .unavailable(reason: AtlasL10n.string("action.undo.unavailable.noRecoverableItem"))
    }

    var body: some View {
        AtlasLedgerSurface(title: AtlasL10n.string("smartclean.receipt.title")) {
            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                if let failureReason = receipt.failureReason {
                    AtlasErrorState(
                        title: AtlasL10n.string("smartclean.status.executionFailed"),
                        message: failureReason,
                        layout: .inlineRow
                    )
                }

                HStack(alignment: .top, spacing: AtlasSpacing.xl) {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        if let number = receipt.planNumber {
                            Text(AtlasL10n.string("smartclean.stage.plan.number", number))
                                .font(AtlasTypography.ledgerNumber)
                                .foregroundStyle(AtlasColor.ledgerInk)
                                .accessibilityLabel(AtlasL10n.string("smartclean.stage.plan.number.a11y", number))
                        }

                        Text(receipt.summary)
                            .font(AtlasTypography.body)
                            .foregroundStyle(AtlasColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        factRows
                    }

                    Spacer(minLength: AtlasSpacing.sm)

                    if receipt.hasRestorePoint {
                        // Fact copy from the real execution outcome (§1.6).
                        AtlasStampBadge(
                            title: AtlasL10n.string("smartclean.receipt.stamp.title"),
                            subtitle: AtlasL10n.string(
                                "smartclean.receipt.stamp.facts",
                                AtlasFormatters.byteCount(receipt.recoveryBytes),
                                receipt.retentionDays
                            ),
                            numberText: receipt.planNumber.map { "\u{2116}\($0)" }
                        )
                        // The badge itself is decorative; voice the facts here.
                        .accessibilityHidden(true)
                    }
                }

                if receipt.hasRestorePoint {
                    Text(AtlasL10n.string(
                        "smartclean.receipt.stamp.facts.a11y",
                        AtlasFormatters.byteCount(receipt.recoveryBytes),
                        receipt.retentionDays
                    ))
                    .font(AtlasTypography.bodySmall)
                    .foregroundStyle(AtlasColor.textSecondary)
                }

                HStack(spacing: AtlasSpacing.lg) {
                    // atlasGhost (round-18): matches the sibling undo button + the
                    // FileOrganizer receipt back-link (round-15) — a plain text
                    // link fell below the branch's own a11y tap-target floor on
                    // this 回链 red-line control.
                    Button(AtlasL10n.string("smartclean.receipt.viewInLedger"), action: onNavigateToLedger)
                        .buttonStyle(.atlasGhost)
                        .accessibilityIdentifier("smartclean.receipt.viewInLedger")

                    // 契约一 §1.2(2) / I-3：控件**必须在场**。
                    // 现状（`P1-8`）是 `if receipt.hasRestorePoint` —— 无可恢复项时
                    // 按钮完全不渲染，用户把它读成「本次不需要撤销」而非「本次不可恢复」。
                    if undoAvailability.isPresent {
                        Button(AtlasL10n.string("smartclean.undo.banner.action")) { onUndo?() }
                            .buttonStyle(.atlasGhost)
                            .disabled(!undoAvailability.isEnabled)
                            .accessibilityIdentifier("smartclean.receipt.undo")
                    }
                }

                // 「禁用 + 理由」：三态都要可读，禁用态必须同屏给出理由。
                if let undoExplanation = undoAvailability.explanation {
                    Text(undoExplanation)
                        .font(AtlasTypography.bodySmall)
                        .foregroundStyle(AtlasColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("smartclean.receipt.undo.reason")
                }
            }
        }
    }

    private var factRows: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
        // `P2-6` / `I-10`：**实测事实组**。估算值不得与它等权并排。
        VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
            // Fact-only failure receipt (review fix #4): on a failure path the
            // count/bytes on the receipt are the *planned* figures, not measured
            // execution outcomes. We never claim 「执行 N 项 / 释放 X」 we did not
            // witness — the count is labelled 「计划 N 项」 (planned) and the freed
            // bytes row is suppressed entirely until execution actually succeeded.
            if receipt.failureReason != nil {
                factRow(
                    label: AtlasL10n.string("smartclean.receipt.items.planned.label"),
                    value: AtlasL10n.string("smartclean.receipt.items.value", receipt.executedItemCount),
                    identifier: "smartclean.receipt.fact.items"
                )
            } else {
                factRow(
                    label: AtlasL10n.string("smartclean.receipt.items.label"),
                    value: AtlasL10n.string("smartclean.receipt.items.value", receipt.executedItemCount),
                    identifier: "smartclean.receipt.fact.items"
                )
            }
            factRow(
                label: AtlasL10n.string("smartclean.receipt.completed.label"),
                value: AtlasFormatters.shortDate(receipt.completedAt),
                identifier: "smartclean.receipt.fact.completed"
            )
            if let code = receipt.receiptCode {
                factRow(
                    label: AtlasL10n.string("smartclean.receipt.code.label"),
                    value: "#\(code)",
                    identifier: "smartclean.receipt.fact.code"
                )
            }
        }
        // `children: .contain`：让**组容器自身**成为 AX 元素、同时把组内的
        // 事实行**保留为可枚举的子元素**。默认（`children: .ignore`）下 SwiftUI 会把
        // 整个 `VStack` 折叠成**单个**元素，容器标识还会**传播覆盖**子行的标识 ——
        // 实测探针：组内只剩 `identifier: 'smartclean.receipt.facts.measured'`、
        // `label: '执行项目'` 一个元素，行标识（`...fact.items` 等）全部消失，
        // `descendants` 仍恒为空集合（复审 `F-09` / `TS-04` 的空转形状会原样复发）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("smartclean.receipt.facts.measured")

        // `P2-6` / `I-10`：**估算值独立分组容器**。此前「预计释放」由一个
        // `if receipt.estimatedFreedBytes > 0` 守卫，和「执行项目 N 项」「完成时间」
        // 等**实测值等权并排** —— 用户执行完发现空间没涨那么多，判定「这 App 骗人」。
        // 现单独成组、带显式「估算（非实测）」标签，并挂稳定标识供 `I-10` 断言
        // （XCUITest 看不到「组」这个概念，没有标识就没有锚点）。
        if receipt.failureReason == nil, receipt.estimatedFreedBytes > 0 {
            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(AtlasL10n.string("smartclean.receipt.estimated.groupLabel"))
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                factRow(
                    label: AtlasL10n.string("smartclean.receipt.estimated.label"),
                    value: AtlasFormatters.byteCount(receipt.estimatedFreedBytes),
                    identifier: "smartclean.receipt.fact.estimated"
                )
            }
            .padding(AtlasSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                    .fill(AtlasColor.surfaceSubdued)
            )
            // 与实测组同因：`.contain` 保住子行标识，否则容器标识传播覆盖它。
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("smartclean.receipt.facts.estimated")
        }
        }
    }

    /// One factual row of the receipt.
    ///
    /// `I-10`：`identifier` 供给守卫的**可枚举锚点**。行用
    /// `.accessibilityElement(children: .ignore)` 折叠成**单个**元素，其子
    /// `Text` 不会以 `staticText` 出现在 AX 树里 —— 于是此前
    /// `measuredGroup.descendants(matching: .staticText)` **恒为空集合**，
    /// 「估算值不在实测组内」的断言恒真（复审 `F-09` / `TS-04` 的实证：
    /// 把估算行搬进实测组容器，守卫照旧通过）。
    ///
    /// 标识挂在**折叠后的行元素**上，因此可以被 `descendants(matching: .any)`
    /// 枚举到，使实测组的内容非空。
    private func factRow(label: String, value: String, identifier: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AtlasSpacing.md) {
            Text(label)
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textSecondary)
                .frame(minWidth: 72, alignment: .leading)
            Text(value)
                .font(AtlasTypography.dataBody)
                .monospacedDigit()
                .foregroundStyle(AtlasColor.ledgerInk)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier ?? "")
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}
