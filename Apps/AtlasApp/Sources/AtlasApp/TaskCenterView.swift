import AtlasDesignSystem
import AtlasDomain
import SwiftUI

struct TaskCenterView: View {
    let taskRuns: [TaskRun]
    let summary: String
    let onOpenHistory: () -> Void

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
                VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                    ForEach(taskRuns.prefix(5)) { taskRun in
                        AtlasDetailRow(
                            title: taskRun.kind.title,
                            subtitle: taskRun.summary,
                            footnote: timelineFootnote(for: taskRun),
                            systemImage: icon(for: taskRun.kind),
                            tone: taskRun.status.tintTone
                        ) {
                            AtlasStatusChip(taskRun.status.title, tone: taskRun.status.tintTone)
                        }
                    }
                }
            }

            Button(action: onOpenHistory) {
                Label(AtlasL10n.string("taskcenter.openHistory"), systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("taskcenter.openHistory")
            .accessibilityHint(AtlasL10n.string("taskcenter.openHistory.hint"))
        }
        .padding(AtlasSpacing.xl)
        .frame(width: 430)
        .accessibilityIdentifier("taskcenter.panel")
    }

    private func timelineFootnote(for taskRun: TaskRun) -> String {
        let start = AtlasFormatters.shortDate(taskRun.startedAt)
        if let finishedAt = taskRun.finishedAt {
            return AtlasL10n.string("taskcenter.timeline.finished", start, AtlasFormatters.shortDate(finishedAt))
        }
        return AtlasL10n.string("taskcenter.timeline.running", start)
    }

    private func icon(for kind: TaskKind) -> String {
        switch kind {
        case .scan:
            return "sparkles"
        case .executePlan:
            return "play.circle"
        case .uninstallApp:
            return "trash"
        case .restore:
            return "arrow.uturn.backward.circle"
        case .inspectPermissions:
            return "lock.shield"
        }
    }
}

private extension TaskStatus {
    var tintTone: AtlasTone {
        switch self {
        case .queued:
            return .neutral
        case .running:
            return .warning
        case .completed:
            return .success
        case .failed, .cancelled:
            return .danger
        }
    }
}
