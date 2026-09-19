//
//  ChatMessageViewTokenIconTests.swift · Wenshu · T63-TOKEN-ICON (2026-09-18)
//
//  Verifies the "number" SF Symbol prefix on the token count
//  text in the sealed-message footer.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView token icon (T63)")
struct ChatMessageViewTokenIconTests {

    /// T63 contract: source uses Image(systemName: "number") in the footer.
    @Test func source_uses_number_sf_symbol() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"number\")"))
    }

    /// T63 contract: icon uses .caption2 + .quaternary tone.
    @Test func icon_uses_caption2_quaternary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let iconPos = src.range(of: "Image(systemName: \"number\")")!
        let tokenPos = src.range(of: "Self.formatTokenCount(tokens)")!
        let iconBlock = src[iconPos.lowerBound..<tokenPos.lowerBound]
        #expect(iconBlock.contains(".font(.caption2)"))
        #expect(iconBlock.contains(".foregroundStyle(.quaternary)"))
    }

    /// T63 contract: icon appears BEFORE the token count text (=
    /// Apple HIG metadata icon convention).
    @Test func icon_appears_before_token_count() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let iconPos = src.range(of: "Image(systemName: \"number\")")!
        let tokenPos = src.range(of: "Self.formatTokenCount(tokens)")!
        #expect(iconPos.lowerBound < tokenPos.lowerBound)
    }

    /// T63 contract: T52 token tooltip preserved.
    @Test func t52_token_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTokenCountTooltip(for: tokens))"))
    }

    /// T63 contract: T62 token cost preserved.
    @Test func t62_token_cost_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Self.formatTokenCost(tokens)"))
    }

    /// T63 contract: T55 footer divider preserved.
    @Test func t55_footer_divider_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".overlay(alignment: .top) {"))
    }
}