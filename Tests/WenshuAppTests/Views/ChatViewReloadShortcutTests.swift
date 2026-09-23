//
//  ChatViewReloadShortcutTests.swift · Wenshu · T59-RELOAD-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘R keyboard shortcut registered in ChatView
//  (= the standard macOS browser-style reload shortcut; = also
//  matches VSCode / Xcode = re-send the last user message).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView reload shortcut (T59)")
struct ChatViewReloadShortcutTests {

    /// T59 contract: ChatView source registers ⌘R shortcut.
    @Test func cmd_r_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
    }

    /// T59 contract: Reload button body re-sends the last user message.
    @Test func cmd_r_resends_last_user_message() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // Locate the Button declaration. Then the button body extends
        // until the matching closing brace at indent level 12 (= one
        // level less than the Button's body). Use substringAfter to
        // capture the entire button block.
        let cmdRPos = src.range(of: "Button(\"Reload chat\")")!
        // Read 1500 chars after; = covers the whole Button body.
        let blockEndOffset = min(src.distance(from: src.startIndex, to: cmdRPos.upperBound) + 1500,
                                src.distance(from: src.startIndex, to: src.endIndex))
        let blockStartOffset = src.distance(from: src.startIndex, to: cmdRPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: blockStartOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: blockEndOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("vm.messages.last(where: { $0.source == .user })"))
        #expect(block.contains("vm.inputText = lastUserText"))
        #expect(block.contains("Task { await vm.send() }"))
    }

    /// T59 contract: ⌘R falls back to focusing the input when
    /// there is no prior user message.
    @Test func cmd_r_falls_back_to_focus_input() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdRPos = src.range(of: "Button(\"Reload chat\")")!
        let blockEndOffset = min(src.distance(from: src.startIndex, to: cmdRPos.upperBound) + 1500,
                                src.distance(from: src.startIndex, to: src.endIndex))
        let blockStartOffset = src.distance(from: src.startIndex, to: cmdRPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: blockStartOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: blockEndOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("inputFocused = true"))
    }

    /// T59 contract: Reload button is visually hidden.
    @Test func cmd_r_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdRShortcutIdx = src.range(of: ".keyboardShortcut(\"r\", modifiers: [.command])")!
        let after = src[cmdRShortcutIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T59 contract: T37 ⌘K + ⌘L + T48 ⌘N + T49 ⌘G preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"l\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
    }

    /// T59 contract: HStack invariant preserved (= new Button is
    /// AFTER the input HStack's closing brace).
    @Test func hstack_invariant_preserved() throws {
        // v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
        // row out of ChatView.swift into ChatInputBarView.swift (= the top
        // layer; = the user-interactive controls). The hidden Button("Reload chat") Button
        // (= a hidden keyboard-shortcut Button outside the visible input
        // row HStack) stays in ChatView.swift (= the keyboard-shortcut
        // block lives as a sibling of ScrollViewReader, not inside the
        // input row). The invariant (= Button("Reload chat") Button is OUTSIDE the
        // input row HStack) is now distributed across two files; = this
        // test verifies both halves exist (= .frame(minHeight: 44) is
        // only in ChatInputBarView; = Button("Reload chat") is only in ChatView).
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
        // The Button("Reload chat") keyboard shortcut Button lives ONLY in
        // ChatView (= the keyboard shortcut block is a sibling of
        // ScrollViewReader; = not inside the input row).
        #expect(chatViewSrc.contains("Button(\"Reload chat\")"))
        #expect(!inputBarSrc.contains("Button(\"Reload chat\")"))
    }
}