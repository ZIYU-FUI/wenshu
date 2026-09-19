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
    @Test func paste_handler_outside_hstack() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        let pastePos = src.range(of: ".onPasteCommand(of: [.image])")!
        let hstackOpenPos = src.range(of: "HStack(alignment: .center, spacing: 8) {")!
        let hstackClosePos = src.range(of: ".frame(minHeight: 30)", range: hstackOpenPos.upperBound..<src.endIndex)
        #expect(hstackClosePos != nil)
        // The paste handler must be AFTER the input HStack closes.
        #expect(pastePos.lowerBound > hstackClosePos!.lowerBound)
    }
}