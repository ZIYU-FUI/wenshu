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
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let mutePos = src.range(of: "Button(\"Mute all sounds\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(mutePos.lowerBound > hstackClosePos)
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