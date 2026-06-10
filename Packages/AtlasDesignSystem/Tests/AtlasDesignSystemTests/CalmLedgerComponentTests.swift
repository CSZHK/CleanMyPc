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
