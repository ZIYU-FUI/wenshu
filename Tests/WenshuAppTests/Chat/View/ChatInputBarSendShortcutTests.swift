//
//  ChatInputBarSendShortcutTests.swift · Wenshu · craft-glass batch (2026-11-22)
//
//  Pins the ⌘↩ send registration in ChatInputBarView: exactly one
//  registration, living on a hidden carrier that is mounted in every
//  streaming state (the visible glyph swaps to a stop button during a
//  reply; the key path must not follow it).
//
//  The suite is source-gated by design, following the existing shortcut
//  pin tests: a keyboard shortcut cannot be asserted through an
//  NSHostingView hit (no key event reaches it off the main run loop),
//  so the mutation guard here is that reverting the hunk (deleting the
//  carrier, or re-burying the shortcut inside a branch) fails assertions
//  1 and 3 respectively.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("ChatInputBar ⌘↩ carrier (craft batch)")
struct ChatInputBarSendShortcutTests {
    private static let relativePath =
        "Sources/WenshuApp/Features/Chat/View/ChatInputBarView.swift"

    /// 1. The carrier exists: one hidden Button carries the registration.
    @Test func returnCommandCarrierExists() throws {
        let src = try SourceLocator.read(Self.relativePath)
        #expect(src.contains("Button(\"Send shortcut carrier\")"))
        #expect(src.contains(".keyboardShortcut(.return, modifiers: [.command])"))
    }

    /// 2. The registration exists exactly once (the visible paperplane
    ///    must not double-register ⌘↩ next to the carrier).
    @Test func returnCommandRegisteredOnce() throws {
        let src = try SourceLocator.read(Self.relativePath)
        var count = 0
        var search = src.startIndex
        while let r = src.range(of: "keyboardShortcut(.return, modifiers: [.command])", range: search ..< src.endIndex) {
            count += 1
            search = r.upperBound
        }
        #expect(count == 1, "⌘↩ registered \(count) times; exactly the carrier may carry it")
    }

    /// 3. The registration sits after both glyph branches, i.e. outside
    ///    the streaming `if`/`else`, so it is mounted unconditionally.
    @Test func returnCommandIsStateIndependent() throws {
        let src = try SourceLocator.read(Self.relativePath)
        let carrier = try #require(
            src.range(of: "Button(\"Send shortcut carrier\")"),
            "carrier missing; ⌘↩ would be state-scoped again"
        )
        let shortcut = try #require(
            src.range(of: ".keyboardShortcut(.return, modifiers: [.command])")
        )
        // The carrier button declaration precedes its own modifier; and
        // the streaming branch marker precedes the carrier, proving the
        // registration is a sibling of the branches, not inside one.
        #expect(carrier.lowerBound < shortcut.upperBound)
        let streaming = try #require(src.range(of: "if isReplyStreaming"))
        #expect(streaming.upperBound < carrier.lowerBound)
        #expect(src[carrier.lowerBound...].contains(".accessibilityHidden(true)"))
    }
}
