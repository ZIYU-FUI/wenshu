//
//  ChatViewOptCmdDShortcutTests.swift · Wenshu · T91-OPT-CMD-D-SHORTCUT (2026-09-18)
//
//  Verifies the ⌥⌘D keyboard shortcut registered in
//  ChatView (= "download conversation as Markdown"
//  via NSLog; = pairs with T76 ⌘⇧S export-MD).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView opt-cmd-d shortcut (T91)")
struct ChatViewOptCmdDShortcutTests {

    /// T91 contract: ⌥⌘D shortcut registered.
    @Test func opt_cmd_d_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .option])"))
    }

    /// T91 contract: Button body NSLogs save intent.
    @Test func body_logs_save_intent() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Save conversation as Markdown\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("NSLog(\"[wenshu.save]"))
        #expect(block.contains("vm.messages.count"))
    }

    /// T91 contract: button is visually hidden.
    @Test func opt_cmd_d_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let optCmdDIdx = src.range(of: ".keyboardShortcut(\"d\", modifiers: [.command, .option])")!
        let after = src[optCmdDIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T91 contract: T85 ⌥C shortcut preserved.
    @Test func t85_alt_c_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Copy last sealed message\")"))
    }

    /// T91 contract: T76 ⌘⇧S export-MD shortcut preserved.
    @Test func t76_export_md_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"s\", modifiers: [.command, .shift])"))
        #expect(src.contains("Button(\"Export as Markdown\")"))
    }

    /// T91 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
        #expect(src.contains("Button(\"Show shortcuts\")"))
    }

    /// T91 contract: T37/T48/T59/T66/T67/T69/T70/T74/T77/T78/T79/T80 prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"p\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"e\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"o\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\".\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
    }

    /// T91 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        // v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
        // row out of ChatView.swift into ChatInputBarView.swift (= the top
        // layer; = the user-interactive controls). The hidden Button("Save conversation as Markdown") Button
        // (= a hidden keyboard-shortcut Button outside the visible input
        // row HStack) stays in ChatView.swift (= the keyboard-shortcut
        // block lives as a sibling of ScrollViewReader, not inside the
        // input row). The invariant (= Button("Save conversation as Markdown") Button is OUTSIDE the
        // input row HStack) is now distributed across two files; = this
        // test verifies both halves exist (= .frame(minHeight: 44) is
        // only in ChatInputBarView; = Button("Save conversation as Markdown") is only in ChatView).
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
        // The Button("Save conversation as Markdown") keyboard shortcut Button lives ONLY in
        // ChatView (= the keyboard shortcut block is a sibling of
        // ScrollViewReader; = not inside the input row).
        #expect(chatViewSrc.contains("Button(\"Save conversation as Markdown\")"))
        #expect(!inputBarSrc.contains("Button(\"Save conversation as Markdown\")"))
    }
}