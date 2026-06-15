import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Apps list (single-select)

/// Application browser list (spec §3 Apps row): icon / name / mono size /
/// leftover badge; **single-select** only (no batch uninstall — regression
/// red line). Grouped by footprint bucket (large / leftovers / other) and
/// selection-bound to `selectedAppID` (the host owns selection truth).
struct AppsListView: View {
    let apps: [AppFootprint]
    @Binding var selectedAppID: UUID?
    let showLeftoversOnly: Bool
    let onToggleLeftoversFilter: () -> Void
    let leftoversCount: Int
    let onRefresh: () -> Void
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                Text(AtlasL10n.string("apps.list.title"))
                    .font(AtlasTypography.label)
                    .foregroundStyle(.secondary)
                Spacer(minLength: AtlasSpacing.sm)
                AtlasFilterChip(
                    title: AtlasL10n.string("apps.filter.leftoversOnly"),
                    isSelected: showLeftoversOnly,
                    count: leftoversCount,
                    action: onToggleLeftoversFilter
                )
            }

            if apps.isEmpty {
                AtlasEmptyState(
                    title: AtlasL10n.string("apps.list.empty.title"),
                    detail: AtlasL10n.string("apps.list.empty.detail"),
                    systemImage: "square.stack.3d.up.slash",
                    tone: .neutral,
                    actionTitle: AtlasL10n.string("emptystate.action.refresh"),
                    onAction: onRefresh
                )
            } else {
                List(selection: $selectedAppID) {
                    ForEach(groupedApps) { group in
                        Section {
                            ForEach(group.apps) { app in
                                AppsListRow(app: app)
                                    .tag(app.id)
                                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                            }
                        } header: {
                            AppsListGroupHeader(title: group.title, count: group.apps.count, tone: group.tone)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .disabled(isRunning && apps.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AtlasSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.cardRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
    }

    private var groupedApps: [AppGroup] {
        var groups: [AppGroup] = []
        let grouped = Dictionary(grouping: apps, by: \.bucket)
        for bucket in AppBucket.displayOrder {
            guard let items = grouped[bucket], !items.isEmpty else { continue }
            groups.append(AppGroup(id: bucket.rawValue, title: bucket.title, tone: bucket.tone, apps: items))
        }
        return groups
    }
}

// MARK: - Row

private struct AppsListRow: View {
    let app: AppFootprint

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                Image(systemName: "app.fill")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(app.leftoverItems > 0 ? AtlasColor.warning : AtlasColor.brand)
                    .accessibilityHidden(true)

                Text(app.name)
                    .font(AtlasTypography.rowTitle)
                    .lineLimit(1)

                Spacer(minLength: AtlasSpacing.sm)

                Text(AtlasFormatters.byteCount(app.bytes))
                    .font(AtlasTypography.captionSmall)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text(app.bundleIdentifier)
                .font(AtlasTypography.bodySmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                AtlasStatusChip(
                    AtlasL10n.string("apps.list.row.leftovers", app.leftoverItems),
                    tone: app.leftoverItems > 0 ? .warning : .success
                )

                Spacer(minLength: AtlasSpacing.sm)

                Text(app.bucket.title)
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AtlasSpacing.xxs)
        .accessibilityElement(children: .contain)
    }
}

private struct AppsListGroupHeader: View {
    let title: String
    let count: Int
    let tone: AtlasTone

    var body: some View {
        HStack(alignment: .center, spacing: AtlasSpacing.sm) {
            Text(title)
                .font(AtlasTypography.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: AtlasSpacing.sm)
            Text("\(count)")
                .font(AtlasTypography.captionSmall)
                .monospacedDigit()
                .foregroundStyle(tone.tint)
        }
        .textCase(nil)
    }
}

// MARK: - Grouping helpers (internal; tested via AppsFeatureView surface)

struct AppGroup: Identifiable {
    let id: String
    let title: String
    let tone: AtlasTone
    let apps: [AppFootprint]
}

enum AppBucket: String, CaseIterable {
    case large
    case leftovers
    case other

    static let displayOrder: [AppBucket] = [.large, .leftovers, .other]

    var title: String {
        switch self {
        case .large: return AtlasL10n.string("apps.group.large")
        case .leftovers: return AtlasL10n.string("apps.group.leftovers")
        case .other: return AtlasL10n.string("apps.group.other")
        }
    }

    var tone: AtlasTone {
        switch self {
        case .large: return .warning
        case .leftovers: return .neutral
        case .other: return .success
        }
    }
}

extension AppFootprint {
    var bucket: AppBucket {
        if bytes >= 2_000_000_000 { return .large }
        if leftoverItems > 0 { return .leftovers }
        return .other
    }
}

// MARK: - Shared sort (used by the coordinator)

extension AppsListView {
    /// Sort order preserved from the legacy view: bytes desc → leftoverItems
    /// desc → name asc. Stable so selection survives re-sort.
    static func sortedApps(_ apps: [AppFootprint]) -> [AppFootprint] {
        apps.sorted { lhs, rhs in
            if lhs.bytes == rhs.bytes {
                if lhs.leftoverItems == rhs.leftoverItems {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.leftoverItems > rhs.leftoverItems
            }
            return lhs.bytes > rhs.bytes
        }
    }
}
