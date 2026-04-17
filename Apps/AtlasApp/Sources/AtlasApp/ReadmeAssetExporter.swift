import AppKit
import AtlasApplication
import AtlasDesignSystem
import AtlasDomain
import AtlasFeaturesApps
import AtlasFeaturesHistory
import AtlasFeaturesOverview
import AtlasFeaturesSmartClean
import Foundation
import SwiftUI

@MainActor
struct ReadmeAssetExportView: View {
    let outputDirectory: URL

    @State private var statusText = "Exporting README icon and screenshots..."

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            Image(systemName: "photo.stack")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.tint)

            Text("Atlas README Export")
                .font(.title3.weight(.semibold))

            Text(statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(24)
        .task {
            do {
                let exporter = AtlasReadmeAssetExporter(outputDirectory: outputDirectory)
                let exportedAssetCount = try await exporter.exportAll()
                statusText = "Exported \(exportedAssetCount) assets to\n\(outputDirectory.path)"
                try? await Task.sleep(nanoseconds: 500_000_000)
                NSApp.terminate(nil)
            } catch {
                let message = "[AtlasReadmeAssetExporter] \(error.localizedDescription)\n"
                if let data = message.data(using: .utf8) {
                    try? FileHandle.standardError.write(contentsOf: data)
                }
                exit(EXIT_FAILURE)
            }
        }
    }
}

// MARK: - Screenshot Shell

/// Lightweight recreation of `AppShellView` layout for screenshot rendering.
/// Replicates the sidebar + content split without requiring live `AtlasAppModel`.
private struct AtlasScreenshotShell<Content: View>: View {
    let activeRoute: AtlasRoute
    let content: Content

    init(activeRoute: AtlasRoute, @ViewBuilder content: () -> Content) {
        self.activeRoute = activeRoute
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebarColumn
                .frame(width: 220)

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Sidebar

    private var sidebarColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation title area
            Text(AtlasL10n.string("app.name"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(AtlasRoute.SidebarSection.allCases) { section in
                        sectionView(section)
                    }

                    // Settings & About section (no section header, matching AppShellView)
                    VStack(alignment: .leading, spacing: 0) {
                        sidebarRow(for: .settings)
                        sidebarRow(for: .about)
                    }
                }
                .padding(.horizontal, 10)
            }
            Spacer()
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func sectionView(_ section: AtlasRoute.SidebarSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 8)
                .padding(.top, 12)
                .padding(.bottom, 4)

            ForEach(section.routes) { route in
                sidebarRow(for: route)
            }
        }
    }

    private func sidebarRow(for route: AtlasRoute) -> some View {
        let isSelected = route == activeRoute
        let themeColor = route.themeColor

        return HStack(alignment: .center, spacing: AtlasSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeColor.opacity(0.18),
                                themeColor.opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: AtlasLayout.sidebarIconSize, height: AtlasLayout.sidebarIconSize)

                Image(systemName: route.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor)
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(route.title)
                    .font(AtlasTypography.rowTitle)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Text(route.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, AtlasSpacing.sm)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                .fill(isSelected ? AtlasColor.brand.opacity(0.08) : .clear)
        )
    }
}

// MARK: - Exporter

@MainActor
private struct AtlasReadmeAssetExporter {
    private let outputDirectory: URL
    private let screenshotSize = CGSize(width: 2880, height: 1800)
    private let screenshotLanguage: AtlasLanguage = .en

    init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    func exportAll() async throws -> Int {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        AtlasL10n.setCurrentLanguage(screenshotLanguage)

        let state = AtlasScaffoldWorkspace.state(language: screenshotLanguage)
        let canExecuteSmartCleanPlan = state.currentPlan.items.contains(where: { $0.kind != .inspectPermission && $0.kind != .reviewEvidence })
            && state.currentPlan.items
                .filter { $0.kind != .inspectPermission && $0.kind != .reviewEvidence }
                .allSatisfy { !($0.targetPaths ?? []).isEmpty }

        try exportAppIcon()
        try renderView(
            AtlasScreenshotShell(activeRoute: .overview) {
                OverviewFeatureView(snapshot: state.snapshot, isRefreshingHealthSnapshot: false)
            },
            fileName: "atlas-overview.png"
        )
        try renderView(
            AtlasScreenshotShell(activeRoute: .smartClean) {
                SmartCleanFeatureView(
                    findings: state.snapshot.findings,
                    plan: state.currentPlan,
                    scanSummary: AtlasL10n.string("model.scan.ready"),
                    scanProgress: 1,
                    isScanning: false,
                    isExecutingPlan: false,
                    isCurrentPlanFresh: true,
                    canExecutePlan: canExecuteSmartCleanPlan,
                    planIssue: nil
                )
            },
            fileName: "atlas-smart-clean.png"
        )
        try renderView(
            AtlasScreenshotShell(activeRoute: .apps) {
                AppsFeatureView(
                    apps: state.snapshot.apps,
                    previewPlan: nil,
                    currentPreviewedAppID: nil,
                    restoreRefreshStatus: nil,
                    summary: AtlasL10n.string("model.apps.ready"),
                    isRunning: false,
                    activePreviewAppID: nil,
                    activeUninstallAppID: nil
                )
            },
            fileName: "atlas-apps.png"
        )
        try renderView(
            AtlasScreenshotShell(activeRoute: .history) {
                HistoryFeatureView(
                    taskRuns: state.snapshot.taskRuns,
                    recoveryItems: state.snapshot.recoveryItems,
                    restoringItemID: nil
                )
            },
            fileName: "atlas-history.png"
        )

        return 5
    }

    private func exportAppIcon() throws {
        let iconImage = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        iconImage.size = NSSize(width: 1024, height: 1024)
        try writePNG(iconImage, to: outputDirectory.appendingPathComponent("atlas-icon.png"))
    }

    private func renderView<Content: View>(_ view: Content, fileName: String) throws {
        let content = view
            .environment(\.locale, screenshotLanguage.locale)
            .environment(\.colorScheme, .light)
            .frame(width: screenshotSize.width, height: screenshotSize.height)

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: screenshotSize)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmapRepresentation = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw AtlasReadmeAssetExporterError.renderFailed(fileName)
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRepresentation)

        guard let pngData = bitmapRepresentation.representation(using: .png, properties: [:]) else {
            throw AtlasReadmeAssetExporterError.pngEncodingFailed(fileName)
        }

        try pngData.write(to: outputDirectory.appendingPathComponent(fileName), options: .atomic)
    }

    private func writePNG(_ image: NSImage, to destinationURL: URL) throws {
        guard let tiffRepresentation = image.tiffRepresentation,
              let bitmapRepresentation = NSBitmapImageRep(data: tiffRepresentation),
              let pngData = bitmapRepresentation.representation(using: .png, properties: [:]) else {
            throw AtlasReadmeAssetExporterError.pngEncodingFailed(destinationURL.lastPathComponent)
        }

        try pngData.write(to: destinationURL, options: .atomic)
    }
}

private extension AtlasRoute {
    /// Per-route theme color for sidebar icon gradients and visual accents.
    var themeColor: Color {
        switch self {
        case .overview:    return AtlasColor.brand
        case .smartClean:  return AtlasColor.success
        case .apps:        return AtlasColor.accent
        case .history:     return AtlasColor.info
        case .permissions: return AtlasColor.warning
        case .settings:    return AtlasColor.textSecondary
        case .about:       return AtlasColor.brand
        }
    }
}

private enum AtlasReadmeAssetExporterError: LocalizedError {
    case renderFailed(String)
    case pngEncodingFailed(String)

    var errorDescription: String? {
        switch self {
        case let .renderFailed(name):
            return "Failed to render README screenshot \(name)."
        case let .pngEncodingFailed(name):
            return "Failed to encode PNG asset \(name)."
        }
    }
}
