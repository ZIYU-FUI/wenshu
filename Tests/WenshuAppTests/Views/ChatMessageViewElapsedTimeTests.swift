//
//  ChatMessageViewElapsedTimeTests.swift · Wenshu · T58-ELAPSED-TIME (2026-09-18)
//
//  Verifies the formatElapsed helper + the TimelineView that
//  drives the streaming "thinking for 3.2s" indicator.
//

import Testing
import Foundation
import SwiftUI
@testable import WenshuApp

@Suite("ChatMessageView elapsed time (T58)")
struct ChatMessageViewElapsedTimeTests {

    // --- formatElapsed formatting ---

    @Test func formatElapsed_subsecond_one_decimal() {
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(0.3) == "0.3s")
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(0.99) == "1.0s")
    }

    @Test func formatElapsed_subminute_one_decimal() {
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(3.2) == "3.2s")
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(12.5) == "12.5s")
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(59.9) == "59.9s")
    }

    @Test func formatElapsed_minute_plus() {
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(60.0) == "1m 0s")
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(125.0) == "2m 5s")
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(3600.0) == "1h 0m")
    }

    @Test func formatElapsed_zero_returns_0() {
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(0.0) == "0.0s")
    }

    @Test func formatElapsed_negative_clamped_to_zero() {
        // Defensive: clock skew can produce negative intervals.
        #expect(ChatMessagePlaceholderRow<EmptyView>.formatElapsed(-1.5) == "0.0s")
    }

    // --- source contract ---

    @Test func source_uses_timeline_view() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessagePlaceholderRow.swift",
            encoding: .utf8
        )
        #expect(src.contains("TimelineView(.periodic(from: .now, by: 0.5))"))
    }

    @Test func elapsed_text_uses_monospaced_caption2() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessagePlaceholderRow.swift",
            encoding: .utf8
        )
        let elapsedBlockStart = src.range(of: "Self.formatElapsed(elapsed)")!
        let elapsedBlockEnd = src.range(of: "}\n        }", range: elapsedBlockStart.upperBound..<src.endIndex)!.lowerBound
        let elapsedBlock = src[elapsedBlockStart.lowerBound..<elapsedBlockEnd]
        #expect(elapsedBlock.contains(".font(.system(.caption2, design: .monospaced))"))
        #expect(elapsedBlock.contains(".foregroundStyle(.tertiary)"))
    }

    @Test func formatElapsed_helper_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessagePlaceholderRow.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func formatElapsed(_ seconds: TimeInterval) -> String"))
    }

    @Test func t53_combo_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.comboFooterTooltip(timestamp: timestamp, tokens: tokens))"))
    }
}