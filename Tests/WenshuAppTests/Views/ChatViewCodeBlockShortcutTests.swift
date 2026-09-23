//
//  ChatViewCodeBlockShortcutTests.swift · Wenshu · T101-CODE-BLOCK-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘⇧K keyboard shortcut registered in
//  ChatView (= wraps the current chat input text in a
//  Markdown code fence ``` ```).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView code block shortcut (T101)")
struct ChatViewCodeBlockShortcutTests {

    /// T101 contract: ⌘⇧K shortcut registered.
    @Test func cmd_shift_k_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command, .shift])"))
    }

    /// T101 contract: Button body wraps vm.inputText in ``` ```.
    @Test func body_wraps_input_text_in_code_block() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Wrap selection in code block\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("let current = vm.inputText"))
        #expect(block.contains("let coded = \"```\\n\\(current)\\n```\""))
        #expect(block.contains("vm.inputText = coded"))
        #expect(block.contains("NSLog(\"[wenshu.codeblock]"))
    }

    /// T101 contract: button is visually hidden.
    @Test func codeblock_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdShiftKIdx = src.range(of: ".keyboardShortcut(\"k\", modifiers: [.command, .shift])")!
        let after = src[cmdShiftKIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T101 contract: T37 ⌘K focus input shortcut preserved
    /// (= T101 uses ⌘⇧K = shift modifier to avoid collision).
    @Test func t37_focus_input_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
    }

    /// T101 contract: T95 ⌘⇧X strikethrough shortcut preserved.
    @Test func t95_strike_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"x\", modifiers: [.command, .shift])"))
        #expect(src.contains("Button(\"Strikethrough selected text\")"))
    }

    /// T101 contract: T93 ⌘B Bold shortcut preserved.
    @Test func t93_bold_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"b\", modifiers: [.command])"))
        #expect(src.contains("Button(\"Bold selected text\")"))
    }

    /// T101 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T101 contract: T37/T48/T59/T66/T67/T69/T70/T74/T77/T78/T79/T80/T85/T91/T92/T93/T94/T95/T96 prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\".\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
    }

    /// T101 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        // v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
        // row out of ChatView.swift into ChatInputBarView.swift (= the top
        // layer; = the user-interactive controls). The hidden Button("Wrap selection in code block") Button
        // (= a hidden keyboard-shortcut Button outside the visible input
        // row HStack) stays in ChatView.swift (= the keyboard-shortcut
        // block lives as a sibling of ScrollViewReader, not inside the
        // input row). The invariant (= Button("Wrap selection in code block") Button is OUTSIDE the
        // input row HStack) is now distributed across two files; = this
        // test verifies both halves exist (= .frame(minHeight: 30) is
        // only in ChatInputBarView; = Button("Wrap selection in code block") is only in ChatView).
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
        // The Button("Wrap selection in code block") keyboard shortcut Button lives ONLY in
        // ChatView (= the keyboard shortcut block is a sibling of
        // ScrollViewReader; = not inside the input row).
        #expect(chatViewSrc.contains("Button(\"Wrap selection in code block\")"))
        #expect(!inputBarSrc.contains("Button(\"Wrap selection in code block\")"))
    }
}