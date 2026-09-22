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
    @Test func helper_uses_i18n_key() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatTextPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("WenshuI18n.t(\"chatview.streaming_cursor.generating\")"))
    }

    /// T61 contract: chatview.streaming_cursor.generating exists in BOTH locales.
    @Test func i18n_keys_in_both_locales() throws {
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        process.arguments = ["-p", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "Plutil", code: Int(process.terminationStatus))
        }
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}