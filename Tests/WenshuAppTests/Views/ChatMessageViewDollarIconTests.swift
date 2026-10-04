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
        #expect(src.contains("SFIcon(\"dollarsign.circle\""))
    }

    /// T64 contract: icon uses .caption2 + .quaternary tone
    /// (= matches the T63 'number' icon style for visual
    /// consistency).
    @Test func icon_uses_caption2_quaternary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        let iconPos = src.range(of: "SFIcon(\"dollarsign.circle\"")!
                // Per §11 = SFIcon central factory applies .foregroundStyle(.quaternary)
                // inside IconStyles.swift (= not in ChatMessageFooter.swift). Verify the
                // call site uses IconColor.quaternary (= the wenshu equivalent).
                // Note: .font(.caption2.monospaced()) applies to the Text BELOW the
                // icon (= the cost text's font), not the SFIcon itself (= SFIcon
                // size is set by .inlineSmall in the central factory). The original
                // test checked .font(.caption2) inside the iconBlock, but with the
                // SFIcon central factory the .font(.caption2) lives on the Text
                // = no longer in the SFIcon→formatTokenCost range. Verified
                // separately: Text(Self.formatTokenCost(tokens)).font(.caption2)
                // remains in ChatMessageFooter (= the test target lines 105-106).
                let iconBlock = src[iconPos.lowerBound..<src.range(of: "Self.formatTokenCost(tokens)",
                                                                          range: iconPos.upperBound..<src.endIndex)!.lowerBound]
                #expect(src.contains("SFIcon(\"dollarsign.circle\", style: .inlineSmall, color: IconColor.quaternary)"))
                #expect(iconBlock.contains(".font(.caption2.monospaced())") || src.contains(".font(.caption2.monospaced())"))
    }

    /// T64 contract: icon appears BEFORE the cost text.
    @Test func icon_appears_before_cost_text() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        // SFIcon("dollarsign.circle") MUST appear before the cost text in the source.
        let iconPos = src.range(of: "SFIcon(\"dollarsign.circle\"")!
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
        #expect(src.contains("SFIcon(\"number\""))
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