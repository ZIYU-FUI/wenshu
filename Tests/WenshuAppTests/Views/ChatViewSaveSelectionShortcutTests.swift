//
//  ChatViewSaveSelectionShortcutTests.swift · Wenshu · T103-SAVE-SELECTION-SHORTCUT (2026-09-18)
//
//  Verifies the ⌥S keyboard shortcut registered in
//  ChatView (= copies the current chat input text to
//  NSPasteboard.general as the "selection").
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView save-selection shortcut (T103)")
struct ChatViewSaveSelectionShortcutTests {

    /// T103 contract: ⌥S shortcut registered.
    @Test func alt_s_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"s\", modifiers: [.option])"))
    }

    /// T103 contract: Button body copies to NSPasteboard.
    @Test func body_copies_to_pasteboard() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Save selection\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("let current = vm.inputText"))
        #expect(block.contains("let pb = NSPasteboard.general"))
        #expect(block.contains("pb.clearContents()"))
        #expect(block.contains("pb.setString(current, forType: .string)"))
        #expect(block.contains("NSLog(\"[wenshu.savesel]"))
    }

    /// T103 contract: button is visually hidden.
    @Test func save_sel_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let altSIdx = src.range(of: ".keyboardShortcut(\"s\", modifiers: [.option])")!
        let after = src[altSIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T103 contract: T85 ⌥C shortcut preserved.
    @Test func t85_alt_c_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Copy last sealed message\")"))
    }

    /// T103 contract: T74 ⌥T theme toggle shortcut preserved.
    @Test func t74_alt_t_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
    }

    /// T103 contract: T102 ⌘⇧Q quote shortcut preserved.
    @Test func t102_quote_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"q\", modifiers: [.command, .shift])"))
        #expect(src.contains("Button(\"Wrap selection in blockquote\")"))
    }

    /// T103 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T103 contract: prior shortcuts preserved.
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

    /// T103 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let saveSelPos = src.range(of: "Button(\"Save selection\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(saveSelPos.lowerBound > hstackClosePos)
    }
}