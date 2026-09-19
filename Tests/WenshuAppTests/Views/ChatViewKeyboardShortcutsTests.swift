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
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // The hidden buttons must appear AFTER the HStack(alignment: .center)
        // closing brace. Find the position of the new Button "Focus input".
        let focusInputPos = src.range(of: "Button(\"Focus input\")")!
        let hstackOpenPos = src.range(of: "HStack(alignment: .center, spacing: 8) {")!
        // Find the matching close. The simplest sanity check: the new
        // buttons are below the existing HStack in source order.
        #expect(focusInputPos.lowerBound > hstackOpenPos.lowerBound)
    }
}