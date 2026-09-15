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

    /// `P2-5`：走 `AtlasL10n`（同文件的 `AtlasTheme.displayName` 一直是这么做的），
    /// 启用此前**全仓零引用**的 `language.zhHans` / `language.en`。
    /// 此前硬编码：界面语言为 English 时，设置行仍显示中文「简体中文」，
    /// 英文用户读到的是「汉化没做完」，也无法确认当前生效的是哪种语言。
    public var displayName: String {
        AtlasL10n.string("language.\(self == .zhHans ? "zhHans" : "en")")
    }
}

public enum AtlasTheme: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case system
    case light
    case dark

    public static let `default`: AtlasTheme = .system

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return AtlasL10n.string("settings.theme.system")
        case .light:  return AtlasL10n.string("settings.theme.light")
        case .dark:   return AtlasL10n.string("settings.theme.dark")
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
        if let path = Bundle.module.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        // SwiftPM `.process` lowercases `.lproj` dir names in dev builds (zh-Hans.lproj →
        // zh-hans.lproj); Foundation's lproj lookup is case-sensitive so the canonical
        // rawValue misses. Release (xcodebuild) preserves canonical case. Fall back to lowercased.
        if let path = Bundle.module.path(forResource: language.rawValue.lowercased(), ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return Bundle.module
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
