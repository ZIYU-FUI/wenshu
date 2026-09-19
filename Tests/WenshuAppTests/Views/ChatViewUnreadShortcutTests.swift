//
//  ChatViewUnreadShortcutTests.swift · Wenshu · T108-UNREAD-SHORTCUT (2026-09-18)
//
//  Verifies the ⌥U keyboard shortcut registered in
//  ChatView (= NSLogs a jump-to-unread intent).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView jump-to-unread shortcut (T108)")
struct ChatViewUnreadShortcutTests {

    /// T108 contract: ⌥U shortcut registered.
    @Test func alt_u_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"u\", modifiers: [.option])"))
    }

    /// T108 contract: Button body NSLogs jump-to-unread.
    @Test func body_logs_jump_to_unread() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Jump to unread\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("NSLog(\"[wenshu.unread]"))
        #expect(block.contains("vm.messages.count"))
    }

    /// T108 contract: button is visually hidden.
    @Test func unread_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let altUIdx = src.range(of: ".keyboardShortcut(\"u\", modifiers: [.option])")!
        let after = src[altUIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T108 contract: T107 ⌥G group-by-date shortcut preserved.
    @Test func t107_group_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Group messages by date\")"))
    }

    /// T108 contract: T106 ⌥F find shortcut preserved.
    @Test func t106_find_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"f\", modifiers: [.option])"))
    }

    /// T108 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T108 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
    }

    /// T108 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let unreadPos = src.range(of: "Button(\"Jump to unread\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(unreadPos.lowerBound > hstackClosePos)
    }
}