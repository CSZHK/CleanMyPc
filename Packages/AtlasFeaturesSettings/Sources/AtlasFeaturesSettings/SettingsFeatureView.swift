import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct SettingsFeatureView: View {
    @State private var selectedPanel: SettingsPanel = .general
    @State private var presentedDocument: SettingsDocument?

    private let settings: AtlasSettings
    private let onSetLanguage: (AtlasLanguage) -> Void
    private let onSetRecoveryRetention: (Int) -> Void
    private let onToggleNotifications: (Bool) -> Void

    public init(
        settings: AtlasSettings = AtlasScaffoldFixtures.settings,
        onSetLanguage: @escaping (AtlasLanguage) -> Void = { _ in },
        onSetRecoveryRetention: @escaping (Int) -> Void = { _ in },
        onToggleNotifications: @escaping (Bool) -> Void = { _ in }
    ) {
        self.settings = settings
        self.onSetLanguage = onSetLanguage
        self.onSetRecoveryRetention = onSetRecoveryRetention
        self.onToggleNotifications = onToggleNotifications
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("settings.screen.title"),
            subtitle: AtlasL10n.string("settings.screen.subtitle")
        ) {
            AtlasCallout(
                title: AtlasL10n.string("settings.callout.title"),
                detail: AtlasL10n.string("settings.callout.detail"),
                tone: .neutral,
                systemImage: "gearshape.2.fill"
            )

            AtlasInfoCard(
                title: AtlasL10n.string("settings.panel.title"),
                subtitle: AtlasL10n.string("settings.panel.subtitle")
            ) {
                VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AtlasSpacing.sm) {
                            ForEach(SettingsPanel.allCases) { panel in
                                Group {
                                    if selectedPanel == panel {
                                        Button(panel.title) {
                                            selectedPanel = panel
                                        }
                                        .buttonStyle(.atlasSecondary)
                                    } else {
                                        Button(panel.title) {
                                            selectedPanel = panel
                                        }
                                        .buttonStyle(.atlasGhost)
                                    }
                                }
                                .accessibilityIdentifier("settings.panel.\(panel.id)")
                            }
                        }
                    }

                    ScrollView {
                        switch selectedPanel {
                        case .general:
                            generalPanel
                        case .recovery:
                            recoveryPanel
                        case .trust:
                            trustPanel
                        }
                    }
                }
            }
        }
        .sheet(item: $presentedDocument) { document in
            SettingsDocumentSheet(document: document)
        }
    }

    private var generalPanel: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            AtlasCallout(
                title: AtlasL10n.string("settings.general.title"),
                detail: AtlasL10n.string("settings.general.subtitle"),
                tone: .neutral,
                systemImage: "slider.horizontal.3"
            )

            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                AtlasKeyValueRow(
                    title: AtlasL10n.string("settings.language.title"),
                    value: settings.language.displayName,
                    detail: AtlasL10n.string("settings.language.detail")
                )

                Picker(AtlasL10n.string("settings.language.picker"), selection: Binding(get: {
                    settings.language
                }, set: { newValue in
                    onSetLanguage(newValue)
                })) {
                    ForEach(AtlasLanguage.allCases) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.language")
                .accessibilityHint(AtlasL10n.string("settings.language.hint"))
            }

            Divider()

            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                AtlasKeyValueRow(
                    title: AtlasL10n.string("settings.notifications.title"),
                    value: settings.notificationsEnabled ? AtlasL10n.string("common.enabled") : AtlasL10n.string("common.disabled"),
                    detail: AtlasL10n.string("settings.notifications.detail")
                )

                Toggle(
                    isOn: Binding(
                        get: { settings.notificationsEnabled },
                        set: onToggleNotifications
                    )
                ) {
                    Text(AtlasL10n.string("settings.notifications.toggle"))
                        .font(AtlasTypography.body.weight(.medium))
                }
                .toggleStyle(.switch)
                .accessibilityIdentifier("settings.notifications")
                .accessibilityHint(AtlasL10n.string("settings.notifications.hint"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recoveryPanel: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            AtlasCallout(
                title: AtlasL10n.string("settings.recoveryPanel.title"),
                detail: AtlasL10n.string("settings.recoveryPanel.subtitle"),
                tone: .warning,
                systemImage: "arrow.uturn.backward.circle.fill"
            )

            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                AtlasKeyValueRow(
                    title: AtlasL10n.string("settings.retention.title"),
                    value: AtlasL10n.string("settings.retention.value", settings.recoveryRetentionDays),
                    detail: AtlasL10n.string("settings.retention.detail")
                )

                Stepper(
                    value: Binding(
                        get: { settings.recoveryRetentionDays },
                        set: onSetRecoveryRetention
                    ),
                    in: 1 ... 30
                ) {
                    Text(AtlasL10n.string("settings.retention.adjust"))
                        .font(AtlasTypography.body.weight(.medium))
                }
                .accessibilityIdentifier("settings.recoveryRetention")
                .accessibilityHint(AtlasL10n.string("settings.retention.hint"))
            }

            Divider()

            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                Text(AtlasL10n.string("settings.exclusions.title"))
                    .font(AtlasTypography.sectionTitle)

                Text(AtlasL10n.string("settings.exclusions.subtitle"))
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)

                if settings.excludedPaths.isEmpty {
                    AtlasEmptyState(
                        title: AtlasL10n.string("settings.exclusions.empty.title"),
                        detail: AtlasL10n.string("settings.exclusions.empty.detail"),
                        systemImage: "folder.badge.minus",
                        tone: .neutral
                    )
                } else {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        ForEach(settings.excludedPaths, id: \.self) { path in
                            AtlasDetailRow(
                                title: path,
                                subtitle: AtlasL10n.string("settings.exclusions.row.subtitle"),
                                systemImage: "folder.badge.minus",
                                tone: .warning
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trustPanel: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            AtlasCallout(
                title: AtlasL10n.string("settings.trust.title"),
                detail: AtlasL10n.string("settings.trust.subtitle"),
                tone: .success,
                systemImage: "checkmark.shield.fill"
            )

            VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                AtlasDetailRow(
                    title: AtlasL10n.string("settings.distribution.title"),
                    subtitle: AtlasL10n.string("settings.distribution.detail"),
                    systemImage: "shippingbox",
                    tone: .neutral
                ) {
                    AtlasStatusChip(AtlasL10n.string("settings.distribution.value"), tone: .neutral)
                }

                AtlasDetailRow(
                    title: AtlasL10n.string("settings.trust.destructive.title"),
                    subtitle: AtlasL10n.string("settings.trust.destructive.subtitle"),
                    systemImage: "checkmark.shield",
                    tone: .success
                ) {
                    AtlasStatusChip(AtlasL10n.string("settings.trust.destructive.badge"), tone: .success)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                Text(AtlasL10n.string("settings.trust.documents.title"))
                    .font(AtlasTypography.sectionTitle)

                Text(AtlasL10n.string("settings.trust.documents.subtitle"))
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: AtlasSpacing.md) {
                        trustDocumentButtons
                    }

                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        trustDocumentButtons
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var trustDocumentButtons: some View {
        Button(AtlasL10n.string("settings.trust.documents.ack")) {
            presentedDocument = .acknowledgement(settings.acknowledgementText)
        }
        .buttonStyle(.atlasSecondary)

        Button(AtlasL10n.string("settings.trust.documents.notices")) {
            presentedDocument = .notices(settings.thirdPartyNoticesText)
        }
        .buttonStyle(.atlasSecondary)
    }
}

private enum SettingsPanel: String, CaseIterable, Identifiable {
    case general
    case recovery
    case trust

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return AtlasL10n.string("settings.panel.general")
        case .recovery:
            return AtlasL10n.string("settings.panel.recovery")
        case .trust:
            return AtlasL10n.string("settings.panel.trust")
        }
    }
}

private enum SettingsDocument: Identifiable {
    case acknowledgement(String)
    case notices(String)

    var id: String {
        switch self {
        case .acknowledgement:
            return "acknowledgement"
        case .notices:
            return "notices"
        }
    }

    var title: String {
        switch self {
        case .acknowledgement:
            return AtlasL10n.string("settings.acknowledgement.title")
        case .notices:
            return AtlasL10n.string("settings.notices.title")
        }
    }

    var bodyText: String {
        switch self {
        case let .acknowledgement(text), let .notices(text):
            return text
        }
    }
}

private struct SettingsDocumentSheet: View {
    let document: SettingsDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(document.bodyText)
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AtlasSpacing.xl)
            }
            .navigationTitle(document.title)
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}
