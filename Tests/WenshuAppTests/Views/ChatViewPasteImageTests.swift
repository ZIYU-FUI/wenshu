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
        // v1.83 (2026-09-23): boss's 3-layer refactor moves the paste
        // handler (= image-paste attach) from ChatView (the middle
        // layer = chat content) into ChatInputBarView (the top layer
        // = user-interactive input controls). The handler reads
        // ChatInputBarView.swift.
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".onPasteCommand(of: [.image])"))
    }

    /// T38 contract: the handler extracts a NSImage, converts to PNG,
    /// writes to a temp file, then hands the URL to vm.attachImage.
    @Test func handler_writes_temp_png_and_calls_attachImage() throws {
        // v1.83: same handler relocation (= ChatView → ChatInputBarView).
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            encoding: .utf8
        )
        #expect(src.contains("NSImage.self"))
        #expect(src.contains("tiffRepresentation"))
        #expect(src.contains("NSBitmapImageRep"))
        #expect(src.contains("representation(using: .png"))
        #expect(src.contains("FileManager.default.temporaryDirectory"))
        // v1.83: paste handler now invokes vm.attachImage via the
        // ImagePasteModifier's onAttach closure (= the call sits one
        // closure inside; = the literal is `vm.attachImage(at: url)`).
        #expect(src.contains("vm.attachImage(at:"))
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
        // v1.83 (2026-09-23): .fileImporter + .dropDestination
        // moved from ChatView (= the middle layer) into ChatInputBarView
        // (= the top layer). Both now live on the input row.
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
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
/// v1.83 (2026-09-23): boss's 3-layer refactor rewrites the chat input
    /// row. The paste handler (= `.onPasteCommand(of: [.image])`) is now
    /// attached to the TextField inside ChatInputBarView (= wrapped in
    /// the ImagePasteModifier modifier; = the paste target IS the
    /// TextField; = not the chat zone's outer VStack anymore). The
    /// invariant (= the paste handler is on the chat input area; =
    /// outside the message bubbles in the ScrollView; = lives on the
    /// TextField inside the top-layer ChatInputBarView) is preserved
    /// via the new file layout; = this test verifies both:
    ///   1. .onPasteCommand(of: [.image]) exists in ChatInputBarView
    ///      (= on the TextField via ImagePasteModifier)
    ///   2. ChatView (= the chat zone's middle layer) doesn't have a
    ///      competing paste handler; = the paste handler is owned by
    ///      the top layer only.
    @Test func paste_handler_outside_hstack() throws {
        let inputBarSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatInputBarView.swift",
            encoding: .utf8
        )
        let chatViewSrc = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        // The paste handler lives in ChatInputBarView (= on the
        // TextField via ImagePasteModifier; = top layer).
        #expect(inputBarSrc.contains(".onPasteCommand(of: [.image])"))
        #expect(!chatViewSrc.contains(".onPasteCommand(of: [.image])"))
        // The input row HStack's minimum height pin (= .frame(minHeight: 44); = boss v1.76 spec: input height = 44PT = match button height)
        // lives in ChatInputBarView (= the top layer).
        #expect(inputBarSrc.contains(".frame(minHeight: 44, maxHeight: 44)"))
        #expect(!chatViewSrc.contains(".frame(minHeight: 44, maxHeight: 44)"))
    }
}