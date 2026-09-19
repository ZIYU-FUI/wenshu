//
//  ChatViewExportMarkdownShortcutTests.swift · Wenshu · T76-EXPORT-MD (2026-09-18)
//
//  Verifies the ⌘⇧S keyboard shortcut registered in ChatView
//  (= opens NSSavePanel and writes the conversation to a
//  .md file).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView export markdown shortcut (T76)")
struct ChatViewExportMarkdownShortcutTests {

    /// T76 contract: ⌘⇧S shortcut registered.
    @Test func cmd_shift_s_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift])"))
    }

    /// T76 contract: Button opens NSSavePanel.
    @Test func button_opens_nssave_panel() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Export as Markdown\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 2500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("let panel = NSSavePanel()"))
        #expect(block.contains("panel.runModal()"))
        #expect(block.contains("panel.title = \"Export chat as Markdown\""))
    }

    /// T76 contract: Body uses Chinese source prefixes (= mirrors
    /// T70 copy conversation format).
    @Test func body_uses_chinese_source_prefixes() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Export as Markdown\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 2500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("case .user: prefix = \"你\""))
        #expect(block.contains("case .wenshu: prefix = \"文枢\""))
        #expect(block.contains("case .system: prefix = \"系统\""))
    }

    /// T76 contract: Body writes formatted string via String.write(to:).
    @Test func body_writes_to_url() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Export as Markdown\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 2500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("try formatted.write(to: url"))
        #expect(block.contains("atomically: true"))
        #expect(block.contains("encoding: .utf8"))
    }

    /// T76 contract: button is visually hidden.
    @Test func export_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdSIdx = src.range(of: ".keyboardShortcut(\"s\", modifiers: [.command, .shift])")!
        let after = src[cmdSIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T76 contract: T70 copy-conversation source-preserved (=
    /// the export reuses the same format).
    @Test func t70_copy_conversation_format_reused() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".joined(separator: \"\\n\\n\")"))
    }

    /// T76 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
    }

    /// T76 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let exportPos = src.range(of: "Button(\"Export as Markdown\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(exportPos.lowerBound > hstackClosePos)
    }
}