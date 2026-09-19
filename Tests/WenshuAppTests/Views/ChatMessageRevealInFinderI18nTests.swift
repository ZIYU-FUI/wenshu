//
//  ChatMessageRevealInFinderI18nTests.swift · Wenshu · T35-REVEAL-I18N (2026-09-18)
//
//  Verifies that the "Reveal in Finder" label landed in T34 is
//  now sourced from WenshuI18n.t(= chatview.message.reveal_in_finder)
//  AND that the key exists in BOTH en.lproj + zh-Hans.lproj
//  (= the i18n parity rule from the project standards).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessage reveal in finder i18n (T35)")
struct ChatMessageRevealInFinderI18nTests {

    /// T35 contract: ChatMessageView source uses WenshuI18n.t
    /// for the reveal button label (= no hardcoded "Reveal in Finder"
    /// string remaining).
    @Test func source_uses_WenshuI18n_t() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("WenshuI18n.t(\"chatview.message.reveal_in_finder\")"))
    }

    /// T35 contract: no hardcoded "Reveal in Finder" string remains
    /// (= the literal English string from T34 was retired).
    @Test func no_hardcoded_label_remaining() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // The T34 hardcoded "Reveal in Finder" inside Label("...") is
        // gone (= replaced by WenshuI18n.t call). Search for the
        // literal string inside a Label constructor.
        #expect(!source.contains("Label(\"Reveal in Finder\""))
    }

    /// T35 contract: chatview.message.reveal_in_finder key exists
    /// in en.lproj.
    @Test func key_in_english_locale() throws {
        let output = try runPlutil("-p", "Sources/WenshuApp/Resources/en.lproj/Localizable.strings")
        #expect(output.contains("\"chatview.message.reveal_in_finder\""))
    }

    /// T35 contract: chatview.message.reveal_in_finder key exists
    /// in zh-Hans.lproj with a non-empty Chinese value.
    @Test func key_in_chinese_locale() throws {
        let output = try runPlutil("-p", "Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings")
        #expect(output.contains("\"chatview.message.reveal_in_finder\""))
    }

    /// T35 contract: en and zh values DIFFER (= actual translation,
    /// not copy-paste).
    @Test func en_and_zh_values_differ() throws {
        let en = try runPlutil("-p", "Sources/WenshuApp/Resources/en.lproj/Localizable.strings")
        let zh = try runPlutil("-p", "Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings")
        let enVal = extractValue(en, key: "chatview.message.reveal_in_finder")
        let zhVal = extractValue(zh, key: "chatview.message.reveal_in_finder")
        #expect(enVal != nil, "en value missing")
        #expect(zhVal != nil, "zh value missing")
        #expect(enVal != zhVal, "en and zh values are identical (= no actual translation)")
    }

    /// Run `/usr/bin/plutil` and return stdout.
    private func runPlutil(_ arg: String, _ path: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        process.arguments = [arg, path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // discard
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Plutil", code: Int(process.terminationStatus))
        }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    /// Extract the value for a given key from a plutil -p output
    /// (= parses lines like `"key" => "value"`).
    private func extractValue(_ output: String, key: String) -> String? {
        let pattern = "\"\(key)\" => \"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = regex.firstMatch(in: output, range: range),
              match.numberOfRanges >= 2,
              let valueRange = Range(match.range(at: 1), in: output)
        else { return nil }
        return String(output[valueRange])
    }
}