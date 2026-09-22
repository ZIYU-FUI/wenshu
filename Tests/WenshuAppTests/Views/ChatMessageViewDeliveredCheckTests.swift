//
//  ChatMessageViewDeliveredCheckTests.swift · Wenshu · T84-DELIVERED-CHECK (2026-09-18)
//
//  Verifies the small "checkmark" SF Symbol after the
//  timestamp text (= Apple Messages delivered/read-
//  receipt affordance).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView delivered check (T84)")
struct ChatMessageViewDeliveredCheckTests {

    /// T84 contract: source contains the T84-DELIVERED-CHECK
    /// marker comment.
    @Test func t84_marker_comment_exists() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("T84-DELIVERED-CHECK"))
    }

    /// T84 contract: checkmark SF Symbol present.
    @Test func checkmark_icon_present() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"checkmark\")"))
    }

    /// T84 contract: checkmark uses .caption2 + .quaternary
    /// (= matches T65 clock icon style).
    @Test func checkmark_uses_caption2_quaternary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        let checkPos = src.range(of: "Image(systemName: \"checkmark\")")!
        let after = src[checkPos.upperBound...]
        #expect(after.contains(".font(.caption2)"))
        #expect(after.contains(".foregroundStyle(.quaternary)"))
    }

    /// T84 contract: checkmark appears AFTER the clock icon
    /// (= T84 = after T65 = the visual flow).
    @Test func checkmark_after_clock() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        let clockPos = src.range(of: "Image(systemName: \"clock\")")!
        // T88-USER-CHECK (2026-09-18) added a 2nd
        // Image(systemName: "checkmark") in the user
        // branch (= BEFORE the timestamp clock icon's
        // checkmark). The T84 contract is specifically
        // about the timestamp-area checkmark = the one
        // that appears AFTER the clock icon. = find the
        // checkmark that appears AFTER the clock icon.
        guard let checkPos = src.range(of: "Image(systemName: \"checkmark\")", range: clockPos.upperBound..<src.endIndex) else {
            #expect(Bool(false), "expected checkmark after clock icon")
            return
        }
        #expect(checkPos.lowerBound > clockPos.lowerBound)
    }

    /// T84 contract: T65 clock icon preserved.
    @Test func t65_clock_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"clock\")"))
    }

    /// T84 contract: T72 fresh chip preserved.
    @Test func t72_fresh_chip_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageFooter.swift",
            encoding: .utf8
        )
        #expect(src.contains("· NEW"))
    }
}