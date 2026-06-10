import AtlasDomain
import SwiftUI

// MARK: - Stage Model

/// One stage in a workflow stage bar (e.g. ①扫描 ②复核 ③执行 ④回执).
public struct AtlasStage: Identifiable, Equatable, Sendable {
    /// Stage ordinal (0-based).
    public let id: Int
    /// Localized title supplied by the caller (DS convention: primary copy is caller-localized).
    public let title: String

    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}

// MARK: - Stage Bar

/// Capsule segmented stage bar (spec §2.3/§4.2).
/// - completed → tappable, `successFill` ground, "①✓" prefix
/// - current   → `brand` ground, white bold
/// - future    → disabled, `textTertiary` on `surfaceSubdued` (tertiary never sits on bare canvas)
///
/// Keyboard: the whole bar is a single Tab stop; ←/→ move the highlight across
/// ALL stages (so a disabled stage can be reached and its reason announced —
/// spec "禁用段可聚焦并朗读原因"); Return/Space activate only completed stages.
/// Compact (<520pt container): collapses to a single "②/④ 复核" capsule (circled
/// numerals are visual-only; a11y always uses plain numbers).
public struct AtlasStageBar: View {
    /// Visual classification of one stage.
    public enum StageState: Equatable, Sendable {
        case completed
        case current
        case future
    }

    private let stages: [AtlasStage]
    private let currentIndex: Int
    private let completedIndices: Set<Int>
    private let onSelect: (Int) -> Void

    @State private var highlightedIndex: Int?
    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let barHeight: CGFloat = 32
    /// Container width below which the bar collapses to "②/④ <title>" (spec §4.2).
    public static let compactThreshold: CGFloat = 520

    public init(
        stages: [AtlasStage],
        currentIndex: Int,
        completedIndices: Set<Int>,
        onSelect: @escaping (Int) -> Void
    ) {
        self.stages = stages
        self.currentIndex = currentIndex
        self.completedIndices = completedIndices
        self.onSelect = onSelect
    }

    // MARK: Pure logic (unit-tested)

    /// Classifies a stage index. Precedence: current → completed → future.
    public static func stageState(at index: Int, currentIndex: Int, completedIndices: Set<Int>) -> StageState {
        if index == currentIndex { return .current }
        if completedIndices.contains(index) { return .completed }
        return .future
    }

    /// Compact when the available container width is below 520pt (spec §4.2).
    public static func isCompact(containerWidth: CGFloat) -> Bool {
        containerWidth < compactThreshold
    }

    /// Circled numeral for 1-based positions (①…⑳); plain number beyond. Visual-only.
    public static func circledNumeral(_ position: Int) -> String {
        guard position >= 1, position <= 20,
              let scalar = Unicode.Scalar(0x2460 + position - 1) else {
            return "\(position)"
        }
        return String(Character(scalar))
    }

    /// Localized a11y value: 「第 N 阶段，共 M 个：X，状态」/ "Stage N of M: X, status".
    /// Disabled stages announce the reason via the unavailable status string.
    public static func accessibilityValue(
        stageTitle: String,
        position: Int,
        total: Int,
        state: StageState,
        language: AtlasLanguage? = nil
    ) -> String {
        let statusKey: String
        switch state {
        case .current:   statusKey = "ds.stagebar.status.current"
        case .completed: statusKey = "ds.stagebar.status.completed"
        case .future:    statusKey = "ds.stagebar.status.unavailable"
        }
        let status = AtlasL10n.string(statusKey, language: language)
        return AtlasL10n.string("ds.stagebar.value", language: language, position, total, stageTitle, status)
    }

    /// Moves the keyboard highlight by `delta`, clamped to the stage range (no wrap).
    public static func movedHighlight(from index: Int, delta: Int, stageCount: Int) -> Int {
        guard stageCount > 0 else { return 0 }
        return min(max(index + delta, 0), stageCount - 1)
    }

    // MARK: Body

    public var body: some View {
        GeometryReader { proxy in
            Group {
                if Self.isCompact(containerWidth: proxy.size.width) {
                    compactSegment
                } else {
                    HStack(spacing: AtlasSpacing.xs) {
                        ForEach(stages) { stage in
                            segment(for: stage)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .animation(reduceMotion ? nil : AtlasMotion.stageTransition, value: currentIndex)
        }
        .frame(height: Self.barHeight)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onMoveCommand { direction in
            switch direction {
            case .left:  moveHighlight(by: -1)
            case .right: moveHighlight(by: +1)
            default: break
            }
        }
        .onKeyPress(.return) { activateHighlighted() }
        .onKeyPress(.space) { activateHighlighted() }
        .onChange(of: isFocused) { _, focused in
            highlightedIndex = focused ? currentIndex : nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(AtlasL10n.string("ds.stagebar.label")))
        .accessibilityValue(Text(announcedValue))
    }

    // MARK: Segments

    @ViewBuilder
    private func segment(for stage: AtlasStage) -> some View {
        let index = indexOf(stage)
        let state = Self.stageState(at: index, currentIndex: currentIndex, completedIndices: completedIndices)
        let label = segmentText(for: stage, at: index, state: state)

        switch state {
        case .completed:
            Button {
                onSelect(index)
            } label: {
                segmentLabel(label, state: state)
            }
            .buttonStyle(.plain)
            .focusable(false) // the BAR is the single Tab stop — inner buttons stay out of the focus loop
            .overlay(focusRing(for: index))
        case .current, .future:
            segmentLabel(label, state: state)
                .overlay(focusRing(for: index))
        }
    }

    private var compactSegment: some View {
        let title = stages.indices.contains(currentIndex) ? stages[currentIndex].title : ""
        let text = "\(Self.circledNumeral(currentIndex + 1))/\(Self.circledNumeral(stages.count)) \(title)"
        return segmentLabel(text, state: .current)
            .overlay(focusRing(for: currentIndex))
    }

    private func segmentLabel(_ text: String, state: StageState) -> some View {
        Text(text)
            .font(state == .current ? AtlasTypography.caption.bold() : AtlasTypography.caption)
            .foregroundStyle(foreground(for: state))
            .lineLimit(1)
            .padding(.horizontal, AtlasSpacing.lg)
            .padding(.vertical, AtlasSpacing.xs)
            .background(Capsule(style: .continuous).fill(background(for: state)))
            .contentShape(Capsule(style: .continuous))
    }

    private func segmentText(for stage: AtlasStage, at index: Int, state: StageState) -> String {
        let numeral = Self.circledNumeral(index + 1)
        switch state {
        case .completed: return "\(numeral)\u{2713} \(stage.title)" // ①✓ prefix
        case .current, .future: return "\(numeral) \(stage.title)"
        }
    }

    private func foreground(for state: StageState) -> Color {
        switch state {
        case .completed: return AtlasColor.success
        case .current:   return .white
        case .future:    return AtlasColor.textTertiary
        }
    }

    private func background(for state: StageState) -> Color {
        switch state {
        case .completed: return AtlasColor.successFill
        case .current:   return AtlasColor.brand
        case .future:    return AtlasColor.surfaceSubdued
        }
    }

    /// Brand 2pt ring, 2pt offset, capsule-shaped (spec §4.2) — drawn only around
    /// the keyboard-highlighted segment while the bar holds focus.
    @ViewBuilder
    private func focusRing(for index: Int) -> some View {
        if isFocused && highlightedIndex == index {
            Capsule(style: .continuous)
                .inset(by: -3) // stroke center 3pt out ⇒ 2pt-wide ring with a 2pt gap
                .stroke(AtlasColor.brand, lineWidth: 2)
        }
    }

    // MARK: Keyboard

    private func moveHighlight(by delta: Int) {
        let base = highlightedIndex ?? currentIndex
        highlightedIndex = Self.movedHighlight(from: base, delta: delta, stageCount: stages.count)
    }

    private func activateHighlighted() -> KeyPress.Result {
        guard let index = highlightedIndex,
              Self.stageState(at: index, currentIndex: currentIndex, completedIndices: completedIndices) == .completed else {
            return .ignored
        }
        onSelect(index)
        return .handled
    }

    private func indexOf(_ stage: AtlasStage) -> Int {
        stages.firstIndex(of: stage) ?? stage.id
    }

    private var announcedValue: String {
        let index = highlightedIndex ?? currentIndex
        guard stages.indices.contains(index) else { return "" }
        let state = Self.stageState(at: index, currentIndex: currentIndex, completedIndices: completedIndices)
        return Self.accessibilityValue(
            stageTitle: stages[index].title,
            position: index + 1,
            total: stages.count,
            state: state
        )
    }
}
