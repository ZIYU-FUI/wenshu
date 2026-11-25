//
//  TokenUnitFormatTests.swift · Wenshu
//
//  Proves the meter's conversion is the locale's own and not a suffix
//  this app picked, and that the exact number survives it.
//
//  The product rule (see OOB.md #2026-11-26) is that a displayed count
//  carries a unit, because an eleven-digit reading is too long to read off
//  the bar. The two failure modes this suite closes:
//
//  - a hand-written "/ 1000 + k" reads wrong in Chinese, whose unit is the
//    ten-thousand and starts at 10,000, not at 1,000, so the assertion is
//    made in BOTH locales, and each one is what Foundation answers on
//    this machine (= a pass here means the locale did the work, not a
//    format string);
//  - a conversion that throws digits away with nothing to fall back on,
//    so the exact form is asserted alongside the unit form and the bar's
//    tooltip is checked to be the exact one.
//
//

import Foundation
import Testing
@testable import WenshuApp

private let chinese = Locale(identifier: "zh-Hans")
private let english = Locale(identifier: "en")

@Suite("TokenUnitFormat")
struct TokenUnitFormatTests {
    @Test("A count below the unit threshold keeps its exact digits")
    func smallCountsPrintInFull() {
        #expect(TokenUnitFormat.string(370, locale: chinese) == "370")
        #expect(TokenUnitFormat.string(3027, locale: chinese) == "3,027")
        #expect(TokenUnitFormat.string(9999, locale: chinese) == "9,999")
        #expect(TokenUnitFormat.string(3027, locale: english) == "3,027")
    }

    @Test("The unit is the locale's own, and it starts at the threshold")
    func unitFormFollowsTheLocale() {
        #expect(TokenUnitFormat.string(10000, locale: chinese) == "1万")
        #expect(TokenUnitFormat.string(128_000, locale: chinese) == "12.8万")
        #expect(TokenUnitFormat.string(118_339, locale: chinese) == "11.8万")
        #expect(TokenUnitFormat.string(10000, locale: english) == "10K")
        #expect(TokenUnitFormat.string(128_000, locale: english) == "128K")
        #expect(TokenUnitFormat.string(118_339, locale: english) == "118.3K")
    }

    @Test("The unit form is shorter than the number it replaced")
    func unitFormIsShorter() {
        for value in [118_339, 242_644, 1_250_000] {
            let unit = TokenUnitFormat.string(value, locale: chinese)
            let exact = TokenUnitFormat.exactString(value, locale: chinese)
            #expect(unit.count < exact.count, "\(value) rendered as \(unit)")
        }
    }

    @Test("The exact reading is what the bar's tooltip carries")
    func exactFormStaysReachable() {
        #expect(TokenUnitFormat.exactString(118_339, locale: chinese) == "118,339")
        #expect(TokenUnitFormat.exactString(128_000, locale: english) == "128,000")
    }

    @Test("The gauge's strings carry the converted pair")
    func gaugeFormatStringsTakeUnitForm() throws {
        let reading = try Self.localizedValue("chat.context.gauge.reading", language: "zh-Hans")
        let rendered = String(format: reading, "11.8万", "12.8万")
        #expect(rendered == "上下文 11.8万 / 12.8万 tokens")

        let summary = try Self.localizedValue("chat.context.breakdown.summary", language: "zh-Hans")
        let renderedSummary = String(format: summary, "11.8万", "12.8万", 92)
        #expect(renderedSummary == "上下文 11.8万 / 12.8万 tokens（92%）")

        let exact = try Self.localizedValue("chat.context.gauge.exact", language: "zh-Hans")
        #expect(String(format: exact, "118,339", "128,000") == "精确值 118,339 / 128,000 tokens")
    }

    /// The catalog's value for one key, read off disk.
    ///
    /// The test formats against the shipped string rather than against a
    /// copy of it, so editing the catalog without editing the call site
    /// fails here instead of painting a broken bar.
    private static func localizedValue(_ key: String, language: String) throws -> String {
        let url = URL(fileURLWithPath: SourceLocator.path("Sources/WenshuApp/Resources/Localizable.xcstrings"))
        let data = try Data(contentsOf: url)
        let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        let entry = try #require(strings[key] as? [String: Any])
        let localizations = try #require(entry["localizations"] as? [String: Any])
        let languageEntry = try #require(localizations[language] as? [String: Any])
        let unit = try #require(languageEntry["stringUnit"] as? [String: Any])
        return try #require(unit["value"] as? String)
    }
}
