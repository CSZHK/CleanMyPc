import Foundation

public enum AtlasLanguage: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case zhHans = "zh-Hans"
    case en = "en"

    public static let `default`: AtlasLanguage = .zhHans

    public var id: String { rawValue }

    public init(localeIdentifier: String) {
        let normalized = localeIdentifier.lowercased()
        if normalized.hasPrefix("en") {
            self = .en
        } else {
            self = .zhHans
        }
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    public var displayName: String {
        switch self {
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }
}

public enum AtlasL10n {
    private static let stateLock = NSLock()
    private static var storedLanguage: AtlasLanguage = .default

    public static var currentLanguage: AtlasLanguage {
        stateLock.withLock {
            storedLanguage
        }
    }

    public static func setCurrentLanguage(_ language: AtlasLanguage) {
        stateLock.withLock {
            storedLanguage = language
        }
    }

    public static func string(_ key: String, language: AtlasLanguage? = nil, _ arguments: CVarArg...) -> String {
        string(key, language: language, arguments: arguments)
    }

    public static func string(_ key: String, language: AtlasLanguage? = nil, arguments: [CVarArg]) -> String {
        let resolvedLanguage = language ?? currentLanguage
        let format = bundle(for: resolvedLanguage).localizedString(forKey: key, value: nil, table: nil)
        guard !arguments.isEmpty else {
            return format
        }
        return String(format: format, locale: resolvedLanguage.locale, arguments: arguments)
    }

    public static func localizedCategory(_ rawCategory: String, language: AtlasLanguage? = nil) -> String {
        switch rawCategory.lowercased() {
        case "developer":
            return string("category.developer", language: language)
        case "system":
            return string("category.system", language: language)
        case "apps":
            return string("category.apps", language: language)
        case "browsers":
            return string("category.browsers", language: language)
        default:
            return rawCategory
        }
    }

    public static func acknowledgement(language: AtlasLanguage? = nil) -> String {
        string("settings.acknowledgement.body", language: language)
    }

    public static func thirdPartyNotices(language: AtlasLanguage? = nil) -> String {
        string("settings.notices.body", language: language)
    }

    private static func bundle(for language: AtlasLanguage) -> Bundle {
        guard let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.module
        }
        return bundle
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
