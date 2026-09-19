//
//  ChatMessageViewTokenFooterTests.swift · Wenshu · T25-TOKEN-FOOTER (2026-09-18)
//
//  Verifies the formatTokenCount helper + the footer rendering gate
//  (= tokens > 0 + source == .wenshu + streamState == .sealed).
//  formatTokenCount is a pure static function (= testable directly).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView token footer (T25)")
struct ChatMessageViewTokenFooterTests {

    /// T25 contract: small counts (< 1000) format as "N tokens"
    /// (= no suffix = most common case for short replies).
    @Test func format_small_count() {
        #expect(ChatMessageView.formatTokenCount(0) == "0 tokens")
        #expect(ChatMessageView.formatTokenCount(1) == "1 tokens")
        #expect(ChatMessageView.formatTokenCount(234) == "234 tokens")
        #expect(ChatMessageView.formatTokenCount(999) == "999 tokens")
    }

    /// T25 contract: 1.2k-9.9k range uses one-decimal format
    /// (= 1.2k, 5.7k, 9.9k = the canonical compact form).
    @Test func format_thousands_one_decimal() {
        #expect(ChatMessageView.formatTokenCount(1_000) == "1.0k tokens")
        #expect(ChatMessageView.formatTokenCount(1_500) == "1.5k tokens")
        #expect(ChatMessageView.formatTokenCount(5_678) == "5.7k tokens")
        #expect(ChatMessageView.formatTokenCount(9_999) == "10.0k tokens")
    }

    /// T25 contract: 10k-999k range uses no-decimal format
    /// (= 10k, 234k, 999k = drop the decimal = less visual noise).
    @Test func format_tens_of_thousands() {
        #expect(ChatMessageView.formatTokenCount(10_000) == "10k tokens")
        #expect(ChatMessageView.formatTokenCount(50_000) == "50k tokens")
        #expect(ChatMessageView.formatTokenCount(234_567) == "234k tokens")
        #expect(ChatMessageView.formatTokenCount(999_999) == "999k tokens")
    }

    /// T25 contract: 1M+ uses one-decimal M suffix
    /// (= 1.2M, 5.7M = for very long conversations / 1M-context models).
    @Test func format_millions() {
        #expect(ChatMessageView.formatTokenCount(1_000_000) == "1.0M tokens")
        #expect(ChatMessageView.formatTokenCount(1_234_567) == "1.2M tokens")
        #expect(ChatMessageView.formatTokenCount(5_000_000) == "5.0M tokens")
    }

    /// T25 contract: source uses Self.formatTokenCount in the body
    /// (= SwiftUI requires Self. for static calls from inside struct
    /// instance body).
    @Test func source_uses_self_formatTokenCount() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("Text(Self.formatTokenCount(tokens))"))
    }

    /// T25 contract: footer is gated on tokens > 0 (= not nil + positive).
    @Test func footer_gated_on_positive_tokens() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("if let tokens = message.tokens, tokens > 0"))
    }
}