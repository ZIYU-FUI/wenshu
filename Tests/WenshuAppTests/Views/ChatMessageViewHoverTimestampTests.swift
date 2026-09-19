//
//  ChatMessageViewHoverTimestampTests.swift · Wenshu · T26-HOVER-TIMESTAMP (2026-09-18)
//
//  Verifies the hover-expand timestamp footer contract via source
//  inspection (= SwiftUI @State value-typed views can't be introspected
//  at runtime; = source-level checks for the @State + onHover +
//  format-style wiring).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView hover timestamp (T26)")
struct ChatMessageViewHoverTimestampTests {

    /// T26 contract: @State isTimestampHovered exists (= SwiftUI
    /// tracks hover state for re-render).
    @Test func source_has_timestamp_hovered_state() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("@State private var isTimestampHovered: Bool = false"))
    }

    /// T26 contract: timestamp Text uses a computed format style
    /// (= not the literal .hour().minute() call from T19).
    @Test func timestamp_uses_computed_format() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains("format: timestampDisplayFormat"))
        #expect(source.contains("private var timestampDisplayFormat: Date.FormatStyle"))
    }

    /// T26 contract: format expands on hover (= uses .day().month()
    /// in the hovered branch).
    @Test func format_expands_on_hover() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains(".dateTime\n                .hour().minute()\n                .day().month()"))
    }

    /// T26 contract: .onHover wired to set isTimestampHovered
    /// (= SwiftUI hover affordance is the trigger).
    @Test func on_hover_wired_to_state() throws {
        let source = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(source.contains(".onHover { hovering in\n                                isTimestampHovered = hovering\n                            }"))
    }
}