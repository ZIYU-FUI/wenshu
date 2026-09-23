//
//  ChatViewClearChatShortcutTests.swift · Wenshu · T79-CLEAR-CHAT (2026-09-18)
//
//  Verifies the ⌘⇧K keyboard shortcut registered in ChatView
//  (= the standard Apple Safari "Clear History" shortcut).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView clear chat shortcut (T79)")
struct ChatViewClearChatShortcutTests {

    @Test func cmd_shift_k_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command, .shift])"))
    }

    @Test func body_clears_messages_and_input() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        guard let removeRange = src.range(of: "vm.messages.removeAll()") else {
            Issue.record("vm.messages.removeAll() not found")
            return
        }
        let removeOffset = src.distance(from: src.startIndex, to: removeRange.lowerBound)
        let startOffset = max(0, removeOffset - 300)
        let endOffset = removeOffset + 200
        let endIdx = src.index(src.startIndex,
                                offsetBy: min(endOffset, src.distance(from: src.startIndex, to: src.endIndex)))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("Button(\"Clear chat\")"))
        #expect(block.contains("vm.inputText = \"\""))
    }

    @Test func clear_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdKIdx = src.range(of: ".keyboardShortcut(\"k\", modifiers: [.command, .shift])")!
        let after = src[cmdKIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    @Test func t37_focus_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // T37 ⌘K focus + T79 ⌘⇧K clear (= both can coexist;
        // SwiftUI distinguishes by modifier set).
        let count = src.components(separatedBy: ".keyboardShortcut(\"k\", modifiers:").count - 1
        #expect(count >= 2)
    }

    @Test func t48_new_chat_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains("Button(\"New chat\")"))
        #expect(src.contains("vm.startNewSession()"))
    }

    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"l\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"o\", modifiers: [.command, .shift])"))
    }

    @Test func hstack_invariant_preserved() throws {
        // v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
        // row out of ChatView.swift into ChatInputBarView.swift (= the top
        // layer; = the user-interactive controls). The hidden Button("Clear chat") Button
        // (= a hidden keyboard-shortcut Button outside the visible input
        // row HStack) stays in ChatView.swift (= the keyboard-shortcut
        // block lives as a sibling of ScrollViewReader, not inside the
        // input row). The invariant (= Button("Clear chat") Button is OUTSIDE the
        // input row HStack) is now distributed across two files; = this
        // test verifies both halves exist (= .frame(minHeight: 44) is
        // only in ChatInputBarView; = Button("Clear chat") is only in ChatView).
        let inputBarSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            encoding: .utf8
        )
        let chatViewSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // The input row HStack's minimum height pin (= .frame(minHeight: 44); = boss v1.76 spec: input height = 44PT = match button height)
        // lives ONLY in the top-layer ChatInputBarView.
        #expect(inputBarSrc.contains(".frame(minHeight: 44, maxHeight: 44)"))
        #expect(!chatViewSrc.contains(".frame(minHeight: 44, maxHeight: 44)"))
        // The Button("Clear chat") keyboard shortcut Button lives ONLY in
        // ChatView (= the keyboard shortcut block is a sibling of
        // ScrollViewReader; = not inside the input row).
        #expect(chatViewSrc.contains("Button(\"Clear chat\")"))
        #expect(!inputBarSrc.contains("Button(\"Clear chat\")"))
    }
}