import XCTest
@testable import AtlasDomain

final class AtlasFindingExplanationsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AtlasL10n.setCurrentLanguage(.zhHans)
    }

    // MARK: - Explanation without File Age

    func testExplanationForSystemCacheSafe() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .systemCache,
            risk: .safe
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("系统缓存"))
    }

    func testExplanationForSystemCacheReview() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .systemCache,
            risk: .review
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("系统缓存"))
    }

    func testExplanationForSystemCacheAdvanced() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .systemCache,
            risk: .advanced
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("系统缓存"))
    }

    func testExplanationForDeveloperArtifactSafe() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .developerArtifact,
            risk: .safe
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("开发者"))
    }

    func testExplanationForBrowserDataReview() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .browserData,
            risk: .review
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("浏览器"))
    }

    func testExplanationForAppCacheAdvanced() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .appCache,
            risk: .advanced
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("应用缓存"))
    }

    func testExplanationForLogFileSafe() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .logFile,
            risk: .safe
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("日志"))
    }

    func testExplanationForDownloadArtifactReview() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .downloadArtifact,
            risk: .review
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("下载"))
    }

    func testExplanationForMailAttachmentSafe() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .mailAttachment,
            risk: .safe
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("邮件"))
    }

    func testExplanationForOldBackupAdvanced() {
        let explanation = AtlasFindingExplanations.explanation(
            for: .oldBackup,
            risk: .advanced
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("备份"))
    }

    // MARK: - Explanation with File Age

    func testExplanationWithFileAgeAppendsAgeDescriptor() {
        let fileAge = FileAgeInfo(lastAccessedDate: Date().addingTimeInterval(-90 * 86400))
        let explanation = AtlasFindingExplanations.explanation(
            for: .systemCache,
            risk: .safe,
            fileAge: fileAge
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertNotEqual(explanation, AtlasFindingExplanations.explanation(for: .systemCache, risk: .safe))
    }

    func testExplanationWithNilFileAgeReturnsBaseExplanation() {
        let withAge = AtlasFindingExplanations.explanation(
            for: .developerArtifact,
            risk: .safe,
            fileAge: nil
        )
        let withoutAge = AtlasFindingExplanations.explanation(
            for: .developerArtifact,
            risk: .safe
        )
        XCTAssertEqual(withAge, withoutAge)
    }

    func testExplanationWithFileAgeWithNoDatesReturnsBaseExplanation() {
        let fileAge = FileAgeInfo()
        let explanation = AtlasFindingExplanations.explanation(
            for: .systemCache,
            risk: .safe,
            fileAge: fileAge
        )
        let base = AtlasFindingExplanations.explanation(for: .systemCache, risk: .safe)
        XCTAssertEqual(explanation, base)
    }

    // MARK: - Localized Explanation for Finding

    func testLocalizedExplanationForFindingWithStorageCategory() {
        AtlasL10n.setCurrentLanguage(.en)
        let finding = Finding(
            title: "Test",
            detail: "Test detail",
            bytes: 100,
            risk: .safe,
            category: "System",
            storageCategory: .browserData
        )
        let explanation = AtlasFindingExplanations.localizedExplanation(
            for: finding,
            language: .en
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("Browser"))
        AtlasL10n.setCurrentLanguage(.zhHans)
    }

    func testLocalizedExplanationForFindingWithoutStorageCategoryFallsBackToSystemCache() {
        AtlasL10n.setCurrentLanguage(.en)
        let finding = Finding(
            title: "Test",
            detail: "Test detail",
            bytes: 100,
            risk: .safe,
            category: "System"
        )
        let explanation = AtlasFindingExplanations.localizedExplanation(
            for: finding,
            language: .en
        )
        XCTAssertFalse(explanation.isEmpty)
        XCTAssertTrue(explanation.contains("System cache"))
        AtlasL10n.setCurrentLanguage(.zhHans)
    }

    // MARK: - Age Descriptor

    func testAgeDescriptorWithRecentLastAccessedDate() {
        let fileAge = FileAgeInfo(lastAccessedDate: Date().addingTimeInterval(-10 * 86400))
        let descriptor = AtlasFindingExplanations.ageDescriptor(from: fileAge)
        XCTAssertFalse(descriptor.isEmpty)
        XCTAssertTrue(descriptor.contains("天"), "Expected '天' in descriptor: \(descriptor)")
    }

    func testAgeDescriptorWith30DayLastAccessedDate() {
        let fileAge = FileAgeInfo(lastAccessedDate: Date().addingTimeInterval(-32 * 86400))
        let descriptor = AtlasFindingExplanations.ageDescriptor(from: fileAge)
        XCTAssertFalse(descriptor.isEmpty)
        XCTAssertTrue(descriptor.contains("月"), "Expected '月' in descriptor: \(descriptor)")
    }

    func testAgeDescriptorWith6MonthLastAccessedDate() {
        let fileAge = FileAgeInfo(lastAccessedDate: Date().addingTimeInterval(-200 * 86400))
        let descriptor = AtlasFindingExplanations.ageDescriptor(from: fileAge)
        XCTAssertFalse(descriptor.isEmpty)
        XCTAssertTrue(descriptor.contains("月"), "Expected '月' in descriptor: \(descriptor)")
    }

    func testAgeDescriptorWith1YearLastAccessedDate() {
        let fileAge = FileAgeInfo(lastAccessedDate: Date().addingTimeInterval(-380 * 86400))
        let descriptor = AtlasFindingExplanations.ageDescriptor(from: fileAge)
        XCTAssertFalse(descriptor.isEmpty)
        XCTAssertTrue(descriptor.contains("年"), "Expected '年' in descriptor: \(descriptor)")
    }

    func testAgeDescriptorWith2YearLastAccessedDate() {
        let fileAge = FileAgeInfo(lastAccessedDate: Date().addingTimeInterval(-800 * 86400))
        let descriptor = AtlasFindingExplanations.ageDescriptor(from: fileAge)
        XCTAssertFalse(descriptor.isEmpty)
        XCTAssertTrue(descriptor.contains("年"), "Expected '年' in descriptor: \(descriptor)")
    }

    func testAgeDescriptorFallsBackToCreationDate() {
        let fileAge = FileAgeInfo(
            lastAccessedDate: nil,
            creationDate: Date().addingTimeInterval(-400 * 86400)
        )
        let descriptor = AtlasFindingExplanations.ageDescriptor(from: fileAge)
        XCTAssertFalse(descriptor.isEmpty)
        XCTAssertTrue(descriptor.contains("年前"), "Expected '年前' in descriptor: \(descriptor)")
    }

    func testAgeDescriptorWithCreationDateOnly() {
        let fileAge = FileAgeInfo(creationDate: Date().addingTimeInterval(-60 * 86400))
        let descriptor = AtlasFindingExplanations.ageDescriptor(from: fileAge)
        XCTAssertFalse(descriptor.isEmpty)
        XCTAssertTrue(descriptor.contains("月前"), "Expected '月前' in descriptor: \(descriptor)")
    }

    func testAgeDescriptorWithNoDatesReturnsEmpty() {
        let fileAge = FileAgeInfo()
        let descriptor = AtlasFindingExplanations.ageDescriptor(from: fileAge)
        XCTAssertEqual(descriptor, "")
    }

    func testAgeDescriptorWithFutureDateReturnsEmpty() {
        let fileAge = FileAgeInfo(lastAccessedDate: Date().addingTimeInterval(86400))
        let descriptor = AtlasFindingExplanations.ageDescriptor(from: fileAge)
        XCTAssertEqual(descriptor, "")
    }

    // MARK: - All Categories × All Risk Levels

    func testAllCategoryRiskCombinationsReturnNonEmptyExplanation() {
        for category in AtlasStorageCategory.allCases {
            for risk in RiskLevel.allCases {
                let explanation = AtlasFindingExplanations.explanation(
                    for: category,
                    risk: risk
                )
                XCTAssertFalse(
                    explanation.isEmpty,
                    "Explanation should not be empty for \(category.rawValue).\(risk.rawValue)"
                )
            }
        }
    }

    func testEnglishExplanationsAreDistinctFromChinese() {
        for category in AtlasStorageCategory.allCases {
            for risk in RiskLevel.allCases {
                AtlasL10n.setCurrentLanguage(.zhHans)
                let zhExplanation = AtlasFindingExplanations.explanation(for: category, risk: risk)

                AtlasL10n.setCurrentLanguage(.en)
                let enExplanation = AtlasFindingExplanations.explanation(for: category, risk: risk)

                XCTAssertFalse(zhExplanation.isEmpty)
                XCTAssertFalse(enExplanation.isEmpty)
                XCTAssertNotEqual(
                    zhExplanation,
                    enExplanation,
                    "Chinese and English explanations should differ for \(category.rawValue).\(risk.rawValue)"
                )
            }
        }
        AtlasL10n.setCurrentLanguage(.zhHans)
    }
}
