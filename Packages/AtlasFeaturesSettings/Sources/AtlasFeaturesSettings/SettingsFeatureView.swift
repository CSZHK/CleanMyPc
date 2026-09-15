import AtlasDesignSystem
import AtlasDomain
import SwiftUI

public struct SettingsFeatureView: View {
    /// `P2-1`：体系词键（四个保留词 + 补解释）。
    static let glossaryTermKeys = ["leftover", "footprint", "ledger", "evidence"]

    @State private var selectedPanel: SettingsPanel = .general
    @State private var presentedDocument: SettingsDocument?

    private let settings: AtlasSettings
    private let recoveryTotalBytes: Int64
    private let onSetLanguage: (AtlasLanguage) -> Void
    private let onSetTheme: (AtlasTheme) -> Void
    private let onSetRecoveryRetention: (Int) -> Void
    private let onToggleNotifications: (Bool) -> Void
    /// `P2-12`：排除项的**写回调**。此前视图只有四个写回调（语言/主题/保留期/通知），
    /// 排除项连一个都没有 —— 用户读到「这些路径不会出现在扫描结果和清理计划里」，
    /// 想加自己的重要目录时**无处可点**（而这是普通用户最本能的保护动作）。
    private let onAddExcludedPath: (String) -> Void
    private let onRemoveExcludedPath: (String) -> Void

    @State private var newExcludedPath = ""

    public init(
        settings: AtlasSettings = AtlasScaffoldFixtures.settings,
        recoveryTotalBytes: Int64 = 0,
        onSetLanguage: @escaping (AtlasLanguage) -> Void = { _ in },
        onSetTheme: @escaping (AtlasTheme) -> Void = { _ in },
        onSetRecoveryRetention: @escaping (Int) -> Void = { _ in },
        onToggleNotifications: @escaping (Bool) -> Void = { _ in },
        onAddExcludedPath: @escaping (String) -> Void = { _ in },
        onRemoveExcludedPath: @escaping (String) -> Void = { _ in }
    ) {
        self.settings = settings
        self.recoveryTotalBytes = recoveryTotalBytes
        self.onSetLanguage = onSetLanguage
        self.onSetTheme = onSetTheme
        self.onSetRecoveryRetention = onSetRecoveryRetention
        self.onToggleNotifications = onToggleNotifications
        self.onAddExcludedPath = onAddExcludedPath
        self.onRemoveExcludedPath = onRemoveExcludedPath
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("settings.screen.title"),
            subtitle: AtlasL10n.string("settings.screen.subtitle"),
            useScrollView: false
        ) {
            AtlasInfoCard(
                title: AtlasL10n.string("settings.panel.title"),
                subtitle: AtlasL10n.string("settings.panel.subtitle")
            ) {
                VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
                    // Tab bar — pinned at top, not inside ScrollView
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AtlasSpacing.sm) {
                            ForEach(SettingsPanel.allCases) { panel in
                                panelButton(for: panel)
                            }
                        }
                    }

                    // Only the panel content scrolls
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
            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                AtlasKeyValueRow(
                    title: AtlasL10n.string("settings.language.title"),
                    value: settings.language.displayName,
                    detail: AtlasL10n.string("settings.language.detail")
                )

                AtlasSegmentedControl(
                    options: AtlasLanguage.allCases,
                    selection: Binding(get: {
                        settings.language
                    }, set: { newValue in
                        onSetLanguage(newValue)
                    }),
                    label: { $0.displayName }
                )
                .accessibilityIdentifier("settings.language")
                .accessibilityHint(AtlasL10n.string("settings.language.hint"))
            }

            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                AtlasKeyValueRow(
                    title: AtlasL10n.string("settings.theme.title"),
                    value: settings.theme.displayName,
                    detail: AtlasL10n.string("settings.theme.detail")
                )

                AtlasSegmentedControl(
                    options: AtlasTheme.allCases,
                    selection: Binding(get: {
                        settings.theme
                    }, set: { newValue in
                        onSetTheme(newValue)
                    }),
                    label: { $0.displayName }
                )
                .accessibilityIdentifier("settings.theme")
                .accessibilityHint(AtlasL10n.string("settings.theme.hint"))
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
                .tint(AtlasColor.brand)
                .accessibilityIdentifier("settings.notifications")
                .accessibilityHint(AtlasL10n.string("settings.notifications.hint"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recoveryPanel: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
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
                .tint(AtlasColor.brand)
                .accessibilityIdentifier("settings.recoveryRetention")
                .accessibilityHint(AtlasL10n.string("settings.retention.hint"))
            }

            // Calm Ledger Batch M: recovery footprint mono row (spec §3 设置
            // 恢复段强化 — data = recoveryItems total bytes, real value; mono).
            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text(AtlasL10n.string("settings.recovery.footprint.title"))
                    .font(AtlasTypography.rowTitle)
                Text(recoveryFootprintValue)
                    .font(AtlasTypography.dataBody)
                    .monospacedDigit()
                    .foregroundStyle(AtlasColor.inkData)
                Text(AtlasL10n.string("settings.recovery.footprint.detail"))
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(AtlasL10n.string("settings.recovery.footprint.title")))
            .accessibilityValue(Text(recoveryFootprintValue))
            .accessibilityIdentifier("settings.recoveryFootprint")

            Divider()

            VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
                Text(AtlasL10n.string("settings.exclusions.title"))
                    .font(AtlasTypography.sectionTitle)

                Text(AtlasL10n.string("settings.exclusions.subtitle"))
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)

                // `P2-1`：**产品内术语表入口**（契约四 §4.2(2)）。
                // 「残留 / 足迹 / 台账 / 证据」是全产品的核心词汇，此前**没有任何一处
                // 解释**——目录里那张 en 术语表是给开发者看的。只回写文档不算达标，
                // 产品内必须有可读入口。定义取自 `terminology-baseline.md` §S-10，不得自造。
                AtlasSectionDisclosure(title: AtlasL10n.string("glossary.title")) {
                    VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                        Text(AtlasL10n.string("glossary.subtitle"))
                            .font(AtlasTypography.bodySmall)
                            .foregroundStyle(AtlasColor.textSecondary)
                        ForEach(Self.glossaryTermKeys, id: \.self) { key in
                            VStack(alignment: .leading, spacing: AtlasSpacing.xxs) {
                                Text(AtlasL10n.string("glossary.\(key).term"))
                                    .font(AtlasTypography.body.weight(.medium))
                                Text(AtlasL10n.string("glossary.\(key).definition"))
                                    .font(AtlasTypography.bodySmall)
                                    .foregroundStyle(AtlasColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .accessibilityIdentifier("settings.glossary")
                }

                // `P2-12`：添加入口。空态/有数据两种分支之上都渲染它。
                HStack(spacing: AtlasSpacing.sm) {
                    TextField(
                        AtlasL10n.string("settings.exclusions.add.placeholder"),
                        text: $newExcludedPath
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings.exclusions.addField")
                    Button {
                        let trimmed = newExcludedPath.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAddExcludedPath(trimmed)
                        newExcludedPath = ""
                    } label: {
                        Text(AtlasL10n.string("settings.exclusions.add.action"))
                    }
                    .buttonStyle(.atlasSecondary)
                    .disabled(newExcludedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("settings.exclusions.add")
                }

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
                            HStack(spacing: AtlasSpacing.sm) {
                                AtlasDetailRow(
                                    title: path,
                                    subtitle: AtlasL10n.string("settings.exclusions.row.subtitle"),
                                    systemImage: "folder.badge.minus",
                                    tone: .warning
                                )
                                Button {
                                    onRemoveExcludedPath(path)
                                } label: {
                                    Text(AtlasL10n.string("settings.exclusions.remove.action"))
                                }
                                .buttonStyle(.atlasGhost)
                                .accessibilityIdentifier("settings.exclusions.remove")
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trustPanel: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
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
        Button {
            presentedDocument = .acknowledgement(settings.acknowledgementText)
        } label: {
            Text(AtlasL10n.string("settings.trust.documents.ack"))
        }
        .buttonStyle(.atlasSecondary)

        Button {
            presentedDocument = .notices(settings.thirdPartyNoticesText)
        } label: {
            Text(AtlasL10n.string("settings.trust.documents.notices"))
        }
        .buttonStyle(.atlasSecondary)
    }

    @ViewBuilder
    private func panelButton(for panel: SettingsPanel) -> some View {
        if selectedPanel == panel {
            Button(panel.title) {
                selectedPanel = panel
            }
            .buttonStyle(.atlasSecondary)
            .accessibilityIdentifier("settings.panel.\(panel.id)")
        } else {
            Button(panel.title) {
                selectedPanel = panel
            }
            .buttonStyle(.atlasGhost)
            .accessibilityIdentifier("settings.panel.\(panel.id)")
        }
    }

    /// Recovery footprint display value (spec §3 设置 恢复段强化). Fail-closed:
    /// zero bytes (no recovery items) renders the empty sentence rather than a
    /// fabricated 「0 KB」 mono figure.
    private var recoveryFootprintValue: String {
        guard recoveryTotalBytes > 0 else {
            return AtlasL10n.string("settings.recovery.footprint.empty")
        }
        return AtlasFormatters.byteCount(recoveryTotalBytes)
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
        // Calm Ledger Batch M: surface container + ledgerTitle header (spec §3.1
        // 文档 sheet 换装). Content排版沿用; behavior unchanged.
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            Text(document.title)
                .font(AtlasTypography.ledgerTitle)
                .foregroundStyle(AtlasColor.ledgerInk)

            Divider()

            ScrollView {
                Text(document.bodyText)
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(AtlasSpacing.xl)
        .background(AtlasColor.surface)
        .frame(minWidth: 560, minHeight: 420)
    }
}
