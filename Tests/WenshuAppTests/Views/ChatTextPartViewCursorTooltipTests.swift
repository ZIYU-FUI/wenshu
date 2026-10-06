//
//  ChatTextPartViewCursorTooltipTests.swift · Wenshu · T61-CURSOR-HELP (2026-09-18)
//
//  Verifies the .help() tooltip on the streaming cursor + the
//  streamingCursorTooltip static helper.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatTextPartView cursor tooltip (T61)")
struct ChatTextPartViewCursorTooltipTests {

    /// T61 contract: source uses .help(Self.streamingCursorTooltip).
    @Test func source_uses_help_tooltip() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatTextPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.streamingCursorTooltip)"))
    }

    /// T61 contract: streamingCursorTooltip helper exists.
    @Test func helper_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatTextPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static var streamingCursorTooltip: String {"))
    }

    /// T61 contract: helper uses chatview.streaming_cursor.generating key.
    @Test func helper_uses_localized_key() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatTextPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("String(localized: \"chatview.streaming_cursor.generating\")"))
    }

    /// T61 contract: chatview.streaming_cursor.generating exists in BOTH locales.
    @Test func localized_key_in_both_locales() throws {
        let en = try runPlutil("Sources/WenshuApp/Resources/en.lproj/Localizable.strings")
        let zh = try runPlutil("Sources/WenshuApp/Resources/zh-Hans.lproj/Localizable.strings")
        #expect(en.contains("\"chatview.streaming_cursor.generating\""))
        #expect(zh.contains("\"chatview.streaming_cursor.generating\""))
    }

    /// T61 contract: T42 streaming cursor preserved.
    @Test func t42_stream_cursor_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatTextPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("TimelineView(.periodic(from: .now, by: 0.5))"))
        #expect(src.contains("Text(\"▎\")"))
    }

    /// T61 contract: T49 text fade-in transition preserved.
    @Test func t49_text_fadein_preserved() throws {
        // The .transition(.wenshuThinkingAppear()) call for .text
        // case lives in ChatPartView (= the switch dispatch).
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".wenshuThinkingAppear"))
    }

    private func runPlutil(_ path: String) throws -> String {
        // Apple canonical source of truth: Localizable.xcstrings
        // (Xcode 15+ String Catalog format). Produce a plutil -p
        // style "key" => "value" output (= the format the
        // existing contains() assertions match on). The path
        // argument is preserved for caller compatibility; the
        // helper detects the locale from the path suffix.
        let lang: String
        if path.contains("zh-Hans.lproj") {
            lang = "zh-Hans"
        } else if path.contains("en.lproj") {
            lang = "en"
        } else {
            return ""
        }
        let xcstringsPath = "Sources/WenshuApp/Resources/Localizable.xcstrings"
        let data = try Data(contentsOf: URL(fileURLWithPath: xcstringsPath))
        guard let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = catalog["strings"] as? [String: [String: Any]] else { return "" }
        var out = "{\n"
        for (key, entry) in strings.sorted(by: { $0.key < $1.key }) {
            guard let localizations = entry["localizations"] as? [String: Any],
                  let loc = localizations[lang] as? [String: Any],
                  let unit = loc["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else { continue }
            out += "  \"\(key)\" => \"\(value)\"\n"
        }
        out += "}"
        return out
    }
}