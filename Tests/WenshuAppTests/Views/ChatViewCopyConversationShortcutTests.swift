//
//  ChatViewCopyConversationShortcutTests.swift · Wenshu · T70-COPY-CONVERSATION (2026-09-18)
//
//  Verifies the ⌘⇧C keyboard shortcut registered in ChatView
//  (= copy the entire conversation to the clipboard, with each
//  message prefixed by "[你]:" / "[文枢]:" / "[系统]:"). Silent
//  no-op when the conversation is empty.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView copy conversation shortcut (T70)")
struct ChatViewCopyConversationShortcutTests {

    /// T70 contract: ⌘⇧C shortcut registered.
    @Test func cmd_shift_c_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
    }

    /// T70 contract: Copy button formats messages with Chinese
    /// source prefixes.
    @Test func cmd_shift_c_uses_chinese_source_prefixes() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Copy conversation\")")!
        let blockEndOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 2500,
                                src.distance(from: src.startIndex, to: src.endIndex))
        let blockStartOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: blockStartOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: blockEndOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("case .user: prefix = \"你\""))
        #expect(block.contains("case .wenshu: prefix = \"文枢\""))
        #expect(block.contains("case .system: prefix = \"系统\""))
        #expect(block.contains("\"[\\(prefix)]: \\(msg.content)\""))
    }

    /// T70 contract: format joins messages with double newline.
    @Test func cmd_shift_c_joins_with_double_newline() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".joined(separator: \"\\n\\n\")"))
    }

    /// T70 contract: button body calls NSPasteboard.general + setString.
    @Test func cmd_shift_c_uses_nspasteboard() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Copy conversation\")")!
        let blockEndOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 2500,
                                src.distance(from: src.startIndex, to: src.endIndex))
        let blockStartOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: blockStartOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: blockEndOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("NSPasteboard.general"))
        #expect(block.contains("clearContents()"))
        #expect(block.contains("setString(formatted, forType: .string)"))
    }

    /// T70 contract: button is visually hidden.
    @Test func cmd_shift_c_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdCIdx = src.range(of: ".keyboardShortcut(\"c\", modifiers: [.command, .shift])")!
        let after = src[cmdCIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T70 contract: T37/T48/T59/T66/T67/T69 prior shortcuts preserved.
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
        #expect(src.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift])"))
    }

    /// T70 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let copyPos = src.range(of: "Button(\"Copy conversation\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(copyPos.lowerBound > hstackClosePos)
    }
}