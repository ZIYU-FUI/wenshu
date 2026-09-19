//
//  ChatViewListShortcutTests.swift · Wenshu · T110-LIST-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘; keyboard shortcut registered in
//  ChatView (= prefixes each line of vm.inputText with
//  "- " for Markdown bullet list).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView bullet-list shortcut (T110)")
struct ChatViewListShortcutTests {

    /// T110 contract: ⌘; shortcut registered.
    @Test func cmd_semicolon_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\";\", modifiers: [.command])"))
    }

    /// T110 contract: Button body wraps vm.inputText with "- " prefix.
    @Test func body_wraps_input_text_in_list() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Wrap selection in bullet list\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("let current = vm.inputText"))
        #expect(block.contains("let listed = lines.map { \"- \\($0)\" }"))
        #expect(block.contains("vm.inputText = listed"))
        #expect(block.contains("NSLog(\"[wenshu.list]"))
    }

    /// T110 contract: button is visually hidden.
    @Test func list_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdSemiIdx = src.range(of: ".keyboardShortcut(\";\", modifiers: [.command])")!
        let after = src[cmdSemiIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T110 contract: T109 ⌥W word-count shortcut preserved.
    @Test func t109_word_count_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"w\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Show word count\")"))
    }

    /// T110 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T110 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
    }

    /// T110 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let listPos = src.range(of: "Button(\"Wrap selection in bullet list\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(listPos.lowerBound > hstackClosePos)
    }
}