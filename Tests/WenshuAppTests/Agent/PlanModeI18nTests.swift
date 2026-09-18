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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        process.arguments = ["-p", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // discard stderr
        do {
            try process.run()
        } catch {
            return [:]
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [:] }
        let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // plutil -p output: "key" => "value" lines (= one per entry).
        // = parse them into a dictionary. Quoted values may contain
        // escaped quotes (= the standard plutil format).
        var dict: [String: String] = [:]
        let pattern = try? NSRegularExpression(
            pattern: "^\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*=>\\s*\"((?:[^\"\\\\]|\\\\.)*)\"",
            options: [.anchorsMatchLines]
        )
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        pattern?.enumerateMatches(in: raw, options: [], range: range) { match, _, _ in
            guard let m = match,
                  m.numberOfRanges == 3 else { return }
            guard let keyRange = Range(m.range(at: 1), in: raw),
                  let valRange = Range(m.range(at: 2), in: raw) else { return }
            let key = raw[keyRange]
            let val = raw[valRange]
            dict[String(key)] = String(val)
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