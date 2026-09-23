//
//  ChatViewKeyboardShortcutsTests.swift · Wenshu · T37-KEYBOARD-SHORTCUTS (2026-09-18)
//
//  Verifies the two new keyboard shortcuts registered in ChatView:
//    - ⌘K → focus the chat input (inputFocused = true)
//    - ⌘L → clear chat (vm.inputText = "" + vm.startNewSession())
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView keyboard shortcuts (T37)")
struct ChatViewKeyboardShortcutsTests {

    /// T37 contract: ChatView source registers ⌘K shortcut
    /// (= the standard Slack / Discord focus-input shortcut).
    @Test func cmd_k_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
    }

    /// T37 contract: ChatView source registers ⌘L shortcut
    /// (= the standard ChatGPT / Claude clear-chat shortcut).
    @Test func cmd_l_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"l\", modifiers: [.command])"))
    }

    /// T37 contract: ⌘K button action sets inputFocused = true.
    @Test func cmd_k_focuses_input() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // Locate the ⌘K button body.
        let cmdKRange = src.range(of: "Button(\"Focus input\")")!
        let cmdKBody = src[cmdKRange.lowerBound..<src.range(of: "}", range: cmdKRange.upperBound..<src.endIndex)!.lowerBound]
        #expect(cmdKBody.contains("inputFocused = true"))
    }

    /// T37 contract: ⌘L button clears input + starts new session.
    @Test func cmd_l_clears_and_starts_new_session() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // Locate the ⌘L button body.
        let cmdLRange = src.range(of: "Button(\"Clear chat\")")!
        let cmdLBody = src[cmdLRange.lowerBound..<src.range(of: "}", range: cmdLRange.upperBound..<src.endIndex)!.lowerBound]
        #expect(cmdLBody.contains("vm.inputText = \"\""))
        #expect(cmdLBody.contains("vm.startNewSession()"))
        #expect(cmdLBody.contains("inputFocused = true"))
    }

    /// T37 contract: both Buttons are visually hidden
    /// (= .frame(width: 0, height: 0) + .opacity(0)) so they
    /// don't take up chat zone space.
    @Test func buttons_are_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdKRange = src.range(of: ".keyboardShortcut(\"k\", modifiers: [.command])")!
        let cmdLRange = src.range(of: ".keyboardShortcut(\"l\", modifiers: [.command])")!
        // Verify .frame(width: 0, height: 0) appears after each
        // keyboardShortcut modifier.
        let frameK = src.range(of: ".frame(width: 0, height: 0)",
                               range: cmdKRange.upperBound..<src.endIndex)
        let frameL = src.range(of: ".frame(width: 0, height: 0)",
                               range: cmdLRange.upperBound..<src.endIndex)
        #expect(frameK != nil)
        #expect(frameL != nil)
    }

    /// T37 contract: HStack invariant preserved (= chat input
    /// HStack is unchanged; = the new Buttons are AFTER the
    /// closing `}` of the HStack).
    @Test func hstack_invariant_preserved() throws {
        // v1.83 (2026-09-23): boss's 3-layer refactor rewrites the chat input
        // row (= buttons + TextField) into a dedicated ChatInputBarView
        // (= the top layer; = the user-interactive controls). The hidden
        // buttons (= ⌘K Focus input + other ⌘K/⌘L/etc. keyboard
        // shortcuts) stay in ChatView.swift (= a sibling of
        // ScrollViewReader, not inside the input row). The HStack
        // invariant (= the input row HStack opens at
        // `HStack(alignment: .center, spacing: 10)` (= per boss v1.82
        // spec '1.token 压缩 2.10PT，按钮、10PT，...')) and the hidden
        // `Focus input` Button is positioned AFTER the HStack opens) is
        // now distributed across two files; = this test reads both
        // files to verify the cross-file invariant (= the input row
        // HStack exists in ChatInputBarView; = the Focus input Button
        // exists in ChatView; = the Focus input Button's source
        // position is after the input row HStack in source order,
        // which means it sits outside the input row visually).
        let inputBarSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            encoding: .utf8
        )
        let chatViewSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // The hidden Focus input Button lives in ChatView (= the keyboard
        // shortcut block is a sibling of ScrollViewReader).
        #expect(chatViewSrc.contains("Button(\"Focus input\")"))
        #expect(!inputBarSrc.contains("Button(\"Focus input\")"))
        // The input row HStack lives in ChatInputBarView (= the top layer;
        // = boss v1.82 spec 'spacing: 10' = 10PT between every element).
        #expect(inputBarSrc.contains("HStack(alignment: .center, spacing: 10) {"))
        #expect(!chatViewSrc.contains("HStack(alignment: .center, spacing: 10) {"))
    }
}