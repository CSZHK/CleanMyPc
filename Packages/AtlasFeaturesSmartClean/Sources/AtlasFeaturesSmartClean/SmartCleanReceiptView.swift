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
                    Button(action: onNavigateToLedger) {
                        Text(AtlasL10n.string("smartclean.receipt.viewInLedger"))
                            .font(AtlasTypography.label)
                            .foregroundStyle(AtlasColor.brand)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("smartclean.receipt.viewInLedger")

                    if receipt.hasRestorePoint, let onUndo {
                        Button(AtlasL10n.string("smartclean.undo.banner.action"), action: onUndo)
                            .buttonStyle(.atlasGhost)
                            .accessibilityIdentifier("smartclean.receipt.undo")
                    }
                }
            }
        }
    }

    private var factRows: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
            factRow(
                label: AtlasL10n.string("smartclean.receipt.items.label"),
                value: AtlasL10n.string("smartclean.receipt.items.value", receipt.executedItemCount)
            )
            if receipt.estimatedFreedBytes > 0 {
                factRow(
                    label: AtlasL10n.string("smartclean.receipt.estimated.label"),
                    value: AtlasFormatters.byteCount(receipt.estimatedFreedBytes)
                )
            }
            factRow(
                label: AtlasL10n.string("smartclean.receipt.completed.label"),
                value: AtlasFormatters.shortDate(receipt.completedAt)
            )
            if let code = receipt.receiptCode {
                factRow(label: AtlasL10n.string("smartclean.receipt.code.label"), value: "#\(code)")
            }
        }
    }

    private func factRow(label: String, value: String) -> some View {
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
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
    }
}
