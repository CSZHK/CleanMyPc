import Foundation

/// Generates human-readable explanations for why scan findings are recommended for cleanup.
///
/// Each explanation is composed from a storage category template, risk level assessment,
/// and optional file age metadata. All strings are localized through ``AtlasL10n``.
public enum AtlasFindingExplanations {

    // MARK: - Public API

    /// Generates a human-readable explanation for why a finding is recommended for cleanup.
    ///
    /// - Parameters:
    ///   - category: The storage category of the finding (e.g., system cache, developer artifact).
    ///   - risk: The risk level of the finding (safe, review, or advanced).
    ///   - fileAge: Optional file age metadata for additional context.
    /// - Returns: A localized explanation string describing why this finding is recommended for cleanup.
    public static func explanation(
        for category: AtlasStorageCategory,
        risk: RiskLevel,
        fileAge: FileAgeInfo? = nil
    ) -> String {
        buildExplanation(for: category, risk: risk, fileAge: fileAge, language: nil)
    }

    /// Returns the explanation for a finding in the specified language.
    ///
    /// Uses the finding's own ``Finding/storageCategory``, ``Finding/risk``, and
    /// ``Finding/fileAge`` fields to compose the explanation. Falls back to
    /// ``AtlasStorageCategory/systemCache`` when the finding has no explicit category.
    ///
    /// - Parameters:
    ///   - finding: The finding to explain.
    ///   - language: The target language for the explanation.
    /// - Returns: A localized explanation string in the requested language.
    public static func localizedExplanation(
        for finding: Finding,
        language: AtlasLanguage
    ) -> String {
        let category = finding.storageCategory ?? .systemCache
        return buildExplanation(
            for: category,
            risk: finding.risk,
            fileAge: finding.fileAge,
            language: language
        )
    }

    /// Converts file age information into a human-readable descriptor.
    ///
    /// Produces strings like "not used in 6 months", "created 2 years ago",
    /// or "not used in 30 days". Uses the last accessed date when available,
    /// falling back to creation date.
    ///
    /// - Parameter fileAge: The file age metadata containing last accessed and creation dates.
    /// - Returns: A localized human-readable age descriptor, or an empty string if no dates are available.
    public static func ageDescriptor(from fileAge: FileAgeInfo) -> String {
        formattedAgeDescriptor(from: fileAge, language: nil)
    }

    // MARK: - Internal

    private static let calendar = Calendar.current

    private static func buildExplanation(
        for category: AtlasStorageCategory,
        risk: RiskLevel,
        fileAge: FileAgeInfo?,
        language: AtlasLanguage?
    ) -> String {
        let key = explanationKey(for: category, risk: risk)
        let base = AtlasL10n.string(key, language: language)

        guard let fileAge = fileAge else {
            return base
        }

        let age = formattedAgeDescriptor(from: fileAge, language: language)
        guard !age.isEmpty else {
            return base
        }

        return AtlasL10n.string("explanation.withAge", language: language, base, age)
    }

    private static func explanationKey(
        for category: AtlasStorageCategory,
        risk: RiskLevel
    ) -> String {
        "explanation.\(category.rawValue).\(risk.rawValue)"
    }

    private static func formattedAgeDescriptor(
        from fileAge: FileAgeInfo,
        language: AtlasLanguage?
    ) -> String {
        let now = Date()

        if let lastModified = fileAge.lastModifiedDate {
            let components = calendar.dateComponents([.day], from: lastModified, to: now)
            let days = max(components.day ?? 0, 0)
            if days > 0 {
                return lastModifiedDescriptor(days: days, language: language)
            }
        }

        if let creationDate = fileAge.creationDate {
            let components = calendar.dateComponents([.day], from: creationDate, to: now)
            let days = max(components.day ?? 0, 0)
            if days > 0 {
                return createdAgoDescriptor(days: days, language: language)
            }
        }

        return ""
    }

    private static func lastModifiedDescriptor(
        days: Int,
        language: AtlasLanguage?
    ) -> String {
        let years = days / 365
        let months = days / 30

        if years >= 2 {
            let period = AtlasL10n.string("fileage.years", language: language, years)
            return AtlasL10n.string("fileage.notUsedIn", language: language, period)
        } else if years >= 1 {
            let period = AtlasL10n.string("fileage.year", language: language)
            return AtlasL10n.string("fileage.notUsedIn", language: language, period)
        } else if months >= 6 {
            let period = AtlasL10n.string("fileage.months", language: language, 6)
            return AtlasL10n.string("fileage.notUsedIn", language: language, period)
        } else if months >= 3 {
            let period = AtlasL10n.string("fileage.months", language: language, 3)
            return AtlasL10n.string("fileage.notUsedIn", language: language, period)
        } else if months >= 1 {
            let period = AtlasL10n.string("fileage.month", language: language)
            return AtlasL10n.string("fileage.notUsedIn", language: language, period)
        } else {
            let period = AtlasL10n.string("fileage.days", language: language, max(days, 1))
            return AtlasL10n.string("fileage.notUsedIn", language: language, period)
        }
    }

    private static func createdAgoDescriptor(
        days: Int,
        language: AtlasLanguage?
    ) -> String {
        let years = days / 365
        let months = days / 30

        if years >= 2 {
            return AtlasL10n.string("fileage.yearsAgo", language: language, years)
        } else if years >= 1 {
            return AtlasL10n.string("fileage.yearAgo", language: language)
        } else if months >= 6 {
            return AtlasL10n.string("fileage.monthsAgo", language: language, 6)
        } else if months >= 3 {
            return AtlasL10n.string("fileage.monthsAgo", language: language, 3)
        } else if months >= 1 {
            return AtlasL10n.string("fileage.monthAgo", language: language)
        } else {
            return AtlasL10n.string("fileage.daysAgo", language: language, max(days, 1))
        }
    }
}
