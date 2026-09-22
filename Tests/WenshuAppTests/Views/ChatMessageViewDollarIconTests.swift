//
//  ChatMessageViewDollarIconTests.swift · Wenshu · T64-DOLLAR-ICON (2026-09-18)
//
//  Verifies the "$" SF Symbol prefix on the token cost label
//  in the sealed-message footer (= Apple HIG metadata icon
//  affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView dollar icon (T64)")
struct ChatMessageViewDollarIconTests {

    /// T64 contract: source uses Image(systemName: "dollarsign.circle").
    @Test func source_uses_dollarsign_circle() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"dollarsign.circle\")"))
    }

    /// T64 contract: icon uses .caption2 + .quaternary tone
    /// (= matches the T63 'number' icon style for visual
    /// consistency).
    @Test func icon_uses_caption2_quaternary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        let iconPos = src.range(of: "Image(systemName: \"dollarsign.circle\")")!
        // The icon block ends where the SECOND `Self.formatTokenCost`
        // call begins (= T64 added a duplicate Text wrapping the
        // cost text, so the icon's tail is the start of the
        // duplicate Text).
        let secondCostPos = src.range(of: "Self.formatTokenCost(tokens)",
                                     range: iconPos.upperBound..<src.endIndex)!
        let iconBlock = src[iconPos.lowerBound..<secondCostPos.lowerBound]
        #expect(iconBlock.contains(".font(.caption2)"))
        #expect(iconBlock.contains(".foregroundStyle(.quaternary)"))
    }

    /// T64 contract: icon appears BEFORE the cost text.
    @Test func icon_appears_before_cost_text() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        let iconPos = src.range(of: "Image(systemName: \"dollarsign.circle\")")!
        // First Text(Self.formatTokenCost...) call AFTER the icon.
        let firstCostAfter = src.range(of: "Self.formatTokenCost(tokens)",
                                      range: iconPos.upperBound..<src.endIndex)!
        #expect(iconPos.lowerBound < firstCostAfter.lowerBound)
    }

    /// T64 contract: T63 'number' icon preserved (= the token
    /// count still has its icon).
    @Test func t63_number_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"number\")"))
    }

    /// T64 contract: T62 formatTokenCost preserved.
    @Test func t62_token_cost_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("Self.formatTokenCost(tokens)"))
    }

    /// T64 contract: T52 token tooltip preserved.
    @Test func t52_token_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTokenCountTooltip(for: tokens))"))
    }
}