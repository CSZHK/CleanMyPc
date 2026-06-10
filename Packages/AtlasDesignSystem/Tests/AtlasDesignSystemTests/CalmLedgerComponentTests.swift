import XCTest
@testable import AtlasDesignSystem
import AtlasDomain
import SwiftUI

/// Batch F — Calm Ledger M2 core interactive components.
/// Logic-first tests: each component exposes its decision logic as pure
/// functions/static helpers so behavior is testable without rendering.
@MainActor
final class CalmLedgerComponentTests: XCTestCase {

    // MARK: - F1 AtlasStageBar

    func testStageBarStateMapping() {
        let completed: Set<Int> = [0, 1]
        // completed / current / future classification
        XCTAssertEqual(AtlasStageBar.stageState(at: 0, currentIndex: 2, completedIndices: completed), .completed)
        XCTAssertEqual(AtlasStageBar.stageState(at: 1, currentIndex: 2, completedIndices: completed), .completed)
        XCTAssertEqual(AtlasStageBar.stageState(at: 2, currentIndex: 2, completedIndices: completed), .current)
        XCTAssertEqual(AtlasStageBar.stageState(at: 3, currentIndex: 2, completedIndices: completed), .future)
        // current takes precedence even when the host also marks it completed
        XCTAssertEqual(AtlasStageBar.stageState(at: 1, currentIndex: 1, completedIndices: [0, 1]), .current)
    }

    func testStageBarCompactThreshold() {
        XCTAssertTrue(AtlasStageBar.isCompact(containerWidth: 519))
        XCTAssertTrue(AtlasStageBar.isCompact(containerWidth: 519.9))
        XCTAssertFalse(AtlasStageBar.isCompact(containerWidth: 520))
        XCTAssertFalse(AtlasStageBar.isCompact(containerWidth: 880))
        XCTAssertEqual(AtlasStageBar.compactThreshold, 520)
    }

    func testStageBarA11yValueString() {
        // Plain numbers (circled numerals are visual-only), N/M interpolation, status suffix.
        let en = AtlasStageBar.accessibilityValue(
            stageTitle: "Review", position: 2, total: 4, state: .current, language: .en
        )
        XCTAssertEqual(en, "Stage 2 of 4: Review, current")

        let zh = AtlasStageBar.accessibilityValue(
            stageTitle: "复核", position: 2, total: 4, state: .current, language: .zhHans
        )
        XCTAssertEqual(zh, "第 2 阶段，共 4 个：复核，当前")

        // Disabled stage announces the reason (spec: 禁用段可聚焦并朗读原因).
        let disabledEn = AtlasStageBar.accessibilityValue(
            stageTitle: "Run", position: 3, total: 4, state: .future, language: .en
        )
        XCTAssertTrue(disabledEn.contains("unavailable"), "got: \(disabledEn)")
        let disabledZh = AtlasStageBar.accessibilityValue(
            stageTitle: "执行", position: 3, total: 4, state: .future, language: .zhHans
        )
        XCTAssertTrue(disabledZh.contains("不可用"), "got: \(disabledZh)")
    }

    // MARK: - F2 AtlasEvidencePanel

    func testEvidencePanelStateExhaustive() {
        let content = AtlasEvidenceContent(
            title: "Safari 缓存",
            whyText: "仅缓存数据，应用会自动重建",
            evidence: [AtlasEvidenceItem(id: "p1", label: "路径", value: "~/Library/Caches/com.apple.Safari")],
            recoveryText: "恢复点已建立 · 1.2 GB · 保留 7 天"
        )
        let aggregate = AtlasEvidenceAggregate(
            count: 12,
            totalText: "3.4 GB",
            riskBreakdown: [("安全", 10, AtlasTone.success), ("复核", 2, AtlasTone.warning)],
            commonRecoveryText: "全部可恢复"
        )
        let states: [AtlasEvidenceState] = [
            .empty,
            .single(content),
            .aggregate(aggregate),
            .executing(rows: [("已清理 Safari 缓存", .success, nil), ("清理失败", .danger, "权限不足")]),
        ]
        // All four kinds construct and discriminate; panel hosts each without crashing.
        XCTAssertEqual(states.map(\.kind), [.empty, .single, .aggregate, .executing])
        for state in states {
            let panel = AtlasEvidencePanel(state: state) { Text("act") }
            XCTAssertNotNil(panel.body)
        }
        // Recovery predicate across kinds: only single/aggregate with text show the box.
        XCTAssertFalse(AtlasEvidenceState.empty.showsRecoveryBox)
        XCTAssertTrue(AtlasEvidenceState.single(content).showsRecoveryBox)
        XCTAssertTrue(AtlasEvidenceState.aggregate(aggregate).showsRecoveryBox)
        XCTAssertFalse(AtlasEvidenceState.executing(rows: []).showsRecoveryBox)
    }

    func testEvidenceRecoveryNilHidesShieldBox() {
        // fail-closed (spec §1.6): no recovery facts ⇒ no ⛨ box, ever.
        let noRecovery = AtlasEvidenceContent(title: "t", whyText: "w", evidence: [], recoveryText: nil)
        XCTAssertFalse(AtlasEvidenceState.single(noRecovery).showsRecoveryBox)

        let blankRecovery = AtlasEvidenceContent(title: "t", whyText: "w", evidence: [], recoveryText: "  \n")
        XCTAssertFalse(AtlasEvidenceState.single(blankRecovery).showsRecoveryBox, "whitespace-only must stay fail-closed")

        let noCommon = AtlasEvidenceAggregate(count: 2, totalText: "1 MB", riskBreakdown: [], commonRecoveryText: nil)
        XCTAssertFalse(AtlasEvidenceState.aggregate(noCommon).showsRecoveryBox)

        let withRecovery = AtlasEvidenceContent(title: "t", whyText: "w", evidence: [], recoveryText: "保留 7 天")
        XCTAssertTrue(AtlasEvidenceState.single(withRecovery).showsRecoveryBox)
    }

    // MARK: - F3 AtlasActionBar

    func testActionBarCompactDropsPromiseKeepsPrimary() {
        let breakpoint = AtlasLayout.actionBarCompactBreakpoint // 740
        // Wide: full ⛨ sentence.
        XCTAssertEqual(AtlasActionBar.promiseDisplay(contentWidth: breakpoint, hasPromise: true), .full)
        XCTAssertEqual(AtlasActionBar.promiseDisplay(contentWidth: 1000, hasPromise: true), .full)
        // Narrow: promise yields to the ⛨ icon — primary mode is untouched by width
        // (the button never enters the yield order).
        XCTAssertEqual(AtlasActionBar.promiseDisplay(contentWidth: breakpoint - 1, hasPromise: true), .icon)
        XCTAssertEqual(AtlasActionBar.primaryMode(progress: nil), .button)
        // No promise ⇒ hidden at every width (fail-closed §1.6 — no static ⛨ claim).
        XCTAssertEqual(AtlasActionBar.promiseDisplay(contentWidth: 1000, hasPromise: false), .hidden)
        XCTAssertEqual(AtlasActionBar.promiseDisplay(contentWidth: 400, hasPromise: false), .hidden)
    }

    func testActionBarProgressMode() {
        XCTAssertEqual(AtlasActionBar.primaryMode(progress: nil), .button)
        XCTAssertEqual(AtlasActionBar.primaryMode(progress: 0.42), .progress(0.42))
        // Out-of-range progress clamps instead of crashing the ProgressView.
        XCTAssertEqual(AtlasActionBar.primaryMode(progress: -0.5), .progress(0))
        XCTAssertEqual(AtlasActionBar.primaryMode(progress: 1.7), .progress(1))
        XCTAssertEqual(AtlasActionBar.percentText(for: 0.42), "42%")
        XCTAssertEqual(AtlasActionBar.percentText(for: 1.7), "100%")
        // Construction smoke for both modes.
        let bar = AtlasActionBar(
            primaryTitle: "执行清理计划", primaryEnabled: true, onPrimary: {},
            promise: "⛨ 执行前自动建立恢复点 · 保留 7 天", metricText: "3.4 GB", progress: 0.5
        )
        XCTAssertNotNil(bar.body)
    }

    // MARK: - F4 AtlasLedgerTimeline

    private func ledgerEntry(_ id: String, number: Int, status: AtlasLedgerEntryStatus) -> AtlasLedgerEntryModel {
        AtlasLedgerEntryModel(id: id, number: number, title: "清理计划", detail: "d", metricText: nil, status: status)
    }

    func testLedgerPinningOrder() {
        let entries = [
            ledgerEntry("a", number: 40, status: .verified),
            ledgerEntry("b", number: 42, status: .inProgress),
            ledgerEntry("c", number: 43, status: .recoverable(daysLeft: 5)),
            ledgerEntry("d", number: 41, status: .archived),
            ledgerEntry("e", number: 39, status: .inProgress),
        ]
        let ordered = AtlasLedgerTimeline.pinnedOrder(entries)
        // inProgress pinned first (№ desc within the pin group), rest by № desc.
        XCTAssertEqual(ordered.map(\.id), ["b", "e", "c", "d", "a"])
        XCTAssertEqual(ordered.map(\.number), [42, 39, 43, 41, 40])
        // Empty input stays empty (no crash).
        XCTAssertTrue(AtlasLedgerTimeline.pinnedOrder([]).isEmpty)
    }

    func testLedgerStatusBadgeMapping() {
        let recoverable = AtlasLedgerTimeline.badge(for: .recoverable(daysLeft: 5), language: .zhHans)
        XCTAssertEqual(recoverable.text, "恢复点 · 5 天")
        XCTAssertEqual(recoverable.symbol, "checkmark.shield.fill") // ⛨ teal shield, never red
        XCTAssertEqual(recoverable.tone, .neutral) // neutral → brand teal

        let recoverableEn = AtlasLedgerTimeline.badge(for: .recoverable(daysLeft: 7), language: .en)
        XCTAssertEqual(recoverableEn.text, "Restore point · 7 days")

        let verified = AtlasLedgerTimeline.badge(for: .verified, language: .zhHans)
        XCTAssertEqual(verified.text, "已验证")
        XCTAssertEqual(verified.symbol, "checkmark") // ✓
        XCTAssertEqual(verified.tone, .success)

        XCTAssertEqual(AtlasLedgerTimeline.badge(for: .archived, language: .zhHans).text, "已归档")
        XCTAssertNil(AtlasLedgerTimeline.badge(for: .archived, language: .zhHans).tone, "archived renders muted")
        XCTAssertEqual(AtlasLedgerTimeline.badge(for: .superseded, language: .en).text, "Superseded")
        XCTAssertNil(AtlasLedgerTimeline.badge(for: .superseded, language: .en).tone)
        XCTAssertEqual(AtlasLedgerTimeline.badge(for: .inProgress, language: .zhHans).text, "进行中")
        XCTAssertEqual(AtlasLedgerTimeline.badge(for: .inProgress, language: .zhHans).tone, .warning) // running precedent
    }

    func testLedgerEntryA11yLabel() {
        XCTAssertEqual(
            AtlasLedgerTimeline.accessibilityLabel(number: 42, title: "清理计划", language: .zhHans),
            "计划编号 42，清理计划"
        )
        XCTAssertEqual(
            AtlasLedgerTimeline.accessibilityLabel(number: 42, title: "Cleanup plan", language: .en),
            "Plan number 42, Cleanup plan"
        )
    }

    // MARK: - F5 AtlasStampBadge

    func testStampBadgeStyleVariants() {
        // badge = full presence, interactive layer behaves normally
        XCTAssertEqual(AtlasStampBadge.Style.badge.opacity, 1.0)
        XCTAssertEqual(AtlasStampBadge.Style.badge.sizeMultiplier, 1.0)
        XCTAssertTrue(AtlasStampBadge.Style.badge.allowsHitTesting)
        // watermark = 0.45 opacity, ×1.4 size, never intercepts clicks (spec §4.2)
        XCTAssertEqual(AtlasStampBadge.Style.watermark.opacity, 0.45)
        XCTAssertEqual(AtlasStampBadge.Style.watermark.sizeMultiplier, 1.4)
        XCTAssertFalse(AtlasStampBadge.Style.watermark.allowsHitTesting)
    }

    func testStampBadgeConstruction() {
        // Both variants construct with full and minimal content (default style = .badge).
        let badge = AtlasStampBadge(
            title: "恢复点已建立", subtitle: "1.2 GB · 保留 7 天", numberText: "№42"
        )
        XCTAssertNotNil(badge.body)
        let watermark = AtlasStampBadge(title: "已验证", subtitle: nil, numberText: nil, style: .watermark)
        XCTAssertNotNil(watermark.body)
    }

    func testStageBarCircledNumeralAndHighlightClamp() {
        XCTAssertEqual(AtlasStageBar.circledNumeral(1), "①")
        XCTAssertEqual(AtlasStageBar.circledNumeral(4), "④")
        XCTAssertEqual(AtlasStageBar.circledNumeral(20), "⑳")
        XCTAssertEqual(AtlasStageBar.circledNumeral(21), "21") // beyond circled range → plain
        // ←→ movement clamps at both ends (no wrap)
        XCTAssertEqual(AtlasStageBar.movedHighlight(from: 0, delta: -1, stageCount: 4), 0)
        XCTAssertEqual(AtlasStageBar.movedHighlight(from: 3, delta: 1, stageCount: 4), 3)
        XCTAssertEqual(AtlasStageBar.movedHighlight(from: 1, delta: 1, stageCount: 4), 2)
    }
}
