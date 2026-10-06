//
//  PlanModeI18nTests.swift · Wenshu · T21-PLAN-I18N (2026-09-18)
//
//  Verifies that the /plan mode i18n keys exist in BOTH locales
//  (= en.lproj + zh-Hans.lproj = the i18n parity rule from the
//  project's standards). Uses plutil -p to inspect the binary
//  Localizable.strings files (= same approach as the rest of the
//  i18n parity audits; = no need to convert to XML for these
//  lookup assertions).
//

import Testing
import Foundation

@Suite("Plan mode i18n parity (T21)")
struct PlanModeI18nTests {

    private func readStrings(at path: String) -> [String: String] {
        // Apple canonical source of truth: Localizable.xcstrings
        // (Xcode 15+ String Catalog format). The path parameter
        // is preserved for caller compatibility (= existing tests
        // pass per-locale paths like ".../en.lproj/Localizable.strings"
        // for documentation); the helper detects the locale from
        // the path suffix and reads the .xcstrings JSON once.
        let lang: String
        if path.contains("zh-Hans.lproj") {
            lang = "zh-Hans"
        } else if path.contains("en.lproj") {
            lang = "en"
        } else {
            return [:]
        }
        let xcstringsPath = "Sources/WenshuApp/Resources/Localizable.xcstrings"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: xcstringsPath)) else { return [:] }
        guard let catalog = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        guard let strings = catalog["strings"] as? [String: [String: Any]] else { return [:] }
        var dict: [String: String] = [:]
        for (key, entry) in strings {
            guard let localizations = entry["localizations"] as? [String: Any] else { continue }
            guard let loc = localizations[lang] as? [String: Any] else { continue }
            guard let unit = loc["stringUnit"] as? [String: Any] else { continue }
            guard let value = unit["value"] as? String else { continue }
            dict[key] = value
        }
        return dict
    }

    /// T21 contract: chatview.plan.via exists in en.lproj.
    @Test func plan_via_in_english() {
        let en = readStrings(
            at: "Sources/WenshuApp/Resources/en.lproj/Localizable.strings"
        )
        #expect(en["chatview.plan.via"] != nil,
                "expected chatview.plan.via in en.lproj/Localizable.strings")
        #expect(en["chatview.plan.via"]?.contains("%@") == true,
                "expected 'chatview.plan.via' to contain %@ format placeholder")
    }

    /// T21 contract: chatview.plan.via exists in zh-Hans.lproj.
    @Test func plan_via_in_chinese() {
        let zh = readStrings(
            at: "Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings"
        )
        #expect(zh["chatview.plan.via"] != nil,
                "expected chatview.plan.via in zh-Hans.lproj/Localizable.strings")
        #expect(zh["chatview.plan.via"]?.contains("%@") == true,
                "expected 'chatview.plan.via' to contain %@ format placeholder")
    }

    /// T21 contract: chatview.plan.failed exists in BOTH locales.
    @Test func plan_failed_in_both_locales() {
        let en = readStrings(
            at: "Sources/WenshuApp/Resources/en.lproj/Localizable.strings"
        )
        let zh = readStrings(
            at: "Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings"
        )
        #expect(en["chatview.plan.failed"] != nil)
        #expect(zh["chatview.plan.failed"] != nil)
        // The values should differ (= en vs zh translation).
        #expect(en["chatview.plan.failed"] != zh["chatview.plan.failed"],
                "expected EN and ZH 'plan.failed' to differ (= actual translation)")
    }
}