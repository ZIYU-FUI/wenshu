//
//  ChatMessageViewFreshChipTests.swift · Wenshu · T72-FRESH-CHIP (2026-09-18)
//
//  Verifies the small "NEW" badge that appears next to the
//  timestamp when the message was created < 60 seconds ago
//  (= the Apple HIG "fresh content" affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView fresh chip (T72)")
struct ChatMessageViewFreshChipTests {

    /// T72 contract: source uses a "· NEW" Text in the footer.
    @Test func source_uses_new_chip_text() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Text(\"· NEW\")"))
    }

    /// T72 contract: chip gated by streamState == .sealed AND
    /// timestamp < 60s ago.
    @Test func chip_gated_on_sealed_and_recent() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if message.streamState == .sealed,\n                               Date().timeIntervalSince(message.timestamp) < 60 {"))
    }

    /// T72 contract: chip uses .caption2 + monospaced + .accentColor.
    @Test func chip_uses_caption2_monospaced_accent() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let chipPos = src.range(of: "Text(\"· NEW\")")!
        let endOffset = src.distance(from: src.startIndex, to: chipPos.upperBound) + 250
        let startOffset = src.distance(from: src.startIndex, to: chipPos.lowerBound)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let chipBlock = String(src[startIdx..<endIdx])
        #expect(chipBlock.contains(".font(.system(.caption2, design: .monospaced))"))
        #expect(chipBlock.contains(".foregroundStyle(Color.accentColor)"))
    }

    /// T72 contract: T65 clock icon preserved.
    @Test func t65_clock_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"clock\")"))
    }

    /// T72 contract: T50 timestamp tooltip preserved.
    @Test func t50_timestamp_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTimestampTooltip(for: message.timestamp))"))
    }

    /// T72 contract: T23 PLAN badge logic preserved.
    @Test func t23_plan_badge_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if case .plan = part.kind"))
    }
}