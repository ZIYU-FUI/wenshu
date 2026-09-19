//
//  ChatViewOpenMarkdownShortcutTests.swift · Wenshu · T78-OPEN-MD (2026-09-18)
//
//  Verifies the ⌘⇧O keyboard shortcut registered in ChatView
//  (= opens NSOpenPanel and parses a .md chat file back into
//  the conversation history).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView open markdown shortcut (T78)")
struct ChatViewOpenMarkdownShortcutTests {

    /// T78 contract: ⌘⇧O shortcut registered.
    @Test func cmd_shift_o_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"o\", modifiers: [.command, .shift])"))
    }

    /// T78 contract: Button opens NSOpenPanel.
    @Test func button_opens_nsopen_panel() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Open chat Markdown\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 3000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("let panel = NSOpenPanel()"))
        #expect(block.contains("panel.runModal()"))
        #expect(block.contains("panel.title = \"Open chat Markdown\""))
    }

    /// T78 contract: Body parses Chinese source prefixes (=
    /// mirrors T70/T76 export format).
    @Test func body_parses_chinese_source_prefixes() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Open chat Markdown\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 3000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("trimmed.hasPrefix(\"[你]: \")"))
        #expect(block.contains("trimmed.hasPrefix(\"[文枢]: \")"))
        #expect(block.contains("trimmed.hasPrefix(\"[系统]: \")"))
        #expect(block.contains("source = .user") || block.contains("source = .wenshu"))
    }

    /// T78 contract: Body splits by double newline (= the separator
    /// T70/T76 use to join blocks; = the same format on read).
    @Test func body_splits_by_double_newline() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Open chat Markdown\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 3000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("raw.components(separatedBy: \"\\n\\n\")"))
    }

    /// T78 contract: button is visually hidden.
    @Test func open_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdOIdx = src.range(of: ".keyboardShortcut(\"o\", modifiers: [.command, .shift])")!
        let after = src[cmdOIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T78 contract: T76 export-MD shortcut preserved.
    @Test func t76_export_md_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift])"))
    }

    /// T78 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
    }

    /// T78 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let openPos = src.range(of: "Button(\"Open chat Markdown\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(openPos.lowerBound > hstackClosePos)
    }
}