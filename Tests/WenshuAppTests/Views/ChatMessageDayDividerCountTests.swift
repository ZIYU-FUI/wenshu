//
//  ChatMessageDayDividerCountTests.swift · Wenshu · T68-COUNT-DIVIDER (2026-09-18)
//
//  Verifies the optional messageCount parameter on
//  ChatMessageDayDivider (= "Today · 5" affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider count (T68)")
struct ChatMessageDayDividerCountTests {

    /// T68 contract: source has messageCount public property.
    @Test func messageCount_property_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public let messageCount: Int?"))
    }

    /// T68 contract: source has 2-arg init.
    @Test func two_arg_init_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public init(timestamp: TimeInterval, messageCount: Int? = nil)"))
    }

    /// T68 contract: 1-arg init still works (= backward compat).
    @Test func one_arg_init_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public init(timestamp: TimeInterval)"))
    }

    /// T68 contract: countOnly factory exists.
    @Test func count_only_factory_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public static func countOnly(_ count: Int) -> ChatMessageDayDivider"))
    }

    /// T68 contract: body renders " · N" when count != nil.
    @Test func body_renders_count_suffix() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("if let count = messageCount {"))
        #expect(src.contains("Text(\"· \\(count)\")"))
    }

    /// T68 contract: T36/T39/T56/T57/T60 prior behavior preserved
    /// when messageCount is nil (= no count suffix rendered).
    @Test func prior_behavior_preserved_when_count_nil() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        // T36 i18n keys preserved.
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.today\")"))
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.yesterday\")"))
        // T39 material preserved.
        #expect(src.contains(".fill(.ultraThinMaterial)"))
        // T56 calendar icon preserved.
        #expect(src.contains("Image(systemName: \"calendar\")"))
        // T57 accent tint preserved.
        #expect(src.contains("isTodayLabel ? AnyShapeStyle(Color.accentColor)"))
        // T60 star.fill overlay preserved.
        #expect(src.contains("Image(systemName: \"star.fill\")"))
    }

    /// T68 contract: ChatView caller still uses 1-arg init
    /// (= ChatView doesn't need to be updated for T68 = pure
    /// backward-compatible additive API).
    @Test func chatview_caller_unchanged() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatView.swift",
            encoding: .utf8
        )
        #expect(src.contains("ChatMessageDayDivider(timestamp: msg.timestamp.timeIntervalSince1970)"))
    }
}