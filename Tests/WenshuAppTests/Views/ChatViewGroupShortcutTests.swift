//
//  ChatViewGroupShortcutTests.swift · Wenshu · T107-GROUP-SHORTCUT (2026-09-18)
//
//  Verifies the ⌥G keyboard shortcut registered in
//  ChatView (= NSLogs a group-by-date intent with the
//  current message count + unique-day count).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView group-by-date shortcut (T107)")
struct ChatViewGroupShortcutTests {

    /// T107 contract: ⌥G shortcut registered.
    @Test func alt_g_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.option])"))
    }

    /// T107 contract: Button body NSLogs group-by-date.
    @Test func body_logs_group_by_date() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Group messages by date\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("NSLog(\"[wenshu.group]"))
        #expect(block.contains("vm.messages.count"))
        #expect(block.contains("dates.count"))
    }

    /// T107 contract: button is visually hidden.
    @Test func group_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let altGIdx = src.range(of: ".keyboardShortcut(\"g\", modifiers: [.option])")!
        let after = src[altGIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T107 contract: T106 ⌥F find shortcut preserved.
    @Test func t106_find_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"f\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Find in conversation\")"))
    }

    /// T107 contract: T105 ⌥E expand-reasoning shortcut preserved.
    @Test func t105_expand_reasoning_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"e\", modifiers: [.option])"))
    }

    /// T107 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T107 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
    }

    /// T107 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let groupPos = src.range(of: "Button(\"Group messages by date\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(groupPos.lowerBound > hstackClosePos)
    }
}