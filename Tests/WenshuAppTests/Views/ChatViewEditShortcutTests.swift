//
//  ChatViewEditShortcutTests.swift · Wenshu · T69-EDIT-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘⇧E keyboard shortcut registered in ChatView
//  (= edit the last user message: copy text to input + focus input).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView edit last user message shortcut (T69)")
struct ChatViewEditShortcutTests {

    /// T69 contract: ⌘⇧E shortcut registered.
    @Test func cmd_shift_e_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift])"))
    }

    /// T69 contract: Edit button body copies text + focuses input.
    @Test func cmd_shift_e_copies_text_and_focuses() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Edit last user message\")")!
        let blockEndOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 1500,
                                src.distance(from: src.startIndex, to: src.endIndex))
        let blockStartOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: blockStartOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: blockEndOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("vm.messages.last(where: { $0.source == .user })"))
        #expect(block.contains("vm.inputText = lastUserText"))
        #expect(block.contains("inputFocused = true"))
    }

    /// T69 contract: button is visually hidden (= .frame(0,0) +
    /// .opacity(0) + .accessibilityHidden).
    @Test func cmd_shift_e_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdEIdx = src.range(of: ".keyboardShortcut(\"e\", modifiers: [.command, .shift])")!
        let after = src[cmdEIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T69 contract: T37/T48/T59/T66/T67 prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"l\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\".\", modifiers: [.command])"))
    }

    /// T69 contract: HStack invariant preserved (= new Button is
    /// AFTER the input HStack's closing brace).
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let editPos = src.range(of: "Button(\"Edit last user message\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(editPos.lowerBound > hstackClosePos)
    }
}