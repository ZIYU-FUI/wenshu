//
//  ChatMessageDayDividerDateInitTests.swift · Wenshu · T100-DATE-INIT (2026-09-18)
//
//  Verifies the Date-based convenience initializer on
//  ChatMessageDayDivider (= forward-flexibility: callers
//  can pass a Foundation Date directly without computing
//  timeIntervalSince1970).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider Date init (T100)")
struct ChatMessageDayDividerDateInitTests {

    /// T100 contract: T100 marker comment exists.
    @Test func t100_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T100-DATE-INIT (2026-09-18)"))
    }

    /// T100 contract: Date-based convenience init exists.
    @Test func date_init_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public init(date: Date, messageCount: Int? = nil, style: DividerStyle = .standard)"))
    }

    /// T100 contract: Date init delegates to the 3-arg init
    /// via timeIntervalSince1970.
    @Test func date_init_delegates_to_time_interval_init() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("self.init(timestamp: date.timeIntervalSince1970"))
    }

    /// T100 contract: 3-arg init (timestamp:messageCount:style:) preserved.
    @Test func three_arg_init_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public init(timestamp: TimeInterval, messageCount: Int? = nil, style: DividerStyle = .standard)"))
    }

    /// T100 contract: 2-arg init preserved.
    @Test func two_arg_init_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public init(timestamp: TimeInterval, messageCount: Int? = nil)"))
    }

    /// T100 contract: 1-arg init preserved.
    @Test func one_arg_init_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public init(timestamp: TimeInterval) {"))
    }

    /// T100 contract: countOnly static factory preserved.
    @Test func count_only_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public static func countOnly(_ count: Int) -> ChatMessageDayDivider"))
    }

    /// T100 contract: T36/T39/T56/T57/T60/T68/T81/T83/T89/T97/T98 prior divider treatments preserved.
    @Test func prior_treatments_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("WenshuI18n.t(\"chatview.day_divider.today\")"))
        #expect(src.contains(".fill(.ultraThinMaterial)"))
        #expect(src.contains("Image(systemName: \"calendar\")"))
        #expect(src.contains("Image(systemName: \"star.fill\")"))
        #expect(src.contains("Image(systemName: \"mappin.circle.fill\")"))
        #expect(src.contains("public enum DividerStyle: String, Equatable, Sendable"))
        #expect(src.contains(".easeInOut(duration: 2.5).repeatForever(autoreverses: true)"))
        #expect(src.contains(".foregroundStyle(.green)"))
        #expect(src.contains("// T98-FULL-DATE-TOOLTIP (2026-09-18)"))
    }
}