//
//  ChatViewAppendShortcutTests.swift · Wenshu · T104-APPEND-SHORTCUT (2026-09-18)
//
//  Verifies the ⌥A keyboard shortcut registered in
//  ChatView (= appends the LAST sealed assistant message
//  content to the current chat input text).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView append-last-assistant shortcut (T104)")
struct ChatViewAppendShortcutTests {

    /// T104 contract: ⌥A shortcut registered.
    @Test func alt_a_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"a\", modifiers: [.option])"))
    }

    /// T104 contract: Button body appends last assistant to input.
    @Test func body_appends_last_assistant_to_input() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Append last assistant to input\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 2000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("$0.source == .wenshu"))
        #expect(block.contains("!$0.isPlaceholder"))
        #expect(block.contains("vm.inputText = lastAssistant") || block.contains("vm.inputText += "))
        #expect(block.contains("inputFocused = true"))
        #expect(block.contains("NSLog(\"[wenshu.append]"))
    }

    /// T104 contract: button is visually hidden.
    @Test func append_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let altAIdx = src.range(of: ".keyboardShortcut(\"a\", modifiers: [.option])")!
        let after = src[altAIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T104 contract: T103 ⌥S save-selection shortcut preserved.
    @Test func t103_save_selection_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"s\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Save selection\")"))
    }

    /// T104 contract: T85 ⌥C copy-last-sealed shortcut preserved.
    @Test func t85_alt_c_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Copy last sealed message\")"))
    }

    /// T104 contract: T74 ⌥T theme toggle shortcut preserved.
    @Test func t74_alt_t_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
    }

    /// T104 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T104 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\".\", modifiers: [.command])"))
    }

    /// T104 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let appendPos = src.range(of: "Button(\"Append last assistant to input\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(appendPos.lowerBound > hstackClosePos)
    }
}