import AtlasDesignSystem
import AtlasDomain
import AppKit
import Foundation

// MARK: - Ledger export report (pure function, spec §3 台账「导出报告」)

/// Builds a human-readable markdown report of the visible ledger content
/// (spec §3: 导出页脚注「本报告由 Atlas 在本机生成，仅供个人参考」).
///
/// Pure function: takes the same data the timeline shows + a closure that
/// resolves the stored № for a run (shell-owned counter) and returns a plain
/// markdown string. The view layer owns `NSSavePanel` (file IO stays out of
/// the pure builder). All copy is localized via `AtlasL10n`.
public enum LedgerExportBuilder {

    /// Inputs needed to render one report. `planNumber` is the stored counter
    /// number for a run (nil for runs created before the counter existed — the
    /// builder then falls back to the chronological display number, same rule
    /// as the timeline, so the report never invents numbers).
    public struct Input: Equatable, Sendable {
        public let title: String
        public let generatedAt: Date
        public let retentionDays: Int
        public let entries: [ExportEntry]
        public let summary: ExportSummary

        public init(
            title: String,
            generatedAt: Date,
            retentionDays: Int,
            entries: [ExportEntry],
            summary: ExportSummary
        ) {
            self.title = title
            self.generatedAt = generatedAt
            self.retentionDays = retentionDays
            self.entries = entries
            self.summary = summary
        }
    }

    public struct ExportEntry: Equatable, Sendable, Identifiable {
        public let id: String
        public let displayNumber: Int
        public let kind: String
        public let status: String
        public let summary: String
        public let startedAt: Date
        public let finishedAt: Date?
        public let recoveryBytes: Int64?

        public init(
            id: String,
            displayNumber: Int,
            kind: String,
            status: String,
            summary: String,
            startedAt: Date,
            finishedAt: Date?,
            recoveryBytes: Int64?
        ) {
            self.id = id
            self.displayNumber = displayNumber
            self.kind = kind
            self.status = status
            self.summary = summary
            self.startedAt = startedAt
            self.finishedAt = finishedAt
            self.recoveryBytes = recoveryBytes
        }
    }

    public struct ExportSummary: Equatable, Sendable {
        public let taskRunCount: Int
        public let recoveryItemCount: Int
        public let totalRecoveryBytes: Int64
        public let activeTaskCount: Int

        public init(taskRunCount: Int, recoveryItemCount: Int, totalRecoveryBytes: Int64, activeTaskCount: Int) {
            self.taskRunCount = taskRunCount
            self.recoveryItemCount = recoveryItemCount
            self.totalRecoveryBytes = totalRecoveryBytes
            self.activeTaskCount = activeTaskCount
        }
    }

    /// Renders the markdown report (pure). Locale-independent line breaks;
    /// localized copy for section headers, the body of each entry, and the
    /// mandated footer disclaimer.
    public static func render(_ input: Input) -> String {
        var lines: [String] = []
        lines.append("# \(input.title)")
        lines.append("")
        lines.append("- \(AtlasL10n.string("ledger.export.generated", AtlasFormatters.shortDate(input.generatedAt)))")
        lines.append("- \(AtlasL10n.string("ledger.export.retention", input.retentionDays))")
        lines.append("- \(AtlasL10n.string("ledger.export.summary.runs", input.summary.taskRunCount))")
        lines.append("- \(AtlasL10n.string("ledger.export.summary.recovery", input.summary.recoveryItemCount))")
        if input.summary.totalRecoveryBytes > 0 {
            lines.append("- \(AtlasL10n.string("ledger.export.summary.bytes", AtlasFormatters.byteCount(input.summary.totalRecoveryBytes)))")
        }
        lines.append("")
        lines.append("## \(AtlasL10n.string("ledger.export.section.entries"))")
        lines.append("")

        if input.entries.isEmpty {
            lines.append(AtlasL10n.string("ledger.export.empty"))
            lines.append("")
        } else {
            for entry in input.entries {
                lines.append("### №\(entry.displayNumber) · \(entry.kind)")
                lines.append("")
                lines.append("- \(AtlasL10n.string("ledger.export.entry.status", entry.status))")
                lines.append("- \(AtlasL10n.string("ledger.export.entry.started", AtlasFormatters.shortDate(entry.startedAt)))")
                if let finished = entry.finishedAt {
                    lines.append("- \(AtlasL10n.string("ledger.export.entry.finished", AtlasFormatters.shortDate(finished)))")
                }
                if let bytes = entry.recoveryBytes, bytes > 0 {
                    lines.append("- \(AtlasL10n.string("ledger.export.entry.recovery", AtlasFormatters.byteCount(bytes)))")
                }
                lines.append("")
                lines.append("> \(entry.summary)")
                lines.append("")
            }
        }

        // Mandated footer (spec §3 导出页脚注). Always present.
        lines.append("---")
        lines.append("")
        lines.append(AtlasL10n.string("ledger.export.footer"))
        lines.append("")

        return lines.joined(separator: "\n")
    }
}

// MARK: - View-layer IO helper (NSSavePanel stays out of the pure builder)

/// Bridges the pure `LedgerExportBuilder` to AppKit file IO. Kept in this file
/// so the coordinator stays under the view-file line budget (spec §5.1).
public enum LedgerExportController {

    /// Build the markdown report from the same inputs the timeline shows.
    public static func renderReport(
        taskRuns: [TaskRun],
        recoveryItems: [RecoveryItem],
        retentionDays: Int,
        planNumber: (TaskRun) -> Int?
    ) -> String {
        let numbers = LedgerEntryMapping.chronologicalDisplayNumbers(for: taskRuns, planNumber: planNumber)
        let entries = taskRuns.map { run in
            LedgerExportBuilder.ExportEntry(
                id: run.id.uuidString,
                displayNumber: numbers[run.id] ?? 0,
                kind: run.kind.title,
                status: run.status.title,
                summary: run.summary,
                startedAt: run.startedAt,
                finishedAt: run.finishedAt,
                recoveryBytes: nil
            )
        }
        let totalBytes = recoveryItems.map(\.bytes).reduce(Int64(0), +)
        let activeCount = taskRuns.filter { $0.status == .queued || $0.status == .running }.count
        let input = LedgerExportBuilder.Input(
            title: AtlasL10n.string("ledger.export.report.title"),
            generatedAt: Date(),
            retentionDays: retentionDays,
            entries: entries,
            summary: LedgerExportBuilder.ExportSummary(
                taskRunCount: taskRuns.count,
                recoveryItemCount: recoveryItems.count,
                totalRecoveryBytes: totalBytes,
                activeTaskCount: activeCount
            )
        )
        return LedgerExportBuilder.render(input)
    }

    /// Presents an `NSSavePanel` and writes the markdown. No-op if the user
    /// cancels. Safe to call on the main thread (AppKit is main-actor).
    public static func presentSavePanel(markdown: String) {
        let panel = NSSavePanel()
        panel.title = AtlasL10n.string("ledger.export.panel.save")
        panel.nameFieldStringValue = "atlas-ledger.md"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // Surface the write failure — the user explicitly tapped 保存, so a
            // silent `try?` would let them believe the report was saved when it
            // was not (round-6: read-only mount / disk full / invalid URL).
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = AtlasL10n.string("ledger.export.write.failed.title")
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: AtlasL10n.string("ledger.export.panel.cancel"))
            alert.runModal()
        }
    }
}
