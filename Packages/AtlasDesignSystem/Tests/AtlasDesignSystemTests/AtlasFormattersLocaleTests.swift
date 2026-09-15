import XCTest
import AtlasDesignSystem
import AtlasDomain

/// `REQ-copy-plain-language` 的真机视觉验收顺带查出的缺陷的回归守卫。
///
/// **缺陷**：UI 语言为 English、系统为 zh-CN 时，历史记录屏渲染出
/// 「2026年9月15日 17:07」与「4分钟前」——界面全英文、日期全中文。
/// **根因**：`AtlasFormatters` 的两个函数**独立构造** formatter / 独立调用
/// `formatted(...)`，读的是 `Locale.current`（系统），而 app 的
/// `.environment(\.locale, …)` 只覆盖**视图树内**的格式化。
///
/// 这两条断言是**变异可检**的：把 `appLocale` 改回 `Locale.current` 即红。
final class AtlasFormattersLocaleTests: XCTestCase {

    override func tearDown() {
        AtlasL10n.setCurrentLanguage(.default)
        super.tearDown()
    }

    /// 参照时刻：用一个明确的固定日期，避免断言依赖「现在」。
    private var reference: Date {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    func testRelativeDateFollowsAppLanguageNotSystem() {
        AtlasL10n.setCurrentLanguage(.en)
        let en = AtlasFormatters.relativeDate(reference)

        AtlasL10n.setCurrentLanguage(.zhHans)
        let zh = AtlasFormatters.relativeDate(reference)

        XCTAssertNotEqual(
            en, zh,
            "相对日期必须随 app 内语言切换而变。若两者相等，说明 formatter 仍在读系统 locale。"
        )
        XCTAssertFalse(
            en.contains("前"),
            "app 语言为 English 时不得渲染中文相对时间，实际得到：\(en)"
        )
    }

    func testShortDateFollowsAppLanguageNotSystem() {
        AtlasL10n.setCurrentLanguage(.en)
        let en = AtlasFormatters.shortDate(reference)

        AtlasL10n.setCurrentLanguage(.zhHans)
        let zh = AtlasFormatters.shortDate(reference)

        XCTAssertNotEqual(
            en, zh,
            "短日期必须随 app 内语言切换而变。若两者相等，说明 formatted(...) 仍在读系统 locale。"
        )
        XCTAssertFalse(
            en.contains("年"),
            "app 语言为 English 时不得渲染中文年月日，实际得到：\(en)"
        )
    }
}
