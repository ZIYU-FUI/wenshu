//
//  ChatMessageViewClockPrefixTests.swift · Wenshu · T65-CLOCK-PREFIX (2026-09-18)
//
//  Verifies the small "clock" SF Symbol prefix on the
//  timestamp text in the sealed-message footer.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView clock prefix (T65)")
struct ChatMessageViewClockPrefixTests {

    /// T65 contract: source uses Image(systemName: "clock") in the footer.
    @Test func source_uses_clock_sf_symbol() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"clock\")"))
    }

    /// T65 contract: icon uses .caption2 + .quaternary tone.
    @Test func icon_uses_caption2_quaternary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        let iconPos = src.range(of: "Image(systemName: \"clock\")")!
        let tokenPos = src.range(of: "Text(timestamp, format: timestampDisplayFormat)")!
        let iconBlock = src[iconPos.lowerBound..<tokenPos.lowerBound]
        #expect(iconBlock.contains(".font(.caption2)"))
        #expect(iconBlock.contains(".foregroundStyle(.quaternary)"))
    }

    /// T65 contract: icon appears BEFORE the timestamp text.
    @Test func icon_appears_before_timestamp_text() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        let iconPos = src.range(of: "Image(systemName: \"clock\")")!
        let textPos = src.range(of: "Text(timestamp, format: timestampDisplayFormat)")!
        #expect(iconPos.lowerBound < textPos.lowerBound)
    }

    /// T65 contract: T50 timestamp tooltip preserved.
    @Test func t50_timestamp_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.fullTimestampTooltip(for: timestamp))"))
    }

    /// T65 contract: T26 hover timestamp logic preserved.
    @Test func t26_hover_timestamp_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("private var timestampDisplayFormat: Date.FormatStyle"))
        #expect(src.contains("isTimestampHovered = hovering"))
    }

    /// T65 contract: T53 combo tooltip preserved.
    @Test func t53_combo_tooltip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains(".help(Self.comboFooterTooltip(timestamp: timestamp, tokens: tokens))"))
    }

    /// T65 contract: T63 'number' icon preserved (= mirror pattern).
    @Test func t63_number_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"number\")"))
    }

    /// T65 contract: T64 '$' icon preserved.
    @Test func t64_dollar_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"dollarsign.circle\")"))
    }
}