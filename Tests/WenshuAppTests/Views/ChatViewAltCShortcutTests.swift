//
//  ChatViewAltCShortcutTests.swift · Wenshu · T85-ALT-C-SHORTCUT (2026-09-18)
//
//  Verifies the ⌥C keyboard shortcut registered in ChatView
//  (= the lightweight "Alt-Copy" shortcut for the last sealed
//  message content; = complement to T66 ⌘⇧D).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView alt-c shortcut (T85)")
struct ChatViewAltCShortcutTests {

    /// T85 contract: ⌥C shortcut registered.
    @Test func alt_c_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.option])"))
    }

    /// T85 contract: Button body uses NSPasteboard to copy.
    @Test func body_copies_last_sealed_message() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Copy last sealed message\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("NSPasteboard.general"))
        #expect(block.contains("pb.clearContents()"))
        #expect(block.contains("pb.setString(lastAssistant, forType: .string)"))
        #expect(block.contains("$0.source == .wenshu"))
        #expect(block.contains("!$0.isPlaceholder"))
    }

    /// T85 contract: button is visually hidden.
    @Test func alt_c_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let altCIdx = src.range(of: ".keyboardShortcut(\"c\", modifiers: [.option])")!
        let after = src[altCIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T85 contract: T66 ⌘⇧D shortcut preserved.
    @Test func t66_cmd_shift_d_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
        #expect(src.contains("Button(\"Copy last assistant\")"))
    }

    /// T85 contract: T70 ⌘⇧C shortcut preserved (= different
    /// combination than ⌥C = no collision).
    @Test func t70_cmd_shift_c_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
        #expect(src.contains("Button(\"Copy conversation\")"))
    }

    /// T85 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
        #expect(src.contains("Button(\"Show shortcuts\")"))
    }

    /// T85 contract: T37/T48/T59 prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
    }

    /// T85 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        // v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
        // row out of ChatView.swift into ChatInputBarView.swift (= the top
        // layer; = the user-interactive controls). The hidden Button("Copy last sealed message") Button
        // (= a hidden keyboard-shortcut Button outside the visible input
        // row HStack) stays in ChatView.swift (= the keyboard-shortcut
        // block lives as a sibling of ScrollViewReader, not inside the
        // input row). The invariant (= Button("Copy last sealed message") Button is OUTSIDE the
        // input row HStack) is now distributed across two files; = this
        // test verifies both halves exist (= .frame(minHeight: 44) is
        // only in ChatInputBarView; = Button("Copy last sealed message") is only in ChatView).
        let inputBarSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            encoding: .utf8
        )
        let chatViewSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // The input row HStack's minimum height pin (= .frame(minHeight: 44); = boss v1.76 spec: input height = 44PT = match button height)
        // lives ONLY in the top-layer ChatInputBarView.
        #expect(inputBarSrc.contains(".frame(minHeight: 44, maxHeight: 44)"))
        #expect(!chatViewSrc.contains(".frame(minHeight: 44, maxHeight: 44)"))
        // The Button("Copy last sealed message") keyboard shortcut Button lives ONLY in
        // ChatView (= the keyboard shortcut block is a sibling of
        // ScrollViewReader; = not inside the input row).
        #expect(chatViewSrc.contains("Button(\"Copy last sealed message\")"))
        #expect(!inputBarSrc.contains("Button(\"Copy last sealed message\")"))
    }
}