import AtlasDesignSystem
import AtlasDomain
import SwiftUI

/// Task-center popover (Calm Ledger §3.1 壳层表面): surface cards with mono
/// data rows; running rows carry their ledger № prefix when the owning
/// workflow has an assigned plan.
struct TaskCenterView: View {
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

            AtlasCallout(
                title: taskRuns.isEmpty ? AtlasL10n.string("taskcenter.callout.empty.title") : AtlasL10n.string("taskcenter.callout.active.title"),
                detail: taskRuns.isEmpty
                    ? AtlasL10n.string("taskcenter.callout.empty.detail")
                    : AtlasL10n.string("taskcenter.callout.active.detail"),
                tone: taskRuns.isEmpty ? .neutral : .success,
                systemImage: taskRuns.isEmpty ? "clock.badge.questionmark" : "clock.arrow.circlepath"
            )

            if taskRuns.isEmpty {
                AtlasEmptyState(
                    title: AtlasL10n.string("taskcenter.empty.title"),
                    detail: AtlasL10n.string("taskcenter.empty.detail"),
                    systemImage: "list.bullet.rectangle.portrait",
                    tone: .neutral
                )
            } else {
                VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                    ForEach(taskRuns.prefix(5)) { taskRun in
                        TaskCenterRow(
                            taskRun: taskRun,
                            planNumber: planNumber(taskRun),
                            footnote: timelineFootnote(for: taskRun)
                        )
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
