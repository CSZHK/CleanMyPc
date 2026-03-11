import AppKit
import AtlasApplication
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

@MainActor
private struct AtlasReadmeAssetExporter {
    private let outputDirectory: URL
    private let screenshotSize = CGSize(width: 1600, height: 1100)
    private let screenshotLanguage: AtlasLanguage = .en

    init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    func exportAll() async throws -> Int {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        AtlasL10n.setCurrentLanguage(screenshotLanguage)

        let state = AtlasScaffoldWorkspace.state(language: screenshotLanguage)

        try exportAppIcon()
        try renderView(
            OverviewFeatureView(snapshot: state.snapshot, isRefreshingHealthSnapshot: false),
            fileName: "atlas-overview.png"
        )
        try renderView(
            SmartCleanFeatureView(
                findings: state.snapshot.findings,
                plan: state.currentPlan,
                scanSummary: AtlasL10n.string("model.scan.ready"),
                scanProgress: 1,
                isScanning: false,
                isExecutingPlan: false,
                isCurrentPlanFresh: true,
                canExecutePlan: true,
                planIssue: nil
            ),
            fileName: "atlas-smart-clean.png"
        )
        try renderView(
            AppsFeatureView(
                apps: state.snapshot.apps,
                previewPlan: nil,
                currentPreviewedAppID: nil,
                summary: AtlasL10n.string("model.apps.ready"),
                isRunning: false,
                activePreviewAppID: nil,
                activeUninstallAppID: nil
            ),
            fileName: "atlas-apps.png"
        )
        try renderView(
            HistoryFeatureView(
                taskRuns: state.snapshot.taskRuns,
                recoveryItems: state.snapshot.recoveryItems,
                restoringItemID: nil
            ),
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
