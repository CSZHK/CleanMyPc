import AppKit
import AtlasDesignSystem
import AtlasDomain
import SwiftUI

/// `I-8`：权限页计数的**单一来源**（internal：只服务本模块的渲染与单测）。
enum PermissionsSummaryMetrics {
    /// 「可稍后授权」（非主流程必需且未授予）的权限个数。
    static func optionalMissingCount(_ states: [PermissionState]) -> Int {
        states.filter { !$0.kind.isRequiredForCurrentWorkflows && !$0.isGranted }.count
    }

    /// 主流程必需权限的就绪度（分子/分母），供「当前必需」卡使用。
    static func requiredReadiness(_ states: [PermissionState]) -> (granted: Int, total: Int) {
        let required = states.filter { $0.kind.isRequiredForCurrentWorkflows }
        return (required.filter(\.isGranted).count, max(required.count, 1))
    }
}

public struct PermissionsFeatureView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOptionalExpanded = false
    /// `P1-6`：用户从本屏跳去过系统设置。回来后若该项权限仍未生效，必须给出
    /// 二次引导 —— 否则他面对的是一个和离开前**一模一样**的页面，结论是
    /// 「这个软件坏了」，然后放弃清理。
    @State private var pendingAuthorizeKind: PermissionKind?

    private let permissionStates: [PermissionState]
    private let summary: String
    /// 契约一 §1.2(1)：权限屏**只订阅自己 source 的结果**（`CT-07`）。
    /// 权限巡检失败此前只写进 `summary` 这个不带 source 标识的状态行 ——
    /// 与本屏的「下一步」卡片同容器渲染，看起来像正常提示而不是失败。
    private let outcome: AtlasActionOutcome?
    private let isRefreshing: Bool
    private let onRefresh: () -> Void
    private let onRequestNotificationPermission: () -> Void

    public init(
        permissionStates: [PermissionState] = AtlasScaffoldFixtures.permissions,
        summary: String = AtlasL10n.string("model.permissions.ready"),
        outcome: AtlasActionOutcome? = nil,
        isRefreshing: Bool = false,
        onRefresh: @escaping () -> Void = {},
        onRequestNotificationPermission: @escaping () -> Void = {}
    ) {
        self.permissionStates = permissionStates
        self.summary = summary
        self.outcome = outcome
        self.isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.onRequestNotificationPermission = onRequestNotificationPermission
    }

    public var body: some View {
        AtlasScreen(
            title: AtlasL10n.string("permissions.screen.title"),
            subtitle: AtlasL10n.string("permissions.screen.subtitle")
        ) {
            // Hero card with permission progress ring
            AtlasHeroCard(
                progress: Double(grantedRequiredCount) / max(Double(requiredCount), 1.0),
                value: "\(grantedRequiredCount)/\(max(requiredCount, 1))",
                subtitle: corePermissionsReady
                    ? AtlasL10n.string("permissions.callout.ready.detail")
                    : AtlasL10n.string("permissions.callout.limited.detail"),
                tone: corePermissionsReady ? .success : .warning,
                icon: "lock.shield",
                ringSize: 120,
                lineWidth: 10
            )

            if let outcome, outcome.isError {
                // `CT-07`：失败走 `AtlasErrorState`（规格 §1.2(1)：只有 `.failed`
                // 才走错误态）。此前该失败挂在 `summary` 上，与本卡片的正常
                // 「下一步」提示等权并排 —— 用户读不出「这次巡检失败了」。
                AtlasErrorState(
                    title: AtlasL10n.string("permissions.outcome.failed.title"),
                    message: outcome.message,
                    layout: .inlineRow
                )
                .accessibilityIdentifier("permissions.outcome.failed")
            }

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

                        if showsAfterReturnGuidance {
                            // `P1-6`：回执 + 下一步。此前回来只靠 `onRefresh()` 被动刷新一次，
                            // 状态没变就什么都不说。
                            AtlasCallout(
                                title: AtlasL10n.string("permissions.afterReturn.title"),
                                detail: AtlasL10n.string("permissions.afterReturn.detail"),
                                tone: .warning,
                                systemImage: "arrow.uturn.backward.circle"
                            )
                            .accessibilityIdentifier("permissions.afterReturn")
                        }

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
                                // `P1-4`：标题与值同口径。原标题「暂不需要」是**类别名**，
                                // 而值是一个**缺失计数** —— 两处结论相反（审计 P1-4）。
                                // 现标题「可稍后授权」+ 值「N 个」，与下方列表
                                // 「%d 个权限可稍后授权」同源于 `optionalMissingCount`（I-8）。
                                title: AtlasL10n.string("permissions.metric.later.title"),
                                value: summaryTexts.card,
                                detail: AtlasL10n.string("permissions.metric.later.detail"),
                                tone: optionalMissingCount == 0 ? .success : .neutral,
                                systemImage: "hourglass"
                            )
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: AtlasSpacing.md) {
                                nextStepButtons
                                Spacer(minLength: 0)
                            }

                            VStack(alignment: .leading, spacing: AtlasSpacing.md) {
                                nextStepButtons
                            }
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
                            PermissionRowView(state: state, onAuthorize: performAction)
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
                                PermissionRowView(state: state, onAuthorize: performAction)
                            }
                        }
                        .padding(.top, AtlasSpacing.md)
                    } label: {
                        HStack(alignment: .center, spacing: AtlasSpacing.sm) {
                            Text(AtlasL10n.string("permissions.optionalSection.disclosure"))
                                .font(AtlasTypography.rowTitle)

                            Spacer(minLength: AtlasSpacing.sm)

                            AtlasStatusChip(
                                summaryTexts.sectionCount,
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
        // 权限一旦生效就收起二次引导；用户手动刷新也视为重新开始。
        .onChange(of: permissionStates, initial: false) { _, _ in
            if let kind = pendingAuthorizeKind,
               permissionStates.first(where: { $0.kind == kind })?.isGranted == true {
                pendingAuthorizeKind = nil
            }
        }
    }

    /// `P1-6`：仅当「跳去过设置」且「该项仍未生效」且「已从设置返回（scene 为 active）」
    /// 时渲染。返回时机用 `scenePhase` 判定 —— 离开时 app 不在渲染，故不会提前弹出。
    private var showsAfterReturnGuidance: Bool {
        guard scenePhase == .active, let kind = pendingAuthorizeKind else { return false }
        return permissionStates.first(where: { $0.kind == kind })?.isGranted == false
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

    /// `I-8`：与 `optionalMissingCount` 同源 —— 都走 `PermissionsSummaryMetrics`。
    /// 此前 `requiredReadiness` 只被自己的单测调用（**测试专属 API**：断言的不是产品行为）。
    private var requiredCount: Int {
        PermissionsSummaryMetrics.requiredReadiness(permissionStates).total
    }

    private var grantedRequiredCount: Int {
        PermissionsSummaryMetrics.requiredReadiness(permissionStates).granted
    }

    /// `I-8`：权限页「可稍后授权」计数。**唯一的取值处** ——
    /// 概览卡的值与下方列表的计数都由 `summaryTexts` 派生。
    /// 抽成可测的纯函数是为了让「两处同源」成为**可断言的模型层事实**
    /// （审计 `P1-4` 的原始形状正是两处各自计算、给出相反结论）。
    private var optionalMissingCount: Int {
        PermissionsSummaryMetrics.optionalMissingCount(permissionStates)
    }

    /// `I-8`：本屏两处「可稍后授权」计数的**真实渲染串**（internal：只服务本模块
    /// 的渲染与单测）。
    ///
    /// 视图的 `body` 读它、单测也读它 —— 这样「两处同源」才是**对被测视图本身**
    /// 的断言。此前的守卫自算 `n` 再造两个期望串比对，被测视图**一行未读**：
    /// 把列表侧的取值口径改成独立计算（变异），守卫照旧通过（复审 `F-05` 的实证）。
    ///
    /// 两处都必须走 `PermissionsSummaryMetrics` 与 `AtlasL10n`，不得各自另算。
    var summaryTexts: (card: String, sectionCount: String) {
        // 两处共用同一个 n（而不是各调一次 `optionalMissingCount`）——把「同源」
        // 从注释里的承诺变成结构上的事实。
        let n = optionalMissingCount
        return (
            card: AtlasL10n.string("permissions.metric.later.value", n),
            sectionCount: AtlasL10n.string(
                n == 1
                    ? "permissions.optionalSection.count.one"
                    : "permissions.optionalSection.count.other",
                n
            )
        )
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
    private var nextStepButtons: some View {
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

        // `P1-6`：记下「用户为哪一项跳去了系统设置」，回来后据此给出二次引导。
        pendingAuthorizeKind = kind
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
