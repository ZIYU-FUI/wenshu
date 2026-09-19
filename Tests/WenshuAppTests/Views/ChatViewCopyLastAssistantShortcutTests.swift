//
//  ChatViewCopyLastAssistantShortcutTests.swift · Wenshu · T66-COPY-LAST-ASSISTANT (2026-09-18)
//
//  Verifies the ⌘⇧D keyboard shortcut registered in ChatView
//  (= the standard macOS duplicate-shortcut; = in wenshu
//  = copy the last sealed assistant message to clipboard).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView copy last assistant shortcut (T66)")
struct ChatViewCopyLastAssistantShortcutTests {

    /// T66 contract: ⌘⇧D shortcut registered.
    @Test func cmd_shift_d_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
    }

    /// T66 contract: button body looks up the last assistant message.
    @Test func cmd_shift_d_finds_last_assistant() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdDPos = src.range(of: "Button(\"Copy last assistant\")")!
        let blockEndOffset = min(src.distance(from: src.startIndex, to: cmdDPos.upperBound) + 1500,
                                src.distance(from: src.startIndex, to: src.endIndex))
        let blockStartOffset = src.distance(from: src.startIndex, to: cmdDPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: blockStartOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: blockEndOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("vm.messages.last(where: { $0.source == .wenshu })"))
    }

    /// T66 contract: button body calls NSPasteboard.general + setString.
    @Test func cmd_shift_d_uses_nspasteboard() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdDPos = src.range(of: "Button(\"Copy last assistant\")")!
        let blockEndOffset = min(src.distance(from: src.startIndex, to: cmdDPos.upperBound) + 1500,
                                src.distance(from: src.startIndex, to: src.endIndex))
        let blockStartOffset = src.distance(from: src.startIndex, to: cmdDPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: blockStartOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: blockEndOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("NSPasteboard.general"))
        #expect(block.contains("clearContents()"))
        #expect(block.contains("setString(lastAssistant, forType: .string)"))
    }

    /// T66 contract: button is visually hidden (= .frame(0,0) +
    /// .opacity(0) + .accessibilityHidden).
    @Test func cmd_shift_d_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdDShortcutIdx = src.range(of: ".keyboardShortcut(\"d\", modifiers: [.command, .shift])")!
        let after = src[cmdDShortcutIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T66 contract: T37/T48/T59 prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"l\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
    }

    /// T66 contract: HStack invariant preserved (= new Button is
    /// AFTER the input HStack's closing brace).
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdDPos = src.range(of: "Button(\"Copy last assistant\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(cmdDPos.lowerBound > hstackClosePos)
    }
}