//
//  ChatMessageDayDividerStyleTests.swift · Wenshu · T81-DIVIDER-STYLE (2026-09-18)
//
//  Verifies the DividerStyle enum on ChatMessageDayDivider
//  (= .standard / .compact styles for forward-flexibility).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider style (T81)")
struct ChatMessageDayDividerStyleTests {

    /// T81 contract: DividerStyle enum exists with .standard + .compact.
    @Test func style_enum_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public enum DividerStyle: String, Equatable, Sendable"))
        #expect(src.contains("case standard"))
        #expect(src.contains("case compact"))
    }

    /// T81 contract: style public let exists.
    @Test func style_property_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public let style: DividerStyle"))
    }

    /// T81 contract: 3-arg init with style default exists.
    @Test func three_arg_init_with_style_default() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public init(timestamp: TimeInterval, messageCount: Int? = nil, style: DividerStyle = .standard)"))
    }

    /// T81 contract: 2-arg init preserved (backward compat).
    @Test func two_arg_init_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public init(timestamp: TimeInterval, messageCount: Int? = nil)"))
    }

    /// T81 contract: 1-arg init preserved (backward compat).
    @Test func one_arg_init_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public init(timestamp: TimeInterval) {"))
    }

    /// T81 contract: T36/T39/T56/T57/T60/T68 prior behavior preserved
    /// when style is .standard (= default).
    @Test func prior_behavior_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.today\")"))
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.yesterday\")"))
        #expect(src.contains(".fill(.ultraThinMaterial)"))
        #expect(src.contains("Image(systemName: \"calendar\")"))
        #expect(src.contains("Image(systemName: \"star.fill\")"))
        #expect(src.contains(".joined(separator: \" · \")") || src.contains("· \\(count)"))
    }

    /// T81 contract: ChatView caller still uses 1-arg init (= no
    /// ChatView changes = pure additive API).
    @Test func chatview_caller_unchanged() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains("ChatMessageDayDivider(timestamp: msg.timestamp.timeIntervalSince1970)"))
    }
}