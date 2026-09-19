//
//  ChatViewWordCountShortcutTests.swift · Wenshu · T109-WORD-COUNT-SHORTCUT (2026-09-18)
//
//  Verifies the ⌥W keyboard shortcut registered in
//  ChatView (= NSLogs the total word count of all
//  messages + the per-message word count for the last
//  sealed message).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView word-count shortcut (T109)")
struct ChatViewWordCountShortcutTests {

    /// T109 contract: ⌥W shortcut registered.
    @Test func alt_w_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"w\", modifiers: [.option])"))
    }

    /// T109 contract: Button body NSLogs word count.
    @Test func body_logs_word_count() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Show word count\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 2000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("NSLog(\"[wenshu.wordcount]"))
        #expect(block.contains("totalWords"))
        #expect(block.contains("lastAssistantWords"))
        #expect(block.contains("split(separator: \" \")"))
        #expect(block.contains(".reduce(0, +)"))
    }

    /// T109 contract: button is visually hidden.
    @Test func word_count_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let altWIdx = src.range(of: ".keyboardShortcut(\"w\", modifiers: [.option])")!
        let after = src[altWIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T109 contract: T108 ⌥U unread shortcut preserved.
    @Test func t108_unread_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"u\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Jump to unread\")"))
    }

    /// T109 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T109 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
    }

    /// T109 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let wcPos = src.range(of: "Button(\"Show word count\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(wcPos.lowerBound > hstackClosePos)
    }
}