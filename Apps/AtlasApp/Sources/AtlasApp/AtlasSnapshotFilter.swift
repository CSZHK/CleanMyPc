import AtlasApplication
import AtlasDomain
import Combine
import Foundation

@MainActor
final class AtlasSnapshotFilter: ObservableObject {
    @Published private var searchTextByRoute: [AtlasRoute: String] = [:]

    // MARK: - Search Text Management

    func searchText(for route: AtlasRoute) -> String {
        searchTextByRoute[route, default: ""]
    }

    func setSearchText(_ text: String, for route: AtlasRoute) {
        searchTextByRoute[route] = text
    }

    // MARK: - Filtered Results

    func filteredSnapshot(from snapshot: AtlasWorkspaceSnapshot) -> AtlasWorkspaceSnapshot {
        var filtered = snapshot
        filtered.findings = filter(snapshot.findings, route: .overview) { finding in
            [finding.title, finding.detail, AtlasL10n.localizedCategory(finding.category), finding.risk.title]
        }
        filtered.apps = filter(snapshot.apps, route: .overview) { app in
            [app.name, app.bundleIdentifier, app.bundlePath, "\(app.leftoverItems)"]
        }
        filtered.taskRuns = filter(snapshot.taskRuns, route: .overview) { task in
            [task.kind.title, task.status.title, task.summary]
        }
        filtered.recoveryItems = filter(snapshot.recoveryItems, route: .overview) { item in
            [item.title, item.detail, item.originalPath]
        }
        filtered.permissions = filter(snapshot.permissions, route: .overview) { permission in
            [
                permission.kind.title,
                permission.rationale,
                permissionStatusText(for: permission)
            ]
        }
        return filtered
    }

    func filteredFindings(from snapshot: AtlasWorkspaceSnapshot) -> [Finding] {
        filter(snapshot.findings, route: .smartClean) { finding in
            [finding.title, finding.detail, AtlasL10n.localizedCategory(finding.category), finding.risk.title]
        }
    }

    func filteredApps(from snapshot: AtlasWorkspaceSnapshot) -> [AppFootprint] {
        filter(snapshot.apps, route: .apps) { app in
            [app.name, app.bundleIdentifier, app.bundlePath, "\(app.leftoverItems)"]
        }
    }

    func filteredTaskRuns(from snapshot: AtlasWorkspaceSnapshot) -> [TaskRun] {
        filter(snapshot.taskRuns, route: .history) { task in
            [task.kind.title, task.status.title, task.summary]
        }
    }

    func filteredRecoveryItems(from snapshot: AtlasWorkspaceSnapshot) -> [RecoveryItem] {
        filter(snapshot.recoveryItems, route: .history) { item in
            [item.title, item.detail, item.originalPath]
        }
    }

    func filteredPermissionStates(from snapshot: AtlasWorkspaceSnapshot) -> [PermissionState] {
        filter(snapshot.permissions, route: .permissions) { permission in
            [
                permission.kind.title,
                permission.rationale,
                permissionStatusText(for: permission)
            ]
        }
    }

    // MARK: - Private

    private func filter<Element>(
        _ elements: [Element],
        route: AtlasRoute,
        fields: (Element) -> [String]
    ) -> [Element] {
        let query = searchText(for: route)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else {
            return elements
        }

        return elements.filter { element in
            fields(element)
                .joined(separator: " ")
                .lowercased()
                .contains(query)
        }
    }

    private func permissionStatusText(for permission: PermissionState) -> String {
        if permission.isGranted {
            return AtlasL10n.string("common.granted")
        }
        return permission.kind.isRequiredForCurrentWorkflows
            ? AtlasL10n.string("permissions.status.required")
            : AtlasL10n.string("permissions.status.optional")
    }
}
