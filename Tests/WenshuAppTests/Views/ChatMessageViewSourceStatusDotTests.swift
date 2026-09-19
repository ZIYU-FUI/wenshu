//
//  ChatMessageViewSourceStatusDotTests.swift · Wenshu · T71-SOURCE-STATUS-DOT (2026-09-18)
//
//  Verifies the small green status dot rendered next to the
//  source label on sealed assistant messages (= Apple
//  Messages read-receipt pattern).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView source status dot (T71)")
struct ChatMessageViewSourceStatusDotTests {

    /// T71 contract: source uses Image(systemName: "circle.fill")
    /// BEFORE the source label.
    @Test func source_uses_circle_fill() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"circle.fill\")"))
    }

    /// T71 contract: icon uses .system(size: 6, weight: .bold)
    /// + .green foregroundStyle (= small green delivery dot).
    @Test func dot_uses_green_tone() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let dotPos = src.range(of: "Image(systemName: \"circle.fill\")")!
        let labelPos = src.range(of: "Text(sourceLabel)")!
        let dotBlock = src[dotPos.lowerBound..<labelPos.lowerBound]
        #expect(dotBlock.contains(".font(.system(size: 6, weight: .bold))"))
        #expect(dotBlock.contains(".foregroundStyle(.green)"))
    }

    /// T71 contract: dot is gated by source == .wenshu (= only
    /// assistant messages get the green dot).
    @Test func dot_gated_on_wenshu_source() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if message.source == .wenshu {"))
    }

    /// T71 contract: T23 PLAN badge logic preserved.
    @Test func t23_plan_badge_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        // T23 used a hasPlanPart helper (= the closure uses
        // `if case .plan = part.kind { return true }`).
        #expect(src.contains("if case .plan = part.kind"))
    }

    /// T71 contract: T28 PLAN badge expand logic preserved.
    @Test func t28_plan_badge_expand_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("isPlanBadgeHovered"))
    }

    /// T71 contract: T65 'clock' icon footer preserved.
    @Test func t65_clock_icon_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"clock\")"))
    }

    /// T71 contract: T62 token cost preserved.
    @Test func t62_token_cost_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Self.formatTokenCost(tokens)"))
    }
}