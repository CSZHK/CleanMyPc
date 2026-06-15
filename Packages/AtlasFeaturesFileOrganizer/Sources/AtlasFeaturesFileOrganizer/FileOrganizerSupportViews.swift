import AtlasDesignSystem
import AtlasDomain
import SwiftUI

// MARK: - Thumbnail cache (image-category entry rows)

/// In-process thumbnail cache for image-category entry rows. Resize-on-load
/// keeps the cache small; misses fall back to the placeholder icon.
final class FileOrganizerThumbnailCache {
    static let shared = FileOrganizerThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()

    func image(for path: String) -> NSImage? {
        cache.object(forKey: path as NSString)
    }

    func setImage(_ image: NSImage, for path: String) {
        cache.setObject(image, forKey: path as NSString)
    }
}

/// 32×32 file thumbnail with placeholder. Loads asynchronously, resizes to
/// 64×64 on first load, then caches. Decorative unless the entry has no
/// conflict/large/duplicate badge (the row hides thumbnails for flagged rows).
struct FileThumbnailView: View {
    let path: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: AtlasLayout.iconSM))
                    .foregroundStyle(AtlasColor.textTertiary)
            }
        }
        .frame(width: 32, height: 32)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous)
                .fill(AtlasColor.cardRaised)
        )
        .clipShape(RoundedRectangle(cornerRadius: AtlasRadius.sm, style: .continuous))
        .task(id: path) {
            let expandedPath = (path as NSString).expandingTildeInPath
            if let cached = FileOrganizerThumbnailCache.shared.image(for: expandedPath) {
                image = cached
                return
            }
            // Blocking disk read + bitmap resize — run off the MainActor so a
            // long image-category list doesn't jank scroll (round-9). NSImage is
            // not Sendable, so the detached task returns the resized bitmap as
            // Data (tiffRepresentation); the NSImage is reconstructed on the
            // MainActor. NSCache is thread-safe.
            let data = await Task.detached(priority: .userInitiated) { () -> Data? in
                guard let nsImage = NSImage(contentsOf: URL(fileURLWithPath: expandedPath)) else { return nil }
                let size = NSSize(width: 64, height: 64)
                let resized = NSImage(size: size)
                resized.lockFocus()
                nsImage.draw(in: NSRect(origin: .zero, size: size))
                resized.unlockFocus()
                return resized.tiffRepresentation
            }.value
            guard let data, let resized = NSImage(data: data) else { return }
            FileOrganizerThumbnailCache.shared.setImage(resized, for: expandedPath)
            image = resized
        }
    }
}

// MARK: - Stage header (plan № + five-segment stage bar)

/// Header strip under the screen title (spec §2.3): serif 「计划 №N」 with the
/// mono scan-receipt code, and the five-segment stage bar. Completed stages
/// are tappable look-back entries. Mirrors `SmartCleanStageHeader` with the
/// FileOrganizer five-segment stage set.
struct FileOrganizerStageHeader: View {
    let planNumber: Int?
    let receiptCode: String?
    let effectiveStage: Int
    let completedStages: Set<Int>
    let onSelectStage: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            if let number = planNumber {
                HStack(spacing: AtlasSpacing.md) {
                    Text(AtlasL10n.string("fileorganizer.stage.plan.number", number))
                        .font(AtlasTypography.ledgerNumber)
                        .foregroundStyle(AtlasColor.ink)
                        .accessibilityLabel(AtlasL10n.string("fileorganizer.stage.plan.number.a11y", number))
                    if let receiptCode {
                        Text("#\(receiptCode)")
                            .font(AtlasTypography.dataCaption)
                            .monospacedDigit()
                            .foregroundStyle(AtlasColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }

            AtlasStageBar(
                stages: Self.stages,
                currentIndex: effectiveStage,
                completedIndices: completedStages,
                onSelect: onSelectStage
            )
        }
    }

    static var stages: [AtlasStage] {
        [
            AtlasStage(id: FileOrganizerStage.scan, title: AtlasL10n.string("fileorganizer.stage.scan")),
            AtlasStage(id: FileOrganizerStage.rules, title: AtlasL10n.string("fileorganizer.stage.rules")),
            AtlasStage(id: FileOrganizerStage.preview, title: AtlasL10n.string("fileorganizer.stage.preview")),
            AtlasStage(id: FileOrganizerStage.execute, title: AtlasL10n.string("fileorganizer.stage.execute")),
            AtlasStage(id: FileOrganizerStage.receipt, title: AtlasL10n.string("fileorganizer.stage.receipt")),
        ]
    }
}

// MARK: - Read-only look-back banner

/// 「回看 = 只读快照」 banner with the mandatory 「返回当前阶段」 entry (spec §2.3).
/// Identical surface to SmartClean's; localized under the fileorganizer namespace.
struct FileOrganizerReadOnlyBanner: View {
    let onReturnToCurrent: () -> Void

    var body: some View {
        HStack(spacing: AtlasSpacing.md) {
            Image(systemName: "eye")
                .font(AtlasTypography.caption)
                .foregroundStyle(AtlasColor.textSecondary)
                .accessibilityHidden(true)
            Text(AtlasL10n.string("fileorganizer.stage.readonly.banner"))
                .font(AtlasTypography.bodySmall)
                .foregroundStyle(AtlasColor.textSecondary)
            Spacer(minLength: AtlasSpacing.sm)
            Button(AtlasL10n.string("fileorganizer.stage.readonly.return"), action: onReturnToCurrent)
                .buttonStyle(.atlasSecondary)
                .accessibilityIdentifier("fileorganizer.stage.returnToCurrent")
        }
        .padding(AtlasSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .fill(AtlasColor.surfaceSubdued)
        )
    }
}

// MARK: - Evidence drawer (<880pt container)

/// Non-modal slide-out drawer hosting the evidence panel (spec §2.4). Mirrors
/// SmartClean's drawer; the bottom edge yields the action bar's height.
struct FileOrganizerEvidenceDrawer<Content: View>: View {
    let bottomInset: CGFloat
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            HStack {
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: AtlasLayout.iconXS, weight: .bold))
                        .foregroundStyle(AtlasColor.textSecondary)
                        // 44pt hit target — the visible glyph stays at iconXS
                        // (round-2 a11y; matches the Toast close pattern).
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AtlasL10n.string("fileorganizer.drawer.close")))
            }

            ScrollView {
                content
            }
        }
        .padding(AtlasSpacing.lg)
        .frame(width: 340)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.card)
                .shadow(
                    color: Color.black.opacity(AtlasElevation.prominent.shadowOpacity),
                    radius: AtlasElevation.prominent.shadowRadius,
                    x: 0,
                    y: AtlasElevation.prominent.shadowY
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
        .padding(AtlasSpacing.md)
        .padding(.bottom, bottomInset)
        .onExitCommand(perform: onDismiss)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}

// MARK: - Configuration disclosure (folder / destination / recursive)

/// Collapsible configuration surface: folder selector, destination selector,
/// recursive-scan toggle. Behaviour preserved from the legacy view; lifted
/// into the ① scan stage body. The coordinator owns `selectedFolders` via a
/// binding so the action-bar scan trigger can read the current selection.
struct FileOrganizerConfigurationSection: View {
    @Binding var selectedFolders: [String]
    let destinationBasePath: String
    let isRecursiveScan: Bool
    let isDisabled: Bool
    let onUpdateDestination: (String) -> Void
    let onUpdateRecursiveScan: (Bool) -> Void

    @State private var isFolderPickerPresented = false
    @State private var isDestinationPickerPresented = false

    private var presetFolders: [String] { ["~/Desktop", "~/Downloads"] }

    var body: some View {
        AtlasSectionDisclosure(
            title: AtlasL10n.string("smartclean.controls.title"),
            defaultExpanded: false
        ) {
            VStack(spacing: AtlasSpacing.sm) {
                folderSelector
                destinationSelector
                recursiveScanToggle
            }
        }
        .disabled(isDisabled)
    }

    private var folderSelector: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            HStack(spacing: AtlasSpacing.sm) {
                ForEach(presetFolders, id: \.self) { folder in
                    folderToggle(folder)
                }
                Button {
                    isFolderPickerPresented = true
                } label: {
                    Label(AtlasL10n.string("fileorganizer.folderpicker.title"), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.atlasGhost)
            }

            if !selectedFolders.filter({ !presetFolders.contains($0) }).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AtlasSpacing.xs) {
                        ForEach(selectedFolders.filter { !presetFolders.contains($0) }, id: \.self) { folder in
                            AtlasStatusChip(folder, tone: .neutral)
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                let newFolders = urls.map { url in
                    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                    let path = url.path
                    if path.hasPrefix(homeDir) {
                        return "~" + String(path.dropFirst(homeDir.count))
                    }
                    return path
                }
                for folder in newFolders where !selectedFolders.contains(folder) {
                    selectedFolders.append(folder)
                }
            case .failure:
                break
            }
        }
    }

    private func folderToggle(_ folder: String) -> some View {
        let isSelected = selectedFolders.contains(folder)
        let label = folder == "~/Desktop"
            ? AtlasL10n.string("fileorganizer.folderpicker.default.desktop")
            : AtlasL10n.string("fileorganizer.folderpicker.default.downloads")
        return Button {
            if isSelected {
                selectedFolders.removeAll { $0 == folder }
            } else {
                selectedFolders.append(folder)
            }
        } label: {
            HStack(spacing: AtlasSpacing.xxs) {
                Image(systemName: isSelected ? "checkmark.square" : "square")
                    .accessibilityHidden(true) // decorative — state is conveyed by the trait/value below
                Text(label)
            }
            .font(AtlasTypography.body)
        }
        .buttonStyle(.plain)
        // Expose selection state to VoiceOver (round-8) — the checkmark/square
        // glyph is color/icon-only otherwise, so a preset's on/off is invisible
        // to assistive tech.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(Text(AtlasL10n.string(isSelected ? "fileorganizer.entry.selected.a11y" : "fileorganizer.entry.unselected.a11y")))
    }

    private var destinationSelector: some View {
        HStack(spacing: AtlasSpacing.xs) {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(AtlasColor.textTertiary)
                .font(AtlasTypography.body)
            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                Text(AtlasL10n.string("fileorganizer.destination.title"))
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.textSecondary)
                Text(displayPath(destinationBasePath))
                    .font(AtlasTypography.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                isDestinationPickerPresented = true
            } label: {
                Text(AtlasL10n.string("fileorganizer.destination.change"))
            }
            .buttonStyle(.atlasGhost)
        }
        .fileImporter(
            isPresented: $isDestinationPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else { return }
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            let path = url.path
            let display = path.hasPrefix(homeDir)
                ? "~" + String(path.dropFirst(homeDir.count))
                : path
            onUpdateDestination(display)
        }
    }

    private func displayPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if expanded.hasPrefix(homeDir) {
            return "~" + String(expanded.dropFirst(homeDir.count))
        }
        return path
    }

    private var recursiveScanToggle: some View {
        HStack(spacing: AtlasSpacing.xs) {
            Image(systemName: isRecursiveScan ? "folder.fill" : "folder")
                .foregroundStyle(AtlasColor.textTertiary)
                .font(AtlasTypography.body)
                .accessibilityHidden(true) // decorative — the Toggle carries the label
            Text(AtlasL10n.string("fileorganizer.recursive.title"))
                .font(AtlasTypography.body)
                .foregroundStyle(AtlasColor.textPrimary)
                .accessibilityHidden(true) // title is the switch's a11y label below
            Spacer()
            Toggle("", isOn: Binding(
                get: { isRecursiveScan },
                set: { onUpdateRecursiveScan($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            // Name the switch (round-10): with an empty visual label +
            // labelsHidden the native Toggle is otherwise announced as a bare
            // "switch, on/off" with no name.
            .accessibilityLabel(Text(AtlasL10n.string("fileorganizer.recursive.title")))
        }
    }
}
