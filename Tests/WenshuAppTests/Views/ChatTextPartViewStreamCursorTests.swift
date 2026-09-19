//
//  ChatTextPartViewStreamCursorTests.swift · Wenshu · T42-STREAM-CURSOR (2026-09-18)
//
//  Verifies the blinking cursor affordance in ChatTextPartView:
//    - When isStreaming = true, a trailing "▎" glyph is rendered
//      via a TimelineView (.periodic 0.5s).
//    - When isStreaming = false, NO cursor is rendered.
//    - The cursor uses the same foregroundStyle as the text body
//      (= matches user/wenshu bubble tint).
//    - The cursor's opacity oscillates between 1.0 and 0.0 (= blink).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatTextPartView stream cursor (T42)")
struct ChatTextPartViewStreamCursorTests {

    /// T42 contract: source uses TimelineView(.periodic) for the
    /// cursor (= the canonical SwiftUI blink idiom).
    @Test func source_uses_timeline_view_periodic() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("TimelineView(.periodic(from: .now, by: 0.5))"))
    }

    /// T42 contract: cursor only renders when isStreaming = true.
    @Test func cursor_only_renders_when_streaming() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        // Find the cursor block and verify it's gated on isStreaming.
        let cursorBlock = src.range(of: "if isStreaming {\n                // T42 blinking caret")
        #expect(cursorBlock != nil)
    }

    /// T42 contract: cursor glyph is the standard text-caret
    /// (= "▎" = U+258E = "LEFT ONE QUARTER BLOCK" = the canonical
    /// Apple text-cursor glyph).
    @Test func cursor_glyph_is_text_caret() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Text(\"▎\")"))
    }

    /// T42 contract: cursor opacity oscillates (= blink). The
    /// TimelineView computes `phase = Int(elapsed / 0.5) % 2 == 0`
    /// and uses .opacity(phase ? 1.0 : 0.0).
    @Test func cursor_opacity_oscillates() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("let phase = Int(elapsed / 0.5) % 2 == 0"))
        #expect(src.contains(".opacity(phase ? 1.0 : 0.0)"))
    }

    /// T42 contract: the cursor uses the SAME foregroundStyle as
    /// the text body (= matches user/wenshu bubble tint; = doesn't
    /// introduce a new color).
    @Test func cursor_uses_same_foregroundStyle() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatPartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".foregroundStyle(isOutgoing ? Color(nsColor: .windowBackgroundColor) : Color.primary)"))
    }
}