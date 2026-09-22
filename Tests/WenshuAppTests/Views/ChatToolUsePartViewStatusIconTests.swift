//
//  ChatToolUsePartViewStatusIconTests.swift · Wenshu · T44-TOOL-STATUS-ICON (2026-09-18)
//
//  Verifies the statusIconName(for:) helper on ChatToolUsePartView:
//    - .running → "hourglass"
//    - .complete → "checkmark"
//    - .error → "xmark"
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatToolUsePartView status icon SF (T44)")
struct ChatToolUsePartViewStatusIconTests {

    @Test func running_returns_hourglass() {
        let icon = ChatToolUsePartView.statusIconName(
            for: ChatMessagePart.ToolUsePart.Status.running
        )
        #expect(icon == "hourglass")
    }

    @Test func complete_returns_checkmark() {
        let icon = ChatToolUsePartView.statusIconName(
            for: ChatMessagePart.ToolUsePart.Status.complete
        )
        #expect(icon == "checkmark")
    }

    @Test func error_returns_xmark() {
        let icon = ChatToolUsePartView.statusIconName(
            for: ChatMessagePart.ToolUsePart.Status.error
        )
        #expect(icon == "xmark")
    }

    /// T44 contract: source uses statusIconName(for:) in the card
    /// header (= replaces T2's bare Circle status dot with a
    /// visible SF Symbol).
    @Test func source_uses_statusIconName() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: Self.statusIconName(for: toolUse.status))"))
    }

    /// T44 contract: T43's iconName helper is preserved (= no
    /// regression of T43's tool-kind icon map).
    @Test func t43_icon_helper_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatToolUsePartView.swift",
            encoding: .utf8
        )
        #expect(src.contains("nonisolated static func iconName(for toolName: String) -> String"))
    }
}