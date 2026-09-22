//
//  ChatMessageTimestampTests.swift · Wenshu · T19-MESSAGE-TIMESTAMP (2026-09-18)
//
//  Verifies that ChatMessageView renders a small timestamp footer
//  below sealed assistant messages. The view body is hard to
//  introspect at runtime (= SwiftUI Value-typed view); = verify
//  via source inspection (= the timestamp Text(...) call should
//  exist and be gated on streamState == .sealed + source == .wenshu).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView timestamp footer (T19)")
struct ChatMessageTimestampTests {

    /// T19 contract: ChatMessageView source contains the timestamp
    /// Text(...) call gated on sealed + wenshu.
    @Test func source_contains_timestamp_text() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        // The .dateTime.hour().minute() format string is canonical
        // Date.FormatStyle (= Apple HIG small footer pattern).
        #expect(source.contains(".dateTime.hour().minute()"))
    }

    /// T19 contract: timestamp is conditional on streamState == .sealed
    /// (= hidden during streaming).
    @Test func timestamp_only_for_sealed() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("message.streamState == .sealed"))
    }

    /// T19 contract: timestamp is conditional on source == .wenshu
    /// (= only assistant messages, not user/system).
    @Test func timestamp_only_for_wenshu() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("message.source == .wenshu"))
    }

    /// T19 contract: timestamp Text uses .caption2 + .tertiary
    /// (= Apple HIG "secondary metadata" tone).
    @Test func timestamp_uses_caption2_tertiary() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(source.contains(".font(.caption2)"))
        #expect(source.contains(".foregroundStyle(.tertiary)"))
    }
}