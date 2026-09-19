//
//  ChatMessageViewUserSentIconTests.swift · Wenshu · T73-USER-SENT-ICON (2026-09-18)
//
//  Verifies the small "paperplane.fill" SF Symbol rendered
//  next to the source label on user-sent messages (= the
//  "sent" affordance; = mirror of T71's wenshu delivery dot).
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("ChatMessageView user sent icon (T73)")
struct ChatMessageViewUserSentIconTests {

    /// T73 contract: source uses Image(systemName: "paperplane.fill").
    @Test func source_uses_paperplane_fill() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"paperplane.fill\")"))
    }

    /// T73 contract: icon uses .system(size: 9, weight: .regular)
    /// + .secondary foregroundStyle.
    @Test func icon_uses_caption2_secondary() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        let iconPos = src.range(of: "Image(systemName: \"paperplane.fill\")")!
        let endOffset = src.distance(from: src.startIndex, to: iconPos.upperBound) + 200
        let startOffset = src.distance(from: src.startIndex, to: iconPos.lowerBound)
        let endIdx = src.index(src.startIndex, offsetBy: endOffset)
        let startIdx = src.index(src.startIndex, offsetBy: startOffset)
        let iconBlock = String(src[startIdx..<endIdx])
        #expect(iconBlock.contains(".font(.system(size: 9, weight: .regular))"))
        #expect(iconBlock.contains(".foregroundStyle(.secondary)"))
    }

    /// T73 contract: icon only renders for .user source.
    @Test func icon_gated_on_user_source() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if message.source == .user {"))
    }

    /// T73 contract: T71 status dot preserved (wenshu delivery dot).
    @Test func t71_status_dot_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("Image(systemName: \"circle.fill\")"))
        #expect(src.contains("if message.source == .wenshu {"))
    }

    /// T73 contract: T23 PLAN badge logic preserved.
    @Test func t23_plan_badge_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("if case .plan = part.kind"))
    }

    /// T73 contract: T28 PLAN badge expand logic preserved.
    @Test func t28_plan_badge_expand_preserved() throws {
        let src = try String(
            contentsOfFile: "Sources/WenshuApp/Views/Chat/ChatMessageView.swift",
            encoding: .utf8
        )
        #expect(src.contains("isPlanBadgeHovered"))
    }
}