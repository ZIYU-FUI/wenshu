//
//  ChatMessageViewFooterComboTooltipTests.swift · Wenshu · T53-FOOTER-COMBO-TOOLTIP (2026-09-18)
//
//  Verifies the comboFooterTooltip helper + the .help() wiring
//  on the sealed footer HStack.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView footer combo tooltip (T53)")
struct ChatMessageViewFooterComboTooltipTests {

    /// T53 contract: comboFooterTooltip helper exists.
    @Test func helper_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func comboFooterTooltip(message: ChatMessage) -> String"))
    }

    /// T53 contract: source uses .help(Self.comboFooterTooltip).
    @Test func source_uses_help_tooltip() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.comboFooterTooltip(message: message))"))
    }

    /// T53 contract: T50 timestamp tooltip preserved.
    @Test func t50_timestamp_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTimestampTooltip(for: message.timestamp))"))
    }

    /// T53 contract: T52 token tooltip preserved.
    @Test func t52_token_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTokenCountTooltip(for: tokens))"))
    }

    /// T53 contract: comboFooterTooltip with both tokens + timestamp
    /// produces a joined "X tokens · <ISO>" string.
    @Test func combo_tooltip_combines_both() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 18
        components.hour = 14
        components.minute = 32
        components.second = 5
        components.timeZone = TimeZone(identifier: "UTC")
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else {
            Issue.record("failed to build date")
            return
        }
        let message = ChatMessage(
            id: UUID(),
            role: .agent,
            source: .wenshu,
            content: "test",
            timestamp: date,
            isPlaceholder: false,
            tokens: 1500
        )
        let combo = ChatMessageView.comboFooterTooltip(message: message)
        #expect(combo.contains("tokens"))
        #expect(combo.contains("·"))
    }
}