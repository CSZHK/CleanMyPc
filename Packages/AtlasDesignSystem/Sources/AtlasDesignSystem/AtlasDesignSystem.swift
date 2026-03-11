import Foundation
import SwiftUI

public enum AtlasTone: Sendable {
    case neutral
    case success
    case warning
    case danger

    public var tint: Color {
        switch self {
        case .neutral:
            return AtlasColor.brand
        case .success:
            return AtlasColor.success
        case .warning:
            return AtlasColor.warning
        case .danger:
            return AtlasColor.danger
        }
    }

    public var fill: Color {
        tint.opacity(0.12)
    }

    public var softFill: Color {
        tint.opacity(0.08)
    }

    public var border: Color {
        tint.opacity(0.18)
    }

    public var symbol: String {
        switch self {
        case .neutral:
            return "circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .danger:
            return "xmark.octagon.fill"
        }
    }
}

public enum AtlasFormatters {
    public static func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    public static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    public static func shortDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

public struct AtlasScreen<Content: View>: View {
    private let title: String
    private let subtitle: String
    private let useScrollView: Bool
    private let maxContentWidth: CGFloat?
    private let content: Content

    public init(
        title: String,
        subtitle: String,
        useScrollView: Bool = true,
        maxContentWidth: CGFloat? = AtlasLayout.maxReadingWidth,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.useScrollView = useScrollView
        self.maxContentWidth = maxContentWidth
        self.content = content()
    }

    public var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = resolvedHorizontalPadding(for: proxy.size.width)

            ZStack {
                LinearGradient(
                    colors: [AtlasColor.canvasTop, AtlasColor.canvasBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Group {
                    if useScrollView {
                        ScrollView {
                            contentStack(horizontalPadding: horizontalPadding, containerWidth: proxy.size.width)
                        }
                    } else {
                        contentStack(horizontalPadding: horizontalPadding, containerWidth: proxy.size.width)
                    }
                }
            }
        }
    }

    private func contentStack(horizontalPadding: CGFloat, containerWidth: CGFloat) -> some View {
        let availableWidth = max(containerWidth - horizontalPadding * 2, 0)
        let contentWidth = min(maxContentWidth ?? availableWidth, availableWidth)

        return VStack(alignment: .leading, spacing: AtlasSpacing.xxl) {
            header
            content
        }
        .frame(maxWidth: maxContentWidth ?? .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, AtlasSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.atlasContentWidth, max(0, contentWidth))
    }

    private func resolvedHorizontalPadding(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<820:
            return 16
        case ..<980:
            return 20
        default:
            return AtlasSpacing.screenH
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
            Text(title)
                .font(AtlasTypography.screenTitle)

            Text(subtitle)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

public struct AtlasMetricCard: View {
    private let title: String
    private let value: String
    private let detail: String
    private let tone: AtlasTone
    private let systemImage: String?
    private let elevation: AtlasElevation

    public init(
        title: String,
        value: String,
        detail: String,
        tone: AtlasTone = .neutral,
        systemImage: String? = nil,
        elevation: AtlasElevation = .raised
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.tone = tone
        self.systemImage = systemImage
        self.elevation = elevation
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            HStack(alignment: .center, spacing: AtlasSpacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(tone.tint)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(AtlasTypography.label)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(elevation == .prominent ? AtlasTypography.heroMetric : AtlasTypography.cardMetric)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(detail)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.xl)
        .background(atlasCardBackground(tone: tone, elevation: elevation))
        .overlay(atlasCardBorder(tone: tone, elevation: elevation))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text(detail))
    }
}

public struct AtlasInfoCard<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let tone: AtlasTone
    private let content: Content

    public init(
        title: String,
        subtitle: String? = nil,
        tone: AtlasTone = .neutral,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xl) {
            if !title.isEmpty || subtitle != nil {
                VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                    if !title.isEmpty {
                        Text(title)
                            .font(AtlasTypography.sectionTitle)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(AtlasTypography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.xxl)
        .background(atlasCardBackground(tone: tone))
        .overlay(atlasCardBorder(tone: tone))
    }
}

public struct AtlasCallout: View {
    private let title: String
    private let detail: String
    private let tone: AtlasTone
    private let systemImage: String?

    public init(
        title: String,
        detail: String,
        tone: AtlasTone = .neutral,
        systemImage: String? = nil
    ) {
        self.title = title
        self.detail = detail
        self.tone = tone
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AtlasSpacing.lg) {
            Image(systemName: systemImage ?? tone.symbol)
                .font(.headline)
                .foregroundStyle(tone.tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
                Text(title)
                    .font(AtlasTypography.rowTitle)

                Text(detail)
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AtlasSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(tone.softFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(tone.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(detail))
    }
}

public struct AtlasDetailRow<Trailing: View>: View {
    private let title: String
    private let subtitle: String
    private let footnote: String?
    private let systemImage: String?
    private let tone: AtlasTone
    private let isInteractive: Bool
    private let trailing: Trailing

    public init(
        title: String,
        subtitle: String,
        footnote: String? = nil,
        systemImage: String? = nil,
        tone: AtlasTone = .neutral,
        isInteractive: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.footnote = footnote
        self.systemImage = systemImage
        self.tone = tone
        self.isInteractive = isInteractive
        self.trailing = trailing()
    }

    public var body: some View {
        Group {
            if isInteractive {
                rowBody
                    .atlasHover()
            } else {
                rowBody
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var rowBody: some View {
        AtlasAdaptiveDetailRowLayout(
            spacing: AtlasSpacing.lg,
            accessorySpacing: AtlasSpacing.md,
            minimumTextWidth: AtlasLayout.detailRowMinimumTextWidth
        ) {
            AtlasDetailRowLayoutSlot {
                iconView
            }
            AtlasDetailRowLayoutSlot {
                textStack
            }
            .layoutPriority(1)
            AtlasDetailRowLayoutSlot {
                trailing
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(AtlasColor.cardRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var iconView: some View {
        if let systemImage {
            ZStack {
                Circle()
                    .fill(tone.softFill)
                    .frame(width: AtlasLayout.sidebarIconSize + 4, height: AtlasLayout.sidebarIconSize + 4)

                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tone.tint)
                    .accessibilityHidden(true)
            }
        } else {
            EmptyView()
        }
    }

    private var textStack: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            Text(title)
                .font(AtlasTypography.rowTitle)

            Text(subtitle)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let footnote {
                Text(footnote)
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

public extension AtlasDetailRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String,
        footnote: String? = nil,
        systemImage: String? = nil,
        tone: AtlasTone = .neutral,
        isInteractive: Bool = false
    ) {
        self.init(title: title, subtitle: subtitle, footnote: footnote, systemImage: systemImage, tone: tone, isInteractive: isInteractive) {
            EmptyView()
        }
    }
}

public struct AtlasKeyValueRow: View {
    private let title: String
    private let value: String
    private let detail: String?

    public init(title: String, value: String, detail: String? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AtlasSpacing.md) {
                    titleView

                    Spacer(minLength: AtlasSpacing.lg)

                    valueView(alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: AtlasSpacing.sm) {
                    titleView
                    valueView(alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let detail {
                Text(detail)
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, AtlasSpacing.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text(detail ?? ""))
    }

    private var titleView: some View {
        Text(title)
            .font(AtlasTypography.rowTitle)
    }

    private func valueView(alignment: TextAlignment) -> some View {
        Text(value)
            .font(AtlasTypography.label)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }
}

public struct AtlasMachineTextBlock: View {
    private let title: String
    private let value: String
    private let detail: String?

    public init(title: String, value: String, detail: String? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.xs) {
            Text(title)
                .font(AtlasTypography.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(AtlasTypography.captionSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .strokeBorder(AtlasColor.border, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(value))
        .accessibilityHint(Text(detail ?? ""))
    }
}

private struct AtlasAdaptiveDetailRowLayout: Layout {
    let spacing: CGFloat
    let accessorySpacing: CGFloat
    let minimumTextWidth: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        measurements(for: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let measurements = measurements(
            for: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )

        guard let textSubview = subview(at: 1, in: subviews) else {
            return
        }
        let accessorySubview = subview(at: 2, in: subviews)
        let contentX = bounds.minX + measurements.leadingOffset
        let textProposal = ProposedViewSize(width: measurements.textWidth, height: nil)
        let textSize = textSubview.sizeThatFits(textProposal)

        if measurements.hasIcon, let iconSubview = subview(at: 0, in: subviews) {
            iconSubview.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                proposal: ProposedViewSize(
                    width: measurements.iconSize.width,
                    height: measurements.iconSize.height
                )
            )
        }

        textSubview.place(
            at: CGPoint(x: contentX, y: bounds.minY),
            proposal: textProposal
        )

        guard measurements.hasAccessory else {
            return
        }

        if measurements.useCompactLayout {
            accessorySubview?.place(
                at: CGPoint(
                    x: contentX,
                    y: bounds.minY + textSize.height + accessorySpacing
                ),
                proposal: ProposedViewSize(width: measurements.textWidth, height: nil)
            )
        } else {
            accessorySubview?.place(
                at: CGPoint(
                    x: bounds.maxX - measurements.accessorySize.width,
                    y: bounds.minY
                ),
                proposal: ProposedViewSize(
                    width: measurements.accessorySize.width,
                    height: measurements.accessorySize.height
                )
            )
        }
    }

    private func measurements(
        for proposal: ProposedViewSize,
        subviews: Subviews
    ) -> AtlasAdaptiveDetailRowMeasurements {
        let iconSize = subview(at: 0, in: subviews)?.sizeThatFits(.unspecified) ?? .zero
        let accessoryIdealSize = subview(at: 2, in: subviews)?.sizeThatFits(.unspecified) ?? .zero

        let hasIcon = iconSize != .zero
        let hasAccessory = accessoryIdealSize != .zero
        let leadingOffset = hasIcon ? iconSize.width + spacing : 0
        let horizontalAccessoryOffset = hasAccessory ? accessoryIdealSize.width + spacing : 0
        let resolvedWidth = proposal.width
        let horizontalTextWidth = resolvedWidth.map { max($0 - leadingOffset - horizontalAccessoryOffset, 0) }
        let useCompactLayout = hasAccessory && (horizontalTextWidth.map { $0 < minimumTextWidth } ?? false)

        if useCompactLayout {
            let textWidth = max((resolvedWidth ?? minimumTextWidth) - leadingOffset, 0)
            let textSize = subview(at: 1, in: subviews)?.sizeThatFits(ProposedViewSize(width: textWidth, height: nil)) ?? .zero
            let accessorySize = subview(at: 2, in: subviews)?.sizeThatFits(ProposedViewSize(width: textWidth, height: nil)) ?? .zero
            let contentHeight = textSize.height + accessorySpacing + accessorySize.height
            let width = resolvedWidth ?? (leadingOffset + max(textSize.width, accessorySize.width))

            return AtlasAdaptiveDetailRowMeasurements(
                size: CGSize(width: width, height: max(iconSize.height, contentHeight)),
                iconSize: iconSize,
                accessorySize: accessorySize,
                textWidth: textWidth,
                leadingOffset: leadingOffset,
                hasIcon: hasIcon,
                hasAccessory: hasAccessory,
                useCompactLayout: true
            )
        } else {
            let textSize = subview(at: 1, in: subviews)?.sizeThatFits(ProposedViewSize(width: horizontalTextWidth, height: nil)) ?? .zero
            let width = resolvedWidth ?? (leadingOffset + textSize.width + horizontalAccessoryOffset)

            return AtlasAdaptiveDetailRowMeasurements(
                size: CGSize(width: width, height: max(iconSize.height, textSize.height, accessoryIdealSize.height)),
                iconSize: iconSize,
                accessorySize: accessoryIdealSize,
                textWidth: max(width - leadingOffset - horizontalAccessoryOffset, 0),
                leadingOffset: leadingOffset,
                hasIcon: hasIcon,
                hasAccessory: hasAccessory,
                useCompactLayout: false
            )
        }
    }

    private func subview(at index: Int, in subviews: Subviews) -> LayoutSubview? {
        guard subviews.indices.contains(index) else {
            return nil
        }
        return subviews[index]
    }
}

private struct AtlasAdaptiveDetailRowMeasurements {
    let size: CGSize
    let iconSize: CGSize
    let accessorySize: CGSize
    let textWidth: CGFloat
    let leadingOffset: CGFloat
    let hasIcon: Bool
    let hasAccessory: Bool
    let useCompactLayout: Bool
}

private struct AtlasDetailRowLayoutSlot<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }
}

public struct AtlasStatusChip: View {
    private let label: String
    private let tone: AtlasTone

    public init(_ label: String, tone: AtlasTone) {
        self.label = label
        self.tone = tone
    }

    public var body: some View {
        Text(label)
            .font(AtlasTypography.caption)
            .padding(.horizontal, AtlasSpacing.md)
            .padding(.vertical, AtlasSpacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.fill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tone.border, lineWidth: 1)
            )
            .foregroundStyle(tone.tint)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
    }
}

public struct AtlasEmptyState: View {
    private let title: String
    private let detail: String
    private let systemImage: String
    private let tone: AtlasTone
    private let actionTitle: String?
    private let onAction: (() -> Void)?

    public init(title: String, detail: String, systemImage: String, tone: AtlasTone = .neutral, actionTitle: String? = nil, onAction: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.tone = tone
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: AtlasSpacing.lg) {
            ZStack {
                Circle()
                    .strokeBorder(tone.border, lineWidth: 0.5)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tone.softFill, tone.softFill.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(tone.tint)
                    .accessibilityHidden(true)
            }

            VStack(spacing: AtlasSpacing.xs) {
                Text(title)
                    .font(AtlasTypography.rowTitle)

                Text(detail)
                    .font(AtlasTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let onAction {
                Button(actionTitle) {
                    onAction()
                }
                .buttonStyle(.atlasSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AtlasSpacing.section)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.xl, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.xl, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: onAction != nil ? .contain : .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(detail))
    }
}

public struct AtlasLoadingState: View {
    private let title: String
    private let detail: String
    private let progress: Double?
    @State private var pulsePhase = false

    public init(title: String, detail: String, progress: Double? = nil) {
        self.title = title
        self.detail = detail
        self.progress = progress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AtlasSpacing.lg) {
            HStack(spacing: AtlasSpacing.md) {
                ProgressView()
                    .controlSize(.small)
                    .tint(AtlasColor.brand)
                    .accessibilityHidden(true)

                Text(title)
                    .font(AtlasTypography.rowTitle)
            }

            Text(detail)
                .font(AtlasTypography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let progress {
                ProgressView(value: progress, total: 1)
                    .controlSize(.large)
                    .tint(AtlasColor.brand)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AtlasSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .fill(Color.primary.opacity(pulsePhase ? 0.05 : 0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AtlasRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(progress.map { "\(Int(($0 * 100).rounded())) percent complete" } ?? detail))
        .accessibilityHint(Text(detail))
    }
}
