import XCTest
@testable import AtlasDesignSystem
import AtlasDomain
import SwiftUI

/// Batch G — Calm Ledger M2 surfaces, banners and data-voice infrastructure.
/// Same convention as Batch F: decision logic lives in pure static helpers,
/// rendering is covered by construction smoke tests.
@MainActor
final class CalmLedgerBatchGTests: XCTestCase {

    // MARK: - G1 AtlasLedgerSurface

    func testLedgerSurfaceConstruction() {
        // Titled and untitled constructions both render.
        let titled = AtlasLedgerSurface(title: "台账") { Text("entry") }
        XCTAssertNotNil(titled.body)
        let untitled = AtlasLedgerSurface { Text("entry") }
        XCTAssertNotNil(untitled.body)
        // Dotted rule modifier applies to any view (construction smoke).
        let ruled: any View = Text("row").atlasLedgerRule()
        XCTAssertNotNil(ruled)
    }

    func testLedgerSurfaceTitleBlockPredicate() {
        // Serif title + 1.5pt ink rule render only for non-blank titles.
        XCTAssertTrue(AtlasLedgerSurface<Text>.showsTitleBlock(title: "清理台账"))
        XCTAssertFalse(AtlasLedgerSurface<Text>.showsTitleBlock(title: nil))
        XCTAssertFalse(AtlasLedgerSurface<Text>.showsTitleBlock(title: ""))
        XCTAssertFalse(AtlasLedgerSurface<Text>.showsTitleBlock(title: "  \n"))
    }

    // MARK: - G2 AtlasNextActionBanner

    func testBannerCallbacks() {
        var primary = 0
        var secondary = 0
        var dismissed = 0
        let banner = AtlasNextActionBanner(
            headline: "建议清理 3.4 GB 缓存",
            rationale: "上次扫描 10:24 · 12 项全部可恢复",
            primaryTitle: "执行清理计划",
            onPrimary: { primary += 1 },
            secondaryTitle: "查看计划",
            onSecondary: { secondary += 1 },
            onDismiss: { dismissed += 1 }
        )
        XCTAssertNotNil(banner.body)
        // All three callbacks are stored and fire independently.
        banner.onPrimary()
        banner.onSecondary?()
        banner.onDismiss?()
        XCTAssertEqual([primary, secondary, dismissed], [1, 1, 1])
        // Secondary renders only when both title and action exist.
        XCTAssertTrue(AtlasNextActionBanner.showsSecondary(title: "查看计划", action: {}))
        XCTAssertFalse(AtlasNextActionBanner.showsSecondary(title: nil, action: {}))
        XCTAssertFalse(AtlasNextActionBanner.showsSecondary(title: "查看计划", action: nil))
    }

    func testBannerDismissHiddenWhenNil() {
        // onDismiss nil ⇒ no 忽略 control renders (and the banner still builds).
        XCTAssertFalse(AtlasNextActionBanner.showsDismiss(nil))
        XCTAssertTrue(AtlasNextActionBanner.showsDismiss({}))
        let banner = AtlasNextActionBanner(
            headline: "h", rationale: "r",
            primaryTitle: "p", onPrimary: {},
            secondaryTitle: nil, onSecondary: nil,
            onDismiss: nil
        )
        XCTAssertNil(banner.onDismiss)
        XCTAssertNotNil(banner.body)
        // Rationale opacity stays at the ≥4.5:1-verified level (90%, not 85%).
        XCTAssertEqual(AtlasNextActionBanner.rationaleOpacity, 0.9, accuracy: 0.0001)
    }

    // MARK: - G3 AtlasErrorState

    func testErrorStateLayoutVariants() {
        // Layout-discriminating properties: block centers with the EmptyState
        // icon scale; inlineRow leads with the list-row glyph scale.
        XCTAssertTrue(AtlasErrorState.Layout.block.isCentered)
        XCTAssertFalse(AtlasErrorState.Layout.inlineRow.isCentered)
        XCTAssertEqual(AtlasErrorState.Layout.block.iconPointSize, 28)
        XCTAssertEqual(AtlasErrorState.Layout.inlineRow.iconPointSize, 14)
        // Both layouts construct with full content.
        let block = AtlasErrorState(
            title: "清理失败",
            message: "3 项因权限不足被跳过",
            suggestion: "在权限页授予完全磁盘访问后重试",
            actionTitle: "重试",
            onAction: {},
            layout: .block
        )
        XCTAssertNotNil(block.body)
        let row = AtlasErrorState(
            title: "权限不足",
            message: "~/Library/Caches/com.example 无法删除",
            layout: .inlineRow
        )
        XCTAssertNotNil(row.body)
    }

    func testErrorStateActionHiddenWhenNil() {
        // Fail-closed: the action button needs BOTH a title and a handler.
        XCTAssertTrue(AtlasErrorState.showsAction(title: "重试", action: {}))
        XCTAssertFalse(AtlasErrorState.showsAction(title: nil, action: {}))
        XCTAssertFalse(AtlasErrorState.showsAction(title: "重试", action: nil))
        XCTAssertFalse(AtlasErrorState.showsAction(title: nil, action: nil))
        // Default layout is .block; default action is absent.
        let minimal = AtlasErrorState(title: "t", message: "m")
        XCTAssertNotNil(minimal.body)
    }
}
