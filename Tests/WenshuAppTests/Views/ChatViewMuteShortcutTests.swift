//
//  ChatViewMuteShortcutTests.swift · Wenshu · T67-MUTE-SHORTCUT (2026-09-18)
//
//  Verifies the ⌘. keyboard shortcut registered in ChatView
//  (= the standard macOS Cancel shortcut; = in wenshu = cancel
//  the currently-streaming assistant reply via ChatViewModel.
//  cancelStreaming()).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView mute shortcut (T67)")
struct ChatViewMuteShortcutTests {

    /// T67 contract: ⌘. shortcut registered.
    @Test func cmd_period_shortcut_registered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".keyboardShortcut(\".\", modifiers: [.command])"))
    }

    /// T67 contract: Mute button body calls vm.cancelStreaming().
    @Test func cmd_period_calls_cancel_streaming() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let btnPos = src.range(of: "Button(\"Mute streaming\")")!
        let blockEndOffset = min(src.distance(from: src.startIndex, to: btnPos.upperBound) + 1500,
                                src.distance(from: src.startIndex, to: src.endIndex))
        let blockStartOffset = src.distance(from: src.startIndex, to: btnPos.lowerBound)
        let blockStartIdx = src.index(src.startIndex, offsetBy: blockStartOffset)
        let blockEndIdx = src.index(src.startIndex, offsetBy: blockEndOffset)
        let block = String(src[blockStartIdx..<blockEndIdx])
        #expect(block.contains("vm.cancelStreaming()"))
    }

    /// T67 contract: Button is visually hidden (= .frame(0,0) +
    /// .opacity(0) + .accessibilityHidden).
    @Test func mute_button_is_visually_hidden() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let cmdPeriodIdx = src.range(of: ".keyboardShortcut(\".\", modifiers: [.command])")!
        let after = src[cmdPeriodIdx.upperBound...]
        #expect(after.contains(".frame(width: 0, height: 0)"))
        #expect(after.contains(".opacity(0)"))
        #expect(after.contains(".accessibilityHidden(true)"))
    }

    /// T67 contract: ChatViewModel.cancelStreaming() method exists
    /// + cancelRequested flag exists.
    @Test func chat_view_model_has_cancel_streaming() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains("public var cancelRequested: Bool = false"))
        #expect(src.contains("public func cancelStreaming() {\n        cancelRequested = true\n    }"))
    }

    /// T67 contract: T37/T48/T59/T66 prior shortcuts preserved.
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
    }

    /// T67 contract: HStack invariant preserved (= new Button is
    /// AFTER the input HStack's closing brace).
    @Test func hstack_invariant_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let mutePos = src.range(of: "Button(\"Mute streaming\")")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)")!.lowerBound
        #expect(mutePos.lowerBound > hstackClosePos)
    }
}