//
//  ChatMessageViewTokenCostTests.swift · Wenshu · T62-TOKEN-COST (2026-09-18)
//
//  Verifies the formatTokenCost helper + the inline cost
//  label wired in the sealed-message footer.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView token cost (T62)")
struct ChatMessageViewTokenCostTests {

    // --- formatTokenCost formatting ---

    @Test func formatTokenCost_subcent_returns_subcent() {
        // 100 tokens @ $9 / 1M = $0.0009 (= sub-cent)
        let result = ChatMessageView.formatTokenCost(100)
        #expect(result == "≈ <$0.01")
    }

    @Test func formatTokenCost_medium_returns_decimal() {
        // 1500 tokens @ $9 / 1M = $0.0135 (= 2 decimals)
        let result = ChatMessageView.formatTokenCost(1500)
        #expect(result.hasPrefix("≈ $"))
        #expect(result.hasSuffix("01") || result.hasSuffix("02"))  // rounding tolerance
    }

    @Test func formatTokenCost_large_returns_larger() {
        // 1_000_000 tokens @ $9 / 1M = $9.00
        let result = ChatMessageView.formatTokenCost(1_000_000)
        #expect(result == "≈ $9.00")
    }

    @Test func formatTokenCost_zero_returns_empty() {
        let result = ChatMessageView.formatTokenCost(0)
        #expect(result == "")
    }

    // --- source contract ---

    @Test func source_uses_formatTokenCost() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Self.formatTokenCost(tokens)"))
    }

    @Test func source_renders_cost_label_after_token_count() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let tokenTextRange = src.range(of: "Self.formatTokenCount(tokens)")!
        let costTextRange = src.range(of: "Self.formatTokenCost(tokens)")!
        #expect(costTextRange.lowerBound > tokenTextRange.lowerBound)
    }

    @Test func source_uses_quaternary_tone() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".font(.system(.caption2, design: .monospaced))\n                                .foregroundStyle(.quaternary)"))
    }

    @Test func formatTokenCost_helper_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func formatTokenCost(_ tokens: Int) -> String"))
    }

    @Test func t52_token_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTokenCountTooltip(for: tokens))"))
    }
}