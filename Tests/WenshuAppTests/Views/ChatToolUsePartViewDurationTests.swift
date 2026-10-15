//
//  ChatToolUsePartViewDurationTests.swift · Wenshu · T47-TOOL-DURATION (2026-09-18)
//
//  Verifies the formatDuration helper + the inline duration display.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatToolUsePartView tool duration (T47)")
struct ChatToolUsePartViewDurationTests {

    // --- formatDuration formatting ---

    @Test func formatDuration_subsecond_uses_ms() {
        #expect(ChatToolUsePartView.formatDuration(0.234) == "234ms")
        #expect(ChatToolUsePartView.formatDuration(0.999) == "999ms")
        #expect(ChatToolUsePartView.formatDuration(0.001) == "1ms")
    }

    @Test func formatDuration_subminute_uses_seconds_one_decimal() {
        #expect(ChatToolUsePartView.formatDuration(1.0) == "1.0s")
        #expect(ChatToolUsePartView.formatDuration(1.234) == "1.2s")
        #expect(ChatToolUsePartView.formatDuration(59.9) == "59.9s")
    }

    @Test func formatDuration_minute_plus_uses_minutes_seconds() {
        #expect(ChatToolUsePartView.formatDuration(60.0) == "1m 0s")
        #expect(ChatToolUsePartView.formatDuration(125.0) == "2m 5s")
        #expect(ChatToolUsePartView.formatDuration(3600.0) == "60m 0s")
    }

    @Test func formatDuration_zero_returns_0ms() {
        #expect(ChatToolUsePartView.formatDuration(0.0) == "0ms")
    }

    // --- source contract ---

    @Test func source_uses_formatDuration() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Self.formatDuration(duration)"))
    }

    @Test func source_gates_duration_on_status() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if let duration = toolUse.durationSeconds,\n                   toolUse.status != .running"))
    }

    @Test func t44_status_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func statusIconName(for status: ChatMessagePart.ToolUsePart.Status) -> String"))
    }

    @Test func t43_iconName_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func iconName(for toolName: String) -> String"))
    }
}