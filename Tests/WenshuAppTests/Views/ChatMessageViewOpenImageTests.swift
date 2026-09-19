//
//  ChatMessageViewOpenImageTests.swift · Wenshu · T51-OPEN-IMAGE (2026-09-18)
//
//  Verifies that clicking a chat image thumbnail opens it
//  in Preview.app via NSWorkspace.shared.open(url) (= the
//  standard macOS "open file" affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView open image (T51)")
struct ChatMessageViewOpenImageTests {

    /// T51 contract: thumbnail is wrapped in a Button
    /// (= clickable target).
    @Test func source_wraps_thumbnail_in_button() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Button {\n                                let url = URL(fileURLWithPath: imagePath)\n                                NSWorkspace.shared.open(url)\n                            } label: {\n                                Image(nsImage: nsImage)"))
    }

    /// T51 contract: NSWorkspace.shared.open (NOT activateFileViewerSelecting)
    /// opens the image in the default app (= Preview).
    @Test func source_uses_NSWorkspace_shared_open() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("NSWorkspace.shared.open(url)"))
    }

    /// T51 contract: buttonStyle(.plain) is used (= no visual
    /// chrome around the image = the image is the only thing
    /// the user sees; = click target is invisible).
    @Test func button_uses_plain_style() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".buttonStyle(.plain)"))
    }

    /// T51 contract: T34 Reveal-in-Finder button preserved
    /// (= separate affordance; = unchanged).
    @Test func t34_reveal_in_finder_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("NSWorkspace.shared.activateFileViewerSelecting([url])"))
        #expect(src.contains("WenshuI18n.t(\"chatview.message.reveal_in_finder\")"))
    }

    /// T51 contract: imagePath still rendered (= no path removed).
    @Test func image_path_still_rendered() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if let imagePath = message.imagePath {"))
        #expect(src.contains("NSImage(contentsOfFile: imagePath)"))
    }
}