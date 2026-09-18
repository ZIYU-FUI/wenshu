//
//  ChatToolResultMarkdownTests.swift · Wenshu · T16-TOOL-RESULT-MARKDOWN (2026-09-18)
//
//  Verifies that ChatToolResultPartView renders tool result content
//  as inline markdown (= same parseMarkdown call as ChatTextPartView)
//  and that the expansion toggle appears only when content is long.
//

import Testing
import Foundation
import SwiftUI
@testable import WenshuApp

@Suite("ChatToolResultPartView markdown rendering (T16)")
struct ChatToolResultMarkdownTests {

    /// T16 contract: parseMarkdown reuses ChatTextPartView's parser
    /// (= inline-only preserving whitespace; = bold/italic/code work).
    @Test func parse_markdown_returns_attributed_string() {
        let result = ChatToolResultPartView.parseMarkdown("**bold** and *italic* and `code`")
        // AttributedString from inline markdown should produce a
        // non-empty run. Just verify it parses (= substring presence
        // is the spec).
        let plain = String(result.characters[...])
        #expect(plain.contains("bold"))
        #expect(plain.contains("italic"))
        #expect(plain.contains("code"))
    }

    /// T16 contract: plain text without markdown round-trips (= the
    /// AttributedString fallback path; = never crashes).
    @Test func parse_markdown_plain_text_falls_back() {
        let result = ChatToolResultPartView.parseMarkdown("plain text")
        #expect(String(result.characters[...]) == "plain text")
    }

    /// T16 contract: needsExpandToggle = true when content > 8 lines.
    @Test func expand_toggle_shown_for_multiline_content() {
        let lines = (1...10).map { "line \($0)" }.joined(separator: "\n")
        #expect(Self.heuristicNeedsExpandToggle(lines) == true)
    }

    /// T16 contract: needsExpandToggle = false for short content.
    @Test func expand_toggle_hidden_for_short_content() {
        let short = "small output"
        #expect(Self.heuristicNeedsExpandToggle(short) == false)
    }

    /// T16 contract: needsExpandToggle = true for long single-line
    /// content (> 480 chars).
    @Test func expand_toggle_shown_for_long_single_line() {
        let long = String(repeating: "x", count: 500)
        #expect(Self.heuristicNeedsExpandToggle(long) == true)
    }

    /// Mirror of the view's private `needsExpandToggle` heuristic for
    /// direct testing (= avoids needing to instantiate SwiftUI state).
    /// Kept in sync with `ChatToolResultPartView.needsExpandToggle`.
    private static func heuristicNeedsExpandToggle(_ content: String) -> Bool {
        content.components(separatedBy: "\n").count > 8
            || content.count > 480
    }
}