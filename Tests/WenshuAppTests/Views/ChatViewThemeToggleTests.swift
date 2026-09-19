//
//  ChatViewThemeToggleTests.swift · Wenshu · T74-THEME-TOGGLE (2026-09-18)
//
//  Verifies the ⌥T keyboard shortcut registered in ChatView
//  (= toggles dark/light theme via NSApp.appearance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView theme toggle shortcut (T74)")
struct ChatViewThemeToggleTests {

    /// T74 contract: ⌥T shortcut registered.
    @Test func option_t_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"t\", modifiers: [.option])"))
    }

    /// T74 contract: Button body toggles NSApp.appearance.
    @Test func body_toggles_nsapp_appearance() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Toggle theme\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("NSApp.effectiveAppearance"))
        #expect(block.contains("NSApp.appearance = NSAppearance(named: .aqua)"))
        #expect(block.contains("NSApp.appearance = NSAppearance(named: .darkAqua)"))
    }

    /// T74 contract: button is visually hidden.
    @Test func theme_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdTIdx = src.range(of: ".keyboardShortcut(\"t\", modifiers: [.option])")!
        let after = src[cmdTIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T74 contract: T37/T48/T59/T66/T67/T69/T70 prior shortcuts preserved.
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
        #expect(src.contains(".keyboardShortcut(\"c\", modifiers: [.command, .shift])"))
    }

    /// T74 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let themePos = src.range(of: "Button(\"Toggle theme\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(themePos.lowerBound > hstackClosePos)
    }
}