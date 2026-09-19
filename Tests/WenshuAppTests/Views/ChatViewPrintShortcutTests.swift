//
//  ChatViewPrintShortcutTests.swift · Wenshu · T80-PRINT-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘P keyboard shortcut registered in ChatView
//  (= the standard macOS Print shortcut; = in wenshu = opens
//  the NSPrintOperation print panel for the conversation).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView print shortcut (T80)")
struct ChatViewPrintShortcutTests {

    /// T80 contract: ⌘P shortcut registered.
    @Test func cmd_p_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"p\", modifiers: [.command])"))
    }

    /// T80 contract: Button body creates an NSPrintOperation.
    @Test func body_creates_nsprint_operation() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Print conversation\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 2000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("NSPrintInfo.shared"))
        #expect(block.contains("NSPrintOperation("))
        #expect(block.contains("op.showsPrintPanel = true"))
        #expect(block.contains("op.run()"))
    }

    /// T80 contract: Body uses Chinese source prefixes (= mirrors
    /// T70/T76/T78 export format).
    @Test func body_uses_chinese_source_prefixes() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Print conversation\")")!
        let endOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 2000,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: startOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("case .user: prefix = \"你\""))
        #expect(block.contains("case .wenshu: prefix = \"文枢\""))
        #expect(block.contains("case .system: prefix = \"系统\""))
    }

    /// T80 contract: button is visually hidden.
    @Test func print_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdPIdx = src.range(of: ".keyboardShortcut(\"p\", modifiers: [.command])")!
        let after = src[cmdPIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T80 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"g\", modifiers: [.command, .shift])"))
        #expect(src.contains(".keyboardShortcut(\"k\", modifiers: [.command, .shift])"))
    }

    /// T80 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let printPos = src.range(of: "Button(\"Print conversation\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(printPos.lowerBound > hstackClosePos)
    }
}