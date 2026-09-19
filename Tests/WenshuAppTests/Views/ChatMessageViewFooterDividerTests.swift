//
//  ChatMessageViewFooterDividerTests.swift · Wenshu · T55-FOOTER-DIVIDER (2026-09-18)
//
//  Verifies the thin hairline divider above the sealed
//  message footer (= Apple HIG secondary chrome).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView footer divider (T55)")
struct ChatMessageViewFooterDividerTests {

    /// T55 contract: source uses .overlay(alignment: .top) with Rectangle
    /// for the divider (= the canonical SwiftUI overlay divider
    /// pattern).
    @Test func source_uses_overlay_divider() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".overlay(alignment: .top) {"))
        #expect(src.contains("Rectangle()\n                                .fill(.quaternary)\n                                .frame(height: 0.5)"))
    }

    /// T55 contract: divider only renders when streamState == .sealed
    /// AND tokens > 0 (= the divider is gated on the footer being
    /// meaningful).
    @Test func divider_gated_on_sealed_with_tokens() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if message.streamState == .sealed\n                            && (message.tokens ?? 0) > 0 {"))
    }

    /// T55 contract: T53 combo tooltip preserved.
    @Test func t53_combo_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.comboFooterTooltip(message: message))"))
    }

    /// T55 contract: T50 timestamp tooltip preserved.
    @Test func t50_timestamp_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTimestampTooltip(for: message.timestamp))"))
    }

    /// T55 contract: T52 token tooltip preserved.
    @Test func t52_token_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTokenCountTooltip(for: tokens))"))
    }

    /// T55 contract: T54 attachment icon preserved.
    @Test func t54_attachment_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"paperclip\")"))
    }
}