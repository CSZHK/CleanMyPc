import AtlasApplication
import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Command column (spec §3 概览 指挥台)

/// Left column of the overview: a health ring + module entry rows. Each row
/// shows the module name, a one-line status (sourced from real model state),
/// and a chevron that navigates to the module.
///
/// The column is a **view-only** consumer — no business logic. Inputs come from
/// `OverviewFeatureView` (snapshot + closures). Health ring tone derives from
/// `diskUsedPercent` (>=85% warning, >=95% danger, else success/neutral).
public struct OverviewCommandColumn: View {
    private let snapshot: AtlasWorkspaceSnapshot
    private let requiredPermissionsReady: Bool
    private let onNavigateToSmartClean: (() -> Void)?
    private let onNavigateToApps: (() -> Void)?
    private let onNavigateToFileOrganizer: (() -> Void)?
    private let onNavigateToLedger: (() -> Void)?

    public init(
        snapshot: AtlasWorkspaceSnapshot,
        requiredPermissionsReady: Bool,
        onNavigateToSmartClean: (() -> Void)?,
        onNavigateToApps: (() -> Void)?,
        onNavigateToFileOrganizer: (() -> Void)?,
        onNavigateToLedger: (() -> Void)?
    ) {
        self.snapshot = snapshot
        self.requiredPermissionsReady = requiredPermissionsReady
        self.onNavigateToSmartClean = onNavigateToSmartClean
        self.onNavigateToApps = onNavigateToApps
        self.onNavigateToFileOrganizer = onNavigateToFileOrganizer
        self.onNavigateToLedger = onNavigateToLedger
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            healthRing
            moduleEntries
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .atlasCard()
    }

    // MARK: - Health ring

    @ViewBuilder
    private var healthRing: some View {
        let pct = snapshot.healthSnapshot?.diskUsedPercent ?? 0
        HStack(spacing: AtlasSpacing.lg) {
            AtlasCircularProgress(
                progress: min(max(pct / 100.0, 0), 1),
                tone: OverviewCommandColumn.tone(forDiskPercent: pct),
                lineWidth: 10,
                text: "\(Int(pct.rounded()))%"
            )
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(AtlasL10n.string("overview.command.health.title"))
                    .font(AtlasTypography.sectionTitle)
                Text(AtlasL10n.string("overview.command.health.subtitle"))
                    .font(AtlasTypography.bodySmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Module entries

    @ViewBuilder
    private var moduleEntries: some View {
        VStack(spacing: AtlasSpacing.sm) {
            entryRow(
                title: AtlasL10n.string("overview.command.entry.smartclean.title"),
                status: smartCleanStatus,
                tone: .neutral,
                systemImage: AtlasIcon.smartClean,
                action: onNavigateToSmartClean
            )
            entryRow(
                title: AtlasL10n.string("overview.command.entry.apps.title"),
                status: AtlasL10n.string("overview.command.entry.apps.status", snapshot.apps.count),
                tone: .neutral,
                systemImage: AtlasIcon.apps,
                action: onNavigateToApps
            )
            entryRow(
                title: AtlasL10n.string("overview.command.entry.organizer.title"),
                status: AtlasL10n.string(
                    "overview.command.entry.organizer.status",
                    snapshot.fileOrganizerEntries.count
                ),
                tone: .neutral,
                systemImage: "folder.badge.gearshape",
                action: onNavigateToFileOrganizer
            )
            entryRow(
                title: AtlasL10n.string("overview.command.entry.ledger.title"),
                status: AtlasL10n.string(
                    "overview.command.entry.ledger.status",
                    snapshot.recoveryItems.count
                ),
                tone: .neutral,
                systemImage: AtlasIcon.ledger,
                action: onNavigateToLedger
            )
        }
    }

    private var smartCleanStatus: String {
        if snapshot.findings.isEmpty {
            return AtlasL16nString.smartCleanIdle
        }
        return AtlasL10n.string(
            "overview.command.entry.smartclean.status.findings",
            snapshot.findings.count
        )
    }

    @ViewBuilder
    private func entryRow(
        title: String,
        status: String,
        tone: AtlasTone,
        systemImage: String,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AtlasSpacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: AtlasLayout.iconMD, weight: .medium))
                    .foregroundStyle(tone.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AtlasTypography.label)
                        .foregroundStyle(.primary)
                    Text(status)
                        .font(AtlasTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: AtlasSpacing.sm)

                Image(systemName: "chevron.right")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, AtlasSpacing.sm)
            .padding(.horizontal, AtlasSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(status))
    }

    // MARK: - Pure helpers (unit-tested)

    /// Health-ring tone from disk-used percent. <85 success, 85..95 warning,
    /// >95 danger. 0 (no health snapshot) reads as neutral.
    public static func tone(forDiskPercent pct: Double) -> AtlasTone {
        if pct <= 0 { return .neutral }
        if pct >= 95 { return .danger }
        if pct >= 85 { return .warning }
        return .success
    }
}

/// Tiny indirection to keep `smartCleanStatus` testable without L10n bootstrap.
/// Holds the idle-status string; the finding-count variant uses the L10n call.
enum AtlasL16nString {
    static var smartCleanIdle: String { AtlasL10n.string("overview.command.entry.smartclean.status.idle") }
}
