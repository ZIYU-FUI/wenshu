//
//  ChatViewPrevChatShortcutTests.swift · Wenshu · T114-PREV-CHAT-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘[ keyboard shortcut registered in
//  ChatView (= NSLogs a previous-chat intent).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView previous-chat shortcut (T114)")
struct ChatViewPrevChatShortcutTests {

    /// T114 contract: ⌘[ shortcut registered.
    @Test func cmd_left_bracket_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"[\", modifiers: [.command])"))
    }

    /// T114 contract: Button body NSLogs previous-chat.
    @Test func body_logs_previous_chat() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Previous chat\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("NSLog(\"[wenshu.chat]"))
        #expect(block.contains("previous-chat requested"))
        #expect(block.contains("vm.messages.count"))
    }

    /// T114 contract: button is visually hidden.
    @Test func prev_chat_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdLeftIdx = src.range(of: ".keyboardShortcut(\"[\", modifiers: [.command])")!
        let after = src[cmdLeftIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T114 contract: T113 ⌥= zoom-in shortcut preserved.
    @Test func t113_zoom_in_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"=\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Zoom in chat font\")"))
    }

    /// T114 contract: T112 ⌥Z zoom-out shortcut preserved.
    @Test func t112_zoom_out_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"z\", modifiers: [.option])"))
    }

    /// T114 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T114 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
    }

    /// T114 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let prevChatPos = src.range(of: "Button(\"Previous chat\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(prevChatPos.lowerBound > hstackClosePos)
    }
}