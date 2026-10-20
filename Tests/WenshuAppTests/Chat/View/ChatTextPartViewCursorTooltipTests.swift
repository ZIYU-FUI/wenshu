//
//  ChatTextPartViewCursorTooltipTests.swift · Wenshu · T61-CURSOR-HELP (2026-09-18)
//
//  Verifies the .help() tooltip on the streaming cursor + the
//  streamingCursorTooltip static helper.
//

import Testing
import SwiftUI
import Foundation
@testable import WenshuApp

@Suite("ChatTextPartView cursor tooltip (T61)")
struct ChatTextPartViewCursorTooltipTests {

    /// T61 contract: source uses .help(Self.streamingCursorTooltip).
    @Test func source_uses_help_tooltip() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatTextPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.streamingCursorTooltip)"))
    }

    /// T61 contract: streamingCursorTooltip helper exists.
    @Test func helper_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatTextPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static var streamingCursorTooltip: String {"))
    }

    /// T61 contract: helper uses chatview.streaming_cursor.generating key.
    @Test func helper_uses_localized_key() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatTextPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("String(localized: \"chatview.streaming_cursor.generating\")"))
    }

    /// T61 contract: chatview.streaming_cursor.generating exists in BOTH locales.
    @Test func localized_key_in_both_locales() throws {
        let en = StringCatalogReader.strings(language: "en")
        let zh = StringCatalogReader.strings(language: "zh-Hans")
        #expect(en["chatview.streaming_cursor.generating"] != nil)
        #expect(zh["chatview.streaming_cursor.generating"] != nil)
    }

    /// T61 contract: T42 streaming cursor preserved.
    @Test func t42_stream_cursor_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatTextPartView.swift",
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
            contentsOfFile: "Sources/WenshuApp/Features/Chat/View/ChatPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".wenshuThinkingAppear"))
    }

}