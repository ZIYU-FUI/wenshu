//
//  ChatViewQuoteShortcutTests.swift · Wenshu · T102-QUOTE-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘⇧Q keyboard shortcut registered in
//  ChatView (= wraps the current chat input text in
//  a Markdown blockquote, prefixing each line with "> ").
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView quote shortcut (T102)")
struct ChatViewQuoteShortcutTests {

    /// T102 contract: ⌘⇧Q shortcut registered.
    @Test func cmd_shift_q_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"q\", modifiers: [.command, .shift])"))
    }

    /// T102 contract: Button body wraps vm.inputText with "> " prefix.
    @Test func body_wraps_input_text_in_quote() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Wrap selection in blockquote\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("let current = vm.inputText"))
        #expect(block.contains("let lines = current.split(separator:"))
        #expect(block.contains("let quoted = lines.map"))
        #expect(block.contains("vm.inputText = quoted"))
        #expect(block.contains("NSLog(\"[wenshu.quote]"))
    }

    /// T102 contract: button is visually hidden.
    @Test func quote_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdShiftQIdx = src.range(of: ".keyboardShortcut(\"q\", modifiers: [.command, .shift])")!
        let after = src[cmdShiftQIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T102 contract: T101 ⌘⇧K code-block shortcut preserved.
    @Test func t101_codeblock_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command, .shift])"))
        #expect(src.contains("Button(\"Wrap selection in code block\")"))
    }

    /// T102 contract: T95 ⌘⇧X strikethrough shortcut preserved.
    @Test func t95_strike_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"x\", modifiers: [.command, .shift])"))
    }

    /// T102 contract: T93 ⌘B Bold shortcut preserved.
    @Test func t93_bold_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"b\", modifiers: [.command])"))
    }

    /// T102 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T102 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
    }

    /// T102 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let quotePos = src.range(of: "Button(\"Wrap selection in blockquote\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(quotePos.lowerBound > hstackClosePos)
    }
}