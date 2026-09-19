//
//  ChatMessageDayDividerPinIconTests.swift · Wenshu · T89-PIN-ICON (2026-09-18)
//
//  Verifies the "mappin.circle.fill" SF Symbol overlay
//  on today's day-divider calendar icon (= Apple HIG
//  "you are here" affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageDayDivider pin icon (T89)")
struct ChatMessageDayDividerPinIconTests {

    /// T89 contract: T89 marker comment exists.
    @Test func t89_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("// T89-PIN-ICON (2026-09-18)"))
    }

    /// T89 contract: mappin.circle.fill SF Symbol present.
    @Test func mappin_icon_present() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"mappin.circle.fill\")"))
    }

    /// T89 contract: pin uses .bold + Color.accentColor.
    @Test func pin_uses_bold_accent() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        let mappinPos = src.range(of: "Image(systemName: \"mappin.circle.fill\")")!
        let after = src[mappinPos.upperBound...]
        #expect(after.contains(".font(.system(size: 8, weight: .bold))"))
        #expect(after.contains(".foregroundStyle(Color.accentColor)"))
    }

    /// T89 contract: pin offset below the T60 star (= complementary
    /// overlay positions).
    @Test func pin_offset_below_star() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        let mappinPos = src.range(of: "Image(systemName: \"mappin.circle.fill\")")!
        let after = src[mappinPos.upperBound...]
        #expect(after.contains(".offset(x: 4, y: 4)"))
    }

    /// T89 contract: pin is INSIDE the `if isTodayLabel` branch.
    @Test func pin_inside_today_branch() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        let starPos = src.range(of: "Image(systemName: \"star.fill\")")!
        let startOffset = src.distance(from: src.startIndex, to: starPos.upperBound)
        let endOffset = min(startOffset + 1500,
                            src.distance(from: src.startIndex, to: src.endIndex))
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let block = String(src[startIdx..<endIdx])
        #expect(block.contains("Image(systemName: \"mappin.circle.fill\")"))
    }

    /// T89 contract: T60 star.fill preserved.
    @Test func t60_star_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"star.fill\")"))
        #expect(src.contains(".foregroundStyle(.yellow)"))
    }

    /// T89 contract: T83 today pulse preserved.
    @Test func t83_today_pulse_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains(".easeInOut(duration: 2.5).repeatForever(autoreverses: true)"))
    }

    /// T89 contract: T81 DividerStyle preserved.
    @Test func t81_divider_style_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageDayDivider.swift",
            encoding: .utf8
        )
        #expect(src.contains("public enum DividerStyle: String, Equatable, Sendable"))
    }
}