//
//  ChatViewShortcutHelpTests.swift · Wenshu · T82-SHORTCUT-HELP (2026-09-18)
//
//  Verifies the ⌘? keyboard shortcut registered in ChatView
//  (= the standard Apple help shortcut; = NSLogs a cheat-sheet
//  listing all T37-T82 keyboard shortcuts).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView shortcut help (T82)")
struct ChatViewShortcutHelpTests {

    /// T82 contract: ⌘? shortcut registered.
    @Test func cmd_question_mark_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T82 contract: Button body NSLogs a cheat-sheet.
    @Test func body_logs_cheat_sheet() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Show shortcuts\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 2000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("NSLog(\"[wenshu.shortcuts]"))
        #expect(block.contains("⌘K focus input"))
        #expect(block.contains("⌘N new chat"))
        #expect(block.contains("⌘P print"))
        #expect(block.contains("⌘. cancel streaming"))
        #expect(block.contains("⌘⇧C copy conversation"))
        #expect(block.contains("⌘⇧E edit last user"))
        #expect(block.contains("⌘⇧G regenerate"))
        #expect(block.contains("⌘⇧O open chat markdown"))
        #expect(block.contains("⌘⇧S export markdown"))
        #expect(block.contains("⌥T toggle theme"))
    }

    /// T82 contract: button is visually hidden.
    @Test func shortcut_help_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdQIdx = src.range(of: ".keyboardShortcut(\"?\", modifiers: [.command])")!
        let after = src[cmdQIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T82 contract: T80 ⌘P shortcut preserved.
    @Test func t80_print_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"p\", modifiers: [.command])"))
        #expect(src.contains("Button(\"Print conversation\")"))
    }

    /// T82 contract: T79 ⌘⇧K clear shortcut preserved.
    @Test func t79_clear_chat_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command, .shift])"))
        #expect(src.contains("vm.messages.removeAll()"))
    }

    /// T82 contract: T37/T48/T59/T66/T67/T69/T70/T74/T76/T77/T78 prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"o\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
    }

    /// T82 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        // v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
        // row out of ChatView.swift into ChatInputBarView.swift (= the top
        // layer; = the user-interactive controls). The hidden Button("Show shortcuts") Button
        // (= a hidden keyboard-shortcut Button outside the visible input
        // row HStack) stays in ChatView.swift (= the keyboard-shortcut
        // block lives as a sibling of ScrollViewReader, not inside the
        // input row). The invariant (= Button("Show shortcuts") Button is OUTSIDE the
        // input row HStack) is now distributed across two files; = this
        // test verifies both halves exist (= .frame(minHeight: 30) is
        // only in ChatInputBarView; = Button("Show shortcuts") is only in ChatView).
        let inputBarSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            encoding: .utf8
        )
        let chatViewSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // The input row HStack's minimum height pin (= .frame(minHeight: 30))
        // lives ONLY in the top-layer ChatInputBarView.
        #expect(inputBarSrc.contains(".frame(minHeight: 30)"))
        #expect(!chatViewSrc.contains(".frame(minHeight: 30)"))
        // The Button("Show shortcuts") keyboard shortcut Button lives ONLY in
        // ChatView (= the keyboard shortcut block is a sibling of
        // ScrollViewReader; = not inside the input row).
        #expect(chatViewSrc.contains("Button(\"Show shortcuts\")"))
        #expect(!inputBarSrc.contains("Button(\"Show shortcuts\")"))
    }
}