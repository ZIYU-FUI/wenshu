//
//  ChatViewZoomInShortcutTests.swift · Wenshu · T113-ZOOM-IN-SHORTCUT (2026-09-18)
//
//  Verifies the ⌥= keyboard shortcut registered in
//  ChatView (= NSLogs a zoom-in intent).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView zoom-in shortcut (T113)")
struct ChatViewZoomInShortcutTests {

    /// T113 contract: ⌥= shortcut registered.
    @Test func alt_eq_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"=\", modifiers: [.option])"))
    }

    /// T113 contract: Button body NSLogs zoom-in intent.
    @Test func body_logs_zoom_in() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Zoom in chat font\")")!
        let startOffset = src.distance(from: src.startIndex, to: btnPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("NSLog(\"[wenshu.zoom]"))
        #expect(block.contains("zoom-in requested"))
    }

    /// T113 contract: button is visually hidden.
    @Test func zoom_in_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let altEqIdx = src.range(of: ".keyboardShortcut(\"=\", modifiers: [.option])")!
        let after = src[altEqIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T113 contract: T112 ⌥Z zoom-out shortcut preserved.
    @Test func t112_zoom_out_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"z\", modifiers: [.option])"))
        #expect(src.contains("Button(\"Zoom out chat font\")"))
    }

    /// T113 contract: T110 ⌘; list shortcut preserved.
    @Test func t110_list_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\";\", modifiers: [.command])"))
    }

    /// T113 contract: T82 ⌘? shortcut preserved.
    @Test func t82_cmd_question_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"?\", modifiers: [.command])"))
    }

    /// T113 contract: prior shortcuts preserved.
    @Test func prior_shortcuts_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\"n\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"r\", modifiers: [.command])"))
        #expect(src.contains(".keyboardShortcut(\"d\", modifiers: [.command, .shift])"))
    }

    /// T113 contract: HStack invariant preserved.
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let zoomInPos = src.range(of: "Button(\"Zoom in chat font\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(zoomInPos.lowerBound > hstackClosePos)
    }
}