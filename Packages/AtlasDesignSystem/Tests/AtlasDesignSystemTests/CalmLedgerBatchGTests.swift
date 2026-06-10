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
}
