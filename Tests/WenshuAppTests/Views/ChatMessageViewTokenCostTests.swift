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

    @Test func formatTokenCost_subcent_returns_microformat() {
        // 100 tokens @ (input 3 + output 15) / 2 = 9 / 1M = $0.0009 (< 0.01)
        let result = ChatMessageFooter.formatTokenCost(100)
        #expect(result == "≈ $0.001")
    }

    @Test func formatTokenCost_medium_returns_three_decimals() {
        // 1500 tokens @ 9 / 1M = $0.0135 -> "≈ $0.014" (3 decimals)
        let result = ChatMessageFooter.formatTokenCost(1500)
        #expect(result.hasPrefix("≈ $0.01"))
    }

    @Test func formatTokenCost_large_returns_three_decimals() {
        // 1_000_000 tokens @ 9 / 1M = $9.00 -> "≈ $9.000"
        let result = ChatMessageFooter.formatTokenCost(1_000_000)
        #expect(result == "≈ $9.000")
    }

    @Test func formatTokenCost_zero_returns_microformat() {
        // 0 tokens -> cost = 0 < 0.01 -> "≈ $0.001" (= same as sub-cent path)
        let result = ChatMessageFooter.formatTokenCost(0)
        #expect(result == "≈ $0.001")
    }

    // --- source contract ---

    @Test func source_uses_formatTokenCost() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("Self.formatTokenCost(tokens)"))
    }

    @Test func source_renders_cost_label_after_token_count() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        let tokenTextRange = src.range(of: "Self.formatTokenCount(tokens)")!
        let costTextRange = src.range(of: "Self.formatTokenCost(tokens)")!
        #expect(costTextRange.lowerBound > tokenTextRange.lowerBound)
    }

    @Test func source_uses_quaternary_tone() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains(".font(.system(.caption2, design: .monospaced))\n                    .foregroundStyle(.quaternary)"))
    }

    @Test func formatTokenCost_helper_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func formatTokenCost(_ count: Int) -> String"))
    }

    @Test func t52_token_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTokenCountTooltip(for: tokens))"))
    }
}