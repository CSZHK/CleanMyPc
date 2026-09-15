import AtlasDesignSystem
import AtlasDomain
import SwiftUI

/// Task-center popover (Calm Ledger §3.1 壳层表面): surface cards with mono
/// data rows; running rows carry their ledger № prefix when the owning
/// workflow has an assigned plan.
struct TaskCenterView: View {
    /// 任务中心可见条数上限（`P2-14`：截断必须说明，见 `taskcenter.more`）。
    static let visibleTaskRunLimit = 5

    let taskRuns: [TaskRun]
    let summary: String
    /// Resolves the ledger № prefix for a run (nil ⇒ no prefix). Injected so
    /// the view stays model-free and testable.
    var planNumber: (TaskRun) -> Int? = { _ in nil }
    let onOpenLedger: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                Text(AtlasL10n.string("taskcenter.title"))
                    .font(AtlasTypography.sectionTitle)

                Text(summary)
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // `P2-15`：空态**互斥渲染**。此前同一条件下渲染两个互相矛盾的标题
            // （callout「当前没有**匹配**的任务活动」＋ empty「**还没有**任务」），
            // 用户无法判断自己是没搜到还是没跑过 —— 而这里根本没有搜索框。
            // 空态只留 `AtlasEmptyState` 一处说法。
            if !taskRuns.isEmpty {
                AtlasCallout(
                    title: AtlasL10n.string("taskcenter.callout.active.title"),
                    detail: AtlasL10n.string("taskcenter.callout.active.detail"),
                    tone: .success,
                    systemImage: "clock.arrow.circlepath"
                )
            }

            if taskRuns.isEmpty {
                AtlasEmptyState(
                    title: AtlasL10n.string("taskcenter.empty.title"),
                    detail: AtlasL10n.string("taskcenter.empty.detail"),
                    systemImage: "list.bullet.rectangle.portrait",
                    tone: .neutral
                )
            } else {
                VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                    ForEach(taskRuns.prefix(Self.visibleTaskRunLimit)) { taskRun in
                        TaskCenterRow(
                            taskRun: taskRun,
                            planNumber: planNumber(taskRun),
                            footnote: timelineFootnote(for: taskRun)
                        )
                    }

                    // `P2-14`：列表被截断时必须同屏说明。此前固定只渲染 5 条且
                    // **从不说明被截断** —— 用户看到正好 5 条会以为这就是全部
                    // （实测同一时刻状态文件里 `taskRuns = 147`）。
                    if taskRuns.count > Self.visibleTaskRunLimit {
                        Text(AtlasL10n.string("taskcenter.more", taskRuns.count - Self.visibleTaskRunLimit))
                            .font(AtlasTypography.caption)
                            .foregroundStyle(AtlasColor.textSecondary)
                            .accessibilityIdentifier("taskcenter.more")
                    }
                }
            }

            Button(action: onOpenLedger) {
                Label(AtlasL10n.string("taskcenter.openLedger"), systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.atlasPrimary)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("taskcenter.openLedger")
            .accessibilityHint(AtlasL10n.string("taskcenter.openLedger.hint"))
        }
        .padding(AtlasSpacing.xl)
        .frame(minWidth: 360, idealWidth: 430, maxWidth: 520)
        .background(AtlasColor.surface)
        .accessibilityIdentifier("taskcenter.panel")
    }

    private func timelineFootnote(for taskRun: TaskRun) -> String {
        let start = AtlasFormatters.shortDate(taskRun.startedAt)
        if let finishedAt = taskRun.finishedAt {
            return AtlasL10n.string("taskcenter.timeline.finished", start, AtlasFormatters.shortDate(finishedAt))
        }
        return AtlasL10n.string("taskcenter.timeline.running", start)
    }

}

/// One task run as a subdued surface card: icon · (№ +) title · summary ·
/// mono timeline footnote · status chip.
private struct TaskCenterRow: View {
    let taskRun: TaskRun
    let planNumber: Int?
    let footnote: String

    var body: some View {
        HStack(alignment: .top, spacing: AtlasSpacing.md) {
            Image(systemName: taskRun.kind.atlasSystemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(taskRun.status.atlasTone.tint)
                .frame(width: 24, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                HStack(spacing: AtlasSpacing.xs) {
                    if let planNumber {
                        Text("№\(planNumber)")
                            .font(AtlasTypography.ledgerNumber)
                            .foregroundStyle(AtlasColor.brand)
                            .accessibilityLabel(AtlasL10n.string("taskcenter.planNumber.a11y", planNumber))
                    }

                    Text(taskRun.kind.title)
                        .font(AtlasTypography.rowTitle)
                }

                Text(taskRun.summary)
                    .font(AtlasTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(footnote)
                    .font(AtlasTypography.dataCaption)
                    .monospacedDigit()
                    .foregroundStyle(AtlasColor.textTertiary)
            }

            Spacer(minLength: AtlasSpacing.sm)

            AtlasStatusChip(taskRun.status.title, tone: taskRun.status.atlasTone)
        }
        .padding(AtlasSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .fill(AtlasColor.surfaceSubdued)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
