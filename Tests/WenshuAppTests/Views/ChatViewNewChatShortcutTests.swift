//
//  ChatViewNewChatShortcutTests.swift · Wenshu · T48-NEW-CHAT-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘N keyboard shortcut registered in ChatView
//  (= the standard macOS File > New shortcut; = matches
//  Pages / TextEdit / Xcode).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView new chat shortcut (T48)")
struct ChatViewNewChatShortcutTests {

    /// T48 contract: ChatView source registers ⌘N shortcut.
    @Test func cmd_n_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
    }

    /// T48 contract: ⌘N button body calls vm.startNewSession() + focus input.
    @Test func cmd_n_starts_new_session_and_focuses() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdNRange = src.range(of: "Button(\"New chat\")")!
        let bodyEnd = src.range(of: "}", range: cmdNRange.upperBound..<src.endIndex)!.lowerBound
        let cmdNBody = src[cmdNRange.lowerBound..<bodyEnd]
        #expect(cmdNBody.contains("vm.startNewSession()"))
        #expect(cmdNBody.contains("inputFocused = true"))
    }

    /// T48 contract: ⌘N button is visually hidden (= .frame(0,0) +
    /// .opacity(0) + .accessibilityHidden(true)).
    @Test func cmd_n_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdNShortcutIdx = src.range(of: ".keyboardShortcut(\"n\", modifiers: [.command])")!
        let after = src[cmdNShortcutIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T48 contract: T37's existing ⌘K + ⌘L shortcuts preserved.
    @Test func t37_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"l\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
    }

    /// T48 contract: HStack invariant preserved (= new shortcut
    /// is AFTER the input HStack's closing brace).
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdNPos = src.range(of: "Button(\"New chat\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(cmdNPos.lowerBound > hstackClosePos)
    }
}