import AppKit
import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct PermissionsFeatureView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOptionalExpanded = false

    private let permissionStates: [PermissionState]
    private let summary: String
    private let isRefreshing: Bool
    private let onRefresh: () -> Void
    private let onRequestNotificationPermission: () -> Void

    public init(
        permissionStates: [PermissionState] = AtlasScaffoldFixtures.permissions,
        summary: String = AtlasL10n.string("model.permissions.ready"),
        isRefreshing: Bool = false,
        onRefresh: @escaping () -> Void = {},
        onRequestNotificationPermission: @escaping () -> Void = {}
    ) {
        self.permissionStates = permissionStates
        self.summary = summary
        self.isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.onRequestNotificationPermission = onRequestNotificationPermission
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("permissions.screen.title"),
            subtitle: AtlasL10n.string("permissions.screen.subtitle")
        ) {
            AtlasCallout(
                title: corePermissionsReady ? AtlasL10n.string("permissions.callout.ready.title") : AtlasL10n.string("permissions.callout.limited.title"),
                detail: corePermissionsReady
                    ? AtlasL10n.string("permissions.callout.ready.detail")
                    : AtlasL10n.string("permissions.callout.limited.detail"),
                tone: corePermissionsReady ? .success : .warning,
                systemImage: corePermissionsReady ? "checkmark.shield.fill" : "lock.shield"
            )

            AtlasInfoCard(
                title: AtlasL10n.string("permissions.next.title"),
                subtitle: AtlasL10n.string("permissions.next.subtitle"),
                tone: nextStepTone
            ) {
                if isRefreshing {
                    AtlasLoadingState(
                        title: AtlasL10n.string("permissions.loading.title"),
                        detail: summary
                    )
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                        Text(summary)
                            .font(AtlasTypography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        AtlasCallout(
                            title: nextStepTitle,
                            detail: nextStepDetail,
                            tone: nextStepTone,
                            systemImage: nextStepSystemImage
                        )

                        LazyVGrid(columns: AtlasLayout.wideColumns, spacing: AtlasSpacing.lg) {
                            AtlasMetricCard(
                                title: AtlasL10n.string("permissions.metric.required.title"),
                                value: "\(grantedRequiredCount)/\(max(requiredCount, 1))",
                                detail: AtlasL10n.string("permissions.metric.required.detail"),
                                tone: corePermissionsReady ? .success : .warning,
                                systemImage: "exclamationmark.shield"
                            )
                            AtlasMetricCard(
                                title: AtlasL10n.string("permissions.metric.later.title"),
                                value: "\(optionalMissingCount)",
                                detail: AtlasL10n.string("permissions.metric.later.detail"),
                                tone: optionalMissingCount == 0 ? .success : .neutral,
                                systemImage: "hourglass"
                            )
                        }

                        HStack(alignment: .center, spacing: AtlasSpacing.md) {
                            if let nextActionKind {
                                Button(buttonTitle(for: nextActionKind)) {
                                    performAction(for: nextActionKind)
                                }
                                .buttonStyle(.atlasPrimary)
                            }

                            Button(action: onRefresh) {
                                Label(AtlasL10n.string("permissions.refresh"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.atlasSecondary)
                            .accessibilityIdentifier("permissions.refresh")
                            .accessibilityHint(AtlasL10n.string("permissions.refresh.hint"))
                        }
                    }
                }
            }

            AtlasInfoCard(
                title: AtlasL10n.string("permissions.requiredSection.title"),
                subtitle: AtlasL10n.string("permissions.requiredSection.subtitle"),
                tone: corePermissionsReady ? .success : .warning
            ) {
                if requiredPermissionStates.isEmpty {
                    AtlasEmptyState(
                        title: AtlasL10n.string("permissions.empty.title"),
                        detail: AtlasL10n.string("permissions.empty.detail"),
                        systemImage: "lock.slash",
                        tone: .neutral
                    )
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ForEach(requiredPermissionStates) { state in
                            permissionRow(state)
                        }
                    }
                }
            }

            if !optionalPermissionStates.isEmpty {
                AtlasInfoCard(
                    title: AtlasL10n.string("permissions.optionalSection.title"),
                    subtitle: AtlasL10n.string("permissions.optionalSection.subtitle")
                ) {
                    DisclosureGroup(isExpanded: $isOptionalExpanded) {
                        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                            ForEach(optionalPermissionStates) { state in
                                permissionRow(state)
                            }
                        }
                        .padding(.top, AtlasSpacing.md)
                    } label: {
                        HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                            Text(AtlasL10n.string("permissions.optionalSection.disclosure"))
                                .font(AtlasTypography.rowTitle)

                            Spacer(minLength: AtlasSpacing.sm)

                            AtlasStatusChip(
                                AtlasL10n.string(
                                    optionalMissingCount == 1
                                        ? "permissions.optionalSection.count.one"
                                        : "permissions.optionalSection.count.other",
                                    optionalMissingCount
                                ),
                                tone: optionalMissingCount == 0 ? .success : .neutral
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active, !isRefreshing else {
                return
            }
            onRefresh()
        }
    }

    private var grantedCount: Int {
        permissionStates.filter(\.isGranted).count
    }

    private var requiredPermissionStates: [PermissionState] {
        permissionStates.filter { $0.kind.isRequiredForCurrentWorkflows }
    }

    private var optionalPermissionStates: [PermissionState] {
        permissionStates.filter { !$0.kind.isRequiredForCurrentWorkflows }
    }

    private var requiredCount: Int {
        requiredPermissionStates.count
    }

    private var grantedRequiredCount: Int {
        requiredPermissionStates.filter(\.isGranted).count
    }

    private var optionalMissingCount: Int {
        optionalPermissionStates.filter { !$0.isGranted }.count
    }

    private var corePermissionsReady: Bool {
        requiredCount > 0 && grantedRequiredCount == requiredCount
    }

    private var nextActionKind: PermissionKind? {
        requiredPermissionStates.first(where: { !$0.isGranted })?.kind
            ?? optionalPermissionStates.first(where: { !$0.isGranted })?.kind
    }

    private var nextStepTitle: String {
        guard let nextActionKind else {
            return AtlasL10n.string("permissions.next.ready.title")
        }
        return AtlasL10n.string("permissions.next.missing.title", nextActionKind.title)
    }

    private var nextStepDetail: String {
        guard let nextActionKind else {
            return AtlasL10n.string("permissions.next.ready.detail", grantedCount, permissionStates.count)
        }
        return supportText(for: nextActionKind)
    }

    private var nextStepTone: AtlasTone {
        guard let nextActionKind else {
            return .success
        }
        return nextActionKind.isRequiredForCurrentWorkflows ? .warning : .neutral
    }

    private var nextStepSystemImage: String {
        guard let nextActionKind else {
            return "checkmark.circle.fill"
        }
        return nextActionKind.systemImage
    }

    @ViewBuilder
    private func permissionRow(_ state: PermissionState) -> some View {
        AtlasDetailRow(
            title: state.kind.title,
            subtitle: state.rationale,
            footnote: rowFootnote(for: state),
            systemImage: state.kind.systemImage,
            tone: state.isGranted ? .success : statusTone(for: state)
        ) {
            VStack(alignment: .trailing, spacing: AtlasSpacing.sm) {
                AtlasStatusChip(
                    statusText(for: state),
                    tone: statusTone(for: state)
                )

                if !state.isGranted {
                    Button(buttonTitle(for: state.kind)) {
                        performAction(for: state.kind)
                    }
                    .buttonStyle(.atlasSecondary)
                }
            }
        }
    }

    private func rowFootnote(for state: PermissionState) -> String {
        if state.isGranted {
            return AtlasL10n.string("permissions.row.ready")
        }
        return state.kind.isRequiredForCurrentWorkflows
            ? AtlasL10n.string("permissions.row.required")
            : AtlasL10n.string("permissions.row.optional")
    }

    private func statusText(for state: PermissionState) -> String {
        if state.isGranted {
            return AtlasL10n.string("common.granted")
        }
        return state.kind.isRequiredForCurrentWorkflows
            ? AtlasL10n.string("permissions.status.required")
            : AtlasL10n.string("permissions.status.optional")
    }

    private func statusTone(for state: PermissionState) -> AtlasTone {
        if state.isGranted {
            return .success
        }
        return state.kind.isRequiredForCurrentWorkflows ? .warning : .neutral
    }

    private func buttonTitle(for kind: PermissionKind) -> String {
        switch kind {
        case .notifications:
            return AtlasL10n.string("permissions.grant.notifications")
        case .fullDiskAccess, .accessibility:
            return AtlasL10n.string("permissions.grant.action")
        }
    }

    private func supportText(for kind: PermissionKind) -> String {
        switch kind {
        case .fullDiskAccess:
            return AtlasL10n.string("permissions.support.fullDiskAccess")
        case .accessibility:
            return AtlasL10n.string("permissions.support.accessibility")
        case .notifications:
            return AtlasL10n.string("permissions.support.notifications")
        }
    }

    private func performAction(for kind: PermissionKind) {
        switch kind {
        case .notifications:
            onRequestNotificationPermission()
        case .fullDiskAccess, .accessibility:
            openSystemPreferences(for: kind)
        }
    }

    private func openSystemPreferences(for kind: PermissionKind) {
        let urlString: String
        switch kind {
        case .fullDiskAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .notifications:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
