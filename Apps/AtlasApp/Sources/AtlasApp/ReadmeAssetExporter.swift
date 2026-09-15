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
        // "Screenshot-tool" framed presentation: the app capture sits centered on a Calm
        // Ledger canvas-gradient backdrop with a margin, rounded corners, hairline border,
        // and soft shadow — like a Shottr/CleanShot framed export. No fake title bar; the
        // capture is the real app shell + feature view, edge to edge within the frame.
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
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 36, x: 0, y: 20)
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.56, green: 0.80, blue: 0.76), // #8FCCC2 — Calm Ledger teal backdrop top
                    Color(red: 0.77, green: 0.89, blue: 0.86), // #C5E3DB — teal backdrop bottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
    // Canvas in POINTS (captured at the screen's backing scale, e.g. 2× on Retina →
    // 2880×1800 px). Sized to a realistic Mac window so Calm Ledger workspace content
    // (maxWorkspaceWidth ≈ 1200) fills the detail area instead of floating centered with
    // huge margins: 1440pt − 220pt sidebar − 1pt divider ≈ 1219pt detail, just over the
    // 1200pt workspace ceiling. A giant 2880pt canvas left ~830pt of empty window-background
    // on each side.
    private let screenshotSize = CGSize(width: 1440, height: 900)

    /// 导出渲染的固定时刻（2025-10-09 08:53:20 UTC）。
    ///
    /// 一个常数管两件事，它们必须一致才有意义：
    ///   1. `AtlasRenderClock` 的钉死值 —— 决定截图里所有时间戳；
    ///   2. 回执编号的 `scanDate` —— 与截图上的日期对得上，否则画面自相矛盾。
    ///
    /// 改这个值 = 让所有截图上的日期整体平移一次，**不是**无副作用的改动。
    private static let renderInstant = Date(timeIntervalSince1970: 1_760_000_000)

    /// 截图覆盖的路由与文件名主干。
    ///
    /// ⚠️ 增删本表**必须**同步三处，否则门禁报红（这是设计意图，不是麻烦）：
    ///   1. `README.md` / `README.zh-CN.md` 的 Screens 网格
    ///   2. `scripts/atlas/readme_media_gate.py` 的 `EXPECTED_SCREENSHOTS`
    ///
    /// 门禁那份是**故意不与这里同源**的独立载体：若两边同源，导出器把某个路由
    /// 弄丢时门禁会跟着一起忘掉，等于自证。分开写，漏一个就会响。
    private static let screenshotRoutes: [(route: AtlasRoute, stem: String)] = [
        (.overview, "overview"),
        (.smartClean, "smart-clean"),
        (.apps, "apps"),
        (.ledger, "ledger"),
    ]

    init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }

    func exportAll() async throws -> Int {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        var exportedFileNames: [String] = []

        // 逐语言导出。README.md 引 `-en`，README.zh-CN.md 引 `-zh-Hans` ——
        // 此前两份 README 共用同一批英文图，中文读者看到的是英文界面。
        //
        // 语言是**进程级全局状态**（`AtlasL10n.setCurrentLanguage`），所以必须在
        // 构造视图之前设置，且同一语言的「构造 → 渲染」之间不得插入另一种语言：
        // 视图 body 是在 `cacheDisplay` 时才求值的。
        //
        // 退出前还原 —— 借了进程级状态就要还。当前导出模式下窗口标题写死英文、
        // 导出完即 `NSApp.terminate`，所以**暂无用户可见影响**；但「改了全局态不还原」
        // 这个模式一旦被挪到别的入口就会咬人。质量审查要求补上，故补齐。
        let previousLanguage = AtlasL10n.currentLanguage
        defer { AtlasL10n.setCurrentLanguage(previousLanguage) }

        // 把「现在」钉死，让产物**可复现**。
        //
        // 不钉的话，截图里会烘焙渲染瞬间的墙钟时间 —— 实测重导 9 张里 4 张会变
        // （`atlas-overview-*` / `atlas-ledger-*`），差异就是「Sep 15, 2026 at
        // 6:39 PM」→「9:21 PM」。而漂移守卫会在每次文案改动后要求重导，于是
        // 每次改动都往 git 历史里塞约 4 MB 新 blob。
        //
        // 必须钉 `AtlasRenderClock` 而**不是**改 fixture —— fixture 被
        // `AtlasScaffoldWorkerService` 与 `AtlasWorkspaceRepository` 共用，
        // 全局改它会改变 app 行为。时钟是导出专用的注入点，产品路径零影响。
        AtlasRenderClock.setFixedInstant(Self.renderInstant)
        defer { AtlasRenderClock.setFixedInstant(nil) }

        for language in AtlasLanguage.allCases {
            AtlasL10n.setCurrentLanguage(language)
            let state = AtlasScaffoldWorkspace.state(language: language)
            let canExecuteSmartCleanPlan = Self.canExecuteSmartCleanPlan(in: state)

            for (route, stem) in Self.screenshotRoutes {
                let fileName = "atlas-\(stem)-\(language.rawValue).png"
                try renderView(
                    screenshotView(for: route, state: state, canExecuteSmartCleanPlan: canExecuteSmartCleanPlan),
                    fileName: fileName,
                    language: language
                )
                exportedFileNames.append(fileName)
            }
        }

        try exportAppIcon()
        exportedFileNames.append("atlas-icon.png")

        try verifyWrittenAssets(exportedFileNames)

        return exportedFileNames.count
    }

    private static func canExecuteSmartCleanPlan(in state: AtlasWorkspaceState) -> Bool {
        state.currentPlan.items.contains(where: { $0.kind != .inspectPermission && $0.kind != .reviewEvidence })
            && state.currentPlan.items
                .filter { $0.kind != .inspectPermission && $0.kind != .reviewEvidence }
                .allSatisfy { !($0.targetPaths ?? []).isEmpty }
    }

    private func screenshotView(
        for route: AtlasRoute,
        state: AtlasWorkspaceState,
        canExecuteSmartCleanPlan: Bool
    ) -> AnyView {
        switch route {
        case .overview:
            return AnyView(
                AtlasScreenshotShell(activeRoute: .overview) {
                    OverviewFeatureView(snapshot: state.snapshot, isRefreshingHealthSnapshot: false)
                }
            )
        case .smartClean:
            return AnyView(
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
                        planOutcome: nil,
                        state: SmartCleanWorkflowState(
                            currentStage: SmartCleanStage.review,
                            displayedStage: SmartCleanStage.review,
                            planNumber: state.snapshot.taskRuns.count + 1,
                            receiptCode: AtlasLedgerReceipt.code(
                                findings: state.snapshot.findings,
                                scanDate: Self.renderInstant
                            ),
                            selectedIDs: Set(state.snapshot.findings.map(\.id.uuidString))
                        )
                    )
                }
            )
        case .apps:
            return AnyView(
                AtlasScreenshotShell(activeRoute: .apps) {
                    AppsFeatureView(
                        apps: state.snapshot.apps,
                        previewPlan: nil,
                        currentPreviewedAppID: nil,
                        restoreRefreshStatus: nil,
                        summary: AtlasL10n.string("model.apps.ready"),
                        isRunning: false,
                        activePreviewAppID: nil,
                        activeUninstallAppID: nil,
                        onRefreshApps: {},
                        onPreviewAppUninstall: { _ in },
                        onExecuteAppUninstall: { _ in },
                        onRescanLeftovers: { _ in }
                    )
                }
            )
        case .ledger:
            return AnyView(
                AtlasScreenshotShell(activeRoute: .ledger) {
                    LedgerFeatureView(
                        taskRuns: state.snapshot.taskRuns,
                        recoveryItems: state.snapshot.recoveryItems,
                        restoringItemID: nil
                    )
                }
            )
        default:
            // 不出图的路由走到这里说明 `screenshotRoutes` 与 view 构造脱节了。
            // 静默返回一张别的路由的图比崩溃更糟 —— 截图会「看起来正常」。
            preconditionFailure("README 截图未定义的路由：\(route.rawValue)")
        }
    }

    /// 逐条确认产物真的落盘且非空。
    ///
    /// **不是**断言 `exportedFileNames.count == 预期` —— 那个数由同一段代码算出来，
    /// 永远成立，属于自证断言（本仓 `I-8` 同型）。真正的独立预期在门禁的 Python
    /// 常量表里；这里只负责「写盘这一步没失败」。
    private func verifyWrittenAssets(_ fileNames: [String]) throws {
        for fileName in fileNames {
            let url = outputDirectory.appendingPathComponent(fileName)
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
            guard size > 0 else {
                throw AtlasReadmeAssetExporterError.emptyAsset(fileName)
            }
        }
    }

    private func exportAppIcon() throws {
        let iconImage = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        iconImage.size = NSSize(width: 1024, height: 1024)
        try writePNG(iconImage, to: outputDirectory.appendingPathComponent("atlas-icon.png"))
    }

    private func renderView<Content: View>(_ view: Content, fileName: String, language: AtlasLanguage) throws {
        let content = view
            .environment(\.locale, language.locale)
            .environment(\.colorScheme, .light)
            .frame(width: screenshotSize.width, height: screenshotSize.height)

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: screenshotSize)
        hostingView.layoutSubtreeIfNeeded()

        // Build the backing bitmap EXPLICITLY: 2× pixels with its `.size` pinned to the
        // logical canvas size. This makes `cacheDisplay` map the view's logical bounds onto
        // the FULL pixel grid. Two prior attempts failed:
        //  - `bitmapImageRepForCachingDisplay` (no window → bad backing scale) mapped the
        //    view into only the top-left quadrant, leaving the rest blank.
        //  - `ImageRenderer` rendered the sidebar shell but could not render the
        //    AtlasScreen/ScrollView-backed feature views at all (blank content area).
        // `cacheDisplay` snapshots the complete view hierarchy reliably.
        let scale: CGFloat = 2.0
        guard let bitmapRepresentation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(screenshotSize.width * scale),
            pixelsHigh: Int(screenshotSize.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw AtlasReadmeAssetExporterError.renderFailed(fileName)
        }
        bitmapRepresentation.size = screenshotSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRepresentation)
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRepresentation)
        NSGraphicsContext.restoreGraphicsState()

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
        case .overview:       return AtlasColor.brand
        case .smartClean:     return AtlasColor.success
        case .fileOrganizer:  return AtlasColor.accent
        case .apps:           return AtlasColor.info
        case .ledger:         return AtlasColor.textSecondary
        case .permissions:    return AtlasColor.warning
        case .settings:       return AtlasColor.textSecondary
        case .about:          return AtlasColor.brand
        }
    }
}

private enum AtlasReadmeAssetExporterError: LocalizedError {
    case renderFailed(String)
    case pngEncodingFailed(String)
    case emptyAsset(String)

    var errorDescription: String? {
        switch self {
        case let .renderFailed(name):
            return "Failed to render README screenshot \(name)."
        case let .pngEncodingFailed(name):
            return "Failed to encode PNG asset \(name)."
        case let .emptyAsset(name):
            return "README asset was written empty (0 bytes): \(name)."
        }
    }
}
