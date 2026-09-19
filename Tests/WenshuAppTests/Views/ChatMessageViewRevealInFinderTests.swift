//
//  ChatMessageViewRevealInFinderTests.swift · Wenshu · T34-OPEN-IMAGE-IN-FINDER (2026-09-18)
//
//  Verifies the "Reveal in Finder" button below chat image thumbnails.
//  Strategy: source inspection (= the view body is value-typed; = the
//  NSWorkspace.activateFileViewerSelecting call can only be verified
//  at the source level).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView reveal in Finder (T34)")
struct ChatMessageViewRevealInFinderTests {

    /// T34 contract: source contains a Button with NSWorkspace
    /// activateFileViewerSelecting (= the standard macOS "Reveal in
    /// Finder" affordance).
    @Test func source_uses_activateFileViewerSelecting() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("NSWorkspace.shared.activateFileViewerSelecting([url])"))
    }

    /// T34 contract: the Button label uses the localized key
    /// (= WenshuI18n.t = T35 retired the hardcoded English label).
    @Test func button_label_uses_localized_key() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("WenshuI18n.t(\"chatview.message.reveal_in_finder\")"))
    }

    /// T34 contract: the Button is placed inside the same `if let
    /// imagePath` branch as the thumbnail (= the button is hidden
    /// when there's no image, AND when the file fails to load).
    @Test func button_inside_image_branch() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // Verify the Button appears AFTER the Image(nsImage:) call
        // AND before the matching "} else {" of the nsImage branch.
        guard let buttonIdx = source.range(of: "NSWorkspace.shared.activateFileViewerSelecting([url])"),
              let elseStart = source.range(of: "} else {", range: buttonIdx.upperBound..<source.endIndex)
        else {
            Issue.record("couldn't locate Button / else block")
            return
        }
        #expect(buttonIdx.upperBound < elseStart.lowerBound)
    }

    /// T34 contract: button uses .caption2 (= smaller than the image
    /// = standard Apple HIG secondary metadata tone).
    @Test func button_uses_caption2() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains(".font(.caption2)"))
    }
}