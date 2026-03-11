import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct AboutUpdateToolbarButton: View {
    private let appVersion: String
    private let appBuild: String
    private let updateResult: AtlasAppUpdate?
    private let isCheckingForUpdate: Bool
    private let updateCheckNotice: String?
    private let updateCheckError: String?
    private let onCheckForUpdate: () -> Void

    @State private var isPopoverPresented = false

    public init(
        appVersion: String,
        appBuild: String,
        updateResult: AtlasAppUpdate?,
        isCheckingForUpdate: Bool,
        updateCheckNotice: String?,
        updateCheckError: String?,
        onCheckForUpdate: @escaping () -> Void
    ) {
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.updateResult = updateResult
        self.isCheckingForUpdate = isCheckingForUpdate
        self.updateCheckNotice = updateCheckNotice
        self.updateCheckError = updateCheckError
        self.onCheckForUpdate = onCheckForUpdate
    }

    public var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: AtlasSpacing.xs) {
                if isCheckingForUpdate {
                    ProgressView()
                        .controlSize(.small)
                }

                Text("v\(appVersion)")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.textPrimary)

                if updateResult?.isUpdateAvailable == true {
                    Circle()
                        .fill(AtlasColor.danger)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, AtlasSpacing.md)
            .padding(.vertical, AtlasSpacing.sm)
            .background(
                Capsule(style: .continuous)
                    .fill(AtlasColor.cardRaised)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AtlasColor.borderEmphasis, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            AtlasInfoCard(
                title: AtlasL10n.string("update.version.title")
            ) {
                AtlasDetailRow(
                    title: AtlasL10n.string("update.version.current"),
                    subtitle: appVersion,
                    systemImage: "tag"
                )

                AtlasDetailRow(
                    title: AtlasL10n.string("update.version.build"),
                    subtitle: appBuild,
                    systemImage: "hammer"
                )

                Button {
                    onCheckForUpdate()
                } label: {
                    HStack(spacing: AtlasSpacing.xs) {
                        if isCheckingForUpdate {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isCheckingForUpdate
                             ? AtlasL10n.string("update.check.checking")
                             : AtlasL10n.string("update.check.action"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.atlasSecondary)
                .disabled(isCheckingForUpdate)
                .padding(.top, AtlasSpacing.sm)
            }

            if let result = updateResult {
                if result.isUpdateAvailable {
                    AtlasCallout(
                        title: AtlasL10n.string("update.available.title", result.latestVersion),
                        detail: AtlasL10n.string("update.available.detail", result.currentVersion, result.latestVersion),
                        tone: .warning,
                        systemImage: "arrow.down.circle"
                    )

                    if let url = result.releaseURL {
                        Link(destination: url) {
                            Text(AtlasL10n.string("update.available.download"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.atlasPrimary)
                    }
                } else {
                    AtlasCallout(
                        title: AtlasL10n.string("update.upToDate.title"),
                        detail: AtlasL10n.string("update.upToDate.detail", result.currentVersion),
                        tone: .success,
                        systemImage: "checkmark.circle"
                    )
                }
            }

            if let notice = updateCheckNotice {
                AtlasCallout(
                    title: AtlasL10n.string("update.notice.title"),
                    detail: notice,
                    tone: .neutral,
                    systemImage: "info.circle"
                )
            }

            if let error = updateCheckError {
                AtlasCallout(
                    title: AtlasL10n.string("update.error.title"),
                    detail: error,
                    tone: .danger,
                    systemImage: "exclamationmark.triangle"
                )
            }
        }
        .padding(AtlasSpacing.xl)
        .frame(width: 360)
    }
}
