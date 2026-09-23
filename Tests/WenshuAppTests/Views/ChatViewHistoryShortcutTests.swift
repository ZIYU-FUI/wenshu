//
//  ChatViewHistoryShortcutTests.swift · Wenshu · T92-HISTORY-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘Y keyboard shortcut registered in ChatView
//  (= the standard Apple Mail Show History shortcut; = in
//  wenshu = NSLogs a history-view intent with conversation
//  metadata).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView history shortcut (T92)")
struct ChatViewHistoryShortcutTests {

    /// T92 contract: ⌘Y shortcut registered.
    @Test func cmd_y_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"y\", modifiers: [.command])"))
    }

    /// T92 contract: Button body NSLogs conversation metadata.
    @Test func body_logs_history_metadata() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Show conversation history\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("NSLog(\"[wenshu.history]"))
        #expect(block.contains("vm.messages.count"))
        #expect(block.contains("totalTokens"))
        #expect(block.contains("firstTs"))
        #expect(block.contains("lastTs"))
    }

    /// T92 contract: button is visually hidden.
    @Test func history_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdYIdx = src.range(of: ".keyboardShortcut(\"y\", modifiers: [.command])")!
        let after = src[cmdYIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T92 contract: T91 ⌥⌘D shortcut preserved.
    @Test func t91_opt_cmd_d_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .option])"))
        #expect(src.contains("Button(\"Save conversation as Markdown\")"))
    }

    /// T92 contract: T85 ⌥C shortcut preserved.
    @Test func t85_alt_c_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.option])"))
    }

    /// T92 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T92 contract: T37/T48/T59/T66/T67/T69/T70/T74/T77/T78/T79/T80 prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\".\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
    }

    /// T92 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        // v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
        // row out of ChatView.swift into ChatInputBarView.swift (= the top
        // layer; = the user-interactive controls). The hidden Button("Show conversation history") Button
        // (= a hidden keyboard-shortcut Button outside the visible input
        // row HStack) stays in ChatView.swift (= the keyboard-shortcut
        // block lives as a sibling of ScrollViewReader, not inside the
        // input row). The invariant (= Button("Show conversation history") Button is OUTSIDE the
        // input row HStack) is now distributed across two files; = this
        // test verifies both halves exist (= .frame(minHeight: 44) is
        // only in ChatInputBarView; = Button("Show conversation history") is only in ChatView).
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
        // The Button("Show conversation history") keyboard shortcut Button lives ONLY in
        // ChatView (= the keyboard shortcut block is a sibling of
        // ScrollViewReader; = not inside the input row).
        #expect(chatViewSrc.contains("Button(\"Show conversation history\")"))
        #expect(!inputBarSrc.contains("Button(\"Show conversation history\")"))
    }
}