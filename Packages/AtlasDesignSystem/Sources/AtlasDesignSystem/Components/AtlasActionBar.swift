import SwiftUI

/// Pinned ink-dark action bar (spec §2.3/§4.2):
/// `[primary →] ⛨ state-driven promise ………… mono total`.
///
/// - `promise` is the state-driven recovery sentence; nil ⇒ no ⛨ sentence at all
///   (fail-closed, spec §1.6 — never render a static trust claim).
/// - `progress` non-nil ⇒ the primary button is replaced by a progress capsule.
/// - Yield order under narrow width (`atlasContentWidth` < `actionBarCompactBreakpoint`):
///   promise collapses to a ⛨ icon badge (full text via tooltip), metric stays,
///   the primary button never truncates.
public struct AtlasActionBar: View {
    private let primaryTitle: String
    private let primaryEnabled: Bool
    private let onPrimary: () -> Void
    private let promise: String?
    private let metricText: String?
    private let progress: Double?

    @Environment(\.atlasContentWidth) private var contentWidth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        primaryTitle: String,
        primaryEnabled: Bool,
        onPrimary: @escaping () -> Void,
        promise: String?,
        metricText: String?,
        progress: Double?
    ) {
        self.primaryTitle = primaryTitle
        self.primaryEnabled = primaryEnabled
        self.onPrimary = onPrimary
        self.promise = promise
        self.metricText = metricText
        self.progress = progress
    }

    // MARK: Pure layout logic (unit-tested)

    /// How the promise sentence renders at a given content width.
    public enum PromiseDisplay: Equatable, Sendable {
        /// No promise supplied — nothing renders (fail-closed).
        case hidden
        /// Narrow width — ⛨ icon badge only, full sentence via tooltip.
        case icon
        /// Full ⛨ sentence.
        case full
    }

    /// Primary slot mode: tappable button, or progress capsule while executing.
    public enum PrimaryMode: Equatable, Sendable {
        case button
        case progress(Double)
    }

    /// Yield decision (spec §4.2): promise gives way first; metric stays;
    /// the primary button is never sacrificed.
    public static func promiseDisplay(contentWidth: CGFloat, hasPromise: Bool) -> PromiseDisplay {
        guard hasPromise else { return .hidden }
        return contentWidth < AtlasLayout.actionBarCompactBreakpoint ? .icon : .full
    }

    /// Progress non-nil ⇒ progress mode, clamped to 0…1.
    public static func primaryMode(progress: Double?) -> PrimaryMode {
        guard let progress else { return .button }
        return .progress(min(max(progress, 0), 1))
    }

    /// Mono percent label for the progress capsule.
    public static func percentText(for progress: Double) -> String {
        "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
    }

    // MARK: Body

    public var body: some View {
        HStack(spacing: AtlasSpacing.lg) {
            primarySlot

            promiseSlot

            Spacer(minLength: AtlasSpacing.sm)

            if let metricText {
                Text(metricText)
                    .font(AtlasTypography.dataBody)
                    .monospacedDigit()
                    .foregroundStyle(AtlasColor.actionBarData)
                    .contentTransition(.numericText())
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AtlasSpacing.lg)
        .padding(.vertical, AtlasSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AtlasRadius.md, style: .continuous)
                .fill(AtlasColor.actionBarBg)
                .shadow(
                    color: Color.black.opacity(AtlasElevation.raised.shadowOpacity),
                    radius: AtlasElevation.raised.shadowRadius,
                    x: 0,
                    y: AtlasElevation.raised.shadowY
                )
        )
        .animation(reduceMotion ? nil : AtlasMotion.standard, value: Self.primaryMode(progress: progress))
        .animation(reduceMotion ? nil : AtlasMotion.standard, value: promiseDisplay)
    }

    private var promiseDisplay: PromiseDisplay {
        Self.promiseDisplay(contentWidth: contentWidth, hasPromise: promise != nil)
    }

    // MARK: Primary slot

    @ViewBuilder
    private var primarySlot: some View {
        switch Self.primaryMode(progress: progress) {
        case .button:
            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(AtlasTypography.label)
                    .foregroundStyle(AtlasColor.onBrand) // AA on both gradient stops (PER #9)
                    .lineLimit(1)
                    .fixedSize() // never truncates (spec §4.2 yield order)
                    .padding(.horizontal, AtlasSpacing.xxl)
                    .padding(.vertical, AtlasSpacing.sm)
                    .background(Capsule(style: .continuous).fill(AtlasColor.bannerGradient))
                    .opacity(primaryEnabled ? 1 : 0.45)
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!primaryEnabled)
            .accessibilityLabel(Text(primaryTitle))

        case .progress(let value):
            HStack(spacing: AtlasSpacing.sm) {
                ProgressView(value: value, total: 1)
                    .progressViewStyle(.linear)
                    .tint(AtlasColor.actionBarData)
                    .frame(width: 120)

                Text(Self.percentText(for: value))
                    .font(AtlasTypography.dataBody)
                    .monospacedDigit()
                    .foregroundStyle(AtlasColor.actionBarData)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, AtlasSpacing.lg)
            .padding(.vertical, AtlasSpacing.sm)
            .background(Capsule(style: .continuous).fill(AtlasColor.actionBarTrack))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(primaryTitle))
            .accessibilityValue(Text(Self.percentText(for: value)))
        }
    }

    // MARK: Promise slot

    @ViewBuilder
    private var promiseSlot: some View {
        switch promiseDisplay {
        case .hidden:
            EmptyView()

        case .icon:
            if let promise {
                Image(systemName: "checkmark.shield.fill")
                    .font(AtlasTypography.caption)
                    .foregroundStyle(AtlasColor.actionBarText)
                    .help(promise) // full sentence on hover
                    .accessibilityLabel(Text(promise))
            }

        case .full:
            if let promise {
                HStack(spacing: AtlasSpacing.xs) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(AtlasTypography.captionSmall)
                        .foregroundStyle(AtlasColor.actionBarText)
                        .accessibilityHidden(true)
                    Text(promise)
                        .font(AtlasTypography.bodySmall)
                        .foregroundStyle(AtlasColor.actionBarText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(promise))
            }
        }
    }
}
