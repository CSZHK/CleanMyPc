import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Title area (plan № + stage bar)

/// Header strip under the screen title (spec §2.3 骨架): serif 「计划 №N」 with
/// the mono scan-receipt code, and the four-segment stage bar. Completed stages
/// are tappable look-back entries; the № reads localized for VoiceOver
/// (zh 「计划编号 N」 / en "Plan number N" — §1.6).
struct SmartCleanStageHeader: View {
    let planNumber: Int?
    let receiptCode: String?
    let effectiveStage: Int
    let completedStages: Set<Int>
    let onSelectStage: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            if let number = planNumber {
                HStack(spacing: AtlasSpacing.md) {
                    Text(AtlasL10n.string("smartclean.stage.plan.number", number))
                        .font(AtlasTypography.ledgerNumber)
                        .foregroundStyle(AtlasColor.ink)
                        .accessibilityLabel(AtlasL10n.string("smartclean.stage.plan.number.a11y", number))
                    if let receiptCode {
                        Text("#\(receiptCode)")
                            .font(AtlasTypography.dataCaption)
                            .monospacedDigit()
                            .foregroundStyle(AtlasColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }

            AtlasStageBar(
                stages: Self.stages,
                currentIndex: effectiveStage,
                completedIndices: completedStages,
                onSelect: onSelectStage
            )
        }
    }

    static var stages: [AtlasStage] {
        [
            AtlasStage(id: SmartCleanStage.scan, title: AtlasL10n.string("smartclean.stage.scan")),
            AtlasStage(id: SmartCleanStage.review, title: AtlasL10n.string("smartclean.stage.review")),
            AtlasStage(id: SmartCleanStage.execute, title: AtlasL10n.string("smartclean.stage.execute")),
            AtlasStage(id: SmartCleanStage.receipt, title: AtlasL10n.string("smartclean.stage.receipt")),
        ]
    }
}

// MARK: - Read-only look-back banner

/// 「回看 = 只读快照」 banner with the mandatory 「返回当前阶段」 entry (spec §2.3).
struct SmartCleanReadOnlyBanner: View {
    let onReturnToCurrent: () -> Void

    var body: some View {
        HStack(spacing: AtlasSpacing.md) {
            Image(systemName: "eye")
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textSecondary)
                .accessibilityHidden(true)
            Text(AtlasL10n.string("smartclean.stage.readonly.banner"))
                .font(AtlasTypography.bodySmall)
                .foregroundStyle(AtlasColor.textSecondary)
            Spacer(minLength: AtlasSpacing.sm)
            Button(AtlasL10n.string("smartclean.stage.readonly.return"), action: onReturnToCurrent)
                .buttonStyle(.atlasSecondary)
                .accessibilityIdentifier("smartclean.stage.returnToCurrent")
        }
        .padding(AtlasSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .fill(AtlasColor.surfaceSubdued)
        )
    }
}

// MARK: - Evidence drawer (<880pt container)

/// Non-modal slide-out drawer hosting the evidence panel (spec §2.4): the list
/// stays scrollable/checkable, Esc and outside-click dismiss, z-order above the
/// action bar with its bottom edge yielding the bar's height. Focus return to
/// the triggering row is handled by the coordinator on dismiss.
struct SmartCleanEvidenceDrawer<Content: View>: View {
    let bottomInset: CGFloat
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            HStack {
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: AtlasLayout.iconXS, weight: .bold))
                        .foregroundStyle(AtlasColor.textSecondary)
                        // 44pt hit target — the visible glyph stays at iconXS
                        // (round-2 a11y; matches the Toast close pattern).
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AtlasL10n.string("smartclean.drawer.close")))
            }

            ScrollView {
                content
            }
        }
        .padding(AtlasSpacing.lg)
        .frame(width: 340)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.card)
                .shadow(
                    color: Color.black.opacity(AtlasElevation.prominent.shadowOpacity),
                    radius: AtlasElevation.prominent.shadowRadius,
                    x: 0,
                    y: AtlasElevation.prominent.shadowY
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
        .padding(AtlasSpacing.md)
        .padding(.bottom, bottomInset)
        .onExitCommand(perform: onDismiss)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}
