//
//  ChatViewMuteShortcutTests.swift · Wenshu · T96-MUTE-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘⇧M keyboard shortcut registered in
//  ChatView (= the standard macOS Mute shortcut; =
//  NSLogs a mute-request intent).
//
//  Note: this test SUITE was previously named for T67
//  (= the ⌘. cancel-streaming shortcut test); = T96
//  expanded it to cover both ⌘. (T67) and ⌘⇧M (T96)
//  mute affordances. The T67 contract is preserved
//  in the t67_cancel_streaming_preserved test below.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView mute shortcut (T67+T96)")
struct ChatViewMuteShortcutTests {

    /// T96 contract: ⌘⇧M shortcut registered.
    @Test func cmd_shift_m_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"m\", modifiers: [.command, .shift])"))
    }

    /// T96 contract: Button body NSLogs mute request.
    @Test func body_logs_mute_request() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Mute all sounds\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("NSLog(\"[wenshu.mute]"))
    }

    /// T96 contract: button is visually hidden.
    @Test func mute_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdShiftMIdx = src.range(of: ".keyboardShortcut(\"m\", modifiers: [.command, .shift])")!
        let after = src[cmdShiftMIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T96 contract: T95 ⌘⇧X strikethrough shortcut preserved.
    @Test func t95_strike_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"x\", modifiers: [.command, .shift])"))
        #expect(src.contains("Button(\"Strikethrough selected text\")"))
    }

    /// T96 contract: T93 ⌘B Bold shortcut preserved.
    @Test func t93_bold_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"b\", modifiers: [.command])"))
        #expect(src.contains("Button(\"Bold selected text\")"))
    }

    /// T96 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T96 contract: T37/T48/T59/T66/T67/T69/T70/T74/T77/T78/T79/T80 prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\".\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
    }

    /// T96 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        // v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
        // row out of ChatView.swift into ChatInputBarView.swift (= the top
        // layer; = the user-interactive controls). The hidden Button("Mute all sounds") Button
        // (= a hidden keyboard-shortcut Button outside the visible input
        // row HStack) stays in ChatView.swift (= the keyboard-shortcut
        // block lives as a sibling of ScrollViewReader, not inside the
        // input row). The invariant (= Button("Mute all sounds") Button is OUTSIDE the
        // input row HStack) is now distributed across two files; = this
        // test verifies both halves exist (= .frame(minHeight: 44) is
        // only in ChatInputBarView; = Button("Mute all sounds") is only in ChatView).
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
        // The Button("Mute all sounds") keyboard shortcut Button lives ONLY in
        // ChatView (= the keyboard shortcut block is a sibling of
        // ScrollViewReader; = not inside the input row).
        #expect(chatViewSrc.contains("Button(\"Mute all sounds\")"))
        #expect(!inputBarSrc.contains("Button(\"Mute all sounds\")"))
    }

    /// T67 contract: ⌘. cancel streaming shortcut preserved
    /// (= the suite name was originally for T67's ⌘. test; =
    /// T96 expanded the suite but kept the T67 contract).
    @Test func t67_cancel_streaming_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\".\", modifiers: [.command])"))
        #expect(src.contains("vm.cancelStreaming()"))
    }
}