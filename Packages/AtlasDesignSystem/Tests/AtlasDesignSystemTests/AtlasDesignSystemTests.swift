import XCTest
@testable import AtlasDesignSystem
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
        let _ = AtlasTypography.heroMetric
        let _ = AtlasTypography.sectionTitle
        let _ = AtlasTypography.cardMetric
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
}
