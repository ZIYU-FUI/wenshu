//
//  ChatToolUsePartViewCardTintTests.swift · Wenshu · T46-CARD-STATUS-TINT (2026-09-18)
//
//  Verifies the status-based card background tint:
//    - .running  → neutral quaternary (no green/red tint)
//    - .complete → green.opacity(0.06)
//    - .error    → red.opacity(0.06)
//    - outgoing user bubble preserved (= windowBackground tint)
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatToolUsePartView card tint (T46)")
struct ChatToolUsePartViewCardTintTests {

    /// T46 contract: source's toolCardFill switches on
    /// toolUse.status (.running / .complete / .error).
    @Test func source_switches_on_tool_use_status() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("switch toolUse.status {"))
        #expect(src.contains("case .running:\n            return AnyShapeStyle(.quaternary.opacity(0.5))"))
        #expect(src.contains("case .complete:\n            return AnyShapeStyle(Color.green.opacity(0.06))"))
        #expect(src.contains("case .error:\n            return AnyShapeStyle(Color.red.opacity(0.06))"))
    }

    /// T46 contract: outgoing bubble tint preserved
    /// (= isOutgoing short-circuits the status switch).
    @Test func outgoing_bubble_tint_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if isOutgoing {\n            return AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.12))"))
    }

    /// T46 contract: T2 statusColor preserved (= still drives
    /// the border color).
    @Test func t2_statusColor_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("private var statusColor: Color"))
        #expect(src.contains("private var borderColor: Color {\n        statusColor.opacity(0.5)\n    }"))
    }

    /// T46 contract: T44 status icon preserved.
    @Test func t44_status_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func statusIconName(for status: ChatMessagePart.ToolUsePart.Status) -> String"))
    }

    /// T46 contract: T45 status pulse preserved.
    @Test func t45_status_pulse_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".opacity(isRunningStatus ? runningStatusOpacity : 1.0)"))
    }
}