//
//  ChatViewPasteImageTests.swift · Wenshu · T38-PASTE-IMAGE (2026-09-18)
//
//  Verifies that ChatView.swift handles ⌘V on an image from
//  the clipboard (= the standard Apple Messages / Slack /
//  Discord affordance). Strategy: source inspection (= the
//  onPasteCommand handler is value-typed; the runtime clipboard
//  can't be exercised in a unit test).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatView paste image (T38)")
struct ChatViewPasteImageTests {

    /// T38 contract: ChatView source uses .onPasteCommand(of: [.image])
    /// (= the SwiftUI native paste handler for image UTType).
    @Test func source_uses_onPasteCommand_image() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".onPasteCommand(of: [.image])"))
    }

    /// T38 contract: the handler extracts a NSImage, converts to PNG,
    /// writes to a temp file, then hands the URL to vm.attachImage.
    @Test func handler_writes_temp_png_and_calls_attachImage() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains("NSImage.self"))
        #expect(src.contains("tiffRepresentation"))
        #expect(src.contains("NSBitmapImageRep"))
        #expect(src.contains("representation(using: .png"))
        #expect(src.contains("FileManager.default.temporaryDirectory"))
        #expect(src.contains("vm.attachImage(at: tempURL)"))
    }

    /// T38 contract: the paste handler is on the same outer VStack
    /// (= sibling of the .fileImporter). Both should be near each
    /// other in source order (= both attached to the same VStack).
    @Test func paste_handler_is_on_outer_vstack() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // Find ALL occurrences of "fileImporter(" (not just first); the
        // fileImporter CALL SITE is on the outer VStack near the paste
        // handler. Comment mentions elsewhere in the file don't count.
        let callPattern = ".fileImporter(\n"
        guard let callSiteRange = src.range(of: callPattern) else {
            Issue.record("no .fileImporter( call site found")
            return
        }
        let pasteOffset = src.distance(
            from: src.startIndex,
            to: src.range(of: ".onPasteCommand(of: [.image])")!.lowerBound
        )
        let importerOffset = src.distance(
            from: src.startIndex,
            to: callSiteRange.lowerBound
        )
        let gap = abs(pasteOffset - importerOffset)
        #expect(gap < 5_000, "paste handler should be near fileImporter call (= same outer VStack); gap = \(gap)")
    }

    /// T38 contract: existing image affordances (fileImporter +
    /// dropDestination) are preserved (= no regression).
    @Test func existing_image_paths_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".fileImporter("))
        #expect(src.contains(".dropDestination(for: URL.self)"))
        #expect(src.contains("vm.attachImage(at: url)"))
    }

    /// T38 contract: the paste handler is on the chat input area
    /// (= NOT inside the input HStack = HStack invariant preserved).
    /// v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
    /// row (= buttons + TextField + paste handler) out of ChatView.swift
    /// into a dedicated ChatInputBarView (= the top layer; = the user-
    /// interactive controls). The paste handler (= `.onPasteCommand(of:
    /// [.image])` on the chat input area) is now in ChatInputBarView.swift;
    /// = the input row HStack's `.frame(minHeight: 30)` (= HStack close
    /// marker) is also in ChatInputBarView.swift. The HStack invariant
    /// (= `.onPasteCommand(of: [.image])` is positioned AFTER the input
    /// row HStack's `.frame(minHeight: 30)` close) is now distributed
    /// across the SAME file (= ChatInputBarView.swift); = this test reads
    /// ChatInputBarView.swift and verifies the same positional invariant.
    /// v1.81 (2026-09-23): boss's 3-layer refactor hoists the chat input
    /// row (= buttons + TextField) out of ChatView.swift into a dedicated
    /// ChatInputBarView (= the top layer; = the user-interactive
    /// controls). The paste handler (= `.onPasteCommand(of: [.image])` on
    /// the chat input area) stays in ChatView.swift (= it was attached
    /// to the chat zone's outer VStack, not the input HStack, so it
    /// didn't move with the HStack). The invariant (= the paste handler
    /// is OUTSIDE the input row HStack; = the HStack invariant is
    /// preserved) is now distributed across two files; = this test
    /// verifies both halves exist (= the paste handler lives in
    /// ChatView; = the input row HStack's `.frame(minHeight: 30)` lives
    /// in ChatInputBarView).
    @Test func paste_handler_outside_hstack() throws {
        let inputBarSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            encoding: .utf8
        )
        let chatViewSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // The paste handler lives in ChatView (= outer VStack modifier;
        // = outside the input row HStack).
        #expect(chatViewSrc.contains(".onPasteCommand(of: [.image])"))
        #expect(!inputBarSrc.contains(".onPasteCommand(of: [.image])"))
        // The input row HStack's minimum height pin (= .frame(minHeight: 30))
        // lives in ChatInputBarView (= the top layer).
        #expect(inputBarSrc.contains(".frame(minHeight: 30)"))
        #expect(!chatViewSrc.contains(".frame(minHeight: 30)"))
    }
}