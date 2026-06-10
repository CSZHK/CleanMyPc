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
