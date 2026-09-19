//
//  ChatMessageViewMicroscopeIconTests.swift · Wenshu · T116-MICROSCOPE-ICON (2026-09-18)
//
//  Verifies the small "magnifyingglass" SF Symbol rendered
//  next to the T111 flask icon for wenshu messages (= Apple
//  HIG "detailed analysis" affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView microscope icon (T116)")
struct ChatMessageViewMicroscopeIconTests {

    /// T116 contract: T116 marker comment exists.
    @Test func t116_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T116-MICROSCOPE-ICON (2026-09-18)"))
    }

    /// T116 contract: magnifyingglass SF Symbol present.
    @Test func magnifyingglass_icon_present() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"magnifyingglass\")"))
    }

    /// T116 contract: magnifyingglass uses .system(size: 9, weight: .regular).
    @Test func magnifyingglass_uses_size_9_regular() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let mgPos = src.range(of: "Image(systemName: \"magnifyingglass\")")!
        let after = src[mgPos.upperBound...]
        #expect(after.contains(".font(.system(size: 9, weight: .regular))"))
    }

    /// T116 contract: magnifyingglass uses .tertiary tone.
    @Test func magnifyingglass_uses_tertiary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let mgPos = src.range(of: "Image(systemName: \"magnifyingglass\")")!
        let after = src[mgPos.upperBound...]
        #expect(after.contains(".foregroundStyle(.tertiary)"))
    }

    /// T116 contract: magnifyingglass AFTER flask icon (= correct visual order).
    @Test func magnifyingglass_after_flask() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let flaskPos = src.range(of: "Image(systemName: \"flask.fill\")")!
        let mgPos = src.range(of: "Image(systemName: \"magnifyingglass\")")!
        #expect(mgPos.lowerBound > flaskPos.lowerBound)
    }

    /// T116 contract: T111 flask icon preserved.
    @Test func t111_flask_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T111-FLASK-ICON (2026-09-18)"))
    }

    /// T116 contract: T90 link icon preserved.
    @Test func t90_link_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T90-LINK-ICON (2026-09-18)"))
    }

    /// T116 contract: T99 user read receipt preserved.
    @Test func t99_user_read_receipt_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T99-USER-READ-RECEIPT (2026-09-18)"))
    }
}