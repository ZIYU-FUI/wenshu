//
//  ChatViewRegenShortcutTests.swift · Wenshu · T77-REGEN-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘⇧G keyboard shortcut registered in ChatView
//  (= regenerates the last assistant message by discarding it
//  and re-sending the most recent user prompt).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView regenerate shortcut (T77)")
struct ChatViewRegenShortcutTests {

    /// T77 contract: ⌘⇧G shortcut registered.
    @Test func cmd_shift_g_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
    }

    /// T77 contract: Button body removes the last assistant message
    /// and re-sends the last user prompt.
    @Test func regen_removes_last_assistant_and_resends_user() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Regenerate last assistant\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 2000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("vm.messages.lastIndex(where: { $0.source == .wenshu })"))
        #expect(block.contains("vm.messages.remove(at: lastAssistantIndex)"))
        #expect(block.contains("vm.messages.last(where: { $0.source == .user })"))
        #expect(block.contains("vm.inputText = lastUserText"))
        #expect(block.contains("Task { await vm.send() }"))
    }

    /// T77 contract: button is visually hidden.
    @Test func regen_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdGIdx = src.range(of: ".keyboardShortcut(\"g\", modifiers: [.command, .shift])")!
        let after = src[cmdGIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T77 contract: T37/T48/T59/T66/T67/T69/T70/T74/T76 prior shortcuts
    /// preserved.
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
        #expect(src.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
    }

    /// T77 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        // v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
        // row out of ChatView.swift into ChatInputBarView.swift (= the top
        // layer; = the user-interactive controls). The hidden Button("Regenerate last assistant") Button
        // (= a hidden keyboard-shortcut Button outside the visible input
        // row HStack) stays in ChatView.swift (= the keyboard-shortcut
        // block lives as a sibling of ScrollViewReader, not inside the
        // input row). The invariant (= Button("Regenerate last assistant") Button is OUTSIDE the
        // input row HStack) is now distributed across two files; = this
        // test verifies both halves exist (= .frame(minHeight: 30) is
        // only in ChatInputBarView; = Button("Regenerate last assistant") is only in ChatView).
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
        // The Button("Regenerate last assistant") keyboard shortcut Button lives ONLY in
        // ChatView (= the keyboard shortcut block is a sibling of
        // ScrollViewReader; = not inside the input row).
        #expect(chatViewSrc.contains("Button(\"Regenerate last assistant\")"))
        #expect(!inputBarSrc.contains("Button(\"Regenerate last assistant\")"))
    }
}