//
//  ChatViewItalicShortcutTests.swift · Wenshu · T94-ITALIC-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘I keyboard shortcut registered in ChatView
//  (= the standard Apple Italic shortcut; = in wenshu =
//  wraps the current chat input text in _ ... _ markdown).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView italic shortcut (T94)")
struct ChatViewItalicShortcutTests {

    /// T94 contract: ⌘I shortcut registered.
    @Test func cmd_i_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"i\", modifiers: [.command])"))
    }

    /// T94 contract: Button body wraps vm.inputText in _ _.
    @Test func body_wraps_input_text_in_italic() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Italicize selected text\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("let current = vm.inputText"))
        #expect(block.contains("let italicized = \"_\\(current)_\""))
        #expect(block.contains("vm.inputText = italicized"))
        #expect(block.contains("NSLog(\"[wenshu.italic]"))
    }

    /// T94 contract: button is visually hidden.
    @Test func italic_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdIIdx = src.range(of: ".keyboardShortcut(\"i\", modifiers: [.command])")!
        let after = src[cmdIIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T94 contract: T93 ⌘B Bold shortcut preserved.
    @Test func t93_bold_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"b\", modifiers: [.command])"))
        #expect(src.contains("Button(\"Bold selected text\")"))
    }

    /// T94 contract: T92 ⌘Y History shortcut preserved.
    @Test func t92_history_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"y\", modifiers: [.command])"))
    }

    /// T94 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T94 contract: T37/T48/T59/T66/T67/T69/T70/T74/T77/T78/T79/T80 prior shortcuts preserved.
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
    }

    /// T94 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let italicPos = src.range(of: "Button(\"Italicize selected text\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(italicPos.lowerBound > hstackClosePos)
    }
}