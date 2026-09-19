//
//  ChatViewFindShortcutTests.swift · Wenshu · T106-FIND-SHORTCUT (2026-09-18)
//
//  Verifies the ⌥F keyboard shortcut registered in
//  ChatView (= NSLogs a find-in-conversation intent with
//  the current chat input as the search term).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView find shortcut (T106)")
struct ChatViewFindShortcutTests {

    /// T106 contract: ⌥F shortcut registered.
    @Test func alt_f_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"f\", modifiers: [.option])"))
    }

    /// T106 contract: Button body NSLogs find-in-conversation.
    @Test func body_logs_find_in_conversation() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Find in conversation\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("NSLog(\"[wenshu.find]"))
        #expect(block.contains("vm.messages.count"))
        #expect(block.contains("vm.inputText"))
    }

    /// T106 contract: button is visually hidden.
    @Test func find_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let altFIdx = src.range(of: ".keyboardShortcut(\"f\", modifiers: [.option])")!
        let after = src[altFIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T106 contract: T105 ⌥E expand-reasoning shortcut preserved.
    @Test func t105_expand_reasoning_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"e\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Expand all reasoning blocks\")"))
    }

    /// T106 contract: T104 ⌥A append shortcut preserved.
    @Test func t104_append_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"a\", modifiers: [.option])"))
    }

    /// T106 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T106 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
    }

    /// T106 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let findPos = src.range(of: "Button(\"Find in conversation\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(findPos.lowerBound > hstackClosePos)
    }
}