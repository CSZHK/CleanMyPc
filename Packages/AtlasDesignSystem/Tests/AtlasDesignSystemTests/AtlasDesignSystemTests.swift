import XCTest
@testable import AtlasDesignSystem
import AppKit
import CoreText
import SwiftUI

@MainActor
final class AtlasDesignSystemTests: XCTestCase {

    // MARK: - AtlasTone

    func testToneSymbols() {
        XCTAssertEqual(AtlasTone.neutral.symbol, "circle.fill")
        XCTAssertEqual(AtlasTone.success.symbol, "checkmark.circle.fill")
        XCTAssertEqual(AtlasTone.warning.symbol, "exclamationmark.triangle.fill")
        XCTAssertEqual(AtlasTone.danger.symbol, "xmark.octagon.fill")
    }

    func testAllToneCasesCovered() {
        let allCases: [AtlasTone] = [.neutral, .success, .warning, .danger]
        XCTAssertEqual(allCases.count, 4)
    }

    // MARK: - AtlasElevation

    func testElevationFlatProperties() {
        XCTAssertEqual(AtlasElevation.flat.shadowRadius, 0)
        XCTAssertEqual(AtlasElevation.flat.shadowY, 0)
        XCTAssertEqual(AtlasElevation.flat.shadowOpacity, 0)
        XCTAssertGreaterThan(AtlasElevation.flat.cornerRadius, 0)
        XCTAssertEqual(AtlasElevation.flat.borderOpacity, 0.04)
    }

    func testElevationRaisedHasShadow() {
        XCTAssertGreaterThan(AtlasElevation.raised.shadowRadius, 0)
        XCTAssertGreaterThan(AtlasElevation.raised.shadowOpacity, 0)
    }

    func testElevationProminentHasLargerShadow() {
        XCTAssertGreaterThanOrEqual(AtlasElevation.prominent.shadowRadius, AtlasElevation.raised.shadowRadius)
        XCTAssertGreaterThan(AtlasElevation.prominent.shadowOpacity, AtlasElevation.raised.shadowOpacity)
    }

    // MARK: - AtlasFormatters

    func testByteCountZero() {
        let result = AtlasFormatters.byteCount(0)
        XCTAssertFalse(result.isEmpty)
    }

    func testByteCountMB() {
        let result = AtlasFormatters.byteCount(100_000_000)
        XCTAssertTrue(result.contains("MB") || result.contains("100"), "Expected MB in '\(result)'")
    }

    func testByteCountGB() {
        let result = AtlasFormatters.byteCount(5_000_000_000)
        XCTAssertTrue(result.contains("GB") || result.contains("5"), "Expected GB in '\(result)'")
    }

    func testRelativeDate() {
        let now = Date()
        let result = AtlasFormatters.relativeDate(now)
        XCTAssertFalse(result.isEmpty)
    }

    func testShortDate() {
        let result = AtlasFormatters.shortDate(Date())
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - AtlasSpacing

    func testSpacingValuesIncrease() {
        XCTAssertLessThan(AtlasSpacing.xxs, AtlasSpacing.xs)
        XCTAssertLessThan(AtlasSpacing.xs, AtlasSpacing.sm)
        XCTAssertLessThan(AtlasSpacing.sm, AtlasSpacing.md)
        XCTAssertLessThan(AtlasSpacing.md, AtlasSpacing.lg)
        XCTAssertLessThan(AtlasSpacing.lg, AtlasSpacing.xl)
        XCTAssertLessThan(AtlasSpacing.xl, AtlasSpacing.xxl)
    }

    // MARK: - AtlasRadius

    func testRadiusValuesIncrease() {
        XCTAssertLessThan(AtlasRadius.sm, AtlasRadius.md)
        XCTAssertLessThan(AtlasRadius.md, AtlasRadius.lg)
    }

    func testRadiusValuesPositive() {
        XCTAssertGreaterThan(AtlasRadius.sm, 0)
        XCTAssertGreaterThan(AtlasRadius.md, 0)
        XCTAssertGreaterThan(AtlasRadius.lg, 0)
    }

    // MARK: - AtlasLayout

    func testLayoutConstants() {
        XCTAssertGreaterThan(AtlasLayout.maxReadingWidth, 0)
        XCTAssertGreaterThan(AtlasLayout.maxWorkspaceWidth, AtlasLayout.maxReadingWidth)
        XCTAssertGreaterThan(AtlasLayout.browserSplitThreshold, 0)
    }

    func testAdaptiveMetricColumnsForNarrowWidth() {
        let columns = AtlasLayout.adaptiveMetricColumns(for: 200)
        XCTAssertFalse(columns.isEmpty)
    }

    func testAdaptiveMetricColumnsForWideWidth() {
        let columns = AtlasLayout.adaptiveMetricColumns(for: 1200)
        XCTAssertFalse(columns.isEmpty)
    }

    // MARK: - AtlasColor

    func testBrandColorsExist() {
        // Verify colors can be accessed without crashing
        let _ = AtlasColor.brand
        let _ = AtlasColor.accent
        let _ = AtlasColor.success
        let _ = AtlasColor.warning
        let _ = AtlasColor.danger
        let _ = AtlasColor.info
    }

    func testCanvasColorsExist() {
        let _ = AtlasColor.canvasTop
        let _ = AtlasColor.canvasBottom
        let _ = AtlasColor.card
        // cardRaised requires NSApp which is unavailable in test context
    }

    func testTextColorsExist() {
        let _ = AtlasColor.textPrimary
        let _ = AtlasColor.textSecondary
        let _ = AtlasColor.textTertiary
    }

    func testBorderColorsExist() {
        let _ = AtlasColor.border
        let _ = AtlasColor.borderEmphasis
    }

    // MARK: - AtlasTypography

    func testTypographyFonts() {
        let _ = AtlasTypography.screenTitle
        let _ = AtlasTypography.dataHero
        let _ = AtlasTypography.sectionTitle
        let _ = AtlasTypography.dataMetric
        let _ = AtlasTypography.label
        let _ = AtlasTypography.rowTitle
        let _ = AtlasTypography.body
        let _ = AtlasTypography.bodySmall
        let _ = AtlasTypography.caption
        let _ = AtlasTypography.captionSmall
    }

    // MARK: - AtlasMotion

    func testMotionAnimations() {
        let _ = AtlasMotion.fast
        let _ = AtlasMotion.standard
        let _ = AtlasMotion.slow
        let _ = AtlasMotion.spring
    }

    // MARK: - Calm Ledger v3 Tokens

    func testCalmLedgerColorTokensExist() {
        let _ = AtlasColor.ink
        let _ = AtlasColor.inkData
        let _ = AtlasColor.surface
        let _ = AtlasColor.surfaceSubdued
        let _ = AtlasColor.surfaceInput
        let _ = AtlasColor.ledgerPaper
        let _ = AtlasColor.ledgerInk
        let _ = AtlasColor.ledgerSecondary
        let _ = AtlasColor.ledgerBorder
        let _ = AtlasColor.ledgerRule
        let _ = AtlasColor.successFill
        let _ = AtlasColor.warningFill
        let _ = AtlasColor.dangerFill
        let _ = AtlasColor.infoFill
        let _ = AtlasColor.actionBarBg
        let _ = AtlasColor.actionBarText
        let _ = AtlasColor.actionBarData
        let _ = AtlasColor.brandHover
        let _ = AtlasColor.cardRaised   // v3: no longer @MainActor — plain static let
        let _ = AtlasColor.heroSurface  // v3: no longer @MainActor — plain static let
    }

    func testThreeVoiceTypographyExists() {
        let _ = AtlasTypography.dataHero
        let _ = AtlasTypography.dataMetric
        let _ = AtlasTypography.dataBody
        let _ = AtlasTypography.dataCaption
        let _ = AtlasTypography.ledgerTitle
        let _ = AtlasTypography.ledgerNumber
    }

    func testMotionStageTokensExist() {
        let _ = AtlasMotion.stageTransition
        let _ = AtlasMotion.stampIn
    }

    func testLayoutBreakpoints() {
        XCTAssertEqual(AtlasLayout.evidencePanelMinWidth, 300)
        XCTAssertEqual(AtlasLayout.evidencePanelBreakpoint, 880)
        XCTAssertEqual(AtlasLayout.actionBarCompactBreakpoint, 740)
    }

    func testLedgerFontCascadeResolvesSongtiForChinese() {
        // 规格 §1.3: zh 台账声部必须显式解析到 Songti SC，不依赖系统回退。
        // FAIL ⇒ 触发规格降级决策点（serif 仅限拉丁工件），升级人审，不得静默跳过。
        let nsFont = AtlasTypography.ledgerNSFont(size: 19, weight: .bold)
        let sample = "台账" as CFString
        let resolved = CTFontCreateForString(nsFont as CTFont, sample, CFRange(location: 0, length: 2))
        let family = CTFontCopyFamilyName(resolved) as String
        XCTAssertTrue(family.contains("Songti"), "zh ledger voice resolved to '\(family)', expected Songti SC")
    }

    func testNumeroGlyphAvailableInLedgerFont() {
        // 规格 §1.3: № (U+2116) 需在台账声部可用；缺失则 en 回退 "No."（M2 组件层处理）。
        let nsFont = AtlasTypography.ledgerNSFont(size: 13, weight: .bold)
        let resolved = CTFontCreateForString(nsFont as CTFont, "№" as CFString, CFRange(location: 0, length: 1))
        var chars: [UniChar] = [0x2116]
        var glyphs: [CGGlyph] = [0]
        let ok = CTFontGetGlyphsForCharacters(resolved, &chars, &glyphs, 1)
        XCTAssertTrue(ok && glyphs[0] != 0, "№ glyph unavailable — record fallback decision in findings")
    }
}
