//
//  ChatMessageViewFlaskIconTests.swift · Wenshu · T111-FLASK-ICON (2026-09-18)
//
//  Verifies the small "flask.fill" SF Symbol rendered
//  next to the T90 link icon for wenshu messages (= Apple
//  HIG "experiment/test" affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView flask icon (T111)")
struct ChatMessageViewFlaskIconTests {

    /// T111 contract: T111 marker comment exists.
    @Test func t111_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T111-FLASK-ICON (2026-09-18)"))
    }

    /// T111 contract: flask.fill SF Symbol present.
    @Test func flask_icon_present() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"flask.fill\")"))
    }

    /// T111 contract: flask uses .system(size: 9, weight: .regular).
    @Test func flask_uses_size_9_regular() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let flaskPos = src.range(of: "Image(systemName: \"flask.fill\")")!
        let after = src[flaskPos.upperBound...]
        #expect(after.contains(".font(.system(size: 9, weight: .regular))"))
    }

    /// T111 contract: flask uses .tertiary tone.
    @Test func flask_uses_tertiary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let flaskPos = src.range(of: "Image(systemName: \"flask.fill\")")!
        let after = src[flaskPos.upperBound...]
        #expect(after.contains(".foregroundStyle(.tertiary)"))
    }

    /// T111 contract: flask AFTER link icon.
    @Test func flask_after_link() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let linkPos = src.range(of: "Image(systemName: \"link\")")!
        let flaskPos = src.range(of: "Image(systemName: \"flask.fill\")")!
        #expect(flaskPos.lowerBound > linkPos.lowerBound)
    }

    /// T111 contract: T90 link icon preserved.
    @Test func t90_link_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T90-LINK-ICON (2026-09-18)"))
    }

    /// T111 contract: T75 brain icon preserved.
    @Test func t75_brain_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"brain.head.profile\")"))
    }

    /// T111 contract: T99 user read receipt preserved.
    @Test func t99_user_read_receipt_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T99-USER-READ-RECEIPT (2026-09-18)"))
    }
}