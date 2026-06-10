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
}
