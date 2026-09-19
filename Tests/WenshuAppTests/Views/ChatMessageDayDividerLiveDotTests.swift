//
//  ChatMessageDayDividerLiveDotTests.swift · Wenshu · T97-LIVE-DOT (2026-09-18)
//
//  Verifies the small "circle.fill" SF Symbol overlay
//  on today's day-divider calendar icon (= Apple HIG
//  "live/now" affordance; = marks today as currently
//  happening).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider live dot (T97)")
struct ChatMessageDayDividerLiveDotTests {

    /// T97 contract: T97 marker comment exists.
    @Test func t97_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T97-LIVE-DOT (2026-09-18)"))
    }

    /// T97 contract: circle.fill SF Symbol present in the today branch.
    @Test func live_dot_circle_present() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        let mappinPos = src.range(of: "Image(systemName: \"mappin.circle.fill\")")!
        let startOffset = src.distance(from: src.startIndex, to: mappinPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("Image(systemName: \"circle.fill\")"))
    }

    /// T97 contract: live dot uses .system(size: 5, weight: .bold).
    @Test func live_dot_uses_size_5_bold() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        // Find the 3rd Image(systemName: "circle.fill") (= T97's live
        // dot, after T60's star and... wait, star is "star.fill", not
        // "circle.fill"). Use the comment marker as the anchor.
        let t97MarkerPos = src.range(of: "T97-LIVE-DOT (2026-09-18)")!
        let after = src[t97MarkerPos.upperBound..<src.endIndex]
        #expect(after.contains(".font(.system(size: 5, weight: .bold))"))
    }

    /// T97 contract: live dot uses Color.green (= the universal live color).
    @Test func live_dot_uses_green() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        let t97MarkerPos = src.range(of: "T97-LIVE-DOT (2026-09-18)")!
        let after = src[t97MarkerPos.upperBound..<src.endIndex]
        #expect(after.contains(".foregroundStyle(.green)"))
    }

    /// T97 contract: live dot offset to bottom-left (= -3, 3 = bottom-left).
    @Test func live_dot_offset_bottom_left() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        let t97MarkerPos = src.range(of: "T97-LIVE-DOT (2026-09-18)")!
        let after = src[t97MarkerPos.upperBound..<src.endIndex]
        #expect(after.contains(".offset(x: -3, y: 3)"))
    }

    /// T97 contract: T60 star.fill preserved.
    @Test func t60_star_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"star.fill\")"))
        #expect(src.contains(".foregroundStyle(.yellow)"))
    }

    /// T97 contract: T89 mappin.circle.fill preserved.
    @Test func t89_mappin_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"mappin.circle.fill\")"))
    }

    /// T97 contract: T83 today-pulse preserved.
    @Test func t83_today_pulse_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".easeInOut(duration: 2.5).repeatForever(autoreverses: true)"))
    }
}